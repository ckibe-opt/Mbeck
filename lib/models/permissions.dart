/// Permission constants for Role-Based Access Control (RBAC)
/// Based on industry-standard POS systems (Square, Shopify POS, Lightspeed)
class Permissions {
  // Sales & Transactions
  static const String createSale = 'create_sale';
  static const String voidSale = 'void_sale';
  static const String applyDiscount = 'apply_discount';
  static const String processRefund = 'process_refund';

  // Inventory Management
  static const String viewInventory = 'view_inventory';
  static const String addInventoryItem = 'add_inventory_item';
  static const String editInventoryItem = 'edit_inventory_item';
  static const String deleteInventoryItem = 'delete_inventory_item';
  static const String adjustStock = 'adjust_stock';

  // Financial & Reports
  static const String viewReports = 'view_reports';
  static const String viewProfitMargins = 'view_profit_margins';
  static const String manageAccounting = 'manage_accounting';
  static const String viewCashCount = 'view_cash_count';
  static const String performCashCount = 'perform_cash_count';

  // Customer Management
  static const String viewCustomers = 'view_customers';
  static const String addCustomer = 'add_customer';
  static const String editCustomer = 'edit_customer';
  static const String deleteCustomer = 'delete_customer';
  static const String viewCustomerDetails =
      'view_customer_details'; // ID, phone numbers

  // Team Management
  static const String viewTeamMembers = 'view_team_members';
  static const String addTeamMember = 'add_team_member';
  static const String removeTeamMember = 'remove_team_member';
  static const String managePermissions = 'manage_permissions';

  // Settings & Configuration
  static const String changeSettings = 'change_settings';
  static const String manageSubscription = 'manage_subscription';
  static const String viewShopId = 'view_shop_id'; // For security reasons
  static const String exportData = 'export_data';
  static const String importData = 'import_data';

  // Delivery & Orders
  static const String viewOrders = 'view_orders';
  static const String markDelivered = 'mark_delivered';
}

/// Role Presets with default permissions for each role
class RolePresets {
  /// Owner role - Has ALL permissions implicitly
  static Map<String, dynamic> get owner => {
        'is_owner': true,
        // Owners have all permissions by default
        // This is checked in ShopMember.hasPermission()
      };

  /// Admin role - Has most permissions except critical operations
  static Map<String, dynamic> get admin => {
        Permissions.createSale: true,
        Permissions.voidSale: true,
        Permissions.applyDiscount: true,
        Permissions.processRefund: true,
        Permissions.viewInventory: true,
        Permissions.addInventoryItem: true,
        Permissions.editInventoryItem: true,
        Permissions.deleteInventoryItem: true,
        Permissions.adjustStock: true,
        Permissions.viewReports: true,
        Permissions.viewProfitMargins: true,
        Permissions.manageAccounting: true,
        Permissions.viewCashCount: true,
        Permissions.performCashCount: true,
        Permissions.viewCustomers: true,
        Permissions.addCustomer: true,
        Permissions.editCustomer: true,
        Permissions.deleteCustomer: true,
        Permissions.viewCustomerDetails: true,
        Permissions.viewTeamMembers: true,
        Permissions.addTeamMember: true, // Allow Managers to add staff
        Permissions.removeTeamMember: true, // Allow Managers to remove staff
        Permissions.managePermissions: false, // Only Owners can manage granular permissions
        Permissions.changeSettings: true,
        Permissions.manageSubscription: false, // Only Owners can manage subscription
        Permissions.viewShopId: true,
        Permissions.exportData: true,
        Permissions.importData: true,
      };

