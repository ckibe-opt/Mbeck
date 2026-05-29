import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  console.log("🔧 ADD COLUMN FUNCTION V2 CALLED!")
  
  try {
    // Initialize Supabase client with service role key for admin operations
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      db: {
        schema: 'public'
      }
    })

    // Try to add the column using a simple approach
    // First, let's see if we can query the table structure
    const { data: existingData, error: checkError } = await supabase
      .from('transactions')
      .select('*')
      .limit(1)

    if (checkError && checkError.code === 'PGRST116') {
      // Table doesn't exist, create it
      console.log('Creating transactions table...')
      const { error: createError } = await supabase
        .from('transactions')
        .insert({
          id: 'temp',
          shop_id: 'temp',
          source_module: 'retail',
          total_amount: 0,
          type: 'sale',
          created_at: new Date().toISOString()
        })

      if (createError) {
        console.error('❌ Create table error:', createError)
        return new Response(JSON.stringify({ 
          error: 'Failed to create table',
          details: createError.message 
        }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' }
        })
      }

      // Delete the temp record
      await supabase
        .from('transactions')
        .delete()
        .eq('id', 'temp')
    } else if (checkError) {
      console.error('❌ Check error:', checkError)
      return new Response(JSON.stringify({ 
        error: 'Failed to check table',
        details: checkError.message 
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Check if source_module column exists by trying to select it
    const { data, error: columnError } = await supabase
      .from('transactions')
      .select('source_module')
      .limit(1)

    if (columnError && columnError.message?.includes('source_module')) {
      console.log('Column does not exist, need to add it manually')
      return new Response(JSON.stringify({ 
        error: 'Column missing',
        message: 'source_module column does not exist. Please add it manually via Supabase Dashboard.',
        sql: 'ALTER TABLE transactions ADD COLUMN source_module TEXT DEFAULT \'retail\';'
      }), {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        status: 200
      })
    }

    console.log('✅ source_module column exists')
    
    return new Response(JSON.stringify({ 
      success: true,
      message: 'source_module column already exists'
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
