import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/main.dart' as app;

void main() async {
  await Supabase.initialize(
    url: app.supabaseUrl,
    anonKey: app.supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
  final res = await client.from('marketplace_items').select().limit(5);
  print(res);
}
