import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/shop_session_provider.dart';
import '../../services/shop_api_service.dart';
import '../../theme/shop_theme_extension.dart';
import 'package:mbeck_shared/mbeck_shared.dart';

/// Entertainment browsing screen for buyer app.
/// Shows available assets (pool tables, gaming stations, etc.) with status and pricing.
class EntertainmentBrowseScreen extends StatefulWidget {
  const EntertainmentBrowseScreen({super.key});

  @override
  State<EntertainmentBrowseScreen> createState() => _EntertainmentBrowseScreenState();
}

class _EntertainmentBrowseScreenState extends State<EntertainmentBrowseScreen> {
  List<Map<String, dynamic>> _assets = [];
  bool _isLoading = true;
  String? _error;
  int? _bookingAssetId; // asset being booked right now

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() { _isLoading = true; _error = null; });
    final session = context.read<ShopSessionProvider>();
    final api = session.api;
    if (api == null) {
      setState(() { _error = 'Not connected'; _isLoading = false; });
      return;
    }
    try {
      final assets = await api.getEntertainmentAssets();
      if (mounted) setState(() { _assets = assets; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  /// Safely converts a value that may be num OR String to double.
  double _toDouble(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  /// Safely converts a value that may be num OR String to int.
  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Entertainment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(onPressed: _loadAssets, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                    ],
                  ),
                )
              : _assets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_esports_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No entertainment available', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAssets,
                      child: _buildAssetList(theme),
                    ),
    );
  }

  Widget _buildAssetList(ThemeData theme) {
    final ext = theme.extension<ShopThemeExtension>() ?? const ShopThemeExtension();
    // Group by category
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final asset in _assets) {
      final cat = asset['category'] as String? ?? 'General';
      grouped.putIfAbsent(cat, () => []).add(asset);
    }

    return ListView(
      padding: ext.contentPadding,
      children: [
        // Stats summary
        if (ext.showHero)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: ext.buildHeroDecoration(primary: theme.primaryColor, secondary: theme.colorScheme.secondary),
            child: Row(
              children: [
                Icon(Icons.sports_esports,
                  color: ext.heroDarkText ? theme.primaryColor : Colors.white, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available Activities', style: TextStyle(
                      color: ext.heroDarkText ? theme.textTheme.bodyLarge?.color : Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('${_assets.length} options', style: TextStyle(
                      color: ext.heroDarkText ? Colors.grey.shade600 : Colors.white.withOpacity(0.8))),
                  ],
                ),
              ],
            ),
          ),
        if (ext.showHero) SizedBox(height: ext.itemSpacing + 4),
        // Categories
        ...grouped.entries.map((entry) => _buildCategorySection(entry.key, entry.value, theme, ext)),
      ],
    );
  }

  Widget _buildCategorySection(String category, List<Map<String, dynamic>> assets, ThemeData theme, ShopThemeExtension ext) {
    final categoryIcons = {
      'Pool': Icons.sports_bar,
      'Gaming': Icons.videogame_asset,
      'Swimming': Icons.pool,
      'Karaoke': Icons.mic,
      'Bowling': Icons.album,
      'VR': Icons.vrpano,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(categoryIcons[category] ?? Icons.sports_esports, size: 20, color: theme.primaryColor),
            const SizedBox(width: 8),
            Text(
              ext.transformSectionHeader(category),
              style: ext.buildSectionHeaderStyle(
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.primaryColor),
              ),
            ),
          ],
        ),
        SizedBox(height: ext.itemSpacing * 0.6),
        ...assets.map((asset) => _buildAssetCard(asset, theme, ext)),
        SizedBox(height: ext.itemSpacing),
      ],
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> asset, ThemeData theme, ShopThemeExtension ext) {
    final name = asset['name'] as String? ?? 'Unknown';
    final type = asset['asset_type'] as String? ?? 'hourly';
    final ratePerHour = _toDouble(asset['rate_per_hour']);
    final flatRate = _toDouble(asset['flat_rate']);
    final activeSessions = _toInt(asset['active_sessions']);
    final description = asset['description'] as String? ?? '';
    final isAvailable = activeSessions == 0;
    final assetId = asset['id'] == null ? null : _toInt(asset['id']);
    final isBookingThis = _bookingAssetId == assetId;

    return Container(
      margin: EdgeInsets.only(bottom: ext.itemSpacing * 0.6),
      decoration: ext.buildCardDecoration(
        surface: theme.cardColor,
        accentColor: isAvailable ? Colors.green : Colors.orange,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isAvailable ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ext.cardBorderRadius * 0.7),
              ),
              child: Icon(
                isAvailable ? Icons.check_circle_outline : Icons.timer,
                color: isAvailable ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (description.isNotEmpty)
                    Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAvailable ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(ext.chipBorderRadius),
                        ),
                        child: Text(
                          isAvailable ? 'Available' : 'In Use',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isAvailable ? Colors.green.shade700 : Colors.orange.shade700),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        type == 'flat' ? '${CurrencyFormatter.formatWithCurrency(flatRate)} flat' : '${CurrencyFormatter.formatWithCurrency(ratePerHour)}/hr',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor),
                      ),
                    ],
                  ),
                  if (isAvailable && assetId != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: (_bookingAssetId != null) ? null : () => _startSession(asset),
                        icon: isBookingThis
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_circle_outline, size: 18),
                        label: Text(isBookingThis ? 'Starting…' : 'Start Session'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSession(Map<String, dynamic> asset) async {
    final assetId = asset['id'] == null ? null : _toInt(asset['id']);
    final name = asset['name'] as String? ?? 'Asset';
    if (assetId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Start $name session?'),
        content: const Text('The shop operator will be notified and your session will begin. You will be charged when the session ends.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _bookingAssetId = assetId);
    final session = context.read<ShopSessionProvider>();
    final api = session.api;
    if (api is! LocalShopApiService) {
      setState(() => _bookingAssetId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session booking requires a LAN connection to the shop.')),
        );
      }
      return;
    }
    try {
      final localApi = api;
      await localApi.entertainmentBook(
        assetId: assetId,
        customerName: session.currentShopName ?? 'Customer',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text('$name session started! Enjoy.'),
            ]),
            backgroundColor: Colors.green.shade700,
          ),
        );
        await _loadAssets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start session: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _bookingAssetId = null);
    }
  }
}
