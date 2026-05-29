import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _formatter = NumberFormat('#,###');

  /// Formats a number with comma separators.
  /// Example: 30000 -> "30,000"
  static String format(num amount) {
    return _formatter.format(amount);
  }

  /// Formats a number with currency prefix.
  /// Example: 30000 -> "KES 30,000"
  static String formatWithCurrency(num amount, {String currency = 'KES'}) {
    return '$currency ${format(amount)}';
  }
}
