# Deploy sync-events Edge Function - Manual Instructions

The `sync-events` Edge Function has been created but needs to be deployed to your Supabase project to fix the hash mismatch errors.

## Prerequisites

1. **Install Supabase CLI** (if not already installed):
   ```bash
   # Using npm
   npm install -g supabase
   
   # Or using yarn
   yarn global add supabase
   
   # Or using homebrew (macOS)
   brew install supabase/tap/supabase
   ```

2. **Login to Supabase**:
   ```bash
   supabase login
   ```

3. **Link to your project**:
   ```bash
   supabase link --project-ref mmnnrydehabyokygyxpo
   ```

## Deployment Steps

1. **Navigate to project directory**:
   ```bash
   cd "c:\Users\chege\.windsurf\worktrees\Mbeckapp_seller\Mbeckapp_seller-4ab538ed"
   ```

2. **Deploy the function**:
   ```bash
   supabase functions deploy sync-events
   ```

3. **Verify deployment**:
   ```bash
   supabase functions list
   ```

## Test the Function

After deployment, test the function with curl:

```bash
curl -X POST 'https://mmnnrydehabyokygyxpo.supabase.co/functions/v1/sync-events' \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tbm5yeWRlaGFieW9reWd5eHBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1OTM5NTEsImV4cCI6MjA4NTE2OTk1MX0.vSwuvySp8wlSXOXPskGmCMyT6BMZ1WMmsRZwX-Mo3Qo" \
  -H "Content-Type: application/json" \
  -d '[{"id":"test-123","event_type":"TEST","payload":{"message":"test"},"payload_raw":"{\"message\":\"test\"}","hash":"abc123","shop_id":"shop_test","device_id":"device_test","timestamp":1234567890}]'
```

## What the Function Does

The `sync-events` Edge Function:

1. **Receives batch of events** from the Flutter app
2. **Validates each event's hash** using the same algorithm as the client
3. **Checks for duplicates** (idempotent operations)
4. **Inserts valid events** into the `events` table
5. **Returns detailed response** with success/failure counts

## Expected Results

After successful deployment:

✅ **No more hash_mismatch errors** in the Flutter app logs
✅ **Events sync successfully** to Supabase
✅ **Entertainment & lodging modules** sync their data to cloud
✅ **All module data appears** in respective cloud tables

## Troubleshooting

If deployment fails:

1. **Check Supabase CLI version**: `supabase --version`
2. **Verify project linkage**: `supabase projects list`
3. **Check function logs**: `supabase functions logs sync-events`

If still getting hash mismatches:

1. **Check Supabase logs** for the function
2. **Verify environment variables** are set correctly
3. **Test with simple payload** first

## Files Created

- `supabase/functions/sync-events/index.ts` - Main Edge Function
- `supabase/functions/sync-events/deno.json` - Deno configuration
- Updated `lib/main.dart` to use .env file instead of hardcoded credentials

Once deployed, restart your Flutter app and the hash mismatch errors should be resolved! 🚀
