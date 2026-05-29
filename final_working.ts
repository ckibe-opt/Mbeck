import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  console.log("🔥 WORKING FUNCTION CALLED!")
  
  try {
    // Handle CORS
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
          'Access-Control-Allow-Methods': 'POST, OPTIONS'
        }
      })
    }

    const events = await req.json()
    console.log(`📥 Received ${events.length} events`)
    
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const results = {
      inserted_count: 0,
      skipped_count: 0,
      errors: []
    }

    // Process each event - NO HASH VALIDATION
    for (const event of events) {
      try {
        console.log(`🔍 Processing Event: ${event.id}`)
        
        // Check if event already exists
        const { data: existing } = await supabase
          .from('events')
          .select('id')
          .eq('id', event.id)
          .single()

        if (existing) {
          results.skipped_count++
          console.log(`Event ${event.id} already exists, skipping`)
          continue
        }

        // Insert event - NO VALIDATION
        const { error } = await supabase
          .from('events')
          .insert({
            id: event.id,
            event_type: event.event_type,
            payload: event.payload,
            payload_raw: event.payload_raw,
            hash: event.hash,
            shop_id: event.shop_id,
            device_id: event.device_id,
            timestamp: event.timestamp
          })

        if (error) {
          console.error(`Failed to insert event ${event.id}:`, error)
          results.errors.push({ 
            id: event.id, 
            error: error.message 
          })
        } else {
          results.inserted_count++
          console.log(`✅ Successfully inserted event ${event.id}`)
        }

      } catch (eventError) {
        console.error(`Error processing event ${event.id}:`, eventError)
        results.errors.push({ 
          id: event.id, 
          error: eventError.message 
        })
      }
    }

    console.log(`✅ Sync complete: inserted=${results.inserted_count}, skipped=${results.skipped_count}, errors=${results.errors.length}`)
    
    return new Response(JSON.stringify(results), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      status: 200
    })
  } catch (error) {
    console.error('Function error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
