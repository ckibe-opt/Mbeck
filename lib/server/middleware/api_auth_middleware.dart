import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:flutter/foundation.dart';

/// API Authentication Middleware
/// 
/// Provides token-based authentication for the local shop server.
/// - Session tokens are generated on handshake (/api/v1/info)
/// - Protected endpoints require valid token in Authorization header
/// - Tokens expire after 24 hours
/// - Rate limiting: 10 requests/minute per IP on protected endpoints

class ApiAuthMiddleware {
  // In-memory session store: token -> SessionData
  static final Map<String, _SessionData> _sessions = {};
  
  // Rate limiting: IP -> list of request timestamps
  static final Map<String, List<DateTime>> _rateLimitMap = {};
  
  // Configuration
  static const int tokenExpiryHours = 24;
  static const int maxRequestsPerMinute = 10;
  static const int rateLimitWindowSeconds = 60;
  
  /// Generate a new session token for a client
  /// Called during /api/v1/info handshake
  static String generateToken({
    String? clientId,
    String? clientIp,
    String? role,
  }) {
    // Generate random token
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    final token = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    
    // Store session
    _sessions[token] = _SessionData(
      token: token,
      clientId: clientId,
      clientIp: clientIp,
      role: role ?? 'buyer',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(hours: tokenExpiryHours)),
    );
    
    debugPrint('🔐 Generated session token for $clientIp (role: $role)');
    return token;
  }
  
  /// Validate a token from the Authorization header
  /// Returns the session data if valid, null otherwise
  static _SessionData? validateToken(String? authHeader) {
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }
    
    final token = authHeader.substring(7); // Remove 'Bearer ' prefix
    final session = _sessions[token];
    
    if (session == null) {
      debugPrint('⚠️ Invalid token: not found');
      return null;
    }
    
    if (DateTime.now().isAfter(session.expiresAt)) {
      debugPrint('⚠️ Token expired');
      _sessions.remove(token);
      return null;
    }
    
    return session;
  }
  
  /// Check rate limit for an IP address
  /// Returns true if request is allowed, false if rate limited
  static bool checkRateLimit(String? clientIp) {
    if (clientIp == null) return true; // Allow if IP unknown
    
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(seconds: rateLimitWindowSeconds));
    
    // Get or create request list for this IP
    _rateLimitMap[clientIp] ??= [];
    final requests = _rateLimitMap[clientIp]!;
    
    // Remove old requests outside the window
    requests.removeWhere((time) => time.isBefore(windowStart));
    
    // Check if limit exceeded
    if (requests.length >= maxRequestsPerMinute) {
      debugPrint('⚠️ Rate limit exceeded for $clientIp');
      return false;
    }
    
    // Add current request
    requests.add(now);
    return true;
  }
  
  /// Middleware handler for protected endpoints
  /// Use this to wrap handlers that require authentication
  static Middleware requireAuth({bool checkRate = false}) {
    return (Handler innerHandler) {
      return (Request request) async {
        final authHeader = request.headers['authorization'];
        final session = validateToken(authHeader);
        
        if (session == null) {
          return Response.unauthorized(
            '{"error": "Invalid or missing authentication token"}',
            headers: {'Content-Type': 'application/json'},
          );
        }
        
        // Check rate limit if enabled
        if (checkRate) {
          final connectionInfo = request.context['shelf.io.connection_info'];
          final clientIp = request.headers['x-forwarded-for'] ?? 
                          (connectionInfo != null ? (connectionInfo as dynamic).remoteAddress.address : 'unknown');
          if (!checkRateLimit(clientIp)) {
            return Response(
              429, // Too Many Requests
              body: '{"error": "Rate limit exceeded. Try again in 1 minute."}',
              headers: {'Content-Type': 'application/json'},
            );
          }
        }
        
        // Add session to request context for downstream handlers
        final updatedRequest = request.change(
          context: {
            ...request.context,
            'session': session,
            'clientRole': session.role,
          },
        );
        
        return innerHandler(updatedRequest);
      };
    };
  }
  
  /// Middleware that checks for Observer (Ghost) mode
  /// Blocks write operations for observers
  static Middleware blockObservers() {
    return (Handler innerHandler) {
      return (Request request) async {
        final session = request.context['session'] as _SessionData?;
        
        if (session?.role == 'observer') {
          return Response.forbidden(
            '{"error": "Observers cannot perform write operations"}',
            headers: {'Content-Type': 'application/json'},
          );
        }
        
        return innerHandler(request);
      };
    };
  }
  
  /// Clean up expired sessions (call periodically)
  static void cleanupExpiredSessions() {
    final now = DateTime.now();
    _sessions.removeWhere((_, session) => now.isAfter(session.expiresAt));
    debugPrint('🧹 Cleaned up expired sessions. Active: ${_sessions.length}');
  }
  
  /// Get session count (for debugging)
  static int get activeSessionCount => _sessions.length;
}

/// Internal class to hold session data
class _SessionData {
  final String token;
  final String? clientId;
  final String? clientIp;
  final String role;
  final DateTime createdAt;
  final DateTime expiresAt;
  
  _SessionData({
    required this.token,
    this.clientId,
    this.clientIp,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
  });
}