  /// Cashier/Staff role - Basic permissions for daily operations
  static Map<String, dynamic> get cashier => {
        Permissions.createSale: true,
        Permissions.voidSale: false, // Needs manager override
        Permissions.applyDiscount: true,
        Permissions.processRefund: false,
        Permissions.viewInventory: true,
        Permissions.addInventoryItem: false,
        Permissions.editInventoryItem: false,
        Permissions.deleteInventoryItem: false,
        Permissions.adjustStock: false,
        Permissions.viewReports: false,
        Permissions.viewProfitMargins: false, // Privacy
        Permissions.manageAccounting: false,
        Permissions.viewCashCount: false,
        Permissions.performCashCount: true,
        Permissions.viewCustomers: true,
        Permissions.addCustomer: true,
        Permissions.editCustomer: false,
        Permissions.deleteCustomer: false,
        Permissions.viewCustomerDetails: false, // Privacy
        Permissions.viewTeamMembers: false,
        Permissions.addTeamMember: false,
        Permissions.removeTeamMember: false,
        Permissions.managePermissions: false,
        Permissions.changeSettings: false,
        Permissions.manageSubscription: false,
        Permissions.viewShopId: false,
        Permissions.exportData: false,
        Permissions.importData: false,
      };

  /// Stocker/Inventory Clerk role - Focused on inventory management
  static Map<String, dynamic> get stocker => {
        Permissions.createSale: false,
        Permissions.voidSale: false,
        Permissions.applyDiscount: false,
        Permissions.processRefund: false,
        Permissions.viewInventory: true,
        Permissions.addInventoryItem: true, // Add new stock arrivals
        Permissions.editInventoryItem: false, // Cannot change prices
        Permissions.deleteInventoryItem: false,
        Permissions.adjustStock: true, // Restock, count corrections
        Permissions.viewReports: false,
        Permissions.viewProfitMargins: false,
        Permissions.manageAccounting: false,
        Permissions.viewCashCount: false,
        Permissions.performCashCount: false,
        Permissions.viewCustomers: false,
        Permissions.addCustomer: false,
        Permissions.editCustomer: false,
        Permissions.deleteCustomer: false,
        Permissions.viewCustomerDetails: false,
        Permissions.viewTeamMembers: false,
        Permissions.addTeamMember: false,
        Permissions.removeTeamMember: false,
        Permissions.managePermissions: false,
        Permissions.changeSettings: false,
        Permissions.manageSubscription: false,
        Permissions.viewShopId: false,
        Permissions.exportData: false,
        Permissions.importData: false,
      };

  /// Shift Supervisor role - Extended cashier with override powers
  static Map<String, dynamic> get shiftSupervisor => {
        Permissions.createSale: true,
        Permissions.voidSale: true, // Can void own sales
        Permissions.applyDiscount: true,
        Permissions.processRefund: true, // Handle customer issues
        Permissions.viewInventory: true,
        Permissions.addInventoryItem: false,
        Permissions.editInventoryItem: false,
        Permissions.deleteInventoryItem: false,
        Permissions.adjustStock: false,
        Permissions.viewReports: true, // Daily sales reports only
        Permissions.viewProfitMargins: false, // Privacy
        Permissions.manageAccounting: false,
        Permissions.viewCashCount: true,
        Permissions.performCashCount: true,
        Permissions.viewCustomers: true,
        Permissions.addCustomer: true,
        Permissions.editCustomer: true,
        Permissions.deleteCustomer: false,
        Permissions.viewCustomerDetails: true,
        Permissions.viewTeamMembers: true, // See team but can't edit
        Permissions.addTeamMember: false,
        Permissions.removeTeamMember: false,
        Permissions.managePermissions: false,
        Permissions.changeSettings: false,
        Permissions.manageSubscription: false,
        Permissions.viewShopId: false,
        Permissions.exportData: false,
        Permissions.importData: false,
      };

