import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mbeck_modules/mbeck_modules.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/db_provider.dart';
import 'screens/home_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/import_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/business_type_selector.dart';
import 'screens/onboarding/quick_setup_screen.dart';
import 'widgets/sync_lifecycle_listener.dart';
import 'widgets/module_guard.dart';
import 'services/sync_service.dart';
import 'services/realtime_service.dart';
import 'services/auth_service.dart';
import 'services/onboarding_service.dart';
import 'theme/design_system.dart';
import 'services/background_shop_service.dart';
import 'services/home_widget_service.dart';
import 'services/waiter_ring_service.dart';
import 'screens/auth/shop_selection_screen.dart';
import 'services/revenuecat_service.dart';
import 'services/analytics_service.dart';

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:ui';
import 'firebase_options.dart';

bool _firebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load .env file
  await dotenv.load(fileName: ".env");

  // Initialize Firebase (Crashlytics & Analytics)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    await FirebaseAnalytics.instance.logAppOpen();
    AnalyticsService.firebaseInitialized = true;
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    _firebaseInitialized = true;
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }

  // Register available modules
  _registerModules();
  
  // Preload module selections for synchronous access
  await ModuleHelper.preload();
  
  // Initialize SQLite for Desktop
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Supabase early so it's ready for AuthWrapper
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://mmnnrydehabyokygyxpo.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tbm5yeWRlaGFieW9reWd5eHBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1OTM5NTEsImV4cCI6MjA4NTE2OTk1MX0.vSwuvySp8wlSXOXPskGmCMyT6BMZ1WMmsRZwX-Mo3Qo';
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await SyncService.init(supabaseUrl, supabaseAnonKey);
  }

  // 🚀 Run app FIRST so the splash screen renders immediately (<200ms)
  // DB init and background services are deferred to run while splash is visible
  runApp(const MyApp());

  // Heavy startup tasks run in background while splash screen is displayed
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeBackgroundServices();
  });
}

/// Initialize services that are not required for the first frame.
/// Called after runApp() so the splash screen renders immediately.
Future<void> _initializeBackgroundServices() async {
  try {
    // 1. DB migrations first — splash screen waits for this via AuthWrapper
    await DbProvider.init();

    // 2. Realtime sync (Supabase is already initialized)
    RealtimeService.init();

    // 3. RevenueCat (Google Play Billing)
    RevenueCatService.init();

    // 4. Background Service (Shop Server)
    BackgroundShopService.initialize();

    // 5. Seed home screen widget
    HomeWidgetService.seedShopName();

    // 6. Start polling for waiter rings
    WaiterRingService.instance.startPolling();

    // 7. Listen for home screen widget toggle taps
    HomeWidgetService.startListening();
    
    debugPrint('🚀 All background services initialized');
  } catch (e) {
    debugPrint('⚠️ Error initializing background services: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SyncLifecycleListener(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mbeck Business',
        theme: AppTheme.lightTheme,
        navigatorObservers: [
          if (_firebaseInitialized)
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
        ],
        initialRoute: '/',
        routes: {
          '/': (_) => const AuthWrapper(),
          '/home': (_) => const HomeScreen(),
          '/shop_selection': (_) => const ShopSelectionScreen(),
          '/customers': (_) => const CustomersScreen(),
          '/import': (_) => const ImportScreen(),
          '/signup': (_) => const SignUpScreen(),
          '/welcome': (_) => const WelcomeScreen(),
          '/onboarding': (_) => const BusinessTypeSelectorScreen(),
          '/quick_setup': (_) => const QuickSetupScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Show ultra-premium SplashScreen first — it resolves destination in background
    return SplashScreen(
      resolveDestination: () async {
        final state = await _determineStartScreen();
        switch (state) {
          case _AuthState.welcome:
            return const WelcomeScreen();
          case _AuthState.signup:
            return const SignUpScreen();
          case _AuthState.shopSelection:
            return const ShopSelectionScreen();
          case _AuthState.onboarding:
            return const BusinessTypeSelectorScreen();
          case _AuthState.quickSetup:
            return const QuickSetupScreen();
          case _AuthState.home:
            return const HomeScreen();
        }
      },
    );
  }

  static Future<_AuthState> _determineStartScreen() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check if welcome carousel has been seen
    final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;
    if (!hasSeenWelcome) {
      await prefs.setBool('has_seen_welcome', true);
      return _AuthState.welcome;
    }

    // 2. Check if authenticated (has shop ID)
    final isAuth = await AuthService.isAuthenticated();
    if (!isAuth) {
      // Check if has cloud session but no local shop
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return _AuthState.shopSelection;
        }
      } catch (_) {}
      return _AuthState.signup;
    }

    // 3. Check if onboarding (module selection) is complete
    final onboardingDone = await OnboardingService.isComplete();
    if (!onboardingDone) {
      return _AuthState.onboarding;
    }

    // 4. Check if quick setup wizard is complete
    final setupDone = prefs.getBool('setup_wizard_complete') ?? false;
    if (!setupDone) {
      return _AuthState.quickSetup;
    }

    // 5. All done → HomeScreen
    return _AuthState.home;
  }
}

enum _AuthState {
  welcome,
  signup,
  shopSelection,
  onboarding,
  quickSetup,
  home,
}

/// Register all available modules with the ModuleRegistry.
/// 
/// This is called at startup before any module-dependent code runs.
/// Add new modules here as they are implemented.
void _registerModules() {
  debugPrint(' Registering modules...');
  
  // Register all available modules
  ModuleRegistry.instance.registerAll([
    RetailModule(),
    RestaurantModule(),
    ServicesModule(),
    EntertainmentModule(),
    LodgingModule(),
  ]);
  
  debugPrint(' Registered ${ModuleRegistry.instance.allModules.length} module(s)');
}
