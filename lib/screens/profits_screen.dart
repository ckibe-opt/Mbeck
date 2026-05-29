import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_provider.dart';
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';
import '../services/module_scope.dart';
import '../widgets/interactive_help_scroll.dart';

class ProfitsScreen extends StatefulWidget {
  @override
  _ProfitsScreenState createState() => _ProfitsScreenState();
}

class _ProfitsScreenState extends State<ProfitsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sales = [];
  double _totalRevenue = 0;
  double _totalProfit = 0;
  double _totalCost = 0;
  int _itemCount = 0;

  // Date Range Filter
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Build WHERE clause with module isolation
      final scope = await ModuleScope.current();
      final moduleFilter = scope.txnWhere.replaceAll('source_module', 't.source_module');
      
      // Profits screen only makes sense for retail: it joins inventory for cost basis.
      // Non-retail modules (restaurant, services, lodging) record revenue-only txns —
      // their item_ids point to module-specific tables, NOT the retail inventory table.
      // Including them would produce false cost/profit figures (the bug reported).
      List<String> whereClauses = [
        "t.type = 'sale'",
        "t.source_module = 'retail'",
        moduleFilter,
      ];
      List<dynamic> args = [...scope.moduleArgs];

      if (_startDate != null && _endDate != null) {
        whereClauses.add('t.timestamp BETWEEN ? AND ?');
        args.add(_startDate!.millisecondsSinceEpoch);
        // Include entire end date
        args.add(_endDate!.add(const Duration(days: 1)).millisecondsSinceEpoch);
      }
      
      final whereSql = 'WHERE ${whereClauses.join(' AND ')}';

      // OPTIMIZATION: Calculate totals in SQL (much faster)
      final summarySql = '''
        SELECT 
          SUM(ti.quantity) as itemCount,
          SUM(ti.subtotal) as totalRevenue,
          SUM(COALESCE(i.originalPrice, 0) * ti.quantity) as totalCost,
          SUM(ti.subtotal - (COALESCE(i.originalPrice, 0) * ti.quantity)) as totalProfit
        FROM transaction_items ti
        JOIN inventory i ON ti.itemId = i.id AND i.source_module = 'retail'
        JOIN txn t ON ti.transactionId = t.id
        $whereSql
      ''';
      
      final summaryData = await DbProvider.queryRaw(summarySql, args);
      final summary = summaryData.first;

      String returnsWhere = "1=1";
      List<dynamic> returnsArgs = [];
      if (_startDate != null && _endDate != null) {
        returnsWhere = 'rr.created_at BETWEEN ? AND ?';
        returnsArgs.add(_startDate!.millisecondsSinceEpoch);
        returnsArgs.add(_endDate!.add(const Duration(days: 1)).millisecondsSinceEpoch);
      }

      final returnsSql = '''
        SELECT 
          SUM(rr.quantity) as returnItemCount,
          SUM(rr.refund_amount) as totalRefund,
          SUM(COALESCE(i.originalPrice, 0) * rr.quantity) as returnCost,
          SUM(rr.refund_amount - (COALESCE(i.originalPrice, 0) * rr.quantity)) as returnProfit
        FROM retail_returns rr
        LEFT JOIN inventory i ON rr.item_id = i.id
        WHERE \$returnsWhere
      ''';
      
      final returnsData = await DbProvider.queryRaw(returnsSql, returnsArgs);
      final returnsSum = returnsData.isEmpty ? {} : returnsData.first;

      final int retItemCount = (returnsSum['returnItemCount'] as num?)?.toInt() ?? 0;
      final double retRevenue = (returnsSum['totalRefund'] as num?)?.toDouble() ?? 0.0;
      final double retCost = (returnsSum['returnCost'] as num?)?.toDouble() ?? 0.0;
      final double retProfit = (returnsSum['returnProfit'] as num?)?.toDouble() ?? 0.0;

      // Fetch detailed list for display
      final listSql = '''
        SELECT 
          ti.id, 
          ti.subtotal as totalAmount, 
          t.timestamp,
          i.name as itemName, 
          i.originalPrice,
          i.category,
          ti.quantity,
          (ti.subtotal - (COALESCE(i.originalPrice, 0) * ti.quantity)) as profit
        FROM transaction_items ti
        JOIN inventory i ON ti.itemId = i.id AND i.source_module = 'retail'
        JOIN txn t ON ti.transactionId = t.id
        $whereSql
        ORDER BY t.timestamp DESC
      ''';
      
      final listData = await DbProvider.queryRaw(listSql, args);

      if (mounted) {
        setState(() {
          _sales = listData;
          _itemCount = ((summary['itemCount'] as num?)?.toInt() ?? 0) - retItemCount;
          _totalRevenue = ((summary['totalRevenue'] as num?)?.toDouble() ?? 0.0) - retRevenue;
          _totalCost = ((summary['totalCost'] as num?)?.toDouble() ?? 0.0) - retCost;
          _totalProfit = ((summary['totalProfit'] as num?)?.toDouble() ?? 0.0) - retProfit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profits: $e'))
        );
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (range != null) {
      setState(() { 
        _startDate = range.start; 
        _endDate = range.end; 
      });
      _loadData();
    }
  }

  void _clearFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final profitMargin = _totalRevenue > 0 
      ? (_totalProfit / _totalRevenue * 100) 
      : 0.0;

    return Scaffold(
      appBar: const StandardAppBar(title: 'Profits Analysis'),
      body: Stack(
        children: [
          _isLoading
            ? AppSkeleton.screen()
            : Column(
                children: [
                  // SUMMARY CARDS
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                'Revenue', 
                                _totalRevenue, 
                                Colors.blue,
                                Icons.attach_money,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                'Cost', 
                                _totalCost, 
                                Colors.orange,
                                Icons.shopping_cart,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                'Net Profit', 
                                _totalProfit, 
                                _totalProfit >= 0 ? Colors.green : Colors.red,
                                Icons.trending_up,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Margin', 
                                '${profitMargin.toStringAsFixed(1)}%',
                                profitMargin >= 30 ? Colors.green : Colors.orange,
                                Icons.percent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_bag, 
                                size: 18, 
                                color: Colors.grey
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_itemCount items sold',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1),

                  // Filter Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 8
                    ),
                    color: Colors.grey.shade100,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _startDate != null 
                              ? '${DateFormat.yMMMd().format(_startDate!)} - ${DateFormat.yMMMd().format(_endDate!)}'
                              : 'Showing all time',
                            style: TextStyle(
                              color: Colors.grey.shade700, 
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (_startDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: _clearFilter,
                            tooltip: 'Clear Filter',
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.filter_list, 
                            color: _startDate != null 
                              ? Colors.blue 
                              : Colors.grey
                          ), 
                          onPressed: _pickDateRange,
                          tooltip: 'Filter by Date',
                        ),
                      ],
                    ),
                  ),

                  // TRANSACTION LIST
                  Expanded(
                    child: _sales.isEmpty 
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined, 
                                size: 64, 
                                color: Colors.grey.shade300
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No sales records found", 
                                style: TextStyle(color: Colors.grey)
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.separated(
                            itemCount: _sales.length,
                            separatorBuilder: (c, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _sales[index];
                              final date = DateTime.fromMillisecondsSinceEpoch(
                                item['timestamp']
                              );
                              final sell = (item['totalAmount'] as num).toDouble();
                              final profit = (item['profit'] as num? ?? 0.0).toDouble();
                              final name = item['itemName'] ?? 'Deleted Item';
                              final category = item['category'] ?? '';
                              final quantity = item['quantity'] as int? ?? 1;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: profit >= 0 
                                    ? Colors.green.shade50 
                                    : Colors.red.shade50,
                                  child: Icon(
                                    profit >= 0 
                                      ? Icons.trending_up 
                                      : Icons.trending_down,
                                    color: profit >= 0 
                                      ? Colors.green.shade700 
                                      : Colors.red.shade700,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '$name x$quantity', 
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold
                                  )
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (category.isNotEmpty)
                                      Text(
                                        category,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    Text(
                                      DateFormat('MMM d, h:mm a').format(date), 
                                      style: const TextStyle(
                                        fontSize: 12, 
                                        color: Colors.grey
                                      )
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'KSH ${_format(profit)}', 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        color: profit >= 0 
                                          ? Colors.green 
                                          : Colors.red,
                                        fontSize: 15
                                      )
                                    ),
                                    Text(
                                      'Sold: ${_format(sell)}', 
                                      style: const TextStyle(
                                        fontSize: 11, 
                                        color: Colors.grey
                                      )
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                  ),
                ],
              ),
          const InteractiveHelpScroll(contextKey: 'profits'),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label, 
                style: TextStyle(
                  color: Colors.grey[700], 
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                )
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'KSH ${_format(value)}', 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 18, 
                color: color
              )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label, 
                style: TextStyle(
                  color: Colors.grey[700], 
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                )
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value, 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 18, 
                color: color
              )
            ),
          ),
        ],
      ),
    );
  }

  String _format(double val) {
    return NumberFormat('#,##0.##').format(val);
  }
}
