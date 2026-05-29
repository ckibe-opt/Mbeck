import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/db_provider.dart';
import '../services/event_service.dart';
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';
import '../services/security_service.dart';
import '../widgets/interactive_help_scroll.dart';
import '../services/auth_service.dart';
import '../models/permissions.dart';

class CashCountScreen extends StatefulWidget {
  @override
  _CashCountScreenState createState() => _CashCountScreenState();
}

class _CashCountScreenState extends State<CashCountScreen> {
  final Map<String, TextEditingController> _controllers = {};
  // Notes: 1000, 500, 200, 100, 50. Coins: 40, 20, 10, 5, 1.
  final notes = [1000, 500, 200, 100, 50];
  final coins = [40, 20, 10, 5, 1];
  final denominations = [1000, 500, 200, 100, 50, 40, 20, 10, 5, 1];
  final Map<int, int> _quantities = {};
  int total = 0;
  bool _isSaving = false;
  
  // Access control state
  bool _isCheckingAccess = true;
  bool _hasAccess = false;

  // Colors per denomination
  static const Map<int, Color> _denomColors = {
    1000: Color(0xFF10B981), // emerald
    500: Color(0xFF3B82F6),  // blue
    200: Color(0xFFF59E0B),  // amber
    100: Color(0xFF8B5CF6),  // purple
    50: Color(0xFFF97316),   // orange
    40: Color(0xFF71717A),   // zinc
    20: Color(0xFF71717A),
    10: Color(0xFF71717A),
    5: Color(0xFF71717A),
    1: Color(0xFF71717A),
  };

  @override
  void initState() {
    super.initState();
    _checkAccess();
    for (final d in denominations) {
      _controllers[d.toString()] = TextEditingController(text: '');
      _controllers[d.toString()]!.addListener(() => _recompute(d));
      _quantities[d] = 0;
    }
  }

