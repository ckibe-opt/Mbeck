import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../db/db_provider.dart';
import '../models/inventory_items.dart';
import '../models/cart_item.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../services/event_service.dart';
import '../services/inventory_service.dart';
import '../services/onboarding_service.dart';
import 'inventory_screen.dart';
import 'customers_screen.dart';
import '../models/event.dart'; // Fixed import path
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';
import 'cart_qr_scanner_screen.dart';
import 'barcode_scanner_screen.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../services/auth_service.dart';
import '../models/permissions.dart';
import '../services/security_service.dart';
import '../services/checkout_sync_service.dart';

class NewTransactionScreen extends StatefulWidget {
  final bool autoStartScanner;
  final String? lockTxnType;
  const NewTransactionScreen(
      {super.key, this.autoStartScanner = false, this.lockTxnType});

  @override
  NewTransactionScreenState createState() => NewTransactionScreenState();
}

class NewTransactionScreenState extends State<NewTransactionScreen> {
  final _detailsController = TextEditingController();
  final _amountController = TextEditingController();
  final _paymentRefController = TextEditingController();
  String _txnType = 'sale';
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isDisposed = false;

  List<InventoryItem> _inventoryItems = [];
  final List<CartItem> _cart = [];

  final SecurityService _securityService = SecurityService();
  // ignore: unused_field
  List<String> _enabledModules = ['retail'];

  // Customer selection
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  
  // Active Promotions
  List<Map<String, dynamic>> _activePromotions = [];

  @override
  void initState() {
    super.initState();
    if (widget.lockTxnType != null) {
      _txnType = widget.lockTxnType!;
    }
    _loadInventory();
    _loadModules();
    CheckoutSyncService().reset();
  }

