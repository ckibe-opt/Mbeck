// ============================================================================
// OPTIMIZED RESTOCK ANALYSIS SCREEN (restock_analysis_screen.dart)
// ============================================================================

import 'package:flutter/material.dart';
import '../widgets/empty_state_guide.dart';
import 'package:intl/intl.dart';
import '../db/db_provider.dart';
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';
import '../widgets/interactive_help_scroll.dart';

class RestockAnalysisScreen extends StatefulWidget {
  const RestockAnalysisScreen({Key? key}) : super(key: key);

  @override
  _RestockAnalysisScreenState createState() => _RestockAnalysisScreenState();
}

class _RestockAnalysisScreenState extends State<RestockAnalysisScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _analysisData = [];
  String _timeRange = '30'; // Default: Last 30 Days

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() => _isLoading = true);

    try {
      // Calculate start date based on filter
      int startTimestamp = 0;
      if (_timeRange != 'all') {
        final now = DateTime.now();
        final days = int.parse(_timeRange);
        startTimestamp = now.subtract(Duration(days: days))
          .millisecondsSinceEpoch;
      }

      final results = await DbProvider.queryRaw('''
        SELECT 
          i.name as name,
          i.stock as currentStock,
          i.category as category,
          SUM(ti.quantity) as soldQty,
          SUM(ti.subtotal - (COALESCE(i.originalPrice, 0) * ti.quantity)) as totalProfit
        FROM transaction_items ti
        JOIN inventory i ON ti.itemId = i.id AND i.source_module = 'retail'
        JOIN txn t ON ti.transactionId = t.id
        WHERE t.type = 'sale' AND t.source_module = 'retail' AND t.timestamp >= ?
        GROUP BY i.id
        ORDER BY soldQty DESC
      ''', [startTimestamp]);

      print('Restock Analysis Results: $results');

      if (mounted) {
        setState(() {
          _analysisData = List.from(results);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analysisData = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analysis: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Find max sold qty for progress bar scaling
    int maxSold = 1;
    if (_analysisData.isNotEmpty) {
      maxSold = (_analysisData.first['soldQty'] as num).toInt();
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: StandardAppBar(
        title: 'Restock Analysis',
        actions: [
          // Time Range Filter
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _timeRange,
                icon: const Icon(Icons.filter_list, color: Colors.green),
                items: const [
                  DropdownMenuItem(
                    value: '7',
                    child: Text('Last 7 Days')
                  ),
                  DropdownMenuItem(
                    value: '30',
                    child: Text('Last 30 Days')
                  ),
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All Time')
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _timeRange = val);
                    _loadAnalysis();
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
            ? AppSkeleton.screen()
        : _analysisData.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadAnalysis,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _analysisData.length,
                itemBuilder: (context, index) {
                  final item = _analysisData[index];
                  final name = item['name'] ?? 'Unknown Item';
                  final sold = (item['soldQty'] as num? ?? 0).toInt();
                  final stock = (item['currentStock'] as num? ?? 0).toInt();
                  final profit = (item['totalProfit'] as num? ?? 0).toDouble();
                  final category = item['category'] ?? '';
                  
                  // Restock Priority Logic
                  bool isCritical = stock < (sold * 0.2); // < 20% of sales
                  bool isOut = stock == 0;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Rank Badge
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: index < 3 
                                  ? Colors.orange.shade100 
                                  : Colors.grey.shade100,
                                child: Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12, 
                                    fontWeight: FontWeight.bold,
                                    color: index < 3 
                                      ? Colors.orange.shade800 
                                      : Colors.grey.shade600
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name, 
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 16
                                      )
                                    ),
                                    if (category.isNotEmpty)
                                      Text(
                                        category,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Profit: KSH ${NumberFormat('#,##0').format(profit)}',
                                      style: TextStyle(
                                        color: Colors.green[700], 
                                        fontSize: 13, 
                                        fontWeight: FontWeight.w500
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Status Badge
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (isOut)
                                    _buildBadge('OUT', Colors.red)
                                  else if (isCritical)
                                    _buildBadge('LOW', Colors.orange)
                                  else
                                    _buildBadge('$stock', Colors.blueGrey),
                                  const SizedBox(height: 4),
                                  Text(
                                    'in stock',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Sales Frequency Bar
                          Row(
                            children: [
                              Text(
                                '$sold sold', 
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: Colors.grey[600]
                                )
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: sold / maxSold,
                                    backgroundColor: Colors.grey[100],
                                    color: Colors.blue[400],
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const InteractiveHelpScroll(contextKey: 'restock'),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade100),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.bold, 
          color: color.shade700
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateGuide(
      icon: Icons.bar_chart,
      title: 'No restock data yet',
      subtitle: 'Start selling and we\'ll show you which items are running low and need restocking',
    );
  }
}