  /// Inventory Manager role - Dedicated inventory management
  static Map<String, dynamic> get inventoryManager => {
        Permissions.createSale: false,
        Permissions.voidSale: false,
        Permissions.applyDiscount: false,
        Permissions.processRefund: false,
        Permissions.viewInventory: true,
        Permissions.addInventoryItem: true,
        Permissions.editInventoryItem: true, // Full inventory control
        Permissions.deleteInventoryItem: true,
        Permissions.adjustStock: true,
        Permissions.viewReports: true, // Inventory reports
        Permissions.viewProfitMargins: false, // Privacy
        Permissions.manageAccounting: false,
        Permissions.viewCashCount: false,
        Permissions.performCashCount: false,
        Permissions.viewCustomers: false,
        Permissions.addCustomer: false,
        Permissions.editCustomer: false,
        Permissions.deleteCustomer: false,
        Permissions.viewCustomerDetails: false,
        Permissions.viewTeamMembers: false,
        Permissions.addTeamMember: false,
        Permissions.removeTeamMember: false,
        Permissions.managePermissions: false,
        Permissions.changeSettings: false,
        Permissions.manageSubscription: false,
        Permissions.viewShopId: false,
        Permissions.exportData: true, // Export inventory data
        Permissions.importData: true, // Bulk inventory updates
      };

  /// Custom role - Owner can define permissions manually
  static Map<String, dynamic> get custom => {
        // All permissions default to false
        // Owner will manually enable needed permissions
      };

  // =====================================
  // RESTAURANT MODULE ROLES
  // =====================================

  /// Waiter role - Takes orders, manages tables
  static Map<String, dynamic> get waiter => {
        Permissions.createSale: true, // Take orders
        Permissions.voidSale: false,
        Permissions.applyDiscount: false,
        Permissions.processRefund: false,
        Permissions.viewInventory: true, // View menu
        Permissions.addInventoryItem: false,
        Permissions.editInventoryItem: false,
        Permissions.deleteInventoryItem: false,
        Permissions.adjustStock: false,
        Permissions.viewReports: false,
        Permissions.viewProfitMargins: false,
        Permissions.manageAccounting: false,
        Permissions.viewCashCount: false,
        Permissions.performCashCount: false,
        Permissions.viewCustomers: true,
        Permissions.addCustomer: true,
        Permissions.editCustomer: false,
        Permissions.deleteCustomer: false,
        Permissions.viewCustomerDetails: false,
        Permissions.viewTeamMembers: false,
        Permissions.addTeamMember: false,
        Permissions.removeTeamMember: false,
        Permissions.managePermissions: false,
        Permissions.changeSettings: false,
        Permissions.manageSubscription: false,
        Permissions.viewShopId: false,
        Permissions.exportData: false,
        Permissions.importData: false,
      };

  /// Chef role - Kitchen operations, view queue, mark ready
  static Map<String, dynamic> get chef => {
        Permissions.createSale: false,
        Permissions.voidSale: false,
        Permissions.applyDiscount: false,
        Permissions.processRefund: false,
        Permissions.viewInventory: true, // View stock/ingredients
        Permissions.addInventoryItem: false,
        Permissions.editInventoryItem: false,
        Permissions.deleteInventoryItem: false,
        Permissions.adjustStock: true, // Mark ingredients used
        Permissions.viewReports: false,
        Permissions.viewProfitMargins: false,
        Permissions.manageAccounting: false,
        Permissions.viewCashCount: false,
        Permissions.performCashCount: false,
        Permissions.viewCustomers: false,
        Permissions.addCustomer: false,
        Permissions.editCustomer: false,
        Permissions.deleteCustomer: false,
        Permissions.viewCustomerDetails: false,
        Permissions.viewTeamMembers: false,
        Permissions.addTeamMember: false,
        Permissions.removeTeamMember: false,
        Permissions.managePermissions: false,
        Permissions.changeSettings: false,
        Permissions.manageSubscription: false,
        Permissions.viewShopId: false,
        Permissions.exportData: false,
        Permissions.importData: false,
      };

  // =====================================
  // SERVICES MODULE ROLES
  // =====================================

