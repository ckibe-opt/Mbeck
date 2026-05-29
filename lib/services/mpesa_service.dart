import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MpesaService {
  // Credentials from .env
  static String get _consumerKey => dotenv.env['MPESA_CONSUMER_KEY'] ?? '';
  static String get _consumerSecret => dotenv.env['MPESA_CONSUMER_SECRET'] ?? '';
  static String get _passKey => dotenv.env['MPESA_PASSKEY'] ?? '';
  static String get _shortCode => dotenv.env['MPESA_SHORTCODE'] ?? '174379';
  static String get _callbackUrl => dotenv.env['MPESA_CALLBACK_URL'] ?? '';
  static bool get _isSandbox => (dotenv.env['MPESA_ENVIRONMENT'] ?? 'sandbox') == 'sandbox';

  // Endpoints
  static String get _baseUrl => _isSandbox 
      ? 'https://sandbox.safaricom.co.ke'
      : 'https://api.safaricom.co.ke';
  
  static String get _authEndpoint => '$_baseUrl/oauth/v1/generate?grant_type=client_credentials';
  static String get _stkPushEndpoint => '$_baseUrl/mpesa/stkpush/v1/processrequest';
  static String get _queryStatusEndpoint => '$_baseUrl/mpesa/stkpushquery/v1/query';

  // Cached token
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  /// Generate or retrieve valid Access Token
  static Future<String> _getAccessToken() async {
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    if (_consumerKey.isEmpty || _consumerSecret.isEmpty) {
      throw Exception('M-Pesa Consumer Key/Secret not configured in .env');
    }

    final bytes = utf8.encode('$_consumerKey:$_consumerSecret');
    final basicAuth = base64.encode(bytes);

    try {
      final response = await http.get(
        Uri.parse(_authEndpoint),
        headers: {'Authorization': 'Basic $basicAuth'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        // Token valid for 3599 seconds, cache for 50 mins safely
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
        return _accessToken!;
      } else {
        throw Exception('Auth Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('⚠️ M-Pesa Auth Error: $e');
      rethrow;
    }
  }

  /// Generate Password (Base64(Shortcode + Passkey + Timestamp))
  static String _generatePassword(String timestamp) {
    if (_passKey.isEmpty) throw Exception('M-Pesa Passkey missing');
    final bytes = utf8.encode('$_shortCode$_passKey$timestamp');
    return base64.encode(bytes);
  }

  /// Format phone number to 254...
  static String _formatPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'\s+'), '').replaceAll('+', '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '254${cleanPhone.substring(1)}';
    }
    return cleanPhone;
  }

  /// Initiate STK Push
  static Future<Map<String, dynamic>> initiateSTKPush({
    required String phoneNumber,
    required double amount,
    required String accountReference,
    required String transactionDesc,
  }) async {
    try {
      final token = await _getAccessToken();
      final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
      final password = _generatePassword(timestamp);
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      // Amount must be int string (no decimals for most APIs, but int check is safer)
      final amountStr = amount.toInt().toString();

      final payload = {
        "BusinessShortCode": _shortCode,
        "Password": password,
        "Timestamp": timestamp,
        "TransactionType": "CustomerPayBillOnline", // Or CustomerBuyGoodsOnline
        "Amount": amountStr,
        "PartyA": formattedPhone,
        "PartyB": _shortCode,
        "PhoneNumber": formattedPhone,
        "CallBackURL": _callbackUrl,
        "AccountReference": accountReference,
        "TransactionDesc": transactionDesc
      };

      debugPrint('🚀 Sending STK Push to $formattedPhone for KES $amountStr');
      debugPrint('Example Payload: $payload');

      final response = await http.post(
        Uri.parse(_stkPushEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      final result = json.decode(response.body);
      
      if (response.statusCode == 200 && result['ResponseCode'] == '0') {
        debugPrint('✅ STK Push Initiated: ${result['CheckoutRequestID']}');
        return {
          'success': true,
          'checkoutRequestId': result['CheckoutRequestID'],
          'merchantRequestId': result['MerchantRequestID'],
          'customerMessage': result['CustomerMessage']
        };
      } else {
        debugPrint('❌ STK Push Failed: ${result['errorMessage'] ?? result['ResponseDescription']}');
        return {
          'success': false,
          'error': result['errorMessage'] ?? result['ResponseDescription'] ?? 'STK Push Failed',
          'errorCode': result['errorCode'] ?? result['ResponseCode']
        };
      }
    } catch (e) {
      debugPrint('⚠️ STK Push Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Query Transaction Status
  static Future<Map<String, dynamic>> querySTKStatus({
    required String checkoutRequestId,
  }) async {
    try {
      final token = await _getAccessToken();
      final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
      final password = _generatePassword(timestamp);

      final payload = {
        "BusinessShortCode": _shortCode,
        "Password": password,
        "Timestamp": timestamp,
        "CheckoutRequestID": checkoutRequestId
      };

      final response = await http.post(
        Uri.parse(_queryStatusEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      final result = json.decode(response.body);
      
      if (response.statusCode == 200 && result['ResponseCode'] == '0') {
        return {
          'success': true,
          'resultCode': result['ResultCode'],
          'resultDesc': result['ResultDesc']
        };
      } else {
        return {
          'success': false,
          'error': result['errorMessage'] ?? 'Status check failed',
          'errorCode': result['errorCode']
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
