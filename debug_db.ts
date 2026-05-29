import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  console.log("🔥 DEBUG DB FUNCTION CALLED!")
  
  try {
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

    // Process each event with detailed logging
    for (const event of events) {
      try {
        console.log(`🔍 Processing Event: ${event.id}`)
        console.log(`  Shop ID: ${event.shop_id}`)
        console.log(`  Event Type: ${event.event_type}`)
        
        // Check if event already exists
        console.log(`  Checking if event exists...`)
        const { data: existing, error: checkError } = await supabase
          .from('events')
          .select('id')
          .eq('id', event.id)
          .single()

        if (checkError) {
          console.log(`  Check error: ${checkError.message}`)
        }

        if (existing) {
          results.skipped_count++
          console.log(`  Event ${event.id} already exists, skipping`)
          continue
        }

        console.log(`  Event doesn't exist, attempting insert...`)
        
        // Try to insert event
        const { data, error } = await supabase
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
          .select()

        console.log(`  Insert result - Data: ${JSON.stringify(data)}`)
        console.log(`  Insert result - Error: ${JSON.stringify(error)}`)

        if (error) {
          console.error(`❌ Database error for event ${event.id}:`, error)
          
          // Check if it's a hash validation error
          if (error.message && error.message.includes('hash_mismatch')) {
            console.log(`⚠️  Hash validation failed in database trigger!`)
            console.log(`🚨 EVENT WAS NOT INSERTED - Database rejected it`)
            results.errors.push({ 
              id: event.id, 
              error: `Database hash validation failed: ${error.message}`
            })
          } else {
            results.errors.push({ 
              id: event.id, 
              error: `Database error: ${error.message}`
            })
          }
        } else {
          results.inserted_count++
          console.log(`✅ Successfully inserted event ${event.id}`)
        }

      } catch (eventError) {
        console.error(`❌ Error processing event ${event.id}:`, eventError)
        results.errors.push({ 
          id: event.id, 
          error: `Processing error: ${eventError.message}`
        })
      }
    }

    console.log(`🏁 Final Results: inserted=${results.inserted_count}, skipped=${results.skipped_count}, errors=${results.errors.length}`)
    
    return new Response(JSON.stringify(results), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      status: 200
    })
  } catch (error) {
    console.error('❌ Function error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
