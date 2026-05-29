import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../theme/design_system.dart';
import '../screens/inventory_screen.dart';
import '../screens/paywall_screen.dart';
import '../services/revenuecat_service.dart';

class DemandPulseCard extends StatefulWidget {
  const DemandPulseCard({super.key});

  @override
  State<DemandPulseCard> createState() => _DemandPulseCardState();
}

class _DemandPulseCardState extends State<DemandPulseCard> {
  List<UnmetDemandItem> _items = [];
  bool _isLoading = true;
  bool _hasProAccess = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final shop = await AuthService.getCurrentShop();
    final items = await AnalyticsService.getUnmetDemand();
    final isProSub = await RevenueCatService.isProSubscriber();
    
    if (mounted) {
      setState(() {
        _hasProAccess = (shop?.hasProAccess ?? false) || isProSub;
        _items = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _items.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: AppColors.danger.withOpacity(0.3), width: 1),
      ),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: AppColors.danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    "Missed Revenue Alert",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.textTheme.headlineMedium?.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
                if (!_hasProAccess) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.lock, size: 16, color: AppColors.danger),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            
            if (_hasProAccess) ...[
              Text(
                "People nearby are searching for these items, but you don't have them in stock.",
                style: AppTypography.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isLoading)
                 const Center(child: CircularProgressIndicator())
              else
                ..._items.map((item) => _buildDemandItem(item)),
            ] else ...[
               // Teaser View for Free Tier
               Text(
                "You missed ${_items.length} potential sales recently.",
                style: AppTypography.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.gray800
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Upgrade to PRO to see exactly what your customers are looking for.",
                style: AppTypography.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => PaywallScreen.show(context, featureName: 'Demand Pulse Analytics'),
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text("Unlock Analytics"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDemandItem(UnmetDemandItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.query,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "${item.count} searches recently",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Navigate to Inventory Screen with pre-fill
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InventoryScreen(initialAddItemName: item.query),
                ),
              ).then((_) => _loadData()); // Reload on return
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text("Add Stock"),
          ),
        ],
      ),
    );
  }
}
