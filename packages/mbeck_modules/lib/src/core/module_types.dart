/// Module type enumeration for Mbeck business verticals.
/// 
/// Each type represents a distinct business model with its own
/// screens, services, and data models.
enum ModuleType {
  /// Product-based retail (current Mbeck implementation)
  /// Features: Inventory, Stock management
  retail('retail', 'Retail & Inventory'),

  /// Service-based businesses (appointments, bookings)
  /// Features: Service catalog, Calendar, Bookings
  services('services', 'Services & Bookings'),

  /// Food service with kitchen workflow
  /// Features: Menu, Orders, Kitchen display, Table management
  restaurant('restaurant', 'Restaurant & Food'),

  /// Session-based entertainment (pool tables, PS rooms, swimming, etc.)
  /// Features: Asset registry, timer billing, live sessions, walk-in queue
  entertainment('entertainment', 'Entertainment & Sessions'),

  /// Accommodation / lodging (hotels, guesthouses, Airbnb, hostels)
  /// Features: Room registry, reservations, check-in/out, housekeeping
  lodging('lodging', 'Lodging & Accommodation'),
  ;

  const ModuleType(this.id, this.displayName);

  /// Machine-readable identifier (used in DB and API)
  final String id;

  /// Human-readable name for UI
  final String displayName;

  /// Get ModuleType from string ID
  static ModuleType? fromId(String id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}
