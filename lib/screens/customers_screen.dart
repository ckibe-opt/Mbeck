import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/db_provider.dart';
import '../theme/design_system.dart';
import 'new_customer_screen.dart';
import '../models/customer.dart';
import 'package:intl/intl.dart';
import '../widgets/interactive_help_scroll.dart';

class CustomersScreen extends StatefulWidget {
  final String? initialQuery;
  final bool isPicker;
  
  const CustomersScreen({Key? key, this.initialQuery, this.isPicker = false}) : super(key: key);

  @override
  _CustomersScreenState createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _customers = [];
  Map<int, List<Map<String, dynamic>>> _ledgerById = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _activeFilter = 'all';
  double _totalDebt = 0;
  final ScrollController _scrollController = ScrollController();
  late TextEditingController _searchCtrl; 

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery ?? '';
    _searchCtrl = TextEditingController(text: _searchQuery);
    _refreshCustomers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshCustomers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final data = await DbProvider.queryRaw('''
      SELECT * FROM customer 
      ORDER BY 
        CASE WHEN name IS NOT NULL AND name != '' THEN name ELSE store END 
        COLLATE NOCASE ASC
    ''');

    // Load ledger entries
    Map<int, List<Map<String, dynamic>>> ledger = {};
    double totalDebt = 0;
    try {
      final ledgerData = await DbProvider.queryRaw(
        'SELECT * FROM customer_ledger WHERE status = ? ORDER BY created_at DESC',
        ['open'],
      );
      for (final entry in ledgerData) {
        final customerId = entry['customer_id'] as int?;
        if (customerId != null) {
          ledger.putIfAbsent(customerId, () => []);
          ledger[customerId]!.add(entry);
        }
        if (entry['type'] == 'owing') {
          totalDebt += (entry['amount'] as num?)?.toDouble() ?? 0;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Ledger query error: $e');
    }

    if (mounted) {
      setState(() {
        _customers = data.map((map) => Customer.fromMap(map)).toList();
        _ledgerById = ledger;
        _totalDebt = totalDebt;
        _isLoading = false;
      });
    }
  }

  void _onCustomerTapped(Customer customer) {
    if (widget.isPicker) {
      Navigator.pop(context, customer.phone);
    } else {
      _navigateToEdit(customer);
    }
  }

  Future<void> _navigateToEdit(Customer customer) async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => NewCustomerScreen(customer: customer))
    );
    _refreshCustomers();
  }

  void _copyValue(String label, String? value) {
    if (value == null || value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label: $value'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      )
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
      const Color(0xFF1E293B),
    ];
    return colors[name.length % colors.length];
  }

  String _getLedgerType(Customer c) {
    final entries = c.id != null ? (_ledgerById[c.id!] ?? []) : <Map<String, dynamic>>[];
    if (entries.isEmpty) return 'neutral';
    // Priority: pending > owing > prepaid
    if (entries.any((e) => e['type'] == 'pending')) return 'pending';
    if (entries.any((e) => e['type'] == 'owing')) return 'owing';
    if (entries.any((e) => e['type'] == 'prepaid')) return 'prepaid';
    return 'neutral';
  }

  double _getLedgerAmount(Customer c, String type) {
    final entries = c.id != null ? (_ledgerById[c.id!] ?? []) : <Map<String, dynamic>>[];
    return entries
        .where((e) => e['type'] == type)
        .fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));
  }

  List<Customer> _applyFilters(List<Customer> customers) {
    var filtered = customers.where((c) {
      final name = c.name.toLowerCase();
      final phone = (c.phone ?? '').toLowerCase();
      final store = (c.store ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || phone.contains(query) || store.contains(query);
    }).toList();
    
    if (_activeFilter != 'all') {
      filtered = filtered.where((c) => _getLedgerType(c) == _activeFilter).toList();
    }
    return filtered;
  }

  int _countByType(String type) {
    return _customers.where((c) => _getLedgerType(c) == type).length;
  }

  // ─── Add Ledger Entry ────────────────────
  Future<void> _addLedgerEntry(Customer customer) async {
    final typeCtrl = ValueNotifier<String>('owing');
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text('Add Entry for ${customer.name.isNotEmpty ? customer.name : customer.store ?? "Customer"}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 16),
              // Type selector
              ValueListenableBuilder<String>(
                valueListenable: typeCtrl,
                builder: (_, type, __) => Row(
                  children: [
                    _ledgerTypePill('owing', 'Owing', const Color(0xFFEF4444), type, (v) { typeCtrl.value = v; setSheetState(() {}); }),
                    const SizedBox(width: 8),
                    _ledgerTypePill('prepaid', 'Prepaid', const Color(0xFF10B981), type, (v) { typeCtrl.value = v; setSheetState(() {}); }),
                    const SizedBox(width: 8),
                    _ledgerTypePill('pending', 'Pending', const Color(0xFFF59E0B), type, (v) { typeCtrl.value = v; setSheetState(() {}); }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Amount
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (KES)',
                  labelStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              // Notes
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. "Bought 2 bags of cement, will pay Friday"',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  labelStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Save
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    final db = await DbProvider.db;
                    await db.insert('customer_ledger', {
                      'customer_id': customer.id,
                      'customer_phone': customer.phone,
                      'customer_name': customer.name.isNotEmpty ? customer.name : customer.store,
                      'type': typeCtrl.value,
                      'amount': amount,
                      'notes': notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
                      'status': 'open',
                      'created_at': DateTime.now().millisecondsSinceEpoch,
                    });
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: const Text('Save Entry', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true) _refreshCustomers();
  }

  void _showAddEntryCustomerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) {
        final theCustomers = _customers.where((c) => _getLedgerType(c) == _activeFilter).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Select Customer to Add Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
              const SizedBox(height: 16),
              if (theCustomers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No customers found in this category.', style: TextStyle(color: Colors.grey)),
                )
              else
                Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: theCustomers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (c, i) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getAvatarColor(theCustomers[i].name),
                        child: Text(
                          (theCustomers[i].name.isNotEmpty ? theCustomers[i].name : (theCustomers[i].store ?? 'C'))[0].toUpperCase(), 
                          style: const TextStyle(color: Colors.white)
                        ),
                      ),
                      title: Text(
                        theCustomers[i].name.isNotEmpty ? theCustomers[i].name : (theCustomers[i].store ?? ''),
                        style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                      trailing: const Icon(Icons.add_circle, color: Color(0xFF2563EB)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _addLedgerEntry(theCustomers[i]);
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    );
  }

  Widget _ledgerTypePill(String key, String label, Color color, String active, Function(String) onTap) {
    final isActive = active == key;
    return GestureDetector(
      onTap: () => onTap(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? color : const Color(0xFFE5E7EB)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isActive ? Colors.white : Colors.grey[600])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilters(_customers);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          Column(
            children: [
          _buildAppBar(filtered.length),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? AppSkeleton.screen()
                : filtered.isEmpty && !widget.isPicker
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: (widget.isPicker ? 1 : 0) + (!widget.isPicker ? 1 : 0) + filtered.length,
                    itemBuilder: (context, index) {
                      if (widget.isPicker && index == 0) return _buildWalkInOption();
                      if (!widget.isPicker && index == 0) return _buildQuickAddBanner();
                      final actualIndex = index - 1;
                      final item = filtered[actualIndex];
                      return _buildCustomerCard(item);
                    },
                  ),
          ),
            ],
          ),
          const InteractiveHelpScroll(contextKey: 'customers'),
        ],
      ),
      floatingActionButton: widget.isPicker ? null : FloatingActionButton(
        heroTag: "customers_fab",
        backgroundColor: const Color(0xFF2563EB),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () async {
          if (_activeFilter == 'all') {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewCustomerScreen()));
            _refreshCustomers();
          } else {
            _showAddEntryCustomerPicker();
          }
        },
        child: Icon(_activeFilter == 'all' ? Icons.person_add : Icons.post_add, color: Colors.white, size: 24),
      ),
    );
  }

  // ─── App Bar ─────────────────────────────
  Widget _buildAppBar(int count) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(widget.isPicker ? Icons.close : Icons.arrow_back, color: const Color(0xFF6B7280), size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    widget.isPicker ? 'Select Customer' : 'Directory',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  const Spacer(),
                  if (!widget.isPicker)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('TOTAL DEBT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1.2)),
                        const SizedBox(height: 1),
                        Text(
                          'KES ${NumberFormat('#,##0').format(_totalDebt)}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _totalDebt > 0 ? const Color(0xFFEF4444) : Colors.grey[400]),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (!widget.isPicker)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 0, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterTab('all', 'All (${_customers.length})', null),
                      const SizedBox(width: 8),
                      _buildFilterTab('owing', 'Owing (${_countByType("owing")})', const Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      _buildFilterTab('prepaid', 'Prepaid (${_countByType("prepaid")})', const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      _buildFilterTab('pending', 'Pending (${_countByType("pending")})', const Color(0xFFF59E0B)),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String key, String label, Color? dotColor) {
    final isActive = _activeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? null : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
              const SizedBox(width: 5),
            ],
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? Colors.white : const Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  // ─── Search ──────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            icon: Icon(Icons.search, color: Colors.grey[400], size: 20),
            hintText: 'Search name, phone, ID...',
            hintStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[400]),
            border: InputBorder.none,
            suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                  child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                )
              : null,
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
      ),
    );
  }

  // ─── Quick Add Banner ────────────────────
  Widget _buildQuickAddBanner() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewCustomerScreen()));
        _refreshCustomers();
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDBEAFE)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(color: Color(0xFFDBEAFE), shape: BoxShape.circle),
              child: const Icon(Icons.person_add, size: 20, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Add Walk-in', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E3A5F))),
                  Text('Capture details for credit, debt, or paused transactions', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF2563EB))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Walk-in Option (Picker Mode) ────────
  Widget _buildWalkInOption() {
    return GestureDetector(
      onTap: () => Navigator.pop(context, null),
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(color: Color(0xFFE5E7EB), shape: BoxShape.circle),
              child: Icon(Icons.person_off_outlined, size: 20, color: Colors.grey[500]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Walk-in Customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                  Text('No customer linked to this sale', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ─── Customer Card ───────────────────────
  Widget _buildCustomerCard(Customer item) {
    String displayName = item.name;
    String secondaryInfo = item.phone ?? '';
    if (displayName.isEmpty) {
      displayName = item.store ?? 'No Name';
      secondaryInfo = 'Store Account';
    }
    final ledgerType = _getLedgerType(item);
    final entries = item.id != null ? (_ledgerById[item.id!] ?? []) : <Map<String, dynamic>>[];

    // Picker mode — simple selection card
    if (widget.isPicker) {
      return GestureDetector(
        onTap: () => _onCustomerTapped(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF3F4F6)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Row(
            children: [
              _buildAvatar(displayName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    if (secondaryInfo.isNotEmpty)
                      Text(secondaryInfo, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(Icons.check_circle_outline, size: 20, color: AppColors.primaryGreen),
            ],
          ),
        ),
      );
    }

    // Color indicators based on ledger type
    Color? borderColor;
    Color? leftBarColor;
    if (ledgerType == 'owing') {
      borderColor = const Color(0xFFFEE2E2);
      leftBarColor = const Color(0xFFEF4444);
    } else if (ledgerType == 'pending') {
      borderColor = const Color(0xFFFDE68A);
      leftBarColor = const Color(0xFFF59E0B);
    } else if (ledgerType == 'prepaid') {
      borderColor = const Color(0xFFD1FAE5);
      leftBarColor = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Colored left bar
          if (leftBarColor != null)
            Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 3, color: leftBarColor)),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
              childrenPadding: EdgeInsets.zero,
              leading: _buildAvatar(displayName),
              title: Text(displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              subtitle: Text(
                secondaryInfo.isNotEmpty ? secondaryInfo : 'No phone',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[500]),
              ),
              trailing: _buildStatusBadge(item, ledgerType),
              children: [
                // Copy Utilities Row
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Column(
                    children: [
                      if (item.phone != null && item.phone!.isNotEmpty)
                        _buildCopyRow('Phone', item.phone!),
                      if (item.idNo != null && item.idNo!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildCopyRow('ID Number', item.idNo!),
                      ],
                      if (item.store != null && item.store!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildCopyRow('Store', item.store!),
                      ],
                    ],
                  ),
                ),
                // Ledger entries
                if (entries.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LEDGER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1)),
                        const SizedBox(height: 6),
                        ...entries.take(3).map((e) => _buildLedgerRow(e)),
                        if (entries.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              '+ ${entries.length - 3} older entries...', 
                              style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)
                            ),
                          ),
                      ],
                    ),
                  ),
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _addLedgerEntry(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Add Entry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _navigateToEdit(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_outlined, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[700])),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Customer item, String type) {
    if (type == 'neutral') return const SizedBox.shrink();
    
    Color bgColor, textColor;
    String label;
    double amount = 0;
    
    switch (type) {
      case 'owing':
        bgColor = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFEF4444);
        label = 'OWES';
        amount = _getLedgerAmount(item, 'owing');
        break;
      case 'prepaid':
        bgColor = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF10B981);
        label = 'PREPAID';
        amount = _getLedgerAmount(item, 'prepaid');
        break;
      case 'pending':
        bgColor = const Color(0xFFFFFBEB);
        textColor = const Color(0xFFF59E0B);
        label = 'PENDING';
        amount = _getLedgerAmount(item, 'pending');
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 1)),
          if (amount > 0)
            Text('KES ${NumberFormat('#,##0').format(amount)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildLedgerRow(Map<String, dynamic> entry) {
    final type = entry['type'] as String? ?? 'owing';
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
    final notes = entry['notes'] as String?;
    final createdAt = entry['created_at'] as int?;
    
    Color typeColor;
    switch (type) {
      case 'owing': typeColor = const Color(0xFFEF4444); break;
      case 'prepaid': typeColor = const Color(0xFF10B981); break;
      case 'pending': typeColor = const Color(0xFFF59E0B); break;
      default: typeColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: typeColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(type.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: typeColor, letterSpacing: 0.5)),
                    Text('KES ${NumberFormat('#,##0').format(amount)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: typeColor)),
                  ],
                ),
                if (notes != null && notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(notes, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                if (createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      DateFormat('MMM d, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(createdAt)),
                      style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                    ),
                  ),
              ],
            ),
          ),
          // Resolve button
          GestureDetector(
            onTap: () async {
              final db = await DbProvider.db;
              await db.update('customer_ledger', {'status': 'resolved', 'resolved_at': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [entry['id']]);
              _refreshCustomers();
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Icon(Icons.check, size: 14, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Copy Row ────────────────────────────
  Widget _buildCopyRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1)),
                const SizedBox(height: 1),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: Color(0xFF111827))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _copyValue(label, value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFF3F4F6)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 2)],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, size: 12, color: Color(0xFF2563EB)),
                  SizedBox(width: 3),
                  Text('Copy', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF2563EB), letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: _getAvatarColor(name), shape: BoxShape.circle),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty ? 'No matches found' : 'No customers yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Text('Tap + to add your first customer', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }
}
