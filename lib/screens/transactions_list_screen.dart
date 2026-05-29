import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../db/db_provider.dart';
import '../models/transaction_item.dart';
import '../theme/design_system.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../services/event_service.dart';
import '../services/onboarding_service.dart';
import '../services/module_scope.dart';
import '../services/receipt_helper.dart';
import '../widgets/interactive_help_scroll.dart';

class TransactionsListScreen extends StatefulWidget {
  @override
  _TransactionsListScreenState createState() => 
    _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  List<dynamic> _groupedItems = [];
  bool _isLoading = true;
  String _filterType = 'all'; // all, sale, income, expense
  Map<int, List<TransactionItem>> _transactionItemsCache = {}; // Cache transaction items (for type safety)
  final Set<int> _expandedTransactions = {}; // Track expanded items
  List<String> _enabledModules = [];

  // Single source of truth for currency formatting
  String _formatCurrency(num? value) {
    return NumberFormat('#,##0.00').format(value ?? 0);
  }

  @override
  void initState() {
    super.initState();
    _loadModules();
    _loadTxns();
  }

  Future<void> _loadModules() async {
    final modules = await OnboardingService.getSelectedModules();
    if (mounted) {
      setState(() => _enabledModules = modules);
    }
  }

  Future<void> _loadTxns() async {
    setState(() => _isLoading = true);
    
    try {
      // Build query with optional filter
      final scope = await ModuleScope.current();
      List<String> whereClauses = [scope.txnWhere];
      List<dynamic> args = [...scope.moduleArgs];
      
      if (_filterType != 'all') {
        if (_filterType == 'sale') {
          whereClauses.add("txn.type = 'sale'");
        } else if (_filterType == 'income') {
          whereClauses.add("txn.type = 'incoming'");
        } else if (_filterType == 'expense') {
          whereClauses.add("txn.type = 'outgoing'");
        }
      }
      
      final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
      
      // Query transaction headers (no longer joining inventory for itemId)
      final sql = '''
        SELECT txn.*
        FROM txn 
        $whereSql
        ORDER BY timestamp DESC
      ''';
      
      // sqflite returns read-only maps; create a mutable list of mutable maps
      final data = (await DbProvider.queryRaw(sql, args))
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      
      // For backward compatibility: if itemId exists, fetch item name
      for (var txn in data) {
        if (txn['itemId'] != null && txn['itemId'] != 0) {
          final itemData = await DbProvider.query(
            'inventory',
            where: 'id = ?',
            whereArgs: [txn['itemId']],
            limit: 1,
          );
          if (itemData.isNotEmpty) {
            txn['itemName'] = itemData.first['name'];
          }
        }
      }

      if (mounted) {
        setState(() {
          _groupedItems = _groupTransactions(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e'))
        );
      }
    }
  }

  List<dynamic> _groupTransactions(List<Map<String, dynamic>> txns) {
    if (txns.isEmpty) return [];

    final groupedMap = groupBy(txns, (txn) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        txn['timestamp']
      );
      return DateFormat('yyyy-MM-dd').format(date);
    });

    final List<dynamic> items = [];
    groupedMap.forEach((dateString, txnsInDay) {
      items.add(dateString); // Date header
      items.addAll(txnsInDay); // Transactions
    });

    return items;
  }

  /// Load transaction items for a specific transaction
  Future<List<Map<String, dynamic>>> _loadTransactionItems(int transactionId) async {
    if (_transactionItemsCache.containsKey(transactionId)) {
      // Return cached items with names
      return _transactionItemsCache[transactionId]!.map((item) => {
        'id': item.id,
        'itemId': item.itemId,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'subtotal': item.subtotal,
        'discount': item.discount,
      }).toList();
    }

    try {
      final itemsData = await DbProvider.queryRaw('''
        SELECT ti.*, 
          -- Prefer stored item_name (set by restaurant/services on insert)
          -- Fall back to retail inventory name only when item_name is NULL
          COALESCE(ti.item_name, inventory.name) as itemName
        FROM transaction_items ti
        LEFT JOIN inventory ON ti.itemId = inventory.id AND inventory.source_module = 'retail'
        WHERE ti.transactionId = ?
        ORDER BY ti.id
      ''', [transactionId]);

      final items = itemsData.map((row) => TransactionItem.fromMap(row)).toList();
      _transactionItemsCache[transactionId] = items;
      
      // Return with item names
      return itemsData;
    } catch (e) {
      debugPrint('Error loading transaction items: $e');
      return [];
    }
  }


