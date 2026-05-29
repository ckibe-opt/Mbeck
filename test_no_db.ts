import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  console.log("🔥 NO DB TEST FUNCTION CALLED!")
  
  try {
    const events = await req.json()
    console.log(`📥 Received ${events.length} events`)
    
    // Return success without touching database
    const response = {
      inserted_count: events.length,
      skipped_count: 0,
      errors: []
    }
    
    console.log(`✅ FAKE SUCCESS: ${JSON.stringify(response)}`)
    
    return new Response(JSON.stringify(response), {
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
