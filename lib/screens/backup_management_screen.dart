import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../services/backup_service.dart';
import '../services/onboarding_service.dart';
import '../db/db_provider.dart';
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';
import '../services/auth_service.dart';
import '../models/permissions.dart';


/// Enhanced Backup Management Screen
/// Shows backup stats and cloud upload options
class BackupManagementScreen extends StatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  State<BackupManagementScreen> createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends State<BackupManagementScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<String> _enabledModules = [];

  // Access control state
  bool _isCheckingAccess = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final member = await AuthService.getCurrentMember();
      final hasAccess = member?.hasPermission(Permissions.changeSettings) ?? false;
      if (mounted) {
        setState(() {
          _hasAccess = hasAccess;
          _isCheckingAccess = false;
        });
        if (!hasAccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Access Denied: You do not have permission to manage Backups."),
              backgroundColor: AppColors.danger,
            ),
          );
          Navigator.pop(context);
        } else {
          _loadStats();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingAccess = false;
          _hasAccess = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error checking access: $e"), backgroundColor: AppColors.danger),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      final db = await DbProvider.db;
      _enabledModules = await OnboardingService.getSelectedModules();
      
      // Get inventory count (retail)
      final inventoryCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM inventory')
      ) ?? 0;
      
      // Get inventory with vectors count
      final vectorsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM inventory WHERE visual_vector IS NOT NULL AND visual_vector != "[]"')
      ) ?? 0;
      
      // Get customer count
      final customerCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM customer')
      ) ?? 0;
      
      // Get transaction count
      final transactionCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM txn')
      ) ?? 0;
      
      // Module-specific counts
      int menuCount = 0;
      int ordersCount = 0;
      int servicesCount = 0;
      int appointmentsCount = 0;
      
      if (_enabledModules.contains('restaurant')) {
        try {
          menuCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM restaurant_menu')
          ) ?? 0;
        } catch (_) {}
      }
      
      if (_enabledModules.contains('services')) {
        try {
          servicesCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM services_catalog')
          ) ?? 0;
          appointmentsCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM services_bookings')
          ) ?? 0;
        } catch (_) {}
      }
      
      // Get database size
      // Get database size
      final databasesPath = await getDatabasesPath();
      final dbPath = path.join(databasesPath, 'shop_database_live.db');
      final dbFile = File(dbPath);
      final dbSize = dbFile.existsSync() ? await dbFile.length() : 0;
      
      // Get images count
      final appDir = await getApplicationDocumentsDirectory();
      int imageCount = 0;
      int imageSize = 0;
      if (appDir.existsSync()) {
        final files = appDir.listSync();
        for (var file in files) {
          if (file is File) {
            final ext = path.extension(file.path).toLowerCase();
            if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') {
              imageCount++;
              imageSize += await file.length();
            }
          }
        }
      }
      
      setState(() {
        _stats = {
          'inventory': inventoryCount,
          'vectors': vectorsCount,
          'customers': customerCount,
          'transactions': transactionCount,
          'images': imageCount,
          'dbSize': dbSize,
          'imageSize': imageSize,
          'totalSize': dbSize + imageSize,
          'aiReadiness': '0',
          // Module-specific
          'menuItems': menuCount,
          'ordersCount': ordersCount,
          'services': servicesCount,
          'appointments': appointmentsCount,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load stats: $e')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }


  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(
        appBar: StandardAppBar(
          title: 'Backup & Restore',
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    }
    if (!_hasAccess) {
      return const Scaffold(
        appBar: StandardAppBar(
          title: 'Backup & Restore',
          centerTitle: true,
        ),
        body: Center(child: Text("Access Denied")),
      );
    }
    return Scaffold(
      appBar: const StandardAppBar(
        title: 'Backup & Restore',
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stats Cards
                  _buildStatsCard(),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Backup Actions
                  Text(
                    'Backup Actions',
                    style: AppTypography.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Create Backup Button
                  ElevatedButton.icon(
                    onPressed: () => BackupService.exportDatabase(context),
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Create Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.all(AppSpacing.md),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.sm),
                  
                  // Restore Backup Button
                  OutlinedButton.icon(
                    onPressed: () => BackupService.importDatabase(context),
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Restore Backup'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(AppSpacing.md),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Info Section
                  _buildInfoSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: AppColors.primaryGreen),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Backup Statistics',
                  style: AppTypography.textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Module-aware labels
            if (_enabledModules.contains('retail'))
              _buildStatRow('Products', _stats['inventory'].toString(), Icons.inventory_2),
            if (_enabledModules.contains('restaurant'))
              _buildStatRow('Menu Items', _stats['menuItems'].toString(), Icons.restaurant_menu),
            if (_enabledModules.contains('services')) ...[
              _buildStatRow('Services', _stats['services'].toString(), Icons.design_services),
              _buildStatRow('Appointments', _stats['appointments'].toString(), Icons.calendar_today),
            ],
            // Default if no specific modules
            if (!_enabledModules.contains('retail') && !_enabledModules.contains('restaurant') && !_enabledModules.contains('services'))
              _buildStatRow('Inventory Items', _stats['inventory'].toString(), Icons.inventory_2),
            _buildStatRow('Customers', _stats['customers'].toString(), Icons.people),
            _buildStatRow('Transactions', _stats['transactions'].toString(), Icons.receipt_long),
            _buildStatRow('Product Images', _stats['images'].toString(), Icons.image),
            const Divider(height: AppSpacing.lg),
            _buildStatRow('Total Backup Size', _formatBytes(_stats['totalSize']), Icons.storage, isHighlighted: true),
          ],
        ),
      ),
    );
  }




  Widget _buildStatRow(String label, String value, IconData icon, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isHighlighted ? AppColors.primaryGreen : AppColors.gray600),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isHighlighted ? AppColors.primaryGreen : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'How Backups Work',
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildInfoBullet('Backups include ALL data: inventory, customers, transactions, and images'),
            _buildInfoBullet('Share backups via WhatsApp, email, or any file sharing app'),
            _buildInfoBullet('Restore on new devices to transfer your shop instantly'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: TextStyle(color: Colors.blue.shade700)),
          Expanded(
            child: Text(
              text,
              style: AppTypography.textTheme.bodySmall?.copyWith(
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
