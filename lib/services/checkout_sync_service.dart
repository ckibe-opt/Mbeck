import 'dart:async';

enum CheckoutStatus {
  idle,
  awaiting_process, // Seller has scanned buyer's QR
  completed,        // Seller has saved the transaction
  acknowledged,     // Buyer has received the receipt
}

class CheckoutSyncService {
  static final CheckoutSyncService _instance = CheckoutSyncService._internal();
  factory CheckoutSyncService() => _instance;
  CheckoutSyncService._internal();

  final _statusController = StreamController<CheckoutStatus>.broadcast();
  Stream<CheckoutStatus> get statusStream => _statusController.stream;

  CheckoutStatus _status = CheckoutStatus.idle;
  Map<String, dynamic>? _lastReceipt;

  CheckoutStatus get status => _status;
  Map<String, dynamic>? get lastReceipt => _lastReceipt;

  void updateStatus(CheckoutStatus newStatus, {Map<String, dynamic>? receipt}) {
    _status = newStatus;
    if (receipt != null) {
      _lastReceipt = receipt;
    }
    _statusController.add(newStatus);
  }

  void reset() {
    _status = CheckoutStatus.idle;
    _lastReceipt = null;
  }
}
