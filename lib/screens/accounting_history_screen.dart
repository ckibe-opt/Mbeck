import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_provider.dart';
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';
import '../models/shop.dart';
import '../services/auth_service.dart';

class AccountingHistoryScreen extends StatefulWidget {
  @override
  _AccountingHistoryScreenState createState() => _AccountingHistoryScreenState();
}

class _AccountingHistoryScreenState extends State<AccountingHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  Shop? _shop;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await DbProvider.query('accounting', orderBy: 'timestamp DESC');
    final shop = await AuthService.getCurrentShop();
    setState(() {
      _shop = shop;
      _history = List.from(data);
      _isLoading = false;
    });
  }

  Future<void> _deleteEntry(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('This will permanently delete this accounting record. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await DbProvider.delete('accounting', where: 'id = ?', whereArgs: [id]);
      _loadHistory();
    }
  }

  String _formatNum(int val) {
    return NumberFormat('#,##0').format(val);
  }

  String get _currency => _shop?.currency ?? 'KES';

  String _getAccountLabel(String dbKey) {
    final isKES = _currency == 'KES';
    switch (dbKey) {
      case 'cashTotal':
        return 'Cash';
      case 'mpesa1':
        return isKES ? 'M-Pesa 1' : 'Mobile Wallet 1';
      case 'mpesa2':
        return isKES ? 'M-Pesa 2' : 'Mobile Wallet 2';
      case 'coop':
        return isKES ? 'Co-op' : 'Bank Account 1';
      case 'equity':
        return isKES ? 'Equity' : 'Bank Account 2';
      case 'kcb':
        return isKES ? 'KCB' : 'Bank Account 3';
      case 'airtel':
        return isKES ? 'Airtel' : 'Card / POS';
      case 'otherMpesa':
        return isKES ? 'Other' : 'Other Payment';
      default:
        return dbKey;
    }
  }

  Color _getAccountColor(String dbKey) {
    final isKES = _currency == 'KES';
    switch (dbKey) {
      case 'cashTotal':
        return const Color(0xFF10B981);
      case 'mpesa1':
      case 'mpesa2':
        return const Color(0xFF22C55E);
      case 'coop':
        return const Color(0xFF3B82F6);
      case 'equity':
        return const Color(0xFFD97706);
      case 'kcb':
        return const Color(0xFF0D9488);
      case 'airtel':
        return isKES ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6);
      case 'otherMpesa':
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: const StandardAppBar(title: 'Accounting History'),
      body: _isLoading
          ? AppSkeleton.screen()
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.history_toggle_off_rounded, size: 40, color: Color(0xFFD1D5DB)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No accounting records found',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Records will appear here after your first entry',
                        style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF059669),
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    itemCount: _history.length,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final date = DateTime.fromMillisecondsSinceEpoch(item['timestamp']);
                      final disparity = item['salesDisparity'] as int? ?? 0;
                      
                      final total = (item['cashTotal'] as int? ?? 0) +
                          (item['mpesa1'] as int? ?? 0) +
                          (item['mpesa2'] as int? ?? 0) +
                          (item['coop'] as int? ?? 0) +
                          (item['equity'] as int? ?? 0) + 
                          (item['kcb'] as int? ?? 0) +
                          (item['airtel'] as int? ?? 0) +
                          (item['otherMpesa'] as int? ?? 0);

                      // Date header: show if first item or different day from previous
                      Widget? dateHeader;
                      if (index == 0 || !_isSameDay(date, DateTime.fromMillisecondsSinceEpoch(_history[index - 1]['timestamp']))) {
                        dateHeader = Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 10, top: index == 0 ? 0 : 16),
                          child: Text(
                            _formatDateHeader(date),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 1.5,
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dateHeader != null) dateHeader,
                          _buildHistoryCard(item, date, total, disparity),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) return 'TODAY';
    if (entryDate == yesterday) return 'YESTERDAY';
    return DateFormat('MMM d, yyyy').format(date).toUpperCase();
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, DateTime date, int total, int disparity) {
    // Disparity styling
    Color disparityBg, disparityFg;
    String disparityLabel;
    IconData disparityIcon;

    if (disparity == 0) {
      disparityBg = const Color(0xFFECFDF5);
      disparityFg = const Color(0xFF059669);
      disparityLabel = 'Balanced';
      disparityIcon = Icons.check_circle_rounded;
    } else if (disparity > 0) {
      disparityBg = const Color(0xFFEFF6FF);
      disparityFg = const Color(0xFF2563EB);
      disparityLabel = '+${_formatNum(disparity)}';
      disparityIcon = Icons.arrow_upward_rounded;
    } else {
      disparityBg = const Color(0xFFFEF2F2);
      disparityFg = const Color(0xFFDC2626);
      disparityLabel = _formatNum(disparity);
      disparityIcon = Icons.arrow_downward_rounded;
    }

    return Dismissible(
      key: Key(item['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626)),
      ),
      onDismissed: (_) => _deleteEntry(item['id']),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('h:mm a').format(date),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_currency ${_formatNum(total)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                // Disparity badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: disparityBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(disparityIcon, size: 12, color: disparityFg),
                      const SizedBox(width: 4),
                      Text(
                        disparityLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: disparityFg),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: [
              // Breakdown table
              _detailRow(_getAccountLabel('cashTotal'), item['cashTotal'], _getAccountColor('cashTotal')),
              _detailRow(_getAccountLabel('mpesa1'), item['mpesa1'], _getAccountColor('mpesa1')),
              _detailRow(_getAccountLabel('mpesa2'), item['mpesa2'], _getAccountColor('mpesa2')),
              _detailRow(_getAccountLabel('coop'), item['coop'], _getAccountColor('coop')),
              _detailRow(_getAccountLabel('equity'), item['equity'], _getAccountColor('equity')),
              _detailRow(_getAccountLabel('kcb'), item['kcb'], _getAccountColor('kcb')),
              _detailRow(_getAccountLabel('airtel'), item['airtel'], _getAccountColor('airtel')),
              _detailRow(_getAccountLabel('otherMpesa'), item['otherMpesa'], _getAccountColor('otherMpesa')),
              
              // Notes
              if (item['specialScenarios'] != null && item['specialScenarios'].toString().isNotEmpty) ...[
                const Divider(height: 16, color: Color(0xFFF3F4F6)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined, size: 14, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item['specialScenarios'],
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value, Color dotColor) {
    int val = value as int? ?? 0;
    if (val == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),
          Text('$_currency ${_formatNum(val)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        ],
      ),
    );
  }
}
