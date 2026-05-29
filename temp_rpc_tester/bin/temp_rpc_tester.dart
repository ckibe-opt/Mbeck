import 'dart:convert';
import 'package:supabase/supabase.dart';

void main() async {
  print('📡 Testing Vector RPC (Isolated)...');

  const supabaseUrl = 'https://mmnnrydehabyokygyxpo.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tbm5yeWRlaGFieW9reWd5eHBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1OTM5NTEsImV4cCI6MjA4NTE2OTk1MX0.vSwuvySp8wlSXOXPskGmCMyT6BMZ1WMmsRZwX-Mo3Qo';

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  final List<double> dummyVector = List.generate(1280, (index) => 0.01);
  
  // Attempt 1: jsonEncode
  print("\n➤ Attempt 1: Using jsonEncode(vector)...");
  try {
    final response = await client.rpc(
      'match_global_vectors',
      params: {
        'query_embedding': jsonEncode(dummyVector), 
        'match_threshold': 0.1,
        'match_count': 1,
      },
    );
    // In newer dart supabase, response is the data directly
    print("   ✅ Attempt 1 Success! Data: $response");
  } catch (e) {
    print("   ❌ Attempt 1 Failed: $e");
  }

  // Attempt 2: Raw List
  print("\n➤ Attempt 2: Sending raw List<double>...");
  try {
    final response = await client.rpc(
      'match_global_vectors',
      params: {
        'query_embedding': dummyVector, 
        'match_threshold': 0.1,
        'match_count': 1,
      },
    );
    print("   ✅ Attempt 2 Success! Data: $response");
  } catch (e) {
    print("   ❌ Attempt 2 Failed: $e");
  }
}
