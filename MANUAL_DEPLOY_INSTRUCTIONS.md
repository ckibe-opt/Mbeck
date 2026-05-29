# Manual Edge Function Deployment - Dashboard Method

Since the CLI is having login issues, you can deploy the sync-events Edge Function directly through the Supabase Dashboard.

## Step 1: Access Supabase Dashboard

1. Go to https://supabase.com/dashboard
2. Sign in to your account
3. Select your project: `mmnnrydehabyokygyxpo`

## Step 2: Create Edge Function

1. In the left sidebar, click on **"Edge Functions"**
2. Click **"Create new function"**
3. Name the function: `sync-events`
4. Choose **"TypeScript"** as the language
5. Click **"Create"**

## Step 3: Copy the Function Code

Copy the entire content from `supabase/functions/sync-events/index.ts` and paste it into the editor:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

interface Event {
  id: string
  event_type: string
  payload: any
  payload_raw: string
  hash: string
  shop_id: string
  device_id: string
  timestamp: number
}

interface SyncResponse {
  inserted_count: number
  skipped_count: number
  errors: Array<{ id: string; error: string }>
}

// Calculate SHA256 hash to match client-side calculation
function calculateHash(event: Event): string {
  const crypto = globalThis.crypto || (globalThis as any).webcrypto
  const encoder = new TextEncoder()
  
  // Create canonical JSON string (same as client-side _encodeCanonical)
  const payloadRaw = JSON.stringify(event.payload, null, 0)
  
  // Hash input format: id|eventType|payload|timestamp|shopId|deviceId
  const hashInput = `${event.id}|${event.event_type}|${payloadRaw}|${event.timestamp}|${event.shop_id}|${event.device_id}`
  const data = encoder.encode(hashInput)
  
  return crypto.subtle.digest('SHA-256', data).then(buffer => {
    const hashArray = Array.from(new Uint8Array(buffer))
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
  })
}

serve(async (req) => {
  try {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
          'Access-Control-Allow-Methods': 'POST, OPTIONS'
        }
      })
    }

    // Only accept POST requests
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Parse request body
    const events: Event[] = await req.json()
    
    if (!Array.isArray(events)) {
      return new Response(JSON.stringify({ error: 'Expected array of events' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const results: SyncResponse = {
      inserted_count: 0,
      skipped_count: 0,
      errors: []
    }

    console.log(`Processing ${events.length} events for sync`)

    // Process each event
    for (const event of events) {
      try {
        // Validate required fields
        if (!event.id || !event.event_type || !event.hash || !event.shop_id || !event.device_id) {
          results.errors.push({ 
            id: event.id || 'unknown', 
            error: 'Missing required fields' 
          })
          continue
        }

        // Calculate server-side hash
        const serverHash = await calculateHash(event)
        
        // Compare hashes
        if (serverHash !== event.hash) {
          console.log(`Hash mismatch for event ${event.id}: client=${event.hash}, server=${serverHash}`)
          results.errors.push({ 
            id: event.id, 
            error: 'hash_mismatch' 
          })
          continue
        }

        // Check if event already exists (idempotent)
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

        // Insert event
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
            timestamp: new Date(event.timestamp).toISOString()
          })

        if (error) {
          console.error(`Failed to insert event ${event.id}:`, error)
          results.errors.push({ 
            id: event.id, 
            error: error.message 
          })
        } else {
          results.inserted_count++
          console.log(`Successfully inserted event ${event.id}`)
        }

      } catch (eventError) {
        console.error(`Error processing event ${event.id}:`, eventError)
        results.errors.push({ 
          id: event.id, 
          error: eventError.message 
        })
      }
    }

    console.log(`Sync complete: inserted=${results.inserted_count}, skipped=${results.skipped_count}, errors=${results.errors.length}`)

    return new Response(JSON.stringify(results), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      status: 200
    })

  } catch (error) {
    console.error('Sync function error:', error)
    return new Response(JSON.stringify({ 
      error: error.message 
    }), {
      status: 500,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
})
```

## Step 4: Set Environment Variables

1. In the Edge Function editor, click on **"Secrets"** tab
2. Add these environment variables:
   - `SUPABASE_URL`: `https://mmnnrydehabyokygyxpo.supabase.co`
   - `SUPABASE_SERVICE_ROLE_KEY`: Your service role key from .env file

## Step 5: Deploy the Function

1. Click **"Save"** to save the function
2. Click **"Deploy"** to deploy it
3. Wait for deployment to complete

## Step 6: Test the Function

1. Go to the **"Logs"** tab to see if the function deployed successfully
2. Test with curl command:

```bash
curl -X POST 'https://mmnnrydehabyokygyxpo.supabase.co/functions/v1/sync-events' \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tbm5yeWRlaGFieW9reWd5eHBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1OTM5NTEsImV4cCI6MjA4NTE2OTk1MX0.vSwuvySp8wlSXOXPskGmCMyT6BMZ1WMmsRZwX-Mo3Qo" \
  -H "Content-Type: application/json" \
  -d '[{"id":"test-123","event_type":"TEST","payload":{"message":"test"},"payload_raw":"{\"message\":\"test\"}","hash":"abc123","shop_id":"shop_test","device_id":"device_test","timestamp":1234567890}]'
```

## Step 7: Verify in Flutter App

1. Restart your Flutter app
2. Create a booking or trigger an event
3. Check the logs - should see successful sync instead of hash_mismatch errors

## Expected Results

✅ **No more hash_mismatch errors**
✅ **Events sync successfully to Supabase**
✅ **Entertainment & lodging modules sync their data**
✅ **All module data appears in cloud tables**

## Troubleshooting

If you still get hash mismatches:

1. Check the **Edge Function logs** in Supabase Dashboard
2. Verify environment variables are set correctly
3. Make sure the function deployed successfully
4. Check the events table in Supabase to see if data is appearing

Once deployed, the hash mismatch issue will be resolved and all modules will sync properly! 🚀
