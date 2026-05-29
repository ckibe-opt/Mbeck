import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

// Test Script for Phase 2: Vector RPC Verification
// Goal: Confirm that 'match_global_vectors' accepts our parameter format.

void main() async {
  print('📡 Testing Vector RPC...');

  // Manual Env Load (Copied for simplicity)
  const supabaseUrl = 'https://mmnnrydehabyokygyxpo.supabase.co';
  // Use Service Role Key if possible to bypass RLS, or Anon if logic permits public read
  // For this test, we use Anon as defined in policy "Public read access global vectors"
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tbm5yeWRlaGFieW9reWd5eHBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1OTM5NTEsImV4cCI6MjA4NTE2OTk1MX0.vSwuvySp8wlSXOXPskGmCMyT6BMZ1WMmsRZwX-Mo3Qo';

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    final client = Supabase.instance.client;

    // 1. Create a dummy 1280-dim vector
    final List<double> dummyVector = List.generate(1280, (index) => 0.01);
    
    // 2. Test RPC Call (Mirroring VectorSyncService logic)
    // Attempt 1: Using jsonEncode (Current Logic)
    print("   ➤ Attempt 1: Using jsonEncode(vector)...");
    try {
      final response = await client.rpc(
        'match_global_vectors',
        params: {
          'query_embedding': jsonEncode(dummyVector), 
          'match_threshold': 0.1, // Low threshold to ensure match if data exists
          'match_count': 1,
        },
      );
      print("   ✅ Attempt 1 Success! Response: ${response.length} matches.");
    } catch (e) {
      print("   ❌ Attempt 1 Failed: $e");
      
      // Attempt 2: Sending raw List (If 1 fails)
      print("   ➤ Attempt 2: Sending raw List<double>...");
      try {
        final response = await client.rpc(
          'match_global_vectors',
          params: {
            'query_embedding': dummyVector, 
            'match_threshold': 0.1,
            'match_count': 1,
          },
        );
        print("   ✅ Attempt 2 Success! Response: ${response.length} matches.");
        print("   💡 REMEDY: Update VectorSyncService to use raw List.");
      } catch (e2) {
        print("   ❌ Attempt 2 Failed: $e2");
      }
    }

  } catch (e) {
    print('❌ Initialization Error: $e');
  }
}
