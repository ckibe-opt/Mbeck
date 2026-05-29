# 🎯 Comprehensive Feature Implementation Brief

## Overview
This document outlines the implementation requirements for fixing critical bugs, implementing multi-user authentication with role-based access control (RBAC), and establishing a proper subscription/monetization system for the myShop POS application.

---

## 🐛 PRIORITY 1: Critical Bug Fixes

### Issue 1: Incorrect Revenue Display (CRITICAL)
**Current Behavior:**
- 3 transactions totaling KSH 14,150
- Dashboard shows KSH 141.50 (off by factor of 100)

**Root Cause Analysis Required:**
```dart
// Investigate these potential issues:
1. Database storage: Are amounts stored in cents vs shillings?
2. Display formatting: Is there a division by 100 happening?
3. Aggregation query: Is the SUM() function working correctly?
4. Data type: Is there a float/int conversion issue?
```

**Expected Fix:**
```dart
// In home_screen.dart or wherever dashboard metrics are calculated

// BEFORE (likely buggy code):
final revenue = transactions.fold(0, (sum, txn) => sum + txn['amount']) / 100;

// AFTER (corrected):
final revenue = transactions.fold(0, (sum, txn) => sum + txn['amount']);
// Amounts should already be in shillings (e.g., 5000 = KSH 5,000)
```

**Testing Checklist:**
- [ ] Create 3 test sales: KSH 5,000, KSH 4,150, KSH 5,000
- [ ] Verify dashboard shows exactly KSH 14,150
- [ ] Check database to confirm amounts are stored correctly
- [ ] Test with different transaction types (sale, income, expense)
- [ ] Verify historical data displays correctly

---

### Issue 2: Inconsistent Screen Title Visibility

**Current Behavior:**
- "Business Reports" title is clearly visible
- "Transaction History" and "Customers" titles are barely visible/invisible

**Root Cause:**
Inconsistent AppBar styling across screens.

**Solution:**
Create a standardized AppBar widget:

```dart
// lib/widgets/standard_app_bar.dart

import 'package:flutter/material.dart';

class StandardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool centerTitle;
  final Widget? leading;

  const StandardAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.centerTitle = false,
    this.leading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      backgroundColor: backgroundColor ?? Colors.white,
      foregroundColor: foregroundColor ?? Colors.black87,
      elevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      // Add subtle bottom border
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.grey.shade200,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}
```

**Implementation:**
Replace all AppBars across the app:

```dart
// Example: transaction_history_screen.dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: StandardAppBar(
      title: 'Transaction History',
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterMenu,
        ),
      ],
    ),
    body: ...,
  );
}
```

---

## 👤 PRIORITY 2: Multi-User Authentication & Business Ownership

### User Journey Overview

```
New Install
    ↓
Sign Up / Link to Existing Shop
    ↓
┌─────────────────┬─────────────────┐
│  Create Shop    │   Join Shop     │
│  (Admin)        │   (Staff)       │
└─────────────────┴─────────────────┘
    ↓                   ↓
Set Business Name    Enter Shop ID
Set Password        (or Scan QR Code)
    ↓                   ↓
Generate Shop ID     Enter Password
    ↓                Enter Your Name
Dashboard             ↓
(Shows Business     Dashboard
 Name in AppBar)    (Shows Business
                     Name in AppBar)
```

---

### Database Schema Updates

