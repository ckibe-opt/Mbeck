import 'dart:io';
import 'dart:convert';

void main() async {
  final baseUrl = 'http://localhost:8080/api/v1';
  final client = HttpClient();

  print('📡 Testing Mbeck Local API...');

  // 1. Info / Handshake
  try {
    print('\n➤ Testing /info (Handshake)...');
    final req = await client.getUrl(Uri.parse('$baseUrl/info'));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    
    if (res.statusCode == 200) {
      print('✅ Success: $body');
    } else {
      print('❌ Failed: ${res.statusCode} $body');
      exit(1);
    }
  } catch (e) {
    print('❌ Connection Error: $e');
    exit(1);
  }

  // 2. Checkout
  try {
    print('\n➤ Testing /cart/checkout (Sales)...');
    final req = await client.postUrl(Uri.parse('$baseUrl/cart/checkout'));
    req.headers.contentType = ContentType.json;
    
    final payload = jsonEncode({
      "items": [
        {"id": 1, "qty": 1}
      ],
      "meta": "Agent-Debug-Test-Dart"
    });
    
    req.write(payload);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    
    if (res.statusCode == 200) {
      final json = jsonDecode(body);
      print('✅ Success: Transaction ID: ${json['transactionId']}');
      print('   Signature: ${json['signature']}');
    } else {
      print('❌ Failed: ${res.statusCode} $body');
    }
  } catch (e) {
    print('❌ Checkout Error: $e');
  } finally {
    client.close();
  }
}
