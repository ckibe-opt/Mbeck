import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_system.dart';
import '../services/auth_service.dart';

/// Mbeck Go Analytics Screen.
///
/// Reads from the `shop_analytics_events` table populated by the buyer app
/// whenever a buyer browses or interacts with this shop on Mbeck Go.
///
/// Metrics shown:
///   • Total shop views (event_type = 'shop_view')
///   • Unique buyers reached
///   • Messages received (event_type = 'message_sent')
///   • Top viewed items (event_type = 'item_view', grouped by item_name)
///   • 7-day rolling trend
class OnlineAnalyticsScreen extends StatefulWidget {
  const OnlineAnalyticsScreen({super.key});

  @override
  State<OnlineAnalyticsScreen> createState() => _OnlineAnalyticsScreenState();
}

class _OnlineAnalyticsScreenState extends State<OnlineAnalyticsScreen> {
  bool _isLoading = true;
  String? _error;

  int _shopViews = 0;
  int _uniqueBuyers = 0;
  int _messages = 0;
  int _checkouts = 0;
  int _shopViews7d = 0;
  List<Map<String, dynamic>> _topItems = [];
  List<_DayStat> _trend = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final shopId = await AuthService.getShopId();
      if (shopId == null) {
        setState(() { _isLoading = false; _error = 'Shop not configured.'; });
        return;
      }

      final client = Supabase.instance.client;

      // ── Summary counts ────────────────────────────────────────────────────
      final summary = await client
          .from('shop_analytics_events')
          .select('event_type, buyer_id, created_at')
          .eq('shop_id', shopId);

      final rows = summary as List;
      final now = DateTime.now();
      final cutoff7d = now.subtract(const Duration(days: 7));

      int shopViews = 0, uniqueBuyersSet = 0, messages = 0, checkouts = 0, sv7d = 0;
      final buyerIds = <String>{};

      for (final r in rows) {
        final type = r['event_type'] as String? ?? '';
        final createdAt = DateTime.tryParse(r['created_at'] as String? ?? '');
        final buyerId = r['buyer_id'] as String?;
        if (buyerId != null) buyerIds.add(buyerId);
        if (type == 'shop_view') {
          shopViews++;
          if (createdAt != null && createdAt.isAfter(cutoff7d)) sv7d++;
        }
        if (type == 'message_sent') messages++;
        if (type == 'checkout' || type == 'order_placed') checkouts++;
      }
      uniqueBuyersSet = buyerIds.length;

      // ── Top items ──────────────────────────────────────────────────────────
      final itemRows = await client
          .from('shop_analytics_events')
          .select('item_name, module')
          .eq('shop_id', shopId)
          .eq('event_type', 'item_view')
          .not('item_name', 'is', null);

      final Map<String, int> itemCounts = {};
      final Map<String, String> itemModules = {};
      for (final r in (itemRows as List)) {
        final name = r['item_name'] as String? ?? '';
        if (name.isEmpty) continue;
        itemCounts[name] = (itemCounts[name] ?? 0) + 1;
        itemModules[name] = r['module'] as String? ?? '';
      }
      final topItems = itemCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // ── 7-day trend ───────────────────────────────────────────────────────
      final List<_DayStat> trend = [];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dayLabel = '${day.month}/${day.day}';
        final count = rows.where((r) {
          final t = r['event_type'] as String? ?? '';
          if (t != 'shop_view') return false;
          final d = DateTime.tryParse(r['created_at'] as String? ?? '');
          return d != null &&
              d.year == day.year && d.month == day.month && d.day == day.day;
        }).length;
        trend.add(_DayStat(dayLabel, count));
      }

      if (mounted) {
        setState(() {
          _shopViews = shopViews;
          _uniqueBuyers = uniqueBuyersSet;
          _messages = messages;
          _checkouts = checkouts;
          _shopViews7d = sv7d;
          _topItems = topItems.take(10).map((e) => {
            'name': e.key,
            'views': e.value,
            'module': itemModules[e.key] ?? '',
          }).toList();
          _trend = trend;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Mbeck Go Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlack,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAnalytics),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroCard(),
                        const SizedBox(height: 16),
                        _buildStatGrid(),
                        const SizedBox(height: 24),
                        _buildTrendChart(),
                        const SizedBox(height: 24),
                        _buildTopItems(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.primaryGreen.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          const Icon(Icons.public, color: Colors.white, size: 40),
          const SizedBox(height: 10),
          const Text('Total Shop Views (All-Time)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('$_shopViews', style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold, height: 1)),
          const SizedBox(height: 4),
          Text('+$_shopViews7d this week', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _statCard('Unique Buyers', '$_uniqueBuyers', Icons.people_outline, const Color(0xFF3B82F6)),
        _statCard('Messages', '$_messages', Icons.chat_bubble_outline, const Color(0xFF8B5CF6)),
        _statCard('Checkouts', '$_checkouts', Icons.shopping_cart_outlined, const Color(0xFF059669)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.gray900)),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.gray400, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_trend.isEmpty) return const SizedBox();
    final maxVal = _trend.map((d) => d.count).fold(0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('7-Day Shop Views', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray900)),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _trend.map((d) {
                final ratio = maxVal > 0 ? d.count / maxVal : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.count > 0)
                          Text('${d.count}', style: TextStyle(fontSize: 9, color: AppColors.gray500)),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: (ratio * 70).clamp(4.0, 70.0),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(d.label, style: TextStyle(fontSize: 9, color: AppColors.gray400)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top Items Viewed on Mbeck Go',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray900)),
        const SizedBox(height: 12),
        if (_topItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.visibility_off, size: 40, color: AppColors.gray300),
                  const SizedBox(height: 12),
                  Text('No item views tracked yet.',
                      style: TextStyle(color: AppColors.gray500, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Make sure your shop is published on Mbeck Go.',
                      style: TextStyle(color: AppColors.gray400, fontSize: 13), textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray100),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final item = _topItems[i];
                final views = item['views'] as int;
                final maxViews = (_topItems.first['views'] as int).clamp(1, 999999);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                    child: Text('#${i + 1}',
                        style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  title: Text(item['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: LinearProgressIndicator(
                    value: views / maxViews,
                    backgroundColor: AppColors.gray100,
                    color: AppColors.primaryGreen,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('$views', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 56, color: AppColors.gray300),
            const SizedBox(height: 16),
            Text('Could not load analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray700)),
            const SizedBox(height: 8),
            Text(_error ?? '', style: TextStyle(color: AppColors.gray500, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayStat {
  final String label;
  final int count;
  const _DayStat(this.label, this.count);
}
