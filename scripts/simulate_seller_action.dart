import 'dart:io';
import 'package:supabase/supabase.dart';

// Standalone Simulator for Seller Analytics
// Verifies that the 'analytics_demand_unmet' view is working.

void main(List<String> args) async {
  // Manual Env Load
  final env = <String, String>{};
  try {
    final lines = File('.env').readAsLinesSync();
    for (var line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      final parts = line.split('=');
      if (parts.length >= 2) {
        env[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }
  } catch (e) {
    print('⚠️ Could not read .env: $e');
  }

  final supabaseUrl = env['SUPABASE_URL'] ?? Platform.environment['SUPABASE_URL'];
  // Use Service Role to ensure we can read the view (simulating Auth Seller)
  final supabaseKey = env['SUPABASE_SERVICE_ROLE_KEY'] ?? Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (supabaseUrl == null || supabaseKey == null) {
    print('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return;
  }

  print('🚀 Starting Seller Analytics Simulation...');
  
  try {
    final client = SupabaseClient(supabaseUrl, supabaseKey);

    print('\n📈 Fetching "Market Pulse" (Unmet Demand)...');
    
    final response = await client
        .from('analytics_demand_unmet')
        .select()
        .limit(10);
        
    if (response.isEmpty) {
      print('   ⚠️ No unmet demand found. (Did you search for something that returned 0 results?)');
      
      // Let's generate some fake unmet demand
      print('   🌱 Generating fake unmet demand (Search for "Unobtainium")...');
      await client.from('search_logs').insert({
        'query_text': 'Unobtainium',
        'results_count': 0,
        'device_id': 'sim_seller_1',
        'created_at': DateTime.now().toIso8601String(),
      });
      print('   ✅ Logged "Unobtainium". Re-fetching...');
      
      final retry = await client
        .from('analytics_demand_unmet')
        .select()
        .limit(10);
        
      _printResults(retry);
      
    } else {
      _printResults(response);
    }
    
  } catch (e) {
    print('\n❌ Simulation Failed: $e');
    if (e.toString().contains('42P01')) {
      print('   (Hint: Relation does not exist -> Apply migration_v27!)');
    }
  }
}

void _printResults(List<dynamic> data) {
  print('   ✅ Found ${data.length} demand clusters:');
  for (var item in data) {
    print('      - "${item['query_text']}" : ${item['demand_count']} buyers missed this.');
  }
}
