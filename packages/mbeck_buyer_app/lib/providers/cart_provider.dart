import 'package:flutter/foundation.dart';
import 'package:mbeck_shared/mbeck_shared.dart';

/// A single item in the cart, optionally with a selected variation and modifiers
class CartItem {
  final InventoryItem item;
  final ProductVariation? selectedVariation;
  final List<String>? selectedModifiers;
  int quantity;

  CartItem({
    required this.item,
    this.selectedVariation,
    this.selectedModifiers,
    this.quantity = 1,
  });

  /// Get the effective price including variation modifier
  double get effectivePrice {
    double price = item.sellingPrice;
    if (selectedVariation != null) {
      price += selectedVariation!.priceModifier;
    }
    // Modifiers currently do not add to price in this simplified model,
    // but this could be extended if needed.
    return price;
  }

  /// Total for this cart item
  double get total => effectivePrice * quantity;

  /// Display name including variation and modifiers
  String get displayName {
    String name = item.name;
    if (selectedVariation != null) {
      name += ' (${selectedVariation!.name})';
    }
    if (selectedModifiers != null && selectedModifiers!.isNotEmpty) {
      name += ' [${selectedModifiers!.join(', ')}]';
    }
    return name;
  }

  /// Unique key for cart lookup (combines item ID with variation and modifiers)
  String get cartKey {
    String key = '${item.id}';
    if (selectedVariation != null && selectedVariation!.id != null) {
      key += '_v${selectedVariation!.id}';
    }
    if (selectedModifiers != null && selectedModifiers!.isNotEmpty) {
      // Sort to ensure consistent keys regardless of order
      final sortedMods = List<String>.from(selectedModifiers!)..sort();
      key += '_m${sortedMods.join('-').hashCode}';
    }
    return key;
  }

  /// Serialize the cart item for the unified checkout payload
  Map<String, dynamic> toJson() {
    return {
      'id': item.id,
      'name': displayName, // Pass the full structured name for simplified systems
      'base_name': item.name,
      'qty': quantity,
      'price': effectivePrice,
      'variation_id': selectedVariation?.id,
      'variation_name': selectedVariation?.name,
      'modifiers': selectedModifiers ?? [],
      'item_note': selectedModifiers != null && selectedModifiers!.isNotEmpty 
          ? selectedModifiers!.join('; ') 
          : '',
    };
  }
}

/// Order type for restaurant orders
enum OrderType { dineIn, takeaway, delivery }

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  
  // Restaurant order fields (Phase 5)
  OrderType _orderType = OrderType.takeaway;
  int? _tableNumber;
  String? _customerNote;
  
  OrderType get orderType => _orderType;
  int? get tableNumber => _tableNumber;
  String? get customerNote => _customerNote;
  
  void setOrderType(OrderType type) {
    _orderType = type;
    notifyListeners();
  }
  
  void setTableNumber(int? number) {
    _tableNumber = number;
    notifyListeners();
  }
  
  void setCustomerNote(String? note) {
    _customerNote = note;
    notifyListeners();
  }

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get grandTotal => _items.fold(0.0, (sum, item) => sum + item.total);

  /// Add item with optional variation and modifiers
  void addItem(InventoryItem item, {ProductVariation? variation, List<String>? modifiers}) {
    // Build a key to check for existing items
    String key = '${item.id}';
    if (variation != null && variation.id != null) {
      key += '_v${variation.id}';
    }
    if (modifiers != null && modifiers.isNotEmpty) {
      final sortedMods = List<String>.from(modifiers)..sort();
      key += '_m${sortedMods.join('-').hashCode}';
    }

    final index = _items.indexWhere((i) => i.cartKey == key);
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(
        item: item, 
        selectedVariation: variation,
        selectedModifiers: modifiers,
      ));
    }
    notifyListeners();
  }
  
  /// Add menu item from restaurant (simplified API)
  void addMenuItem({
    required String id,
    required String name,
    required double price,
    String? imagePath,
    List<String>? modifiers,
  }) {
    // Create a minimal InventoryItem for the cart
    final menuItem = InventoryItem(
      id: int.tryParse(id) ?? id.hashCode,
      name: name,
      barcode: 'menu_$id',
      sellingPrice: price,
      originalPrice: 0,
      stock: 999, // Menu items don't track stock
      category: 'Menu',
      imagePath: imagePath,
    );
    addItem(menuItem, modifiers: modifiers);
  }

  /// Decrement quantity by 1, or remove entirely if qty == 1.
  /// Pass [cartKey] from CartItem.cartKey — encodes id + variation + modifiers.
  void removeSingleItem(String cartKey) {
    final index = _items.indexWhere((i) => i.cartKey == cartKey);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  /// Remove all quantities of an item by its cartKey.
  void removeItem(String cartKey) {
    _items.removeWhere((i) => i.cartKey == cartKey);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