  /// Receptionist role - Book appointments, manage schedule
  static Map<String, dynamic> get receptionist => {
        Permissions.createSale: true, // Book appointments
        Permissions.voidSale: false,
        Permissions.applyDiscount: false,
        Permissions.processRefund: false,
        Permissions.viewInventory: true, // View services catalog
        Permissions.addInventoryItem: false,
        Permissions.editInventoryItem: false,
        Permissions.deleteInventoryItem: false,
        Permissions.adjustStock: false,
        Permissions.viewReports: false,
        Permissions.viewProfitMargins: false,
        Permissions.manageAccounting: false,
        Permissions.viewCashCount: false,
        Permissions.performCashCount: true,
        Permissions.viewCustomers: true,
        Permissions.addCustomer: true,
        Permissions.editCustomer: true,
        Permissions.deleteCustomer: false,
        Permissions.viewCustomerDetails: true,
        Permissions.viewTeamMembers: false,
        Permissions.addTeamMember: false,
        Permissions.removeTeamMember: false,
        Permissions.managePermissions: false,
        Permissions.changeSettings: false,
        Permissions.manageSubscription: false,
        Permissions.viewShopId: false,
        Permissions.exportData: false,
        Permissions.importData: false,
      };

  /// Service Provider role - View own schedule, mark services complete
  static Map<String, dynamic> get serviceProvider => {
        Permissions.createSale: true, // Complete service = sale
        Permissions.voidSale: false,
        Permissions.applyDiscount: false,
        Permissions.processRefund: false,
        Permissions.viewInventory: true, // View services
        Permissions.addInventoryItem: false,
        Permissions.editInventoryItem: false,
        Permissions.deleteInventoryItem: false,
        Permissions.adjustStock: false,
        Permissions.viewReports: false, // Own stats only (future)
        Permissions.viewProfitMargins: false,
        Permissions.manageAccounting: false,
        Permissions.viewCashCount: false,
        Permissions.performCashCount: false,
        Permissions.viewCustomers: true, // View client info
        Permissions.addCustomer: false,
        Permissions.editCustomer: false,
        Permissions.deleteCustomer: false,
        Permissions.viewCustomerDetails: true, // For appointment details
        Permissions.viewTeamMembers: false,
        Permissions.addTeamMember: false,
        Permissions.removeTeamMember: false,
        Permissions.managePermissions: false,
        Permissions.changeSettings: false,
        Permissions.manageSubscription: false,
        Permissions.viewShopId: false,
        Permissions.exportData: false,
        Permissions.importData: false,
        Permissions.viewOrders: false,
        Permissions.markDelivered: false,
      };

  // =====================================
  // DELIVERY ROLE
  // =====================================

  /// Delivery role - Sees takeaway orders, marks them delivered
  static Map<String, dynamic> get delivery => {
        Permissions.createSale: false,
        Permissions.voidSale: false,
        Permissions.applyDiscount: false,
        Permissions.processRefund: false,
        Permissions.viewInventory: true, // View menu items for order context
        Permissions.addInventoryItem: false,
        Permissions.editInventoryItem: false,
        Permissions.deleteInventoryItem: false,
        Permissions.adjustStock: false,
        Permissions.viewReports: false,
        Permissions.viewProfitMargins: false,
        Permissions.manageAccounting: false,
        Permissions.viewCashCount: false,
        Permissions.performCashCount: false,
        Permissions.viewCustomers: true, // See delivery address/phone
        Permissions.addCustomer: false,
        Permissions.editCustomer: false,
        Permissions.deleteCustomer: false,
        Permissions.viewCustomerDetails: true, // Delivery details
        Permissions.viewTeamMembers: false,
        Permissions.addTeamMember: false,
        Permissions.removeTeamMember: false,
        Permissions.managePermissions: false,
        Permissions.changeSettings: false,
        Permissions.manageSubscription: false,
        Permissions.viewShopId: false,
        Permissions.exportData: false,
        Permissions.importData: false,
        Permissions.viewOrders: true, // Core: see takeaway orders
        Permissions.markDelivered: true, // Core: mark delivered
      };