#### New Table: `shops`
```sql
CREATE TABLE shops (
  id TEXT PRIMARY KEY, -- shop_TIMESTAMP_RANDOM
  business_name TEXT NOT NULL,
  password_hash TEXT NOT NULL, -- bcrypt hash
  owner_device_id TEXT NOT NULL,
  subscription_tier TEXT DEFAULT 'FREE', -- FREE, PRO, ENTERPRISE
  subscription_status TEXT DEFAULT 'ACTIVE', -- ACTIVE, SUSPENDED, CANCELLED
  joined_at TIMESTAMP DEFAULT NOW(),
  trial_ends_at TIMESTAMP, -- Auto-set to joined_at + 90 days
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

#### New Table: `shop_members`
```sql
CREATE TABLE shop_members (
  id SERIAL PRIMARY KEY,
  shop_id TEXT REFERENCES shops(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  user_name TEXT NOT NULL,
  role TEXT DEFAULT 'STAFF', -- OWNER, ADMIN, STAFF
  permissions JSONB DEFAULT '{}', -- Flexible permissions storage
  joined_at TIMESTAMP DEFAULT NOW(),
  last_active_at TIMESTAMP,
  is_active BOOLEAN DEFAULT TRUE,
  UNIQUE(shop_id, device_id)
);

-- Index for fast lookups
CREATE INDEX idx_shop_members_shop ON shop_members(shop_id);
CREATE INDEX idx_shop_members_device ON shop_members(device_id);
```

#### Update Existing Tables
```sql
-- Add shop_id to existing tables
ALTER TABLE events ADD COLUMN shop_id TEXT;
ALTER TABLE txn ADD COLUMN shop_id TEXT;
ALTER TABLE inventory ADD COLUMN shop_id TEXT;
ALTER TABLE customer ADD COLUMN shop_id TEXT;
ALTER TABLE accounting ADD COLUMN shop_id TEXT;

-- Create indexes
CREATE INDEX idx_events_shop ON events(shop_id);
CREATE INDEX idx_txn_shop ON txn(shop_id);
CREATE INDEX idx_inventory_shop ON inventory(shop_id);
```

---

### Flutter Implementation

#### Step 1: Authentication Flow

```dart
// lib/models/shop.dart

class Shop {
  final String id;
  final String businessName;
  final String ownerDeviceId;
  final String subscriptionTier; // FREE, PRO, ENTERPRISE
  final String subscriptionStatus; // ACTIVE, SUSPENDED, CANCELLED
  final DateTime joinedAt;
  final DateTime? trialEndsAt;

  Shop({
    required this.id,
    required this.businessName,
    required this.ownerDeviceId,
    required this.subscriptionTier,
    required this.subscriptionStatus,
    required this.joinedAt,
    this.trialEndsAt,
  });

  bool get isOnTrial {
    if (trialEndsAt == null) return false;
    return DateTime.now().isBefore(trialEndsAt!);
  }

  bool get hasProAccess {
    return subscriptionTier == 'PRO' || 
           subscriptionTier == 'ENTERPRISE' || 
           isOnTrial;
  }

  int get trialDaysRemaining {
    if (trialEndsAt == null) return 0;
    final diff = trialEndsAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'],
      businessName: map['business_name'],
      ownerDeviceId: map['owner_device_id'],
      subscriptionTier: map['subscription_tier'] ?? 'FREE',
      subscriptionStatus: map['subscription_status'] ?? 'ACTIVE',
      joinedAt: DateTime.parse(map['joined_at']),
      trialEndsAt: map['trial_ends_at'] != null 
          ? DateTime.parse(map['trial_ends_at']) 
          : null,
    );
  }
}
```

```dart
// lib/models/shop_member.dart

class ShopMember {
  final int id;
  final String shopId;
  final String deviceId;
  final String userName;
  final String role; // OWNER, ADMIN, STAFF
  final Map<String, dynamic> permissions;
  final DateTime joinedAt;
  final DateTime? lastActiveAt;
  final bool isActive;

  ShopMember({
    required this.id,
    required this.shopId,
    required this.deviceId,
    required this.userName,
    required this.role,
    required this.permissions,
    required this.joinedAt,
    this.lastActiveAt,
    required this.isActive,
  });

  bool hasPermission(String permission) {
    if (role == 'OWNER') return true; // Owners have all permissions
    return permissions[permission] == true;
  }

  factory ShopMember.fromMap(Map<String, dynamic> map) {
    return ShopMember(
      id: map['id'],
      shopId: map['shop_id'],
      deviceId: map['device_id'],
      userName: map['user_name'],
      role: map['role'] ?? 'STAFF',
      permissions: Map<String, dynamic>.from(map['permissions'] ?? {}),
      joinedAt: DateTime.parse(map['joined_at']),
      lastActiveAt: map['last_active_at'] != null 
          ? DateTime.parse(map['last_active_at']) 
          : null,
      isActive: map['is_active'] ?? true,
    );
  }
}
```

#### Step 2: Auth Service

```dart
// lib/services/auth_service.dart

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop.dart';
import '../models/shop_member.dart';
import 'device_service.dart';

