import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:provider/provider.dart';
import 'providers/starred_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/shop_session_provider.dart';
import 'screens/main_app_shell.dart';
import 'services/auth_service.dart';
import 'theme/buyer_theme.dart';
import 'renderers/design_initializer.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Use a minimal setup for fast boot
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const BuyerApp());
}

class BuyerApp extends StatefulWidget {
  const BuyerApp({super.key});

  @override
  State<BuyerApp> createState() => _BuyerAppState();
}

class _BuyerAppState extends State<BuyerApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Heavy lifting moved here
    // Initialize Supabase
    const supabaseUrl = 'https://mmnnrydehabyokygyxpo.supabase.co';
    const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tbm5yeWRlaGFieW9reWd5eHBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1OTM5NTEsImV4cCI6MjA4NTE2OTk1MX0.vSwuvySp8wlSXOXPskGmCMyT6BMZ1WMmsRZwX-Mo3Qo';

    await Supabase.initialize(
      url: supabaseUrl, 
      anonKey: supabaseAnonKey,
    );

    // Initialize auth
    await AuthService.init();

    // Register designs
    registerAllDesigns();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ShopSessionProvider()),
        ChangeNotifierProvider(create: (_) => StarredProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: !_isInitialized 
        ? const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            debugShowCheckedModeBanner: false,
          )
        : Consumer<ShopSessionProvider>(
            builder: (context, session, child) {
              final themeConfig = session.currentShopTheme;
              final theme = themeConfig != null 
                  ? BuyerTheme.create(themeConfig) 
                  : BuyerTheme.lightTheme();
                  
              return MaterialApp(
                title: 'Mbeck Go',
                theme: theme,
                home: const MainAppShell(),
                debugShowCheckedModeBanner: false,
              );
            },
          ),
    );
  }
}