  /// Get preset permissions for a role
  static Map<String, dynamic> getPresetForRole(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return owner;
      case 'ADMIN':
      case 'MANAGER':
        return admin;
      case 'STAFF':
      case 'CASHIER':
        return cashier;
      case 'STOCKER':
      case 'INVENTORY_CLERK':
        return stocker;
      case 'SHIFT_SUPERVISOR':
      case 'SUPERVISOR':
        return shiftSupervisor;
      case 'INVENTORY_MANAGER':
        return inventoryManager;
      // Restaurant roles
      case 'WAITER':
        return waiter;
      case 'CHEF':
        return chef;
      // Services roles
      case 'RECEPTIONIST':
        return receptionist;
      case 'SERVICE_PROVIDER':
        return serviceProvider;
      // Delivery role
      case 'DELIVERY':
        return delivery;
      case 'CUSTOM':
        return custom;
      default:
        return cashier; // Default to cashier permissions
    }
  }

  /// Get all permission keys as a list
  static List<String> getAllPermissions() {
    return [
      Permissions.createSale,
      Permissions.voidSale,
      Permissions.applyDiscount,
      Permissions.processRefund,
      Permissions.viewInventory,
      Permissions.addInventoryItem,
      Permissions.editInventoryItem,
      Permissions.deleteInventoryItem,
      Permissions.adjustStock,
      Permissions.viewReports,
      Permissions.viewProfitMargins,
      Permissions.manageAccounting,
      Permissions.viewCashCount,
      Permissions.performCashCount,
      Permissions.viewCustomers,
      Permissions.addCustomer,
      Permissions.editCustomer,
      Permissions.deleteCustomer,
      Permissions.viewCustomerDetails,
      Permissions.viewTeamMembers,
      Permissions.addTeamMember,
      Permissions.removeTeamMember,
      Permissions.managePermissions,
      Permissions.changeSettings,
      Permissions.manageSubscription,
      Permissions.viewShopId,
      Permissions.exportData,
      Permissions.importData,
      Permissions.viewOrders,
      Permissions.markDelivered,
    ];
  }

  /// Get human-readable name for a permission
  static String getPermissionDisplayName(String permission) {
    switch (permission) {
      case Permissions.createSale:
        return 'Create Sales';
      case Permissions.voidSale:
        return 'Void Sales';
      case Permissions.applyDiscount:
        return 'Apply Discounts';
      case Permissions.processRefund:
        return 'Process Refunds';
      case Permissions.viewInventory:
        return 'View Inventory';
      case Permissions.addInventoryItem:
        return 'Add Inventory Items';
      case Permissions.editInventoryItem:
        return 'Edit Inventory Items';
      case Permissions.deleteInventoryItem:
        return 'Delete Inventory Items';
      case Permissions.adjustStock:
        return 'Adjust Stock Levels';
      case Permissions.viewReports:
        return 'View Reports';
      case Permissions.viewProfitMargins:
        return 'View Profit Margins';
      case Permissions.manageAccounting:
        return 'Manage Accounting';
      case Permissions.viewCashCount:
        return 'View Cash Count';
      case Permissions.performCashCount:
        return 'Perform Cash Count';
      case Permissions.viewCustomers:
        return 'View Customers';
      case Permissions.addCustomer:
        return 'Add Customers';
      case Permissions.editCustomer:
        return 'Edit Customers';
      case Permissions.deleteCustomer:
        return 'Delete Customers';
      case Permissions.viewCustomerDetails:
        return 'View Customer Details';
      case Permissions.viewTeamMembers:
        return 'View Team Members';
      case Permissions.addTeamMember:
        return 'Add Team Members';
      case Permissions.removeTeamMember:
        return 'Remove Team Members';
      case Permissions.managePermissions:
        return 'Manage Permissions';
      case Permissions.changeSettings:
        return 'Change Settings';
      case Permissions.manageSubscription:
        return 'Manage Subscription';
      case Permissions.viewShopId:
        return 'View Shop ID';
      case Permissions.exportData:
        return 'Export Data';
      case Permissions.importData:
        return 'Import Data';
      case Permissions.viewOrders:
        return 'View Orders';
      case Permissions.markDelivered:
        return 'Mark Delivered';
      default:
        return permission
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  /// Get role display name
  static String getRoleDisplayName(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return 'Owner';
      case 'ADMIN':
      case 'MANAGER':
        return 'Manager';
      case 'STAFF':
      case 'CASHIER':
        return 'Cashier';
      case 'STOCKER':
      case 'INVENTORY_CLERK':
        return 'Stocker';
      case 'SHIFT_SUPERVISOR':
      case 'SUPERVISOR':
        return 'Shift Supervisor';
      case 'INVENTORY_MANAGER':
        return 'Inventory Manager';
      // Restaurant roles
      case 'WAITER':
        return 'Waiter';
      case 'CHEF':
        return 'Chef';
      // Services roles
      case 'RECEPTIONIST':
        return 'Receptionist';
      case 'SERVICE_PROVIDER':
        return 'Service Provider';
      // Delivery role
      case 'DELIVERY':
        return 'Delivery';
      case 'CUSTOM':
        return 'Custom Role';
      default:
        return role;
    }
  }

  /// Get all available roles

  static List<String> getAllRoles() {
    return [
      'CASHIER',
      'STOCKER',
      'SHIFT_SUPERVISOR',
      'INVENTORY_MANAGER',
      'MANAGER',
      'WAITER',
      'CHEF',
      'DELIVERY',
      'RECEPTIONIST',
      'SERVICE_PROVIDER',
      'CUSTOM',
    ];
  }

  /// Get roles filtered by module
  static List<String> getRolesForModule(List<String> enabledModules) {
    final roles = <String>['MANAGER']; // Manager is always available
    
    if (enabledModules.contains('retail')) {
      roles.addAll(['CASHIER', 'STOCKER', 'INVENTORY_MANAGER', 'SHIFT_SUPERVISOR']);
    }
    
    if (enabledModules.contains('restaurant')) {
      roles.addAll(['WAITER', 'CHEF', 'DELIVERY']);
    }
    
    if (enabledModules.contains('services')) {
      roles.addAll(['RECEPTIONIST', 'SERVICE_PROVIDER']);
    }
    
    roles.add('CUSTOM'); // Custom always available
    return roles;
  }

  /// Get role icon (for UI)
  static String getRoleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return '👑';
      case 'ADMIN':
      case 'MANAGER':
        return '👤';
      case 'STAFF':
      case 'CASHIER':
        return '💰';
      case 'STOCKER':
      case 'INVENTORY_CLERK':
        return '📦';
      case 'SHIFT_SUPERVISOR':
      case 'SUPERVISOR':
        return '👥';
      case 'INVENTORY_MANAGER':
        return '📊';
      // Restaurant roles
      case 'WAITER':
        return '🍽️';
      case 'CHEF':
        return '👨‍🍳';
      // Services roles
      case 'RECEPTIONIST':
        return '📞';
      case 'SERVICE_PROVIDER':
        return '✂️';
      // Delivery role
      case 'DELIVERY':
        return '🛵';
      case 'CUSTOM':
        return '⚙️';
      default:
        return '👤';
    }
  }

  /// Get role description
  static String getRoleDescription(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return 'Full access to all features and settings';
      case 'ADMIN':
      case 'MANAGER':
        return 'Manage operations, inventory, and view reports';
      case 'STAFF':
      case 'CASHIER':
        return 'Process sales, handle customers, perform cash counts';
      case 'STOCKER':
      case 'INVENTORY_CLERK':
        return 'Receive stock, restock shelves, update inventory';
      case 'SHIFT_SUPERVISOR':
      case 'SUPERVISOR':
        return 'Supervise cashiers, handle refunds, view daily reports';
      case 'INVENTORY_MANAGER':
        return 'Full inventory control, ordering, and stock management';
      // Restaurant roles
      case 'WAITER':
        return 'Take orders, serve tables, process payments';
      case 'CHEF':
        return 'View kitchen queue, mark orders ready';
      // Services roles
      case 'RECEPTIONIST':
        return 'Book appointments, manage schedule, handle check-in';
      case 'SERVICE_PROVIDER':
        return 'View own schedule, mark services complete';
      // Delivery role
      case 'DELIVERY':
        return 'View takeaway orders, mark them as delivered';
      case 'CUSTOM':
        return 'Custom permissions defined by owner';
      default:
        return 'Team member';
    }
  }
}