  Future<void> _checkAccess() async {
    try {
      final member = await AuthService.getCurrentMember();
      final hasAccess = member?.hasPermission(Permissions.performCashCount) ?? false;
      if (mounted) {
        setState(() {
          _hasAccess = hasAccess;
          _isCheckingAccess = false;
        });
        if (!hasAccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Access Denied: You do not have permission to perform Cash Count."),
              backgroundColor: AppColors.danger,
            ),
          );
          Navigator.pop(context);
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
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _recompute(int changedDenom) {
    final qty = int.tryParse(_controllers[changedDenom.toString()]!.text) ?? 0;
    _quantities[changedDenom] = qty;
    
    int t = 0;
    for (final entry in _quantities.entries) {
      t += entry.key * entry.value;
    }
    
    if (mounted) {
      setState(() => total = t);
    }
  }

  void _clear() {
    for (final d in denominations) {
      _controllers[d.toString()]!.clear();
      _quantities[d] = 0;
    }
    setState(() => total = 0);
  }

  void _adjust(int denom, int amount) {
    final denomStr = denom.toString();
    int current = _quantities[denom] ?? 0;
    int newVal = current + amount;
    if (newVal < 0) newVal = 0;
    _controllers[denomStr]!.text = newVal.toString();
  }

  void _applyPreset(String preset) {
    _clear();
    
    switch (preset) {
      case 'small':
        _controllers['1000']!.text = '2';
        _controllers['500']!.text = '4';
        _controllers['200']!.text = '5';
        break;
      case 'medium':
        _controllers['1000']!.text = '8';
        _controllers['500']!.text = '4';
        break;
      case 'large':
        _controllers['1000']!.text = '15';
        _controllers['500']!.text = '10';
        break;
    }
  }

  int _pct(int subtotal) {
    if (total == 0) return 0;
    return ((subtotal / total) * 100).round();
  }

  String _fmtTotal(int val) {
    if (val == 0) return '0';
    final str = val.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  final _securityService = SecurityService();

  Future<void> _saveToAccounting() async {
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total is zero, nothing to save.'))
      );
      return;
    }
    
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;

      final details = 'Cash Count Entry';
      final signature = await _securityService.signTransaction(
        timestamp: timestamp,
        totalAmount: total,
        type: 'incoming',
        details: details,
      );

      final denominationBreakdown = <String, int>{};
      for (final entry in _quantities.entries) {
        if (entry.value > 0) {
          denominationBreakdown['KSH_${entry.key}'] = entry.value;
        }
      }

      try {
        await EventService.emitEvent(
          eventType: 'CASH_COUNT_ENTRY',
          payload: {
            'type': 'cash_count',
            'amount': total.toDouble(),
            'totalAmount': total.toDouble(),
            'details': details,
            'receiptSignature': signature,
            'denominations': denominationBreakdown,
          },
          timestamp: timestamp,
        );
      } catch (e) {
        debugPrint('⚠️ Event emission failed (non-critical): $e');
      }

      await DbProvider.insert('txn', {
        'type': 'cash_count',
        'totalAmount': total,
        'details': details,
        'timestamp': timestamp,
        'receiptSignature': signature,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cash count recorded successfully as income'),
            backgroundColor: AppColors.primaryGreen,
          )
        );
      }
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

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return Scaffold(
        appBar: StandardAppBar(title: 'Cash Counter'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasAccess) {
      return Scaffold(
        appBar: StandardAppBar(title: 'Cash Counter'),
        body: const Center(child: Text("Access Denied")),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: StandardAppBar(
        title: 'Cash Counter',
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _clear,
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ─── Emerald Total Header with Preset Pills ───
              _buildTotalHeader(),
              
              // ─── Scrollable 2-Column Grid ───
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Notes section
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'NOTES',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 1.5),
                        ),
                      ),
                      _buildGrid(notes),
                      
                      const SizedBox(height: 16),
                      
                      // Coins section
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'COINS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 1.5),
                        ),
                      ),
                      _buildGrid(coins),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const InteractiveHelpScroll(contextKey: 'cash'),
        ],
      ),
      // ─── Fixed Bottom Submit ───
      bottomNavigationBar: _buildBottomAction(),
    );
  }

  // ═══════════════════════════════════════
  // Emerald Total Header
  // ═══════════════════════════════════════
  Widget _buildTotalHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF059669),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF059669).withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL CASH',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFA7F3D0), letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'KSH ${_fmtTotal(total)}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    ),
                  ],
                ),
                if (total > 0)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFFA7F3D0), size: 20),
                    tooltip: 'Copy Total',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: total.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Total copied'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
              ],
            ),
            
            // Preset pills
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF34D399), width: 0.5)),
              ),
              child: Row(
                children: [
                  const Text(
                    'PRESETS:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFA7F3D0), letterSpacing: 1),
                  ),
                  const SizedBox(width: 8),
                  _presetPill('Small', 'small'),
                  const SizedBox(width: 6),
                  _presetPill('Medium', 'medium'),
                  const SizedBox(width: 6),
                  _presetPill('Large', 'large'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetPill(String label, String preset) {
    return GestureDetector(
      onTap: () => _applyPreset(preset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // 2-Column Grid
  // ═══════════════════════════════════════
  Widget _buildGrid(List<int> denoms) {
    final List<Widget> children = [];
    for (int i = 0; i < denoms.length; i += 2) {
      children.add(Row(
        children: [
          Expanded(child: _buildDenomCard(denoms[i])),
          const SizedBox(width: 8),
          if (i + 1 < denoms.length)
            Expanded(child: _buildDenomCard(denoms[i + 1]))
          else
            const Expanded(child: SizedBox()),
        ],
      ));
      if (i + 2 < denoms.length) children.add(const SizedBox(height: 8));
    }
    // Handle KSH 1 (last coin) as full-width if coins list has odd count
    // Actually handled by the grid logic above already
    return Column(children: children);
  }

  Widget _buildDenomCard(int denom) {
    final qty = _quantities[denom] ?? 0;
    final subtotal = qty * denom;
    final color = _denomColors[denom] ?? const Color(0xFF71717A);
    final isNote = notes.contains(denom);
    final pctWidth = _pct(subtotal);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Header: denomination badge + subtotal
              Row(
                children: [
                  // Denomination badge
                  if (isNote)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        '$denom',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color),
                      ),
                    )
                  else
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E4E7),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD4D4D8)),
                      ),
                      child: Center(
                        child: Text(
                          '$denom',
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF52525B)),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    '= ${_fmtTotal(subtotal)}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // Controls: - [input] +
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _roundButton(
                    icon: Icons.remove,
                    color: const Color(0xFFFEE2E2),
                    iconColor: const Color(0xFFDC2626),
                    onTap: () => _adjust(denom, -1),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: TextField(
                        controller: _controllers[denom.toString()],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF111827)),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w900),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ),
                  ),
                  _roundButton(
                    icon: Icons.add,
                    color: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF059669),
                    onTap: () => _adjust(denom, 1),
                  ),
                ],
              ),
            ],
          ),
          
          // Progress bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3,
              width: pctWidth > 0 ? (pctWidth / 100) * 100 : 0, // relative width
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: iconColor),
      ),
    );
  }

  // ═══════════════════════════════════════
  // Bottom Action
  // ═══════════════════════════════════════
  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE5E7EB))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: total > 0 && !_isSaving ? _saveToAccounting : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: total > 0 ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(16),
              boxShadow: total > 0
                  ? [BoxShadow(color: const Color(0xFF111827).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSaving)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                else ...[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: total > 0 ? const Color(0xFF34D399) : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Submit Count',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: total > 0 ? Colors.white : const Color(0xFF9CA3AF),
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
