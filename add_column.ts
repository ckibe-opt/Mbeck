import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  console.log("🔧 ADD COLUMN FUNCTION CALLED!")
  
  try {
    // Initialize Supabase client with service role key for admin operations
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Add the missing source_module column to transactions table
    const { error } = await supabase.rpc('exec_sql', {
      sql: `
        ALTER TABLE transactions 
        ADD COLUMN IF NOT EXISTS source_module TEXT DEFAULT 'retail';
        
        -- Update existing rows to have a default value
        UPDATE transactions 
        SET source_module = 'retail' 
        WHERE source_module IS NULL;
      `
    })

    if (error) {
      console.error('❌ SQL Error:', error)
      return new Response(JSON.stringify({ 
        error: 'Failed to add column',
        details: error.message 
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log('✅ Successfully added source_module column')
    
    return new Response(JSON.stringify({ 
      success: true,
      message: 'source_module column added successfully'
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      status: 200
    })
  } catch (error) {
    console.error('❌ Function error:', error)
    return new Response(JSON.stringify({ 
      error: error.message 
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
