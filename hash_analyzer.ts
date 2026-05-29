import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// Canonical JSON encoding (same as client)
function encodeCanonical(obj: any): string {
  if (obj === null || obj === undefined) return 'null'
  if (typeof obj === 'string') return JSON.stringify(obj)
  if (typeof obj === 'number' || typeof obj === 'boolean') return String(obj)
  if (Array.isArray(obj)) {
    return '[' + obj.map(item => encodeCanonical(item)).join(',') + ']'
  }
  if (typeof obj === 'object') {
    const keys = Object.keys(obj).sort()
    const pairs = keys.map(key => JSON.stringify(key) + ':' + encodeCanonical(obj[key]))
    return '{' + pairs.join(',') + '}'
  }
  return 'null'
}

// Hash calculation (same as client)
async function calculateHash(id: string, eventType: string, payload: any, timestamp: number, shopId: string, deviceId: string): Promise<string> {
  const crypto = globalThis.crypto || (globalThis as any).webcrypto
  const encoder = new TextEncoder()
  
  const payloadRaw = encodeCanonical(payload)
  const hashInput = `${id}|${eventType}|${payloadRaw}|${timestamp}|${shopId}|${deviceId}`
  
  console.log(`🔍 Hash Input: ${hashInput}`)
  console.log(`🔍 Payload Raw: ${payloadRaw}`)
  
  const data = encoder.encode(hashInput)
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}

serve(async (req) => {
  console.log("🔥 HASH ANALYZER FUNCTION CALLED!")
  
  try {
    const events = await req.json()
    console.log(`📥 Received ${events.length} events`)
    
    const results = {
      inserted_count: 0,
      skipped_count: 0,
      errors: []
    }

    // Process each event with hash analysis
    for (const event of events) {
      try {
        console.log(`🔍 Analyzing Event: ${event.id}`)
        console.log(`  Client Hash: ${event.hash}`)
        console.log(`  Event Type: ${event.event_type}`)
        console.log(`  Shop ID: ${event.shop_id}`)
        console.log(`  Device ID: ${event.device_id}`)
        console.log(`  Timestamp: ${event.timestamp} (${typeof event.timestamp})`)
        console.log(`  Payload: ${JSON.stringify(event.payload)}`)
        
        // Calculate what the hash SHOULD be
        const calculatedHash = await calculateHash(
          event.id,
          event.event_type,
          event.payload,
          event.timestamp,
          event.shop_id,
          event.device_id
        )
        
        console.log(`  Calculated Hash: ${calculatedHash}`)
        console.log(`  Hashes Match: ${event.hash === calculatedHash}`)
        
        if (event.hash !== calculatedHash) {
          console.log(`❌ HASH MISMATCH DETECTED!`)
          console.log(`  Client: ${event.hash}`)
          console.log(`  Server: ${calculatedHash}`)
          
          results.errors.push({ 
            id: event.id, 
            error: `Hash mismatch: client=${event.hash}, server=${calculatedHash}`
          })
        } else {
          console.log(`✅ Hash matches, trying database insert...`)
          
          // Try with service role key
          const supabaseUrl = Deno.env.get('SUPABASE_URL')!
          const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
          const supabase = createClient(supabaseUrl, supabaseServiceKey)
          
          const { error } = await supabase
            .from('events')
            .insert({
              id: event.id,
              event_type: event.event_type,
              payload: event.payload,
              payload_raw: encodeCanonical(event.payload),
              hash: calculatedHash,
              shop_id: event.shop_id,
              device_id: event.device_id,
              timestamp: event.timestamp
            })

          if (error) {
            console.error(`❌ Database still rejects with correct hash:`, error)
            results.errors.push({ 
              id: event.id, 
              error: `Database rejected correct hash: ${error.message}`
            })
          } else {
            results.inserted_count++
            console.log(`✅ Successfully inserted event ${event.id}`)
          }
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