class AuthService {
  static const String _shopIdKey = 'current_shop_id';
  static const String _memberIdKey = 'current_member_id';

  /// Check if device is already linked to a shop
  static Future<bool> isAuthenticated() async {
    final shopId = await _getStoredShopId();
    return shopId != null;
  }

  /// Get current shop info
  static Future<Shop?> getCurrentShop() async {
    final shopId = await _getStoredShopId();
    if (shopId == null) return null;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('shops')
          .select()
          .eq('id', shopId)
          .single();

      return Shop.fromMap(response);
    } catch (e) {
      debugPrint('Error fetching shop: $e');
      return null;
    }
  }

  /// Get current member info
  static Future<ShopMember?> getCurrentMember() async {
    final deviceId = await DeviceService.getDeviceId();
    final shopId = await _getStoredShopId();
    if (shopId == null) return null;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('shop_members')
          .select()
          .eq('shop_id', shopId)
          .eq('device_id', deviceId)
          .single();

      return ShopMember.fromMap(response);
    } catch (e) {
      debugPrint('Error fetching member: $e');
      return null;
    }
  }

  /// Create new shop (Admin flow)
  static Future<Shop?> createShop({
    required String businessName,
    required String password,
    required String userName,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    final shopId = 'shop_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final passwordHash = _hashPassword(password);
    final trialEndsAt = DateTime.now().add(const Duration(days: 90));

    try {
      final supabase = Supabase.instance.client;

      // Create shop
      final shopData = await supabase.from('shops').insert({
        'id': shopId,
        'business_name': businessName,
        'password_hash': passwordHash,
        'owner_device_id': deviceId,
        'subscription_tier': 'FREE',
        'subscription_status': 'ACTIVE',
        'trial_ends_at': trialEndsAt.toIso8601String(),
      }).select().single();

      // Add owner as member
      await supabase.from('shop_members').insert({
        'shop_id': shopId,
        'device_id': deviceId,
        'user_name': userName,
        'role': 'OWNER',
        'permissions': {
          'manage_inventory': true,
          'view_reports': true,
          'manage_accounting': true,
          'manage_customers': true,
          'manage_members': true,
          'change_settings': true,
        },
      });

      // Store locally
      await _storeShopId(shopId);

      return Shop.fromMap(shopData);
    } catch (e) {
      debugPrint('Error creating shop: $e');
      return null;
    }
  }

  /// Join existing shop (Staff flow)
  static Future<Shop?> joinShop({
    required String shopId,
    required String password,
    required String userName,
  }) async {
    final deviceId = await DeviceService.getDeviceId();

    try {
      final supabase = Supabase.instance.client;

      // Verify shop exists and password is correct
      final shopData = await supabase
          .from('shops')
          .select()
          .eq('id', shopId)
          .single();

      final shop = Shop.fromMap(shopData);
      final passwordHash = _hashPassword(password);

      if (shopData['password_hash'] != passwordHash) {
        throw Exception('Invalid password');
      }

      // Check if device already member
      final existing = await supabase
          .from('shop_members')
          .select()
          .eq('shop_id', shopId)
          .eq('device_id', deviceId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Device already registered to this shop');
      }

      // Add as member (default STAFF role)
      await supabase.from('shop_members').insert({
        'shop_id': shopId,
        'device_id': deviceId,
        'user_name': userName,
        'role': 'STAFF',
        'permissions': {
          'manage_inventory': false,
          'view_reports': true,
          'manage_accounting': false,
          'manage_customers': true,
          'manage_members': false,
          'change_settings': false,
        },
      });

      // Store locally
      await _storeShopId(shopId);

      return shop;
    } catch (e) {
      debugPrint('Error joining shop: $e');
      rethrow;
    }
  }

  /// Generate QR code data for shop
  static Future<String> generateShopQRCode(String shopId) async {
    // Format: myshop://join?shop_id=SHOP_ID
    return 'myshop://join?shop_id=$shopId';
  }

  /// Parse QR code
  static String? parseShopQRCode(String qrData) {
    final uri = Uri.tryParse(qrData);
    if (uri?.scheme == 'myshop' && uri?.host == 'join') {
      return uri?.queryParameters['shop_id'];
    }
    return null;
  }

  /// Hash password (simple bcrypt-like implementation)
  static String _hashPassword(String password) {
    const salt = 'myshop_salt_2025'; // In production, use unique salt per shop
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Local storage helpers
  static Future<String?> _getStoredShopId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_shopIdKey);
  }

  static Future<void> _storeShopId(String shopId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shopIdKey, shopId);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shopIdKey);
    await prefs.remove(_memberIdKey);
  }
}
```

#### Step 3: Sign Up Screen

```dart
// lib/screens/auth/signup_screen.dart

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/qr_scanner_widget.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isCreateMode = true; // true = Create Shop, false = Join Shop

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo
              const Icon(Icons.store, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Welcome to myShop',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage your business with ease',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              // Mode Toggle
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Create Shop'),
                    icon: Icon(Icons.add_business),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Join Shop'),
                    icon: Icon(Icons.group_add),
                  ),
                ],
                selected: {_isCreateMode},
                onSelectionChanged: (Set<bool> selection) {
                  setState(() {
                    _isCreateMode = selection.first;
                  });
                },
              ),

              const SizedBox(height: 32),

              // Content
              Expanded(
                child: _isCreateMode 
                    ? const _CreateShopForm() 
                    : const _JoinShopForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateShopForm extends StatefulWidget {
  const _CreateShopForm();

  @override
  State<_CreateShopForm> createState() => _CreateShopFormState();
}

class _CreateShopFormState extends State<_CreateShopForm> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _userNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _businessNameController,
            decoration: const InputDecoration(
              labelText: 'Business Name',
              hintText: 'e.g., Mbeck Enterprise',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your business name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _userNameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              hintText: 'e.g., John Doe',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: 'Choose a secure password',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _createShop,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Create Shop', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _createShop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final shop = await AuthService.createShop(
        businessName: _businessNameController.text.trim(),
        password: _passwordController.text,
        userName: _userNameController.text.trim(),
      );

      if (shop != null && mounted) {
        // Show success and navigate to home
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to ${shop.businessName}!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _JoinShopForm extends StatefulWidget {
  const _JoinShopForm();

  @override
  State<_JoinShopForm> createState() => _JoinShopFormState();
}

class _JoinShopFormState extends State<_JoinShopForm> {
  final _formKey = GlobalKey<FormState>();
  final _shopIdController = TextEditingController();
  final _userNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _shopIdController,
            decoration: InputDecoration(
              labelText: 'Shop ID',
              hintText: 'e.g., shop_1234567890_5678',
              prefixIcon: const Icon(Icons.store),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scanQRCode,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter shop ID or scan QR code';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _userNameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              hintText: 'e.g., Jane Smith',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Shop Password',
              hintText: 'Enter shop password',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter shop password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _joinShop,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Join Shop', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _scanQRCode() async {
    // Implement QR scanner
    final scannedData = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerWidget()),
    );

    if (scannedData != null) {
      final shopId = AuthService.parseShopQRCode(scannedData);
      if (shopId != null) {
        _shopIdController.text = shopId;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code')),
        );
      }
    }
  }

  Future<void> _joinShop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final shop = await AuthService.joinShop(
        shopId: _shopIdController.text.trim(),
        password: _passwordController.text,
        userName: _userNameController.text.trim(),
      );

      if (shop != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to ${shop.businessName}!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _shopIdController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

---

## 🔐 PRIORITY 3: Role-Based Access Control (RBAC)

### Permission System

Based on research of similar POS/retail management systems (Square, Shopify POS, Lightspeed), here are the recommended permission categories:

#### Permission Categories

```dart
class Permissions {
  // Sales & Transactions
  static const String createSale = 'create_sale';
  static const String voidSale = 'void_sale';
  static const String applyDiscount = 'apply_discount';
  static const String processRefund = 'process_refund';
  
  // Inventory Management
  static const String viewInventory = 'view_inventory';
  static const String addInventoryItem = 'add_inventory_item';
  static const String editInventoryItem = 'edit_inventory_item';
  static const String deleteInventoryItem = 'delete_inventory_item';
  static const String adjustStock = 'adjust_stock';
  
  // Financial & Reports
  static const String viewReports = 'view_reports';
  static const String viewProfitMargins = 'view_profit_margins';
  static const String manageAccounting = 'manage_accounting';
  static const String viewCashCount = 'view_cash_count';
  static const String performCashCount = 'perform_cash_count';
  
  // Customer Management
  static const String viewCustomers = 'view_customers';
  static const String addCustomer = 'add_customer';
  static const String editCustomer = 'edit_customer';
  static const String deleteCustomer = 'delete_customer';
  static const String viewCustomerDetails = 'view_customer_details'; // ID, phone numbers
  
  // Team Management
  static const String viewTeamMembers = 'view_team_members';
  static const String addTeamMember = 'add_team_member';
  static const String removeTeamMember = 'remove_team_member';
  static const String managePermissions = 'manage_permissions';
  
  // Settings & Configuration
  static const String changeSettings = 'change_settings';
  static const String manageSubscription = 'manage_subscription';
  static const String viewShopId = 'view_shop_id'; // For security reasons
  static const String exportData = 'export_data';
  static const String importData = 'import_data';
}
```

#### Role Presets

```dart
class RolePresets {
  static Map<String, dynamic> get owner => {
    // Owners have ALL permissions (implicitly)
    'is_owner': true,
  };

  static Map<String, dynamic> get admin => {
    Permissions.createSale: true,
    Permissions.voidSale: true,
    Permissions.applyDiscount: true,
    Permissions.processRefund: true,
    Permissions.viewInventory: true,
    Permissions.addInventoryItem: true,
    Permissions.editInventoryItem: true,
    Permissions.deleteInventoryItem: true,
    Permissions.adjustStock: true,
    Permissions.viewReports: true,
    Permissions.viewProfitMargins: true,
    Permissions.manageAccounting: true,
    Permissions.viewCashCount: true,
    Permissions.performCashCount: true,
    Permissions.viewCustomers: true,
    Permissions.addCustomer: true,
    Permissions.editCustomer: true,
    Permissions.deleteCustomer: true,
    Permissions.viewCustomerDetails: true,
    Permissions.viewTeamMembers: true,
    Permissions.addTeamMember: false, // Only owner
    Permissions.removeTeamMember: false,
    Permissions.managePermissions: false,
    Permissions.changeSettings: true,
    Permissions.manageSubscription: false, // Only owner
    Permissions.viewShopId: true,
    Permissions.exportData: true,
    Permissions.importData: true,
  };

  static Map<String, dynamic> get cashier => {
    Permissions.createSale: true,
    Permissions.voidSale: false, // Needs manager override
    Permissions.applyDiscount: true,
    Permissions.processRefund: false,
    Permissions.viewInventory: true,
    Permissions.addInventoryItem: false,
    Permissions.editInventoryItem: false,
    Permissions.deleteInventoryItem: false,
    Permissions.adjustStock: false,
    Permissions.viewReports: false,
    Permissions.viewProfitMargins: false,
    Permissions.manageAccounting: false,
    Permissions.viewCashCount: false,
    Permissions.performCashCount: true,
    Permissions.viewCustomers: true,
    Permissions.addCustomer: true,
    Permissions.editCustomer: false,
    Permissions.deleteCustomer: false,
    Permissions.viewCustomerDetails: false, // Privacy
    Permissions.viewTeamMembers: false,
    Permissions.addTeamMember: false,
    Permissions.removeTeamMember: false,
    Permissions.managePermissions: false,
    Permissions.changeSettings: false,
    Permissions.manageSubscription: false,
    Permissions.viewShopId: false,
    Permissions.exportData: false,
    Permissions.importData: false,
  };
}
```

#### Permission Guard Widget

```dart
// lib/widgets/permission_guard.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class PermissionGuard extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;
  final VoidCallback? onDenied;

  const PermissionGuard({
    Key? key,
    required this.permission,
    required this.child,
    this.fallback,
    this.onDenied,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShopMember?>(
      future: AuthService.getCurrentMember(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return fallback ?? const SizedBox.shrink();
        }

        final member = snapshot.data!;
        if (member.hasPermission(permission)) {
          return child;
        } else {
          onDenied?.call();
          return fallback ?? const SizedBox.shrink();
        }
      },
    );
  }
}

// Usage example:
PermissionGuard(
  permission: Permissions.deleteInventoryItem,
  child: IconButton(
    icon: const Icon(Icons.delete),
    onPressed: () => _deleteItem(),
  ),
  fallback: const SizedBox.shrink(), // Hide button if no permission
)
```

---

## 💳 PRIORITY 4: Subscription & Monetization System

### Subscription Tiers

```dart
class SubscriptionTiers {
  static const String free = 'FREE';
  static const String pro = 'PRO';
  static const String enterprise = 'ENTERPRISE';
}

class SubscriptionPricing {
  static const Map<String, int> monthly = {
    SubscriptionTiers.free: 0,
    SubscriptionTiers.pro: 500, // KSH 500/month
    SubscriptionTiers.enterprise: 1500, // KSH 1,500/month
  };

  static const Map<String, int> annual = {
    SubscriptionTiers.free: 0,
    SubscriptionTiers.pro: 5000, // KSH 5,000/year (save ~17%)
    SubscriptionTiers.enterprise: 15000, // KSH 15,000/year
  };
}
```

### Feature Access Matrix

```dart
class FeatureAccess {
  final String tier;

  FeatureAccess(this.tier);

  // Transaction Limits
  int get maxTransactionsPerMonth {
    switch (tier) {
      case SubscriptionTiers.free:
        return 100;
      case SubscriptionTiers.pro:
        return 1000;
      case SubscriptionTiers.enterprise:
        return -1; // Unlimited
      default:
        return 0;
    }
  }

  int get maxTeamMembers {
    switch (tier) {
      case SubscriptionTiers.free:
        return 1; // Solo
      case SubscriptionTiers.pro:
        return 5;
      case SubscriptionTiers.enterprise:
        return -1; // Unlimited
      default:
        return 1;
    }
  }

  int get maxInventoryItems {
    switch (tier) {
      case SubscriptionTiers.free:
        return 50;
      case SubscriptionTiers.pro:
        return 500;
      case SubscriptionTiers.enterprise:
        return -1; // Unlimited
      default:
        return 50;
    }
  }

  // Feature Flags
  bool get canSendWhatsAppReceipts {
    return tier != SubscriptionTiers.free;
  }

  bool get canAccessAIScanner {
    return true; // Available to all
  }

  bool get canExportData {
    return tier != SubscriptionTiers.free;
  }

  bool get canImportData {
    return tier != SubscriptionTiers.free;
  }

  bool get canAccessAdvancedReports {
    return tier == SubscriptionTiers.pro || tier == SubscriptionTiers.enterprise;
  }

  bool get canAccessTrustScore {
    return tier != SubscriptionTiers.free;
  }

  bool get canSyncToCloud {
    return tier != SubscriptionTiers.free;
  }

  bool get hasEmailSupport {
    return tier == SubscriptionTiers.pro || tier == SubscriptionTiers.enterprise;
  }

  bool get hasPrioritySupport {
    return tier == SubscriptionTiers.enterprise;
  }

  bool get canAccessAPI {
    return tier == SubscriptionTiers.enterprise;
  }
}
```

### Pricing Screen

```dart
// lib/screens/pricing_screen.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/shop.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({Key? key}) : super(key: key);

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool _isAnnual = false;
  Shop? _currentShop;

  @override
  void initState() {
    super.initState();
    _loadShopInfo();
  }

  Future<void> _loadShopInfo() async {
    final shop = await AuthService.getCurrentShop();
    setState(() {
      _currentShop = shop;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trial Banner (if applicable)
            if (_currentShop?.isOnTrial ?? false)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_currentShop!.trialDaysRemaining} days left in your free trial',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Billing Toggle
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBillingOption('Monthly', !_isAnnual),
                    _buildBillingOption('Annual (Save 17%)', _isAnnual),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Pricing Cards
            _buildPricingCard(
              tier: 'FREE',
              price: 0,
              description: 'Perfect for getting started',
              features: [
                '100 transactions/month',
                '50 inventory items',
                '1 team member',
                'Basic reports',
                'AI product scanner',
                'Offline mode',
              ],
              limitations: [
                'No WhatsApp receipts',
                'No cloud sync',
                'No export/import',
                'No trust score',
              ],
              isCurrentPlan: _currentShop?.subscriptionTier == 'FREE',
            ),

            const SizedBox(height: 16),

            _buildPricingCard(
              tier: 'PRO',
              price: _isAnnual ? 417 : 500, // Annual monthly equivalent
              description: 'For growing businesses',
              features: [
                '1,000 transactions/month',
                '500 inventory items',
                'Up to 5 team members',
                'Advanced reports & analytics',
                'WhatsApp receipts',
                'Cloud backup & sync',
                'Export/import data',
                'Trust score & insights',
                'Email support',
              ],
              isPopular: true,
              isCurrentPlan: _currentShop?.subscriptionTier == 'PRO',
            ),

            const SizedBox(height: 16),

            _buildPricingCard(
              tier: 'ENTERPRISE',
              price: _isAnnual ? 1250 : 1500,
              description: 'For established businesses',
              features: [
                'Unlimited transactions',
                'Unlimited inventory',
                'Unlimited team members',
                'Everything in Pro, plus:',
                'API access',
                'Priority support (WhatsApp)',
                'Custom integrations',
                'Dedicated account manager',
              ],
              isCurrentPlan: _currentShop?.subscriptionTier == 'ENTERPRISE',
            ),

            const SizedBox(height: 32),

            // FAQ Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFAQ('Can I switch plans later?', 
                'Yes! You can upgrade or downgrade at any time. Changes take effect immediately.'),
            _buildFAQ('What happens after my trial?', 
                'Your account will automatically switch to the FREE plan. No credit card required.'),
            _buildFAQ('How do I pay?', 
                'Currently, we accept M-Pesa payments. More payment options coming soon!'),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingOption(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isAnnual = label.contains('Annual');
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required String tier,
    required int price,
    required String description,
    required List<String> features,
    List<String>? limitations,
    bool isPopular = false,
    bool isCurrentPlan = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? Colors.green : Colors.grey.shade300,
          width: isPopular ? 2 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isPopular ? Colors.green.shade50 : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tier,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isPopular ? Colors.green.shade900 : Colors.black87,
                      ),
                    ),
                    if (isPopular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'POPULAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (isCurrentPlan) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KSH',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$price',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        '/month',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isAnnual && price > 0)
                  Text(
                    'Billed KSH ${price * 12} annually',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // Features
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
                
                if (limitations != null && limitations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...limitations.map((limitation) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.close,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            limitation,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],

                const SizedBox(height: 16),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan 
                        ? null 
                        : () => _selectPlan(tier),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isPopular ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: Text(
                      isCurrentPlan 
                          ? 'Current Plan' 
                          : (tier == 'FREE' ? 'Downgrade' : 'Upgrade'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            answer,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  void _selectPlan(String tier) {
    if (tier == 'FREE') {
      // Show downgrade confirmation
      _showDowngradeDialog();
    } else {
      // Navigate to payment screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            tier: tier,
            amount: _isAnnual 
                ? SubscriptionPricing.annual[tier]! 
                : SubscriptionPricing.monthly[tier]!,
            isAnnual: _isAnnual,
          ),
        ),
      );
    }
  }

  void _showDowngradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Downgrade to FREE'),
        content: const Text(
          'Are you sure you want to downgrade? You will lose access to:\n\n'
          '• WhatsApp receipts\n'
          '• Cloud sync\n'
          '• Advanced reports\n'
          '• Export/Import data\n\n'
          'Your data will be preserved, but some features will be locked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Process downgrade
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DOWNGRADE'),
          ),
        ],
      ),
    );
  }
}
```

### Payment Screen

```dart
// lib/screens/payment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaymentScreen extends StatefulWidget {
  final String tier;
  final int amount;
  final bool isAnnual;

  const PaymentScreen({
    Key? key,
    required this.tier,
    required this.amount,
    required this.isAnnual,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Order Summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryRow('Plan', widget.tier),
                    _buildSummaryRow(
                      'Billing',
                      widget.isAnnual ? 'Annual' : 'Monthly',
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'KSH ${widget.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Payment Instructions
              const Text(
                'M-Pesa Payment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _buildInstructionStep(
                1,
                'Go to M-Pesa on your phone',
              ),
              _buildInstructionStep(
                2,
                'Select Lipa Na M-Pesa → Paybill',
              ),
              _buildInstructionStep(
                3,
                'Enter Business Number: 522533',
              ),
              _buildInstructionStep(
                4,
                'Account Number: Your Phone Number',
              ),
              _buildInstructionStep(
                5,
                'Amount: KSH ${widget.amount}',
              ),
              _buildInstructionStep(
                6,
                'Enter your M-Pesa PIN and confirm',
              ),

              const SizedBox(height: 24),

              // Alternative: Send via Phone
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Or pay directly from this phone:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'M-Pesa Phone Number',
                        hintText: '0712345678',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your M-Pesa number';
                        }
                        if (!RegExp(r'^07\d{8}$').hasMatch(value)) {
                          return 'Invalid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _initiatePayment,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                        ),
                        child: _isProcessing
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('SEND PAYMENT REQUEST'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Support Contact
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.support_agent, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Need help?',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                const ClipboardData(text: '0701414257'),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Phone copied!')),
                              );
                            },
                            child: const Text(
                              'WhatsApp: 0701414257',
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black87)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(int step, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    // TODO: Integrate with M-Pesa API (Daraja API)
    // For now, just show confirmation dialog
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isProcessing = false);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment Initiated'),
          content: const Text(
            'Please check your phone for the M-Pesa prompt and enter your PIN to complete the payment.\n\n'
            'Your subscription will be activated automatically once payment is confirmed.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close payment screen
                Navigator.pop(context); // Close pricing screen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
```

---

## 🔄 Implementation Checklist

### Phase 1: Critical Fixes (Day 1-2)
- [ ] Fix revenue calculation bug in dashboard
- [ ] Standardize AppBar across all screens
- [ ] Update HomeScreen to show business name instead of "Dashboard"

### Phase 2: Authentication (Day 3-5)
- [ ] Create database tables (shops, shop_members)
- [ ] Implement AuthService
- [ ] Build SignUpScreen with QR scanner
- [ ] Add auth check in main.dart
- [ ] Update all screens to filter by shop_id

### Phase 3: RBAC (Day 6-7)
- [ ] Implement permission system
- [ ] Create PermissionGuard widget
- [ ] Add permission checks to sensitive actions
- [ ] Build Team Management screen (for owners/admins)

### Phase 4: Subscription (Day 8-10)
- [ ] Build PricingScreen
- [ ] Build PaymentScreen
- [ ] Implement feature gates
- [ ] Add upgrade prompts
- [ ] Test trial expiration logic

### Phase 5: Testing (Day 11-12)
- [ ] Test multi-device scenarios
- [ ] Test permission restrictions
- [ ] Test subscription upgrades/downgrades
- [ ] User acceptance testing with shop owner

---

## 📚 References & Best Practices

### Similar Apps to Study
1. **Square POS** - Team management, role permissions
2. **Shopify POS** - Multi-location, staff accounts
3. **Lightspeed Retail** - Advanced permissions, subscription tiers
4. **Toast POS** - Restaurant-specific RBAC
5. **Clover** - Payment processing, team features

### Security Best Practices
- [ ] Hash passwords with bcrypt (or use proper crypto library)
- [ ] Never log passwords or sensitive data
- [ ] Implement rate limiting on auth endpoints
- [ ] Use HTTPS for all API calls
- [ ] Validate all inputs server-side
- [ ] Implement session timeouts for inactive users

### UX Best Practices
- [ ] Clear onboarding for new users
- [ ] QR code for easy shop joining
- [ ] Trial period clearly communicated
- [ ] Easy upgrade path
- [ ] Transparent pricing
- [ ] Helpful error messages

---

**This implementation will transform myShop into a professional, multi-user, subscription-based SaaS product ready for scale!** 🚀