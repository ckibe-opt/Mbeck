import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../db/db_provider.dart';
import '../services/event_service.dart';
import '../theme/design_system.dart';
import 'accounting_history_screen.dart';
import '../models/event.dart';
import '../widgets/standard_app_bar.dart';
import '../widgets/interactive_help_scroll.dart';
import '../services/auth_service.dart';
import '../models/permissions.dart';
import '../models/shop.dart';

class AccountingScreen extends StatefulWidget {
  @override
  _AccountingScreenState createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  final _cashCtrl = TextEditingController();
  final _mpesa1Ctrl = TextEditingController();
  final _mpesa2Ctrl = TextEditingController();
  final _coopCtrl = TextEditingController();
  final _equityCtrl = TextEditingController();
  final _kcbCtrl = TextEditingController();
  final _airtelCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Shop? _shop;
  Map<String, dynamic>? _lastEntry;
  int _inventorySalesSinceLast = 0;
  int _otherIncomeSinceLast = 0;
  int _cashCountSinceLast = 0;
  int _newExpensesSinceLast = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showMorePayments = false;
  
  // Access control state
  bool _isCheckingAccess = true;
  bool _hasAccess = false;
  
  // Live calculation state
  int _currentTotal = 0;
  int _expectedTotal = 0;
  int _disparity = 0;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    final controllers = [
      _cashCtrl, _mpesa1Ctrl, _mpesa2Ctrl, _coopCtrl,
      _equityCtrl, _kcbCtrl, _airtelCtrl, _otherCtrl
    ];
    for (var ctrl in controllers) {
      ctrl.addListener(_calculateTotals);
    }
  }

  Future<void> _checkAccess() async {
    try {
      final member = await AuthService.getCurrentMember();
      final hasAccess = member?.hasPermission(Permissions.manageAccounting) ?? false;
      if (mounted) {
        setState(() {
          _hasAccess = hasAccess;
          _isCheckingAccess = false;
        });
        if (!hasAccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Access Denied: You do not have permission to view Accounting."),
              backgroundColor: AppColors.danger,
            ),
          );
          Navigator.pop(context);
        } else {
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

  @override
  void dispose() {
    [_cashCtrl, _mpesa1Ctrl, _mpesa2Ctrl, _coopCtrl, _equityCtrl, 
     _kcbCtrl, _airtelCtrl, _otherCtrl, _notesCtrl].forEach((c) => c.dispose());
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final shop = await AuthService.getCurrentShop();
      // POLICY 4.1: Business Day Boundary (05:00 -> 04:59)
      final entries = await DbProvider.query(
        'accounting', 
        orderBy: 'timestamp DESC', 
        limit: 1
      );
      final last = entries.isNotEmpty ? entries.first : null;

      int lastTime = last != null ? (last['timestamp'] as int) : 0;
      
      final sales = await DbProvider.queryRaw('''
        SELECT COALESCE(SUM(totalAmount), 0) as total 
        FROM txn 
        WHERE type = 'sale' AND timestamp > ?
      ''', [lastTime]);
      
      final expenses = await DbProvider.queryRaw('''
        SELECT COALESCE(SUM(totalAmount), 0) as total 
        FROM txn 
        WHERE type = 'outgoing' AND timestamp > ?
      ''', [lastTime]);

      final otherIncome = await DbProvider.queryRaw('''
        SELECT COALESCE(SUM(totalAmount), 0) as total 
        FROM txn 
        WHERE type = 'incoming' AND timestamp > ?
      ''', [lastTime]);

      final cashCount = await DbProvider.queryRaw('''
        SELECT COALESCE(SUM(totalAmount), 0) as total 
        FROM txn 
        WHERE type = 'cash_count' AND timestamp > ?
      ''', [lastTime]);

      int newSales = (sales.first['total'] as num? ?? 0).toInt();
      int newExpenses = (expenses.first['total'] as num? ?? 0).toInt();
      int newOtherIncome = (otherIncome.first['total'] as num? ?? 0).toInt();
      int newCashCount = (cashCount.first['total'] as num? ?? 0).toInt();

      int lastSum = 0;
      if (last != null) {
        lastSum = (last['cashTotal'] as int? ?? 0) + 
                  (last['mpesa1'] as int? ?? 0) + 
                  (last['mpesa2'] as int? ?? 0) + 
                  (last['coop'] as int? ?? 0) + 
                  (last['equity'] as int? ?? 0) + 
                  (last['kcb'] as int? ?? 0) + 
                  (last['airtel'] as int? ?? 0) + 
                  (last['otherMpesa'] as int? ?? 0);
      }

      if (mounted) {
        setState(() {
          _shop = shop;
          _lastEntry = last;
          _inventorySalesSinceLast = newSales;
          _otherIncomeSinceLast = newOtherIncome;
          _cashCountSinceLast = newCashCount;
          _newExpensesSinceLast = newExpenses;
          _expectedTotal = lastSum + newSales + newOtherIncome + newCashCount - newExpenses;
          _isLoading = false;
        });
        _calculateTotals();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'))
        );
      }
    }
  }

  String get _currency => _shop?.currency ?? 'KES';

  String _getAccountLabel(String dbKey) {
    final isKES = _currency == 'KES';
    switch (dbKey) {
      case 'cashTotal':
        return 'Cash Total';
      case 'mpesa1':
        return isKES ? 'M-Pesa Line 1' : 'Mobile Wallet 1';
      case 'mpesa2':
        return isKES ? 'M-Pesa Line 2' : 'Mobile Wallet 2';
      case 'coop':
        return isKES ? 'CO-OP Bank' : 'Bank Account 1';
      case 'equity':
        return isKES ? 'Equity Bank' : 'Bank Account 2';
      case 'kcb':
        return isKES ? 'KCB Bank' : 'Bank Account 3';
      case 'airtel':
        return isKES ? 'Airtel Money' : 'Card / POS';
      case 'otherMpesa':
        return isKES ? 'Other' : 'Other Payment';
      default:
        return dbKey;
    }
  }

  IconData _getAccountIcon(String dbKey) {
    final isKES = _currency == 'KES';
    switch (dbKey) {
      case 'cashTotal':
        return Icons.payments_rounded;
      case 'mpesa1':
      case 'mpesa2':
        return isKES ? Icons.phone_android_rounded : Icons.account_balance_wallet_rounded;
      case 'coop':
      case 'equity':
      case 'kcb':
        return Icons.account_balance_rounded;
      case 'airtel':
        return isKES ? Icons.phone_android_rounded : Icons.credit_card_rounded;
      case 'otherMpesa':
        return isKES ? Icons.add_rounded : Icons.add_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
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

  void _calculateTotals() {
    final current = getVal(_cashCtrl) + getVal(_mpesa1Ctrl) + 
                    getVal(_mpesa2Ctrl) + getVal(_coopCtrl) + 
                    getVal(_equityCtrl) + getVal(_kcbCtrl) + 
                    getVal(_airtelCtrl) + getVal(_otherCtrl);
    
    if (mounted) {
      setState(() {
        _currentTotal = current;
        _disparity = _currentTotal - _expectedTotal;
      });
    }
  }

  // Enhanced parser - handles expressions like "5000 + 200 - 50"
  int getVal(TextEditingController c) {
    if (c.text.isEmpty) return 0;
    
    try {
      String text = c.text.replaceAll(',', '').replaceAll(' ', '');
      
      int result = 0;
      String currentNum = '';
      String operation = '+';
      
      for (int i = 0; i < text.length; i++) {
        final char = text[i];
        
        if (char == '+' || char == '-') {
          if (currentNum.isNotEmpty) {
            final num = int.tryParse(currentNum) ?? 0;
            result = operation == '+' ? result + num : result - num;
            currentNum = '';
          }
          operation = char;
        } else if (RegExp(r'[0-9]').hasMatch(char)) {
          currentNum += char;
        }
      }
      
      if (currentNum.isNotEmpty) {
        final num = int.tryParse(currentNum) ?? 0;
        result = operation == '+' ? result + num : result - num;
      }
      
      return result;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _saveEntry() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      Event? closingEvent;
      try {
        closingEvent = await EventService.emitEvent(
          eventType: 'ACCOUNTING_CLOSING',
          payload: {
            'cashTotal': getVal(_cashCtrl),
            'mpesa1': getVal(_mpesa1Ctrl),
            'mpesa2': getVal(_mpesa2Ctrl),
            'coop': getVal(_coopCtrl),
            'equity': getVal(_equityCtrl),
            'kcb': getVal(_kcbCtrl),
            'airtel': getVal(_airtelCtrl),
            'otherMpesa': getVal(_otherCtrl),
            'expectedTotal': _expectedTotal,
            'actualTotal': _currentTotal,
            'disparity': _disparity,
            'specialScenarios': _notesCtrl.text.trim(),
          },
          timestamp: timestamp,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to record accounting closing: $e'))
          );
        }
        return;
      }

      if (_disparity != 0) {
        String disparityType = 'neutral';
        int amount = _disparity.abs();
        
        if (_disparity < 0) {
           if (amount > 1000) {
             disparityType = 'hard_penalty';
           } else if (amount > 300) {
             disparityType = 'soft_penalty';
           } else {
             disparityType = 'ignored';
           }
        } else {
           disparityType = 'surplus_neutral';
        }

        try {
          await EventService.emitEvent(
            eventType: 'DISPARITY',
            payload: {
              'amount': amount,
              'type': _disparity > 0 ? 'surplus' : 'shortage',
              'policy_impact': disparityType,
              'expectedTotal': _expectedTotal,
              'actualTotal': _currentTotal,
              'accountingEventId': closingEvent.id,
            },
            timestamp: timestamp,
          );
        } catch (e) {
          debugPrint('⚠️ Failed to emit disparity event: $e');
        }
      }

      await DbProvider.insert('accounting', {
        'timestamp': timestamp,
        'cashTotal': getVal(_cashCtrl),
        'mpesa1': getVal(_mpesa1Ctrl),
        'mpesa2': getVal(_mpesa2Ctrl),
        'coop': getVal(_coopCtrl),
        'equity': getVal(_equityCtrl),
        'kcb': getVal(_kcbCtrl),
        'airtel': getVal(_airtelCtrl),
        'otherMpesa': getVal(_otherCtrl),
        'salesDisparity': _disparity,
        'specialScenarios': _notesCtrl.text.trim(),
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text("Calculation Done", style: AppTypography.textTheme.headlineMedium),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Previous Total: $_currency ${_lastEntry != null ? _expectedTotal + _newExpensesSinceLast - _inventorySalesSinceLast - _otherIncomeSinceLast - _cashCountSinceLast : 0}'),
              Text('New Sales Added: + $_currency $_inventorySalesSinceLast'),
              Text('Other Income: + $_currency $_otherIncomeSinceLast'),
              Text('Saved Cash: + $_currency $_cashCountSinceLast'),
              Text('New Expenses: - $_currency $_newExpensesSinceLast'),
              const Divider(),
              Text('Expected Total: $_currency $_expectedTotal',
                style: AppTypography.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text('Your Count: $_currency $_currentTotal',
                style: AppTypography.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.info)),
              const SizedBox(height: 10),
              Text(
                'Disparity: $_currency ${_disparity > 0 ? "+$_disparity" : _disparity}',
                style: AppTypography.textTheme.headlineMedium?.copyWith(
                  color: _disparity == 0 ? AppColors.primaryGreen : AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_disparity != 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _disparity > 0 
                          ? '💡 Surplus detected. Neutral impact.'
                          : _disparity.abs() <= 300
                            ? '✅ Within tolerance (≤ $_currency 300).'
                            : _disparity.abs() <= 1000
                              ? '⚠️ Soft penalty: Disparity between $_currency 301-1,000.'
                              : '🔴 Hard penalty: Disparity > $_currency 1,000. Affects Trust Score.',
                        style: AppTypography.textTheme.labelMedium?.copyWith(
                          fontWeight: _disparity.abs() > 1000 ? FontWeight.bold : FontWeight.normal
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _clearAndRefresh();
              }, 
              child: const Text('OK')
            )
          ],
        )
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _clearAndRefresh() {
    _cashCtrl.clear();
    _mpesa1Ctrl.clear();
    _mpesa2Ctrl.clear();
    _coopCtrl.clear();
    _equityCtrl.clear();
    _kcbCtrl.clear();
    _airtelCtrl.clear();
    _otherCtrl.clear();
    _notesCtrl.clear();
    _loadData();
  }

  String _formatNum(int val) {
    if (val == 0) return '0';
    final neg = val < 0;
    final abs = val.abs();
    final str = abs.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return neg ? '-${buf.toString()}' : buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return Scaffold(
        appBar: StandardAppBar(title: 'Accounting'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasAccess) {
      return Scaffold(
        appBar: StandardAppBar(title: 'Accounting'),
        body: const Center(child: Text("Access Denied")),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: StandardAppBar(
        title: 'Accounting',
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'View History',
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => AccountingHistoryScreen())
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          _isLoading
            ? AppSkeleton.screen()
            : Column(
                children: [
                  // ─── Pinned Live Variance Header ───
                  _buildVarianceHeader(),
                  
                  // ─── Scrollable Content ───
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Collapsible Breakdown
                          _buildCollapsibleBreakdown(),
                          const SizedBox(height: 12),
                          
                          // Payment Inputs Card
                          _buildPaymentInputsCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          const InteractiveHelpScroll(contextKey: 'accounting'),
        ],
      ),
      // ─── Fixed Bottom CTA ───
      bottomNavigationBar: _isLoading ? null : _buildBottomCTA(),
    );
  }

  // ═══════════════════════════════════════
  // Pinned Live Variance Header
  // ═══════════════════════════════════════
  Widget _buildVarianceHeader() {
    final bool isEmpty = _currentTotal == 0;
    final bool balanced = !isEmpty && _disparity == 0;
    
    Color bgColor, borderColor, labelColor, valueColor;
    if (isEmpty) {
      bgColor = const Color(0xFFF9FAFB);
      borderColor = const Color(0xFFE5E7EB);
      labelColor = const Color(0xFF9CA3AF);
      valueColor = const Color(0xFFD1D5DB);
    } else if (balanced) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFF6EE7B7);
      labelColor = const Color(0xFF059669);
      valueColor = const Color(0xFF047857);
    } else {
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFCA5A5);
      labelColor = const Color(0xFFDC2626);
      valueColor = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE VARIANCE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: labelColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEmpty
                      ? '$_currency ---'
                      : '${_disparity >= 0 ? '+' : ''}$_currency ${_formatNum(_disparity)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: valueColor,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('EXPECTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF9CA3AF), letterSpacing: 1)),
                Text('$_currency ${_formatNum(_expectedTotal)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF4B5563))),
                const SizedBox(height: 4),
                Text('YOUR COUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF9CA3AF), letterSpacing: 1)),
                Text(
                  '$_currency ${_formatNum(_currentTotal)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isEmpty ? const Color(0xFFD1D5DB) : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // Collapsible Breakdown Details
  // ═══════════════════════════════════════
  Widget _buildCollapsibleBreakdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            'BREAKDOWN DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E40AF),
              letterSpacing: 1,
            ),
          ),
          iconColor: const Color(0xFF93C5FD),
          collapsedIconColor: const Color(0xFF93C5FD),
          children: [
            _breakdownRow('Last Recorded Total', 
              _lastEntry != null ? _expectedTotal + _newExpensesSinceLast - _inventorySalesSinceLast - _otherIncomeSinceLast - _cashCountSinceLast : 0, 
              const Color(0xFF4B5563)),
            _breakdownRow('Sales Since Last Entry', _inventorySalesSinceLast, const Color(0xFF059669), prefix: '+'),
            _breakdownRow('Other Income Since Last', _otherIncomeSinceLast, const Color(0xFF059669), prefix: '+'),
            _breakdownRow('Saved Cash (Counter)', _cashCountSinceLast, const Color(0xFF059669), prefix: '+'),
            _breakdownRow('Expenses Since Last Entry', _newExpensesSinceLast, const Color(0xFFEF4444), prefix: '-'),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, int value, Color valueColor, {String prefix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
          Text(
            '$prefix $_currency ${_formatNum(value)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // Payment Inputs Card (Smart Hiding)
  // ═══════════════════════════════════════
  Widget _buildPaymentInputsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Always visible: Cash, Mpesa 1, Mpesa 2
          _buildPremiumInput(_getAccountLabel('cashTotal'), _cashCtrl, _getAccountIcon('cashTotal'), _getAccountColor('cashTotal'),
            hint: 'e.g. 5000 + 1050', helperText: 'Tip: Type 500+250 to add receipts'),
          const SizedBox(height: 12),
          _buildPremiumInput(_getAccountLabel('mpesa1'), _mpesa1Ctrl, _getAccountIcon('mpesa1'), _getAccountColor('mpesa1')),
          const SizedBox(height: 12),
          _buildPremiumInput(_getAccountLabel('mpesa2'), _mpesa2Ctrl, _getAccountIcon('mpesa2'), _getAccountColor('mpesa2')),

          // Show More / Less toggle
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _showMorePayments = !_showMorePayments),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showMorePayments ? 'Hide other methods' : '+ 5 more payment methods',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6366F1),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _showMorePayments ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF6366F1)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Hidden payment methods
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _showMorePayments
                ? Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildPremiumInput(_getAccountLabel('coop'), _coopCtrl, _getAccountIcon('coop'), _getAccountColor('coop')),
                      const SizedBox(height: 12),
                      _buildPremiumInput(_getAccountLabel('equity'), _equityCtrl, _getAccountIcon('equity'), _getAccountColor('equity')),
                      const SizedBox(height: 12),
                      _buildPremiumInput(_getAccountLabel('kcb'), _kcbCtrl, _getAccountIcon('kcb'), _getAccountColor('kcb')),
                      const SizedBox(height: 12),
                      _buildPremiumInput(_getAccountLabel('airtel'), _airtelCtrl, _getAccountIcon('airtel'), _getAccountColor('airtel')),
                      const SizedBox(height: 12),
                      _buildPremiumInput(_getAccountLabel('otherMpesa'), _otherCtrl, _getAccountIcon('otherMpesa'), _getAccountColor('otherMpesa')),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Notes
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'NOTES / SPECIAL SCENARIOS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 1.5),
                ),
              ),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                decoration: InputDecoration(
                  hintText: 'Optional notes...',
                  hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w500),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumInput(String label, TextEditingController ctrl, IconData icon, Color iconColor,
      {String hint = '0', String? helperText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 1.5),
          ),
        ),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w500),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: iconColor, width: 2),
            ),
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(helperText, style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF9CA3AF))),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // Fixed Bottom CTA
  // ═══════════════════════════════════════
  Widget _buildBottomCTA() {
    final bool canSubmit = _currentTotal > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE5E7EB))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSubmit && !_isSaving ? _saveEntry : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: canSubmit ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(16),
              boxShadow: canSubmit
                  ? [BoxShadow(color: const Color(0xFF059669).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSaving)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                else ...[
                  Icon(Icons.check_circle_rounded, size: 20, color: canSubmit ? Colors.white : const Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Text(
                    'Calculate & Save',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: canSubmit ? Colors.white : const Color(0xFF9CA3AF),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
