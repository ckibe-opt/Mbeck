import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Supabase Authentication Service for Phone OTP & Google OAuth
/// 
/// Handles user authentication via phone number + OTP,
/// Google sign-in, secure token storage, and offline biometric login.
class SupabaseAuthService {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'supabase_access_token';
  static const _refreshTokenKey = 'supabase_refresh_token';
  static const _userIdKey = 'supabase_user_id';
  static const _phoneKey = 'user_phone_number';
  
  /// Sign in with Google using native Google Sign-In + Supabase
  /// Returns AuthResponse with user session on success
  static Future<AuthResponse?> signInWithGoogle() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Google OAuth Web Client ID (from Google Cloud Console)
      const webClientId = '872769674263-6c0iiuh90l4af7piknns8a80j0u8kqne.apps.googleusercontent.com';
      
      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ Google Sign-In cancelled by user');
        return null;
      }
      
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      
      if (idToken == null) {
        debugPrint('❌ No ID token from Google Sign-In');
        return null;
      }
      
      // Sign in to Supabase with Google credentials
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      
      if (response.session != null) {
        await _storeSession(response.session!);
        debugPrint('✅ Google Sign-In successful: ${response.user?.email}');
        return response;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Google Sign-In failed: $e');
      return null;
    }
  }
  
  /// Send OTP to phone number
  /// Returns true if OTP sent successfully
  static Future<bool> sendOTP(String phoneNumber) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Validate phone number format (E.164: +254712345678)
      if (!phoneNumber.startsWith('+')) {
        throw Exception('Phone number must be in E.164 format (e.g., +254712345678)');
      }
      
      await supabase.auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: true, // Auto-create user if new
      );
      
      debugPrint('✅ OTP sent to $phoneNumber');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send OTP: $e');
      return false;
    }
  }
  
  /// Verify OTP and complete sign-in
  /// Returns AuthResponse with user session
  static Future<AuthResponse?> verifyOTP(String phoneNumber, String token) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase.auth.verifyOTP(
        phone: phoneNumber,
        token: token,
        type: OtpType.sms,
      );
      
      if (response.session != null) {
        // Store tokens securely
        await _storeSession(response.session!);
        debugPrint('✅ OTP verified, user logged in: ${response.user?.id}');
        return response;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ OTP verification failed: $e');
      return null;
    }
  }
  
  /// Store session tokens securely
  static Future<void> _storeSession(Session session) async {
    await _storage.write(
      key: _accessTokenKey,
      value: session.accessToken,
      aOptions: const AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
    
    await _storage.write(
      key: _refreshTokenKey,
      value: session.refreshToken,
    );
    
    if (session.user.id != null) { // ignore: unnecessary_null_comparison
      await _storage.write(key: _userIdKey, value: session.user.id);
    }
    
    if (session.user.phone != null) {
      await _storage.write(key: _phoneKey, value: session.user.phone!);
    }
  }
  
  /// Get currently authenticated user
  static Future<User?> getCurrentUser() async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      
      if (session != null) {
        return session.user;
      }
      
      // Try to restore session from secure storage
      final accessToken = await _storage.read(key: _accessTokenKey);
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      
      if (accessToken != null && refreshToken != null) {
        // Attempt to refresh session
        final response = await supabase.auth.setSession(refreshToken);
        if (response.session != null) {
          await _storeSession(response.session!);
          return response.session!.user;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Failed to get current user: $e');
      return null;
    }
  }
  
  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final user = await getCurrentUser();
    return user != null;
  }
  
  /// Get stored phone number
  static Future<String?> getStoredPhoneNumber() async {
    return await _storage.read(key: _phoneKey);
  }
  
  /// Sign out and clear stored tokens
  static Future<void> signOut() async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.signOut();
      
      // Clear secure storage
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _userIdKey);
      await _storage.delete(key: _phoneKey);
      
      debugPrint('✅ User signed out');
    } catch (e) {
      debugPrint('❌ Sign out failed: $e');
    }
  }
  
  /// Authenticate with biometrics (for offline login)
  /// Returns true if biometric authentication succeeds
  static Future<bool> authenticateWithBiometrics() async {
    try {
      final localAuth = LocalAuthentication();
      
      // Check if device supports biometrics
      if (!await localAuth.canCheckBiometrics) {
        debugPrint('⚠️ Device does not support biometrics');
        return false;
      }
      
      // Check available biometrics
      final availableBiometrics = await localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        debugPrint('⚠️ No biometrics enrolled');
        return false;
      }
      
      // Attempt authentication
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Verify your identity to access mbeck Seller',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      if (authenticated) {
        debugPrint('✅ Biometric authentication successful');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Biometric authentication failed: $e');
      return false;
    }
  }
  
  /// Refresh access token (automatically called by Supabase)
  /// Called when access token expires (every 1 hour by default)
  static Future<Session?> refreshSession() async {
    try {
      final supabase = Supabase.instance.client;
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      
      if (refreshToken == null) {
        debugPrint('⚠️ No refresh token found');
        return null;
      }
      
      final response = await supabase.auth.setSession(refreshToken);
      if (response.session != null) {
        await _storeSession(response.session!);
        debugPrint('✅ Session refreshed');
        return response.session;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Session refresh failed: $e');
      return null;
    }
  }

  /// Check if the user has a Google account linked
  static bool isGoogleLinked(User? user) {
    if (user == null) return false;
    return user.identities?.any((id) => id.provider == 'google') ?? false;
  }

  /// Get the email of the linked Google identity
  static String? getGoogleLinkedEmail(User? user) {
    if (user == null) return null;
    final identities = user.identities;
    if (identities == null) return null;
    for (final identity in identities) {
      if (identity.provider == 'google') {
        return identity.identityData?['email'] as String?;
      }
    }
    return null;
  }

  /// Link Google Account with Native OAuth + Redirect Fallback
  static Future<void> linkGoogleAccount() async {
    try {
      const webClientId = '872769674263-6c0iiuh90l4af7piknns8a80j0u8kqne.apps.googleusercontent.com';
      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In cancelled by user');
      }
      
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      
      if (idToken == null) {
        throw Exception('No ID token from Google Sign-In');
      }
      
      final supabase = Supabase.instance.client;
      await supabase.auth.linkIdentityWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (nativeError) {
      debugPrint('⚠️ Native Google link failed, falling back to browser redirect: $nativeError');
      final supabase = Supabase.instance.client;
      await supabase.auth.linkIdentity(OAuthProvider.google);
    }
  }

  /// Unlink Google Account with Lockout Prevention
  static Future<void> unlinkGoogleAccount() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }
    
    final identities = user.identities ?? [];
    if (identities.length < 2) {
      throw Exception(
        'Cannot unlink Google account. You must keep at least one login method '
        'linked to prevent account lockout.'
      );
    }
    
    final googleIdentity = identities.firstWhere(
      (id) => id.provider == 'google',
      orElse: () => throw Exception('Google account is not linked'),
    );
    
    await supabase.auth.unlinkIdentity(googleIdentity);
  }
}
