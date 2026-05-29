import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  console.log("🔧 ADD ALL COLUMNS FUNCTION CALLED!")
  
  try {
    // Initialize Supabase client with service role key for admin operations
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Check what columns exist by trying to select them
    const { data, error: columnError } = await supabase
      .from('transactions')
      .select('source_module, type')
      .limit(1)

    if (columnError) {
      console.log('Column check error:', columnError.message)
      
      // Parse the error to see which columns are missing
      const missingColumns = []
      if (columnError.message?.includes('source_module')) {
        missingColumns.push('source_module')
      }
      if (columnError.message?.includes('type')) {
        missingColumns.push('type')
      }

      return new Response(JSON.stringify({ 
        error: 'Columns missing',
        message: 'The following columns are missing from the transactions table:',
        missingColumns: missingColumns,
        sql: missingColumns.map(col => `ALTER TABLE transactions ADD COLUMN ${col} TEXT DEFAULT 'retail';`).join('\n')
      }), {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        status: 200
      })
    }

    console.log('✅ All required columns exist')
    
    return new Response(JSON.stringify({ 
      success: true,
      message: 'All required columns (source_module, type) already exist'
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