  Future<void> _loadModules() async {
    final modules = await OnboardingService.getSelectedModules();
    if (mounted) {
      setState(() => _enabledModules = modules);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _detailsController.dispose();
    _amountController.dispose();
    _paymentRefController.dispose();
    CheckoutSyncService().reset();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    try {
      final itemsData = await InventoryService.getItems();
      final items = itemsData.map((item) => InventoryItem.fromMap(item)).toList();
      
      // Load active promotions
      final now = DateTime.now().millisecondsSinceEpoch;
      final promos = await DbProvider.queryRaw('''
        SELECT * FROM retail_promotions 
        WHERE is_active = 1 
        AND start_date <= ?
        AND end_date >= ?
      ''', [now, now]);

      if (!_isDisposed && mounted) {
        setState(() {
          _inventoryItems = items;
          _activePromotions = promos;
        });
      }
    } catch (e) {
      debugPrint('Error loading inventory: $e');
    }
  }

  // Fetch top items (Recently sold, or just first 10 if new shop)
  Future<List<InventoryItem>> _getRecentlySoldItems() async {
    try {
      // 1. Try recently sold
      final result = await DbProvider.queryRaw('''
        SELECT i.*, COUNT(ti.itemId) as sales_count
        FROM inventory i
        INNER JOIN transaction_items ti ON i.id = ti.itemId
        INNER JOIN txn t ON ti.transactionId = t.id
        WHERE t.type = 'sale' AND t.timestamp > ?
        GROUP BY i.id
        ORDER BY sales_count DESC, t.timestamp DESC
        LIMIT 10
      ''', [DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch]);
      
      if (result.isNotEmpty) {
        return result.map((item) => InventoryItem.fromMap(item)).toList();
      }

      // 2. Fallback: Show any items (Limit 20)
      final fallback = await DbProvider.queryRaw('''
        SELECT * FROM inventory 
        WHERE stock > 0
        ORDER BY name ASC
        LIMIT 20
      ''');
       return fallback.map((item) => InventoryItem.fromMap(item)).toList();

    } catch (e) {
      debugPrint('Error fetching quick items: $e');
      return [];
    }
  }

  // Enhanced product card for recently sold items (larger images per research)
  Widget _buildRecentlyItemCard(InventoryItem item) {
    return GestureDetector(
      onTap: () => _addToCart(item),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.gray200),
          boxShadow: [AppShadows.sm],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Larger image (research: photo-first for inventory apps)
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
              child: item.imagePath != null && item.imagePath!.isNotEmpty
                  ? FutureBuilder<File>(
                      future: _resolveImageFile(item.imagePath!),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Image.file(
                            snapshot.data!,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _buildPlaceholderImage(),
                          );
                        }
                        return _buildPlaceholderImage();
                      },
                    )
                  : _buildPlaceholderImage(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.name,
                      style: AppTypography.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.hasVariations)
                      Text(
                        '${item.variations.length} Options',
                        style: const TextStyle(fontSize: 10, color: Colors.blue),
                      ),
                    Text(
                      'KSH ${NumberFormat('#,##0').format(item.sellingPrice)}',
                      style: AppTypography.textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 70,
      color: AppColors.gray100,
      child: Icon(Icons.image, color: AppColors.gray300, size: 32),
    );
  }

  Future<File> _resolveImageFile(String imagePath) async {
    final directFile = File(imagePath);
    if (await directFile.exists()) return directFile;

    final directory = await getApplicationDocumentsDirectory();
    final filename = path.basename(imagePath);
    return File(path.join(directory.path, filename));
  }


  double _calculateCartTotal() {
    double total = 0.0;
    for (var cartItem in _cart) {
      // 1. Base cost
      double itemTotal = cartItem.quantity * cartItem.getUnitPrice(_txnType);
      
      // 2. Evaluate Promotions (Sale only)
      if (_txnType == 'sale' && _activePromotions.isNotEmpty) {
        for (var promo in _activePromotions) {
           final targetCategory = promo['target_category'] as String?;
           final type = promo['type'] as String;
           final discountValue = (promo['discount_value'] as num).toDouble();
           
           // Check if promo applies to this item (null category = storewide)
           if (targetCategory == null || targetCategory.isEmpty || cartItem.item.category?.toLowerCase() == targetCategory.toLowerCase()) {
             if (type == 'percentage') {
               itemTotal -= (itemTotal * (discountValue / 100));
             } else if (type == 'fixed_discount') {
               itemTotal -= (discountValue * cartItem.quantity); // Flat amount off each item
             } else if (type == 'bogo') {
               // Buy 1 Get 1 Free logic: Only charge for every 2nd item
               int payableItems = (cartItem.quantity / 2).ceil() + (cartItem.quantity % 2 == 0 ? 0 : 0);
               itemTotal = payableItems * cartItem.getUnitPrice(_txnType);
             }
           }
        }
      }
      
      // Prevent negative subtotals
      total += itemTotal > 0 ? itemTotal : 0;
    }
    return total;
  }

  Future<void> _addToCart(InventoryItem item, {int quantity = 1, double discount = 0.0, ProductVariation? variation}) async {
    // Check for variations logic
    if (item.hasVariations && variation == null) {
      if (mounted) {
         final selected = await _showVariationPicker(item);
         if (selected != null) {
           variation = selected;
         } else {
           return; // Cancelled
         }
      }
    }

    setState(() {
      final existingIndex = _cart.indexWhere((ci) => 
          ci.item.id == item.id && 
          ci.selectedVariation?.id == variation?.id
      );

      if (existingIndex >= 0) {
        final existing = _cart[existingIndex];
        _cart[existingIndex] = existing.copyWith(
          quantity: existing.quantity + quantity,
        );
      } else {
        _cart.add(CartItem(
          item: item,
          quantity: quantity,
          discount: discount,
          selectedVariation: variation,
        ));
      }
    });
  }
  
  Future<ProductVariation?> _showVariationPicker(InventoryItem item) async {
    return showModalBottomSheet<ProductVariation>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('Select Size / Option', 
               style: AppTypography.textTheme.headlineSmall,
             ),
             const SizedBox(height: 8),
             Text(item.name, style: AppTypography.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
             const SizedBox(height: 24),
             Flexible(
               child: ListView.separated(
                 shrinkWrap: true,
                 itemCount: item.variations.length,
                 separatorBuilder: (ctx, i) => const Divider(),
                 itemBuilder: (ctx, i) {
                   final v = item.variations[i];
                   final priceStr = v.priceModifier > 0 
                       ? '+${NumberFormat('#,##0').format(v.priceModifier)}' 
                       : (v.priceModifier < 0 ? '${NumberFormat('#,##0').format(v.priceModifier)}' : '');
                   
                   return ListTile(
                     contentPadding: EdgeInsets.zero,
                     title: Text(v.name, style: AppTypography.textTheme.titleMedium),
                     trailing: priceStr.isNotEmpty 
                         ? Text(priceStr, style: TextStyle(color: v.priceModifier > 0 ? AppColors.primaryGreen : AppColors.danger, fontWeight: FontWeight.bold))
                         : null,
                     onTap: () => Navigator.pop(ctx, v),
                   );
                 },
               ),
             ),
             const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  void _updateCartItemQuantity(int index, int quantity) {
    if (quantity <= 0) {
      _removeFromCart(index);
      return;
    }
    setState(() {
      _cart[index] = _cart[index].copyWith(quantity: quantity);
    });
  }




  Future<void> _sendDirectWhatsAppReceipt(
      String phone, double total, int timestamp, String signature) async {
    final now = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    // Get business name from shop profile
    final shop = await AuthService.getCurrentShop();
    final businessName = shop?.businessName ?? 'Mbeck Shop';

    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '254${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('254') && cleanPhone.length == 9) {
      cleanPhone = '254$cleanPhone';
    }

    String message = "🧾 *$businessName*\n";
    message += "----------------------------\n";
    message += "Type: ${_txnType.toUpperCase()}\n";
    if (_selectedCustomerName != null) {
      message += "Customer: $_selectedCustomerName\n";
    }

    for (final cartItem in _cart) {
      message += 
          "${cartItem.item.name} x${cartItem.quantity} = KSH ${cartItem.getSubtotal(_txnType)}\n";
    }

    message += "*Total: KSH $total*\n";
    message += "----------------------------\n";
    message +=
        "Ref: ${timestamp.toString().substring(timestamp.toString().length - 6)}\n";
    message += "Security Sig: $signature\n";
    message += "Date: $dateStr\n";
    message += "Time: $timeStr\n\n";
    message += "Thank you for shopping at *$businessName*!\n\n";
    message += "_Powered by Mbeck - Download for Free_";

    final encodedMsg = message.replaceAll('\n', '%0A');

    final whatsappUri =
        Uri.parse("whatsapp://send?phone=$cleanPhone&text=$encodedMsg");
    final httpsUri = Uri.parse(
        "https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMsg");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else if (await canLaunchUrl(httpsUri)) {
        await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
      } else {
        Share.share(message);
      }
    } catch (e) {
      Share.share(message);
    }
  }

  Future<void> _save() async {
    if (_txnType == 'sale') {
      await _saveSale();
    } else {
      await _saveIncomeExpense();
    }
  }

  Future<void> _saveIncomeExpense() async {
    // SECURITY: Prevent staff from bypassing inventory and creating expenses/income
    final currentMember = await AuthService.getCurrentMember();
    final hasPermission = currentMember?.hasPermission(Permissions.manageAccounting) ?? false;
    final isManager = currentMember?.role.toUpperCase() == 'MANAGER';
    final isOwner = currentMember?.role.toUpperCase() == 'OWNER';
    
    if (!hasPermission && !isManager && !isOwner) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⛔ Permission Denied: Only Managers/Owners can record Income/Expenses'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final totalAmount = double.parse(_amountController.text);
      final now = DateTime.now().millisecondsSinceEpoch;
      
      String finalDetails = _detailsController.text.trim();
      if (finalDetails.isEmpty) {
        finalDetails = '${_txnType.capitalize()} Transaction';
      }

      final signature = await _securityService.signTransaction(
        timestamp: now,
        totalAmount: totalAmount.toInt(),
        type: _txnType,
        details: finalDetails,
      );

      final eventPayload = {
        'type': _txnType,
        'amount': totalAmount,
        'items': [],
        'receiptSignature': signature,
        'details': finalDetails,
        'totalAmount': totalAmount,
        'itemId': null,
        'itemName': finalDetails,
      };

      await EventService.emitEvent(
        eventType: _txnType == 'outgoing' ? 'EXPENSE' : 'INCOME',
        payload: eventPayload,
        timestamp: now,
      );

      await DbProvider.insert('txn', {
        'type': _txnType,
        'totalAmount': totalAmount,
        'details': finalDetails,
        'timestamp': now,
        'receiptSignature': signature,
      });

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${_txnType.capitalize()} recorded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
  Future<void> _saveSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart is empty. Add items to continue.')));
      return;
    }

    // Step 1: Prompt for confirmation and M-Pesa code
    final totalAmount = _calculateCartTotal();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Amount:', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            Text('KES ${NumberFormat('#,##0').format(totalAmount)}', 
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryGreen)),
            const SizedBox(height: 20),
            TextField(
              controller: _paymentRefController,
              decoration: InputDecoration(
                labelText: 'M-Pesa Code / Reference (Optional)',
                hintText: 'e.g. SLK4J7HXRT',
                prefixIcon: const Icon(Icons.qr_code_scanner),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONFIRM PAYMENT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != true) return;

    final currentMember = await AuthService.getCurrentMember();
    final hasPermission = currentMember?.hasPermission(Permissions.createSale) ?? false;
    // Allow Owner/Manager implicitly just in case permission is missing from preset
    final isAuthorized = hasPermission || (currentMember != null && (currentMember.isOwner || currentMember.role.toUpperCase() == 'MANAGER'));

    if (!isAuthorized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⛔ Permission Denied: You cannot process sales.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final mpesaRef = _paymentRefController.text.trim();
      
      String finalDetails = _detailsController.text.trim();
      if (finalDetails.isEmpty) {
        finalDetails =
            _cart.map((ci) => '${ci.item.name} x${ci.quantity}').join(', ');
      }

      final signature = await _securityService.signTransaction(
        timestamp: now,
        totalAmount: totalAmount.toInt(),
        type: _txnType,
        details: finalDetails,
      );

      final itemsPayload = _cart.map((cartItem) {
        double discountedSubtotal = cartItem.quantity * cartItem.getUnitPrice(_txnType);
        if (_txnType == 'sale' && _activePromotions.isNotEmpty) {
          for (var promo in _activePromotions) {
             final targetCategory = promo['target_category'] as String?;
             final type = promo['type'] as String;
             final discountValue = (promo['discount_value'] as num).toDouble();
             if (targetCategory == null || targetCategory.isEmpty || cartItem.item.category?.toLowerCase() == targetCategory.toLowerCase()) {
               if (type == 'percentage') {
                 discountedSubtotal -= (discountedSubtotal * (discountValue / 100));
               } else if (type == 'fixed_discount') {
                 discountedSubtotal -= (discountValue * cartItem.quantity);
               } else if (type == 'bogo') {
                 int payableItems = (cartItem.quantity / 2).ceil() + (cartItem.quantity % 2 == 0 ? 0 : 0);
                 discountedSubtotal = payableItems * cartItem.getUnitPrice(_txnType);
               }
             }
          }
        }
        discountedSubtotal = discountedSubtotal > 0 ? discountedSubtotal : 0;
        
        return {
          'itemId': cartItem.item.id,
          'name': cartItem.item.name,
          'qty': cartItem.quantity,
          'price': cartItem.getUnitPrice(_txnType),
          'discount': cartItem.getSubtotal(_txnType) - discountedSubtotal,
          'subtotal': discountedSubtotal,
        };
      }).toList();

      final eventPayload = {
        'type': _txnType,
        'amount': totalAmount,
        'items': itemsPayload,
        'receiptSignature': signature,
        'details': finalDetails,
        'totalAmount': totalAmount,
        'payment_ref': mpesaRef.isNotEmpty ? mpesaRef : null,
        'itemId': _cart.isNotEmpty ? _cart.first.item.id : null,
        'itemName':
            _cart.isNotEmpty ? _cart.first.item.name : 'Multiple Items',
      };

      Event? event;
      try {
        event = await EventService.emitEvent(
          eventType: _txnType == 'sale'
              ? 'SALE'
              : (_txnType == 'outgoing' ? 'EXPENSE' : 'INCOME'),
          payload: eventPayload,
          timestamp: now,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to record transaction: $e')));
        }
        return;
      }

      for (final cartItem in _cart) {
        if (cartItem.item.id != null) {
          int stockChange =
              _txnType == 'sale' ? -cartItem.quantity : cartItem.quantity;
          try {
            await EventService.emitEvent(
              eventType: 'INVENTORY_CHANGE',
              payload: {
                'itemId': cartItem.item.id,
                'itemName': cartItem.item.name,
                'change': stockChange,
                'previousStock': cartItem.item.stock,
                'newStock': cartItem.item.stock + stockChange,
                'reason': _txnType == 'sale'
                    ? 'sale'
                    : (_txnType == 'outgoing' ? 'restock' : 'income'),
                'transactionEventId': event.id,
              },
            );
          } catch (e) {
            debugPrint(
                '⚠️ Failed to emit inventory change event for ${cartItem.item.name}: $e');
          }
        }
      }

      final db = await DbProvider.db;
      int? transactionId;

      final activeModules = await OnboardingService.getSelectedModules();
      final sourceModule = activeModules.isNotEmpty ? activeModules.first : 'retail';

      await db.transaction((txn) async {
        transactionId = await txn.insert('txn', {
          'type': _txnType,
          'totalAmount': totalAmount,
          'details': finalDetails,
          'timestamp': now,
          'receiptSignature': signature,
          'source_module': sourceModule,
          'customer_phone': _selectedCustomerPhone,
          'payment_ref': mpesaRef.isNotEmpty ? mpesaRef : null,
        });

        for (final cartItem in _cart) {
          if (cartItem.item.id != null) {
            await txn.insert('transaction_items', {
              'transactionId': transactionId,
              'itemId': cartItem.item.id,
              'quantity': cartItem.quantity,
              'unitPrice': cartItem.getUnitPrice(_txnType),
              'subtotal': cartItem.getSubtotal(_txnType),
              'discount': cartItem.discount,
            });

            int stockChange =
                _txnType == 'sale' ? -cartItem.quantity : cartItem.quantity;
            
            // Handle variations update
            if (cartItem.selectedVariation != null) {
               final freshData = await txn.query('inventory', 
                   where: 'id = ?', whereArgs: [cartItem.item.id]);
               
               if (freshData.isNotEmpty) {
                 final freshItem = InventoryItem.fromMap(freshData.first);
                 
                 // Update specific variation stock
                 final updatedVariations = freshItem.variations.map((v) {
                    // Match by ID if available, otherwise name
                    if ((v.id != null && v.id == cartItem.selectedVariation!.id) || 
                        (v.name == cartItem.selectedVariation!.name)) {
                       return v.copyWith(stock: v.stock + stockChange);
                    }
                    return v;
                 }).toList();
                 
                 final newJson = jsonEncode(updatedVariations.map((v) => v.toMap()).toList());
                 
                 await txn.update(
                   'inventory',
                   {
                     'stock': freshItem.stock + stockChange, // Update total stock
                     'variationsJson': newJson // Update variations key
                   },
                   where: 'id = ?',
                   whereArgs: [cartItem.item.id],
                 );
               }
            } else {
                // Standard update
                await txn.update(
                  'inventory',
                  {'stock': cartItem.item.stock + stockChange},
                  where: 'id = ?',
                  whereArgs: [cartItem.item.id],
                );
            }
          }
        }
      });

      // Update Sync Service for Auto-Advance
      final shop = await AuthService.getCurrentShop();
      final shopName = shop?.businessName ?? 'Mbeck Shop';
      CheckoutSyncService().updateStatus(
        CheckoutStatus.completed,
        receipt: {
          's': shopName,
          't': totalAmount,
          'd': now,
          'i': _cart.map((c) => {
            'n': c.item.name, 
            'q': c.quantity, 
            'p': c.getUnitPrice(_txnType)
          }).toList(),
          'sig': signature.substring(0, 8), // 8 character signature
        },
      );


      if (mounted) {
        setState(() => _isSaving = false);
        _paymentRefController.clear(); // Clear for next txn
        _showReceiptOption(totalAmount, now, signature);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showReceiptOption(double total, int timestamp, String signature) {
    String title =
        _txnType == 'outgoing' ? "Expense Recorded" : "Sale Successful";
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text("Send a digital receipt for this transaction?"),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Show QR Code for scanning
                    Navigator.pop(ctx); // Close dialog first? Or open new one? 
                    // Better to keep success dialog open or replace content.
                    // For simplicity, close and open QR dialog.
                    _showReceiptQr(total, timestamp, signature);
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text("QR Share"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleReceiptProcess(total, timestamp, signature);
                  },
                  icon: const Icon(Icons.chat), // WhatsApp-like icon
                  label: const Text("WhatsApp"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text("NO, SKIP", style: TextStyle(color: Colors.grey)),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowButtonSpacing: 8,
      ),
    );
  }

  void _showReceiptQr(double total, int timestamp, String signature) async {
    final shop = await AuthService.getCurrentShop();
    final shopName = shop?.businessName ?? 'Mbeck Shop';
    
    // Construct minimal receipt data for QR
    final receiptMap = {
      's': shopName,
      't': total,
      'd': timestamp,
      'i': _cart.map((c) => {'n': c.item.name, 'q': c.quantity, 'p': c.getUnitPrice(_txnType)}).toList(),
      'sig': signature.substring(0, 8) // 8 character signature
    };
    
    final qrData = jsonEncode(receiptMap);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          alignment: Alignment.center,
          title: const Text('Scan for Receipt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 260,
                height: 260,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 10)
                  ]
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 240.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Customer can scan this with Buyer App', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true); // Close transaction screen too
              },
              child: const Text('DONE'),
            )
          ],
        ),
      );
    }
  }

  Future<void> _handleReceiptProcess(
      double total, int timestamp, String signature) async {
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final manualPhoneCtrl = TextEditingController();
        return AlertDialog(
          title: const Text("Receipt Destination"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.contacts, color: AppColors.primaryGreen),
                title: const Text("Select from Customers"),
                onTap: () async {
                  final picked = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CustomersScreen(isPicker: true)),
                  );
                  Navigator.pop(ctx, picked?.toString());
                },
              ),
              const Divider(),
              const Text("Or enter number manually:"),
              TextField(
                controller: manualPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: "e.g. 0712345678"),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("CANCEL")),
            TextButton(
                onPressed: () => Navigator.pop(ctx, manualPhoneCtrl.text),
                child: const Text("PROCEED")),
          ],
        );
      },
    );

    if (phone != null && phone.isNotEmpty) {
      await _sendDirectWhatsAppReceipt(phone, total, timestamp, signature);
    }

    if (mounted) Navigator.pop(context, true);
  }

  // AI scanner methods removed — using manual picker only

  Future<void> _pickManuallyFromInventory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const InventoryScreen(isPicker: true)),
    );
    if (result != null && result is Map<String, dynamic>) {
      final picked = InventoryItem.fromMap(result);
      _addToCart(picked);
    }
  }

  /// Scan a product barcode and add to cart if found in inventory
  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(
          instruction: 'Scan product barcode to add to cart',
        ),
      ),
    );

    if (barcode == null || barcode.isEmpty) return;

    // Search inventory for matching barcode
    final match = _inventoryItems.where(
      (item) => item.barcode != null && item.barcode == barcode,
    ).toList();

    if (match.isNotEmpty) {
      HapticFeedback.mediumImpact();
      _addToCart(match.first);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Added: ${match.first.name}'),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No item found with barcode: $barcode'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Add New',
              textColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InventoryScreen(),
                ),
              ),
            ),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final typeColor =
        _txnType == 'outgoing' ? AppColors.danger : AppColors.primaryGreen;
    final typeLabel = _txnType == 'sale' ? 'New Sale' : (_txnType == 'outgoing' ? 'Record Expense' : 'Record Income');
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              typeLabel,
              style: AppTypography.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: typeColor,
              ),
            ),
          ],
        ),
        actions: [
          if (_txnType == 'sale' && _cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 16, color: AppColors.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      '${_cart.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        bottom: widget.lockTxnType == null ? PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildTypeSelector(),
        ) : null,
      ),
      body: Form(
        key: _formKey,
        child: _txnType == 'sale'
            ? _buildSaleView()
            : _buildIncomeExpenseForm(typeColor),
      ),
      bottomNavigationBar: _txnType == 'sale' && _cart.isNotEmpty
          ? _buildCartBottomBar(typeColor)
          : null,
    );
  }

  Widget _buildSaleView() {
    return Column(
      children: [
        _buildCustomerSelector(),
        Expanded(
          child: _cart.isEmpty
              ? _buildEmptyCartState()
              : _buildCartItemsList(),
        ),
        _buildAddItemButtons(),
      ],
    );
  }

  Future<void> _selectCustomer() async {
    final phone = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CustomersScreen(isPicker: true)),
    );
    if (phone != null && mounted) {
      // Look up customer name from DB
      final rows = await DbProvider.queryRaw(
        'SELECT name, store FROM customer WHERE phone = ? LIMIT 1',
        [phone],
      );
      final name = rows.isNotEmpty
          ? (rows.first['name']?.toString().isNotEmpty == true
              ? rows.first['name'].toString()
              : rows.first['store']?.toString() ?? phone)
          : phone;
      setState(() {
        _selectedCustomerPhone = phone;
        _selectedCustomerName = name;
      });
    }
  }

  Widget _buildCustomerSelector() {
    final hasCustomer = _selectedCustomerPhone != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.gray100)),
      ),
      child: GestureDetector(
        onTap: _selectCustomer,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: hasCustomer
                ? AppColors.primaryGreen.withOpacity(0.08)
                : AppColors.gray100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasCustomer
                  ? AppColors.primaryGreen.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasCustomer ? Icons.person : Icons.person_outline,
                size: 16,
                color: hasCustomer ? AppColors.primaryGreen : AppColors.gray400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCustomer ? _selectedCustomerName! : 'Walk-in Customer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hasCustomer ? AppColors.gray900 : AppColors.gray500,
                      ),
                    ),
                    if (hasCustomer)
                      Text(
                        _selectedCustomerPhone!,
                        style: TextStyle(fontSize: 11, color: AppColors.gray400),
                      ),
                  ],
                ),
              ),
              if (hasCustomer)
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedCustomerPhone = null;
                    _selectedCustomerName = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.gray200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 12, color: AppColors.gray600),
                  ),
                )
              else
                Icon(Icons.chevron_right, size: 18, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importFromQr() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartQrScannerScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      final List<dynamic> items = result['items'] ?? [];
      int importedCount = 0;

      setState(() {
        for (final itemData in items) {
          final int? itemId = itemData['id'];
          final int quantity = itemData['q'] ?? itemData['qty'] ?? 1;

          if (itemId != null) {
            // Find item in local inventory to get full details (like current price/stock)
            final inventoryItemIndex =
                _inventoryItems.indexWhere((i) => i.id == itemId);
            if (inventoryItemIndex != -1) {
              _addToCart(_inventoryItems[inventoryItemIndex], quantity: quantity);
              importedCount++;
            }
          }
        }
      });

      if (mounted && importedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $importedCount items from customer cart')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching items found in your inventory')),
        );
      }
    }
  }

  Widget _buildAddItemButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.gray100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionPill(
              icon: Icons.add_shopping_cart,
              label: 'Add Item',
              color: AppColors.primaryGreen,
              onTap: _pickManuallyFromInventory,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionPill(
              icon: Icons.barcode_reader,
              label: 'Scan',
              color: Colors.deepPurple,
              onTap: _scanBarcode,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionPill(
              icon: Icons.qr_code_scanner,
              label: 'Import',
              color: AppColors.gray600,
              onTap: _importFromQr,
              outlined: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: outlined ? Colors.white : color,
          borderRadius: BorderRadius.circular(12),
          border: outlined ? Border.all(color: color.withOpacity(0.4)) : null,
          boxShadow: outlined ? [] : [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: outlined ? color : Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: outlined ? color : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCartState() {
    return Column(
      children: [
        // Recently Sold section (research-based: Square's quick-access pattern)
        FutureBuilder<List<InventoryItem>>(
          future: _getRecentlySoldItems(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(Icons.flash_on, size: 18, color: AppColors.gray600), // Changed icon
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Quick Add', // Changed Title
                          style: AppTypography.textTheme.headlineMedium?.copyWith(
                            fontSize: 16,
                            color: AppColors.gray700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final item = snapshot.data![index];
                        return _buildRecentlyItemCard(item);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                   Divider(color: AppColors.gray200, height: 1),
                  const SizedBox(height: AppSpacing.lg),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    size: 64, color: AppColors.gray300),
                const SizedBox(height: AppSpacing.md),
                Text('Your Cart is Empty',
                    style: AppTypography.textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Add products using the scanner or by picking from inventory.',
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: AppColors.gray600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemsList() {
    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _cart.length,
        itemBuilder: (context, index) {
          return _buildCartItemCard(index);
        },
      ),
    );
  }

  Widget _buildCartItemCard(int index) {
    final cartItem = _cart[index];
    
    double _getDiscountedSubtotal(CartItem cartItem) {
      double itemTotal = cartItem.quantity * cartItem.getUnitPrice(_txnType);
      if (_txnType == 'sale' && _activePromotions.isNotEmpty) {
        for (var promo in _activePromotions) {
           final targetCategory = promo['target_category'] as String?;
           final type = promo['type'] as String;
           final discountValue = (promo['discount_value'] as num).toDouble();
           
           if (targetCategory == null || targetCategory.isEmpty || cartItem.item.category?.toLowerCase() == targetCategory.toLowerCase()) {
             if (type == 'percentage') {
               itemTotal -= (itemTotal * (discountValue / 100));
             } else if (type == 'fixed_discount') {
               itemTotal -= (discountValue * cartItem.quantity);
             } else if (type == 'bogo') {
               int payableItems = (cartItem.quantity / 2).ceil() + (cartItem.quantity % 2 == 0 ? 0 : 0);
               itemTotal = payableItems * cartItem.getUnitPrice(_txnType);
             }
           }
        }
      }
      return itemTotal > 0 ? itemTotal : 0;
    }
    
    final subtotal = _getDiscountedSubtotal(cartItem);

    return Slidable(
      key: ValueKey(cartItem.item.id),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _removeFromCart(index),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Remove',
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.gray100),
          boxShadow: const [AppShadows.sm],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cartItem.displayName,
                        style: AppTypography.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.gray900,
                        ),
                      ),
                      if (subtotal < cartItem.getSubtotal(_txnType))
                        Text(
                          'Promo Applied',
                          style: TextStyle(fontSize: 10, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'KES ${NumberFormat('#,##0').format(subtotal)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    if (subtotal < cartItem.getSubtotal(_txnType))
                      Text(
                        'KES ${NumberFormat('#,##0').format(cartItem.getSubtotal(_txnType))}',
                        style: TextStyle(
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.gray400,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'KES ${NumberFormat('#,##0').format(cartItem.getUnitPrice(_txnType))} each',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.gray400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _buildQuantityControl(index),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControl(int index) {
    final cartItem = _cart[index];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            onPressed: () {
              HapticFeedback.lightImpact();
              _updateCartItemQuantity(index, cartItem.quantity - 1);
            },
          ),
          Text(
            cartItem.quantity.toString(),
            style: AppTypography.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            onPressed: () {
              HapticFeedback.lightImpact();
              _updateCartItemQuantity(index, cartItem.quantity + 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartBottomBar(Color typeColor) {
    final total = _calculateCartTotal();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -4))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_cart.length} ${_cart.length == 1 ? 'item' : 'items'}',
                      style: TextStyle(fontSize: 12, color: AppColors.gray400, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text('Total', style: AppTypography.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.gray600)),
                  ],
                ),
                Text(
                  'KES ${NumberFormat('#,##0').format(total)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: typeColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: typeColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  shadowColor: typeColor.withOpacity(0.3),
                ),
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _txnType == 'outgoing' ? 'CONFIRM EXPENSE' : 'CHARGE & SAVE',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    final types = [
      {'key': 'sale', 'label': 'Sale', 'icon': Icons.shopping_bag_outlined, 'color': AppColors.primaryGreen},
      {'key': 'incoming', 'label': 'Income', 'icon': Icons.arrow_downward, 'color': AppColors.success},
      {'key': 'outgoing', 'label': 'Expense', 'icon': Icons.arrow_upward, 'color': AppColors.danger},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: types.map((t) {
          final isActive = _txnType == t['key'];
          final color = t['color'] as Color;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _txnType = t['key'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? color : AppColors.gray100,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))] : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t['icon'] as IconData, size: 16, color: isActive ? Colors.white : AppColors.gray500),
                    const SizedBox(width: 5),
                    Text(
                      t['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIncomeExpenseForm(Color typeColor) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'KSH ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md)),
                    filled: true,
                    fillColor: AppColors.surfaceWhite,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _detailsController,
                  decoration: InputDecoration(
                    labelText: 'Details (Optional)',
                    hintText: 'e.g. "Lunch" or "Transport"',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md)),
                    filled: true,
                    fillColor: AppColors.surfaceWhite,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  backgroundColor: typeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.full)),
                ),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: Icon(Icons.hourglass_empty, color: Colors.white, size: 20),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSaving ? 'SAVING...' : 'SAVE TRANSACTION',
                  style: AppTypography.textTheme.labelLarge,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
