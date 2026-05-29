import 'package:flutter/material.dart';
import '../../../widgets/empty_state_guide.dart';
import '../../theme/design_system.dart';
import '../../../db/db_provider.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/interactive_help_scroll.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _promotions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final promos = await DbProvider.query('retail_promotions', orderBy: 'is_active DESC, end_date DESC');
      if (mounted) {
        setState(() {
          _promotions = promos;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(int id, bool currentStatus) async {
    try {
      await DbProvider.update('retail_promotions', {'is_active': currentStatus ? 0 : 1}, where: 'id = ?', whereArgs: [id]);
      _loadData();
    } catch (e) {
      // Ignore in demo
    }
  }

  void _showAddPromoModal() {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    String discountType = 'percentage'; // bogo, percentage, fixed_discount
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16, right: 16, top: 16,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Create Promotion', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gray900)),
                  const SizedBox(height: 16),
                  CustomTextField(controller: nameCtrl, label: 'Promotion Name', icon: Icons.local_offer),
                  const SizedBox(height: 16),
                  
                  // Type Selector
                  Text('Discount Type', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gray700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypePill('percentage', 'Percentage %', discountType, (v) => setModalState(() => discountType = v)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypePill('fixed_discount', 'Fixed \$', discountType, (v) => setModalState(() => discountType = v)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypePill('bogo', 'BOGO', discountType, (v) => setModalState(() => discountType = v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (discountType != 'bogo') ...[
                    CustomTextField(controller: valueCtrl, label: discountType == 'percentage' ? 'Discount % (e.g., 20)' : 'Discount \$ (e.g., 5.00)', icon: Icons.money, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 16),
                  ],
                  
                  CustomTextField(controller: targetCtrl, label: 'Target Category (e.g., Drinks, null for All)', icon: Icons.category),
                  const SizedBox(height: 16),
                  
                  // Date Picker Row
                  Row(
                    children: [
                      const Icon(Icons.date_range, color: AppColors.gray500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              initialDateRange: DateTimeRange(start: startDate, end: endDate),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.primaryGreen,
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: Colors.black,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(() {
                                startDate = picked.start;
                                endDate = picked.end;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.gray50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: Text(
                              '${startDate.toString().split(' ')[0]} to ${endDate.toString().split(' ')[0]}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  PrimaryButton(
                    text: 'Save Promotion',
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty) return;
                      double discountValue = 0.0;
                      if (discountType != 'bogo') {
                        discountValue = double.tryParse(valueCtrl.text) ?? 0.0;
                        if (discountValue <= 0) return;
                      }

                      await DbProvider.insert('retail_promotions', {
                        'name': nameCtrl.text,
                        'type': discountType,
                        'discount_value': discountValue,
                        'target_category': targetCtrl.text.isEmpty ? null : targetCtrl.text,
                        'start_date': startDate.millisecondsSinceEpoch,
                        'end_date': endDate.millisecondsSinceEpoch,
                        'is_active': 1,
                      });
                      
                      if (mounted) Navigator.pop(context);
                      _loadData();
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        }
      ),
    ).then((_) {
      nameCtrl.dispose();
      valueCtrl.dispose();
      targetCtrl.dispose();
    });
  }

  void _showPromoDetails(Map<String, dynamic> promo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(promo['name'] ?? 'Promo Details', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.stars, color: AppColors.primaryGreen),
              title: const Text('Discount Type', style: TextStyle(color: Colors.grey)),
              subtitle: Text(promo['type'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.attach_money, color: AppColors.primaryGreen),
              title: const Text('Value', style: TextStyle(color: Colors.grey)),
              subtitle: Text(promo['discount_value'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.category, color: AppColors.primaryGreen),
              title: const Text('Target Category', style: TextStyle(color: Colors.grey)),
              subtitle: Text(promo['target_category'] ?? 'Storewide', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (promo['start_date'] != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.calendar_today, color: AppColors.primaryGreen),
                title: const Text('Start Date', style: TextStyle(color: Colors.grey)),
                subtitle: Text(DateTime.fromMillisecondsSinceEpoch(promo['start_date'] as int).toString().split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            if (promo['end_date'] != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_busy, color: AppColors.primaryGreen),
                title: const Text('End Date', style: TextStyle(color: Colors.grey)),
                subtitle: Text(DateTime.fromMillisecondsSinceEpoch(promo['end_date'] as int).toString().split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 24),
            PrimaryButton(text: 'Close', onPressed: () => Navigator.pop(context)),
          ],
        ),
      )
    );
  }

  Widget _buildTypePill(String typeId, String label, String currentType, Function(String) onSelect) {
    final isSelected = currentType == typeId;
    return InkWell(
      onTap: () => onSelect(typeId),
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : AppColors.gray100,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: isSelected ? AppColors.primaryGreen : AppColors.gray200),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.gray700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text('Promotions Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.gray900)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _promotions.isEmpty 
                ? EmptyStateGuide(
                    icon: Icons.local_offer_outlined,
                    title: 'No promotions running',
                    subtitle: 'Create a discount or BOGO deal to drive foot traffic and boost sales',
                    actionLabel: 'Create Promotion',
                    onAction: _showAddPromoModal,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _promotions.length,
                    separatorBuilder: (_,__) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final p = _promotions[index];
                      final isActive = p['is_active'] == 1;
                      
                      String typeDesc = '';
                      if (p['type'] == 'percentage') {
                        typeDesc = '${p['discount_value']}% OFF';
                      } else if (p['type'] == 'fixed_discount') {
                        typeDesc = '\$${p['discount_value']} OFF';
                      } else if (p['type'] == 'bogo') {
                        typeDesc = 'Buy 1 Get 1 Free';
                      }

                      String targetDesc = p['target_category'] != null ? 'Category: ${p['target_category']}' : 'Storewide';

                      return InkWell(
                        onTap: () => _showPromoDetails(p),
                        borderRadius: BorderRadius.circular(12.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: isActive ? AppColors.primaryGreen.withOpacity(0.3) : AppColors.gray200),
                            boxShadow: [
                              if (isActive) BoxShadow(color: AppColors.primaryGreen.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                            ]
                          ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.primaryLight : AppColors.gray100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.local_offer, color: isActive ? AppColors.primaryGreen : AppColors.gray400),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['name'] ?? 'Promo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isActive ? AppColors.gray900 : AppColors.gray500)),
                                    const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: AppColors.gray100, borderRadius: BorderRadius.circular(4)),
                                            child: Text(typeDesc, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(targetDesc, style: TextStyle(color: AppColors.gray500, fontSize: 12), overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isActive,
                                activeThumbColor: AppColors.primaryGreen,
                                onChanged: (_) => _toggleStatus(p['id'] as int, isActive),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  ),
          const InteractiveHelpScroll(contextKey: 'promos'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: _showAddPromoModal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Rule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
