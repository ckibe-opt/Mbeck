import 'package:mbeck_go/services/database_service.dart';

class CreditService {
  static final CreditService instance = CreditService._init();
  final _db = DatabaseService.instance.db;

  CreditService._init();

  /// Calculate the "Purchase Power Score" (0-850)
  /// Based on:
  /// - Frequency (Consistency)
  /// - Volume (Total Spend)
  /// - Diversity (Unique Shops)
  Future<int> calculateScore() async {
    final receipts = await _db.select(_db.receipts).get();
    
    if (receipts.isEmpty) return 300; // Base score for new users

    double score = 300;

    // 1. Volume: +1 point per 1000 KES
    final totalSpent = receipts.fold<int>(0, (sum, r) => sum + r.totalAmount);
    score += (totalSpent / 1000);

    // 2. Frequency: +5 points per unique week active
    final uniqueWeeks = receipts.map((r) {
      // Key: "2026-05" (Week number) - simplified logic
      final d = r.timestamp;
      return '${d.year}-${_getWeekOfYear(d)}';
    }).toSet().length;
    
    score += (uniqueWeeks * 5);

    // 3. Diversity: +10 points per unique shop
    final uniqueShops = receipts.map((r) => r.sellerId).toSet().length;
    score += (uniqueShops * 10);

    // TODO: Add penalty for failed payments (requires transaction log)

    // Cap at 850
    if (score > 850) score = 850;
    
    return score.toInt();
  }
  
  int _getWeekOfYear(DateTime date) {
    final dayOfYear = int.parse(
        "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}"); // Simplified hash
    return (dayOfYear / 7).floor(); 
  }

  String getLevel(int score) {
    if (score < 500) return 'Starter';
    if (score < 650) return 'Standard';
    if (score < 750) return 'Silver';
    return 'Gold';
  }
}
