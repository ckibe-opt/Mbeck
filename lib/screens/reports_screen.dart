// ============================================================================
// REPORTS SCREEN — aligned to HTML Showcase (reports_screen)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_provider.dart';
import '../theme/design_system.dart';
import '../services/onboarding_service.dart';
import '../services/module_scope.dart';
import '../services/report_export_service.dart';
import '../widgets/interactive_help_scroll.dart';
import '../services/auth_service.dart';
import '../models/permissions.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _showExportMenu = false;
  List<String> _enabledModules = ['retail'];

  // Access control state
  bool _isCheckingAccess = true;
  bool _hasAccess = false;

  List<_PeriodRow> _weeklyData = [];
  List<_PeriodRow> _monthlyData = [];
  List<_PeriodRow> _yearlyData = [];
  List<Map<String, dynamic>> _itemSalesData = [];
  List<Map<String, dynamic>> _restaurantOrdersData = [];

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final member = await AuthService.getCurrentMember();
      final hasAccess = member?.hasPermission(Permissions.viewReports) ?? false;
      if (mounted) {
        setState(() {
          _hasAccess = hasAccess;
          _isCheckingAccess = false;
        });
        if (!hasAccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Access Denied: You do not have permission to view Reports."),
              backgroundColor: AppColors.danger,
            ),
          );
          Navigator.pop(context);
        } else {
          _loadModules();
          _loadData();
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

  Future<void> _loadModules() async {
    final modules = await OnboardingService.getSelectedModules();
    debugPrint('📊 Reports: Active modules = $modules');
    if (mounted) setState(() => _enabledModules = modules);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── DATA LOADING ──────────────────────────────────────────────────────────

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final scope = await ModuleScope.current();
      final moduleFilter = scope.txnWhere;
      final mArgs = scope.moduleArgs;

      // Helper to process SQL results
      List<_PeriodRow> processSqlResults(
        List<Map<String, dynamic>> rows,
        String Function(DateTime) labelFormatter,
      ) {
        return rows.map((row) {
          final timestamp = row['anchor'] as int;
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return _PeriodRow(
            label: labelFormatter(date),
            income: (row['income'] as num? ?? 0).toInt(),
            expense: (row['expense'] as num? ?? 0).toInt(),
            count: (row['count'] as num? ?? 0).toInt(),
          );
        }).toList();
      }

      // 1. Weekly
      final weeklyRows = await DbProvider.queryRaw('''
        SELECT
          strftime('%Y-%W', timestamp / 1000, 'unixepoch', 'localtime') as bucket,
          MAX(timestamp) as anchor,
          SUM(CASE WHEN type = 'sale' OR type = 'incoming' THEN totalAmount ELSE 0 END) as income,
          SUM(CASE WHEN type = 'outgoing' THEN totalAmount ELSE 0 END) as expense,
          COUNT(id) as count
        FROM txn
        WHERE type IN ('sale', 'incoming', 'outgoing') AND $moduleFilter
        GROUP BY bucket ORDER BY bucket DESC LIMIT 50
      ''', mArgs);

      final weekly = processSqlResults(weeklyRows, (date) {
        final monday = date.subtract(Duration(days: date.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return '${DateFormat('MMM d').format(monday)} - ${DateFormat('MMM d').format(sunday)}';
      });
      // Link prevIncome
      for (int i = 0; i < weekly.length; i++) {
        if (i + 1 < weekly.length) weekly[i].prevIncome = weekly[i + 1].income;
      }

      // 2. Monthly
      final monthlyRows = await DbProvider.queryRaw('''
        SELECT
          strftime('%Y-%m', timestamp / 1000, 'unixepoch', 'localtime') as bucket,
          MAX(timestamp) as anchor,
          SUM(CASE WHEN type = 'sale' OR type = 'incoming' THEN totalAmount ELSE 0 END) as income,
          SUM(CASE WHEN type = 'outgoing' THEN totalAmount ELSE 0 END) as expense,
          COUNT(id) as count
        FROM txn
        WHERE type IN ('sale', 'incoming', 'outgoing') AND $moduleFilter
        GROUP BY bucket ORDER BY bucket DESC LIMIT 24
      ''', mArgs);

      final monthly = processSqlResults(monthlyRows, (date) => DateFormat('MMM yyyy').format(date));
      for (int i = 0; i < monthly.length; i++) {
        if (i + 1 < monthly.length) monthly[i].prevIncome = monthly[i + 1].income;
      }

      // 3. Yearly
      final yearlyRows = await DbProvider.queryRaw('''
        SELECT
          strftime('%Y', timestamp / 1000, 'unixepoch', 'localtime') as bucket,
          MAX(timestamp) as anchor,
          SUM(CASE WHEN type = 'sale' OR type = 'incoming' THEN totalAmount ELSE 0 END) as income,
          SUM(CASE WHEN type = 'outgoing' THEN totalAmount ELSE 0 END) as expense,
          COUNT(id) as count
        FROM txn
        WHERE type IN ('sale', 'incoming', 'outgoing') AND $moduleFilter
        GROUP BY bucket ORDER BY bucket DESC
      ''', mArgs);

      final yearly = processSqlResults(yearlyRows, (date) => date.year.toString());
      for (int i = 0; i < yearly.length; i++) {
        if (i + 1 < yearly.length) yearly[i].prevIncome = yearly[i + 1].income;
      }

      // 4. Items Report
      String itemSql = '''
        SELECT
          i.name, i.category, COUNT(t.id) as qty,
          SUM(t.totalAmount) as revenue, i.originalPrice, i.stock
        FROM txn t LEFT JOIN inventory i ON t.itemId = i.id
      ''';
      List<dynamic> itemArgs = [...mArgs];
      List<String> itemWhereClauses = ["t.type = 'sale'", moduleFilter.replaceAll('source_module', 't.source_module')];
      if (_startDate != null && _endDate != null) {
        itemWhereClauses.add('t.timestamp BETWEEN ? AND ?');
        itemArgs.add(_startDate!.millisecondsSinceEpoch);
        itemArgs.add(_endDate!.millisecondsSinceEpoch);
      }
      itemSql += ' WHERE ${itemWhereClauses.join(' AND ')}';
      itemSql += ' GROUP BY i.id ORDER BY qty DESC';

      final rawItemData = await DbProvider.queryRaw(itemSql, itemArgs);
      final processedItems = rawItemData.map((row) {
        final qty = (row['qty'] as num).toInt();
        final revenue = (row['revenue'] as num).toDouble();
        final cost = (row['originalPrice'] as num?)?.toDouble() ?? 0.0;
        return {
          'name': row['name'] ?? 'Deleted Item',
          'category': row['category'] ?? 'General',
          'qty': qty,
          'revenue': revenue,
          'profit': revenue - (cost * qty),
          'stock': (row['stock'] as num?)?.toInt() ?? 0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _weeklyData = weekly;
          _monthlyData = monthly;
          _yearlyData = yearly;
          _itemSalesData = processedItems;
          _isLoading = false;
        });
      }

      // 5. Restaurant Orders
      if (_enabledModules.contains('restaurant')) {
        try {
          String ordersSql = '''
            SELECT ro.id, ro.order_number, ro.order_type, ro.table_number,
                   ro.customer_name, 
                   COALESCE((SELECT SUM(quantity * unit_price) FROM restaurant_order_items WHERE order_id = ro.id), ro.total) as total,
                   ro.status, ro.items_json, ro.created_at
            FROM restaurant_orders ro
          ''';
          List<dynamic> ordersArgs = [];
          List<String> ordersWhere = [];
          if (_startDate != null && _endDate != null) {
            ordersWhere.add('ro.created_at BETWEEN ? AND ?');
            ordersArgs.add(_startDate!.millisecondsSinceEpoch);
            ordersArgs.add(_endDate!.millisecondsSinceEpoch);
          }
          if (ordersWhere.isNotEmpty) ordersSql += ' WHERE ${ordersWhere.join(' AND ')}';
          ordersSql += ' ORDER BY ro.created_at DESC LIMIT 100';

          final rawOrders = await DbProvider.queryRaw(ordersSql, ordersArgs);
          if (mounted) {
            setState(() => _restaurantOrdersData = rawOrders.map((e) => Map<String, dynamic>.from(e)).toList());
          }
        } catch (e) {
          debugPrint('⚠️ Error loading restaurant orders: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading reports: $e')));
      }
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (range != null) {
      setState(() { _startDate = range.start; _endDate = range.end; });
      _loadData();
    }
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  String _fmt(num val) => NumberFormat('#,##0').format(val);

  String _trendPct(int curr, int prev) {
    if (prev == 0) return '+0.0';
    final pct = ((curr - prev) / prev * 100);
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}';
  }

  bool _trendUp(int curr, int prev) => curr >= prev;

  Color _marginColor(int income, int expense) {
    final m = income > 0 ? ((income - expense) / income * 100) : 0.0;
    if (m >= 20) return const Color(0xFF10B981);
    if (m >= 10) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _marginBgColor(int income, int expense) {
    final m = income > 0 ? ((income - expense) / income * 100) : 0.0;
    if (m >= 20) return const Color(0xFF10B981).withOpacity(0.1);
    if (m >= 10) return const Color(0xFFF59E0B).withOpacity(0.1);
    return const Color(0xFFEF4444).withOpacity(0.1);
  }

  double _barFraction(int expense, int income) {
    if (income == 0) return 0;
    return (expense / income).clamp(0.0, 1.0);
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9FAFB),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasAccess) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9FAFB),
        body: Center(child: Text("Access Denied")),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          Column(
            children: [
              // ─── App Bar ─────────────────────
              Container(
                color: Colors.white,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                        child: Row(
                          children: [
                            const Text('Business Reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5)),
                            const Spacer(),
                            // Export / more menu
                            GestureDetector(
                              onTap: () => setState(() => _showExportMenu = !_showExportMenu),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.more_vert, size: 20, color: Color(0xFF6B7280)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ─── 5 Tabs ─────────────────────
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: const Color(0xFF111827),
                        unselectedLabelColor: const Color(0xFF9CA3AF),
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        indicatorColor: const Color(0xFF16A34A),
                        indicatorWeight: 2.5,
                        tabAlignment: TabAlignment.start,
                        tabs: const [
                          Tab(text: 'Weekly'),
                          Tab(text: 'Monthly'),
                          Tab(text: 'Yearly'),
                          Tab(text: 'Items Sold'),
                          Tab(text: 'Orders'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // ─── Content ─────────────────────
              Expanded(
                child: _isLoading
                    ? AppSkeleton.screen()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPeriodTab(_weeklyData),
                          _buildPeriodTab(_monthlyData),
                          _buildPeriodTab(_yearlyData),
                          _buildItemsTab(),
                          _buildOrdersTab(),
                        ],
                      ),
              ),
            ],
          ),
          // ─── Export Dropdown ─────────────────────
          if (_showExportMenu)
            Positioned(
              right: 16, top: MediaQuery.of(context).padding.top + 44,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                child: Container(
                  width: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildExportOption(Icons.picture_as_pdf, 'Export as PDF', const Color(0xFFEF4444), () => _performExport(true)),
                      Container(height: 1, color: const Color(0xFFF9FAFB)),
                      _buildExportOption(Icons.table_chart, 'Export as CSV', const Color(0xFF10B981), () => _performExport(false)),
                      Container(height: 1, color: const Color(0xFFF9FAFB)),
                      _buildExportOption(Icons.share, 'Share Report', const Color(0xFF3B82F6), () => _performExport(true)), // Default share to PDF
                    ],
                  ),
                ),
              ),
            ),
          // ─── Export FAB ─────────────────────

          Positioned(
            bottom: 16, right: 16,
            child: GestureDetector(
              onTap: () => setState(() => _showExportMenu = !_showExportMenu),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.download, color: Colors.white, size: 22),
              ),
            ),
          ),
          const InteractiveHelpScroll(contextKey: 'reports'),
        ],
      ),
    );
  }

  Future<void> _performExport(bool asPdf) async {
    List<String> headers;
    List<List<dynamic>> rows;
    String title;

    if (_tabController.index == 0) {
      title = 'Weekly_Report';
      headers = ['Period', 'Sales (KES)', 'Expenses (KES)', 'Net (KES)', 'Txns'];
      rows = _weeklyData.map((e) => [e.label, e.income, e.expense, e.income - e.expense, e.count]).toList();
    } else if (_tabController.index == 1) {
      title = 'Monthly_Report';
      headers = ['Period', 'Sales (KES)', 'Expenses (KES)', 'Net (KES)', 'Txns'];
      rows = _monthlyData.map((e) => [e.label, e.income, e.expense, e.income - e.expense, e.count]).toList();
    } else if (_tabController.index == 2) {
      title = 'Yearly_Report';
      headers = ['Period', 'Sales (KES)', 'Expenses (KES)', 'Net (KES)', 'Txns'];
      rows = _yearlyData.map((e) => [e.label, e.income, e.expense, e.income - e.expense, e.count]).toList();
    } else if (_tabController.index == 3) {
      title = 'Item_Sales';
      headers = ['Item Name', 'Category', 'Stock Left', 'Qty Sold', 'Revenue (KES)', 'Profit (KES)'];
      rows = _itemSalesData.map((e) => [e['name'], e['category'], e['stock'], e['qty'], e['revenue'], e['profit']]).toList();
    } else {
      title = 'Restaurant_Orders';
      headers = ['Order #', 'Type', 'Table', 'Status', 'Total (KES)'];
      rows = _restaurantOrdersData.map((e) => [e['order_number'], e['order_type'], e['table_number'] ?? 'N/A', e['status'], e['total']]).toList();
    }

    if (asPdf) {
      await ReportExportService.exportAsPdf(context: context, title: title, headers: headers, data: rows);
    } else {
      await ReportExportService.exportAsCsv(context: context, title: title, rows: [headers, ...rows]);
    }
  }

  Widget _buildExportOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        setState(() => _showExportMenu = false);
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF374151))),
          ],
        ),
      ),
    );
  }

  // ─── SUMMARY HERO CARD (dark gradient, shown on period tabs) ───────────────

  Widget _buildHeroCard(List<_PeriodRow> data) {
    final totalRevenue = data.fold<int>(0, (s, r) => s + r.income);
    final totalExpense = data.fold<int>(0, (s, r) => s + r.expense);
    final totalProfit = totalRevenue - totalExpense;
    final profitMargin = totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0.0;
    final totalTxns = data.fold<int>(0, (s, r) => s + r.count);
    final expenseRatio = totalRevenue > 0 ? (totalExpense / totalRevenue * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF1F2937), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PERIOD OVERVIEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              // Revenue
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REVENUE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF6B7280), letterSpacing: 1)),
                  Text('KES ${_fmt(totalRevenue)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, height: 1.3)),
                ],
              )),
              // Margin
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MARGIN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF6B7280), letterSpacing: 1)),
                  Text('${profitMargin.toStringAsFixed(1)}%', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, height: 1.3,
                    color: profitMargin >= 20 ? const Color(0xFF34D399) : profitMargin >= 10 ? const Color(0xFFFBBF24) : const Color(0xFFF87171),
                  )),
                ],
              )),
              // Transactions
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TRANSACTIONS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF6B7280), letterSpacing: 1)),
                  Text(_fmt(totalTxns), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, height: 1.3)),
                ],
              )),
            ],
          ),
          // Expense ratio bar
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Expense Ratio', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
              Text('${expenseRatio.toStringAsFixed(0)}% of revenue', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF))),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 5,
              child: LinearProgressIndicator(
                value: (expenseRatio / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  expenseRatio > 70 ? const Color(0xFFEF4444) : expenseRatio > 50 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PERIOD TAB (Weekly/Monthly/Yearly) ────────────────────────────────────

  Widget _buildPeriodTab(List<_PeriodRow> data) {
    if (data.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: () => _loadData(silent: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          _buildHeroCard(data),
          const SizedBox(height: 4),
          ...data.map((row) => _buildPeriodCard(row)),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(_PeriodRow row) {
    final net = row.income - row.expense;
    final margin = row.income > 0 ? ((row.income - row.expense) / row.income * 100) : 0.0;
    final hasPrev = row.prevIncome > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: label + margin badge + trend arrow
          Row(
            children: [
              Expanded(child: Text(row.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)))),
              // Margin badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _marginBgColor(row.income, row.expense),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${margin.toStringAsFixed(0)}% margin', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _marginColor(row.income, row.expense))),
              ),
              if (hasPrev) ...[
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_trendPct(row.income, row.prevIncome)}%', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: _trendUp(row.income, row.prevIncome) ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    )),
                    Icon(
                      _trendUp(row.income, row.prevIncome) ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 11,
                      color: _trendUp(row.income, row.prevIncome) ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0xFFF3F4F6)),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children: [
              Expanded(child: _buildPeriodStat('SALES', row.income, const Color(0xFF10B981))),
              Expanded(child: _buildPeriodStat('EXPENSES', row.expense, const Color(0xFFEF4444))),
              Expanded(child: _buildPeriodStat('NET', net, net >= 0 ? const Color(0xFF3B82F6) : const Color(0xFFEA580C))),
            ],
          ),
          const SizedBox(height: 10),
          // Mini expense bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      value: 1.0 - _barFraction(row.expense, row.income),
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${row.count} txns', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color.withOpacity(0.6), letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text('KES ${_fmt(value)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  // ─── ITEMS SOLD TAB ────────────────────────────────────────────────────────

  Widget _buildItemsTab() {
    if (_itemSalesData.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        // Date filter bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _startDate != null ? '${DateFormat.yMMMd().format(_startDate!)} – ${DateFormat.yMMMd().format(_endDate!)}' : 'All time',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                ),
              ),
              GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Change Range', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadData(silent: true),
            child: ListView.builder(
              itemCount: _itemSalesData.length,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemBuilder: (ctx, i) {
                final item = _itemSalesData[i];
                final profit = item['profit'] as double;
                final stock = item['stock'] as int;
                final qty = item['qty'] as int;
                bool lowStock = stock == 0 || (stock < qty * 0.2);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        // Rank circle
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: lowStock ? const Color(0xFFEF4444).withOpacity(0.1) : const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          alignment: Alignment.center,
                          child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: lowStock ? const Color(0xFFEF4444) : const Color(0xFF10B981))),
                        ),
                        const SizedBox(width: 10),
                        // Name + category + stock
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(item['category'], style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                              if (lowStock)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.15)),
                                  ),
                                  child: Text('Stock: $stock – Restock!', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                                )
                              else
                                Text('Stock: $stock', style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Qty + profit
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$qty Sold', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                            Text('KES ${_fmt(profit.toInt())}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: profit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ─── ORDERS TAB ────────────────────────────────────────────────────────────

  Widget _buildOrdersTab() {
    if (_restaurantOrdersData.isEmpty) return _buildEmptyState();

    final completedCount = _restaurantOrdersData.where((o) => o['status'] == 'completed' || o['status'] == 'served').length;
    final pendingCount = _restaurantOrdersData.where((o) => o['status'] == 'pending' || o['status'] == 'preparing').length;
    final totalRevenue = _restaurantOrdersData
        .where((o) => o['status'] == 'completed' || o['status'] == 'served')
        .fold<double>(0, (sum, o) => sum + ((o['total'] as num?)?.toDouble() ?? 0));
    final dineInCount = _restaurantOrdersData.where((o) {
      final t = o['order_type']?.toString().toLowerCase() ?? '';
      return t == 'dine_in' || t == 'dine-in';
    }).length;
    final takeawayCount = _restaurantOrdersData.length - dineInCount;

    return Column(
      children: [
        // Summary bar (gradient teal)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFF0FDFA), Color(0xFFECFDF5)]),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildOrderSummary('Completed', completedCount.toString(), const Color(0xFF10B981))),
                  Expanded(child: _buildOrderSummary('Pending', pendingCount.toString(), const Color(0xFFF59E0B))),
                  Expanded(child: _buildOrderSummary('Revenue', 'KES ${_fmt(totalRevenue.toInt())}', const Color(0xFF0D9488))),
                ],
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: const Color(0xFF0D9488).withOpacity(0.1)),
              const SizedBox(height: 6),
              // Order type breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTypeIndicator(const Color(0xFF3B82F6), 'Dine-in', dineInCount),
                  const SizedBox(width: 16),
                  _buildTypeIndicator(const Color(0xFFF59E0B), 'Takeaway/Delivery', takeawayCount),
                ],
              ),
            ],
          ),
        ),
        // Date filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _startDate != null ? '${DateFormat.yMMMd().format(_startDate!)} – ${DateFormat.yMMMd().format(_endDate!)}' : 'All orders',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                ),
              ),
              GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF0D9488).withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Filter', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0D9488))),
                ),
              ),
            ],
          ),
        ),
        // Orders list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadData(silent: true),
            child: ListView.builder(
              itemCount: _restaurantOrdersData.length,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemBuilder: (ctx, i) {
                final order = _restaurantOrdersData[i];
                final status = order['status']?.toString() ?? 'unknown';
                final total = (order['total'] as num?)?.toDouble() ?? 0;
                final orderNum = order['order_number']?.toString() ?? '#${order['id']}';
                final orderType = (order['order_type']?.toString() ?? 'takeaway').replaceAll('_', ' ');
                final createdAt = order['created_at'] as int? ?? 0;
                final date = createdAt > 0 ? DateTime.fromMillisecondsSinceEpoch(createdAt) : DateTime.now();
                final customerName = order['customer_name']?.toString();
                final table = order['table_number']?.toString();

                Color statusColor;
                IconData statusIcon;
                switch (status) {
                  case 'completed': case 'served':
                    statusColor = const Color(0xFF10B981); statusIcon = Icons.check_circle; break;
                  case 'preparing':
                    statusColor = const Color(0xFFF59E0B); statusIcon = Icons.restaurant; break;
                  case 'ready':
                    statusColor = const Color(0xFF3B82F6); statusIcon = Icons.notifications_active; break;
                  default:
                    statusColor = const Color(0xFF9CA3AF); statusIcon = Icons.access_time;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        // Status icon
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Icon(statusIcon, size: 16, color: statusColor),
                        ),
                        const SizedBox(width: 10),
                        // Order info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Order $orderNum', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: statusColor)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${orderType[0].toUpperCase()}${orderType.substring(1)}${table != null ? ' • $table' : ''}${customerName != null ? ' • $customerName' : ''}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              Text(DateFormat.yMMMd().add_jm().format(date), style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Amount
                        Text(
                          'KES ${_fmt(total.toInt())}',
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900,
                            color: (status == 'completed' || status == 'served') ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildTypeIndicator(Color dotColor, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
        Text('$count', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF374151))),
      ],
    );
  }

  // ─── EMPTY STATE ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No data for this period', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text('Pull down to refresh', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

// ─── DATA MODEL ──────────────────────────────────────────────────────────────

class _PeriodRow {
  String label;
  int income;
  int expense;
  int count;
  int prevIncome;

  _PeriodRow({
    required this.label,
    this.income = 0,
    this.expense = 0,
    this.count = 0,
    this.prevIncome = 0,
  });
}
