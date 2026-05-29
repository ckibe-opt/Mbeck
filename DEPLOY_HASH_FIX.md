# Manual Hash Fix Deployment Instructions

## Step 1: Access Supabase Dashboard
1. Go to https://supabase.com/dashboard
2. Sign in to your account
3. Select your project: `mmnnrydehabyokygyxpo`

## Step 2: Navigate to Edge Functions
1. In the left sidebar, click on **"Edge Functions"**
2. Find and click on the **"sync-events"** function

## Step 3: Update the Function Code
1. Click **"Edit"** on the sync-events function
2. **Delete all existing code** in the editor
3. **Copy and paste** the entire updated code from:
   `supabase/functions/sync-events/index.ts`

## Step 4: Save and Deploy
1. Click **"Save"** to save the changes
2. Click **"Deploy"** to deploy the updated function
3. Wait for deployment to complete (should show "Deployed successfully")

## Step 5: Verify the Fix
1. Go back to your Flutter app
2. Create a booking status change or any event
3. Check the logs - you should see:
   ```
   🔍 Hash Debug - Event: [event-id]
   ✅ Hash verified for event [event-id]
   ```
4. Events should now sync successfully without hash mismatches

## What the Fix Does:
- Adds proper canonical JSON encoding to match client-side
- Fixes hash calculation to be identical between client and server
- Maintains event integrity validation
- Includes debug logging for troubleshooting

## Expected Result:
- ✅ No more "hash_mismatch" errors
- ✅ Events sync successfully to cloud
- ✅ Two-way sync works properly
