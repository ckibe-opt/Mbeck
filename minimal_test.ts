import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  console.log("🔥 MINIMAL TEST FUNCTION CALLED!")
  
  try {
    const events = await req.json()
    console.log(`📥 Received ${events.length} events`)
    
    const response = {
      inserted_count: events.length,
      skipped_count: 0,
      errors: []
    }
    
    console.log(`✅ Returning success: ${JSON.stringify(response)}`)
    
    return new Response(JSON.stringify(response), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      status: 200
    })
  } catch (error) {
    console.log(`❌ Error: ${error.message}`)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