  void _toggleExpanded(int transactionId) {
    setState(() {
      if (_expandedTransactions.contains(transactionId)) {
        _expandedTransactions.remove(transactionId);
      } else {
        _expandedTransactions.add(transactionId);
        // Preload items when expanding
        _loadTransactionItems(transactionId);
      }
    });
  }

  Future<void> _deleteTxn(int id) async {
    try {
      // Delete transaction items first (CASCADE should handle this, but explicit is safer)
      await DbProvider.delete('transaction_items', where: 'transactionId = ?', whereArgs: [id]);
      
      await DbProvider.delete(
        'txn', 
        where: 'id = ?', 
        whereArgs: [id]
      );
      
      // Clear cache
      _transactionItemsCache.remove(id);
      _expandedTransactions.remove(id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted'),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e'))
        );
      }
    } finally {
      await _loadTxns();
    }
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('FILTER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 1.5)),
            const SizedBox(height: 12),
            _buildFilterOption('All Transactions', 'all', Icons.list),
            _buildFilterOption('Sales Only', 'sale', Icons.shopping_bag),
            _buildFilterOption('Income', 'income', Icons.trending_up),
            _buildFilterOption('Expenses', 'expense', Icons.trending_down),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String value, IconData icon) {
    final isSelected = _filterType == value;
    final color = isSelected ? const Color(0xFF3B82F6) : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: () {
        setState(() => _filterType = value);
        Navigator.pop(context);
        _loadTxns();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280)))),
            if (isSelected) const Icon(Icons.check, size: 16, color: Color(0xFF3B82F6)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Text('Transactions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showFilterMenu,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _filterType != 'all' ? const Color(0xFF3B82F6).withOpacity(0.08) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.filter_list, size: 20, color: _filterType != 'all' ? const Color(0xFF3B82F6) : const Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ─── Content ─────────────────────
          Expanded(
            child: _isLoading
                ? AppSkeleton.screen()
                : RefreshIndicator(
                    onRefresh: _loadTxns,
                    child: _groupedItems.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: _buildEmptyState(),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _groupedItems.length,
                            itemBuilder: (context, index) {
                              final item = _groupedItems[index];
                              if (item is String) {
                                return _buildDateHeader(item);
                              } else {
                                return _buildTxnItem(
                                  item as Map<String, dynamic>
                                );
                              }
                            },
                          ),
                  ),
          ),
        ],
      ),
      const InteractiveHelpScroll(contextKey: 'history'),
      ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            _filterType == 'all' ? 'No transactions yet' : 'No ${_filterType}s found',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Text('Pull down to refresh', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    String displayText;
    if (transactionDate == today) {
      displayText = 'TODAY';
    } else if (transactionDate == yesterday) {
      displayText = 'YESTERDAY';
    } else {
      displayText = DateFormat.yMMMEd().format(date).toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        displayText,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildTxnItem(Map<String, dynamic> item) {
    final date = DateTime.fromMillisecondsSinceEpoch(item['timestamp']);
    final rawType = item['type'].toString();
    final transactionId = item['id'] as int;
    final isExpanded = _expandedTransactions.contains(transactionId);
    final sourceModule = item['source_module']?.toString() ?? 'retail';
    final staffName = item['staff_name']?.toString();
    
    String title;
    IconData iconData;
    Color iconColor;
    
    // Check if this is a legacy transaction (has itemId) or new format (has items)
    final isLegacy = item['itemId'] != null && item['itemId'] != 0;
    
    if (rawType == 'sale' && isLegacy && item['itemName'] != null) {
      // Module-aware title for legacy sales
      final prefix = sourceModule == 'restaurant' ? 'Ordered' 
                   : sourceModule == 'services' ? 'Booked' 
                   : sourceModule == 'lodging' ? 'Reserved' 
                   : 'Sold';
      title = '$prefix: ${item['itemName']}';
      iconData = sourceModule == 'restaurant' ? Icons.restaurant 
               : sourceModule == 'services' ? Icons.event_available 
               : sourceModule == 'lodging' ? Icons.hotel 
               : Icons.shopping_bag;
      iconColor = sourceModule == 'restaurant' ? Colors.deepOrange 
                : sourceModule == 'services' ? Colors.purple 
                : sourceModule == 'lodging' ? Colors.teal 
                : Colors.green.shade700;
    } else if (rawType == 'sale') {
      // Module-aware title for multi-item sales
      final saleType = sourceModule == 'restaurant' ? 'Order' 
                     : sourceModule == 'services' ? 'Appointment' 
                     : sourceModule == 'lodging' ? 'Folio' 
                     : 'Sale';
      title = '$saleType (${isExpanded ? 'Tap to collapse' : 'Tap to view items'})';
      iconData = sourceModule == 'restaurant' ? Icons.restaurant 
               : sourceModule == 'services' ? Icons.event_available 
               : sourceModule == 'lodging' ? Icons.hotel 
               : Icons.shopping_bag;
      iconColor = sourceModule == 'restaurant' ? Colors.deepOrange 
                 : sourceModule == 'services' ? Colors.purple 
                 : sourceModule == 'lodging' ? Colors.teal 
                 : Colors.green.shade700;
    } else if (rawType == 'incoming') {
      title = 'INCOME';
      iconData = Icons.add_circle;
      iconColor = Colors.blue.shade700;
    } else if (rawType == 'outgoing') {
      title = 'EXPENSE';
      iconData = Icons.remove_circle;
      iconColor = Colors.red.shade700;
    } else {
      title = rawType.replaceAll('_', ' ').toUpperCase();
      iconData = Icons.receipt;
      iconColor = Colors.grey.shade700;
    }

    String details = item['details'] ?? '';
    final isIncome = rawType == 'incoming' || 
                     rawType == 'sale' || 
                     rawType.contains('cash_in');
    
    final amount = (item['totalAmount'] as num? ?? 0);
    // Amounts are displayed as they are stored.
    final formattedAmount = _formatCurrency(amount);

    return Dismissible(
      key: ValueKey(item['id']),
      // Swipe RIGHT (startToEnd) = Receipt
      background: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, color: Colors.white, size: 24),
            SizedBox(height: 2),
            Text('Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10)),
          ],
        ),
      ),
      // Swipe LEFT (endToStart) = Delete
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_forever, color: Colors.white, size: 24),
            SizedBox(height: 2),
            Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10)),
          ],
        ),
      ),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        // ── Swipe RIGHT → Receipt ──
        if (direction == DismissDirection.startToEnd) {
          final total = (item['totalAmount'] as num?)?.toDouble() ?? 0;
          final timestamp = item['timestamp'] as int;
          final type = item['type']?.toString() ?? 'sale';

          final signature = await ReceiptHelper.ensureSignature(
            timestamp: timestamp,
            totalAmount: total,
            type: type,
            details: item['details']?.toString(),
            existingSignature: item['receiptSignature']?.toString(),
          );

          if (mounted) {
            List<Map<String, dynamic>>? receiptItems;
            try {
              final rows = await DbProvider.queryRaw(
                'SELECT itemId, item_name, quantity, unitPrice, subtotal FROM transaction_items WHERE transactionId = ?',
                [item['id']],
              );
              if (rows.isNotEmpty) {
                receiptItems = [];
                for (final row in rows) {
                  final itemId = row['itemId'];
                  String name = row['item_name']?.toString() ?? '';
                  if (name.isEmpty && itemId != null && itemId != 0) {
                    final inv = await DbProvider.queryRaw(
                      'SELECT name FROM inventory WHERE id = ? AND source_module = ?', [itemId, 'retail'],
                    );
                    if (inv.isNotEmpty) name = inv.first['name']?.toString() ?? '';
                  }
                  if (name.isEmpty) name = 'Item';
                  receiptItems.add({
                    'name': name,
                    'qty': row['quantity'] ?? 1,
                    'price': row['unitPrice'] ?? 0,
                  });
                }
              }
            } catch (_) {}

            await ReceiptHelper.showReceiptDialog(
              context,
              total: total,
              timestamp: timestamp,
              signature: signature,
              txnType: type,
              details: item['details']?.toString(),
              items: receiptItems,
            );
          }
          return false;
        }

        // ── Swipe LEFT → Delete ──
        final currentMember = await AuthService.getCurrentMember();
        final isManager = currentMember != null && currentMember.role.toUpperCase() == 'MANAGER';
        final isOwner = currentMember != null && currentMember.role.toUpperCase() == 'OWNER';

        if (!isManager && !isOwner) {
          EventService.emitEvent(
            eventType: 'SECURITY_VIOLATION',
            payload: {
              'action': 'DELETE_TRANSACTION',
              'transactionId': item['id'],
              'userId': currentMember?.id,
              'userRole': currentMember?.role,
              'reason': 'Unauthorized'
            },
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⛔ Permission Denied: Only Managers/Owners can delete transactions'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }

        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text("Confirm Delete"),
              ],
            ),
            content: const Text(
              "Delete this transaction permanently?\n\n"
              "This action cannot be undone."
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("CANCEL"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "DELETE",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _deleteTxn(item['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleExpanded(transactionId),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Left accent + icon
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: isIncome ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(iconData, size: 18, color: iconColor),
                    ),
                    const SizedBox(width: 12),
                    // Title + details + time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (details.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(details, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          if (staffName != null && staffName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person, size: 10, color: Color(0xFF6B7280)),
                                  const SizedBox(width: 3),
                                  Text(staffName, style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(DateFormat('h:mm a').format(date), style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                          if (item['payment_ref'] != null && (item['payment_ref'] as String).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.phone_android, size: 10, color: const Color(0xFF10B981)),
                                  const SizedBox(width: 3),
                                  Text('Ref: ${item['payment_ref']}', style: const TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Amount + badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isIncome ? const Color(0xFF10B981).withOpacity(0.08) : const Color(0xFFEF4444).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'KES $formattedAmount',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Receipt signature stored for audit; inline verification
                            // removed — per-device HMAC keys cause false alerts on synced txns
                            if (!isLegacy) ...[
                              const SizedBox(width: 4),
                              Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 14, color: const Color(0xFF9CA3AF)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Expanded items list
            if (isExpanded && !isLegacy)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadTransactionItems(transactionId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  final items = snapshot.data!;
                  
                  if (items.isEmpty) {
                    // Provide a fallback detail view for system transactions (POs, Refunds) lacking line items
                    return Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: const Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              details.isNotEmpty ? details : 'System transaction without detailed line items.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sourceModule == 'restaurant'
                              ? 'Dishes (${items.length}):'
                              : sourceModule == 'services'
                                  ? 'Services (${items.length}):'
                                  : sourceModule == 'lodging'
                                      ? 'Folio Items (${items.length}):'
                                      : 'Items (${items.length}):',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        ...items.map((itemRow) {
                          final itemName = itemRow['itemName'] as String? ?? 'Item #${itemRow['itemId']}';
                          final quantity = itemRow['quantity'] as int? ?? 0;
                          final subtotal = (itemRow['subtotal'] as num? ?? 0);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text('$itemName x$quantity', style: const TextStyle(fontSize: 11, color: Color(0xFF374151)))),
                                Text('KES ${_formatCurrency(subtotal)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            // Legacy single item display
            if (isLegacy && item['itemName'] != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item['itemName']}', style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
                    Text('KES ${_formatCurrency(item['totalAmount'])}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
