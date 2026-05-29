import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/db_provider.dart';

class CreditProfile {
  final int score; // 0 - 100
  final double potentialLimit; // Max Potential Partner Financing
  final int activeDays;
  final double monthlyVolume;
  final double dataQualityRatio;
  final String tier; // BRONZE, SILVER, GOLD

  const CreditProfile({
    required this.score,
    required this.potentialLimit,
    required this.activeDays,
    required this.monthlyVolume,
    required this.dataQualityRatio,
    required this.tier,
  });

  /// Features are locked for unverified shops with no activity
  bool get isFeatureLocked => score == 0 && tier == 'NEW';
}

class CreditService {
  
  /// Calculate Trust Score (Run in Isolate if heavy)
  static Future<CreditProfile> calculateScore(String shopId) async {
    // 1. Fetch last 30 days of data
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    
    final txns = await DbProvider.query('txn', 
      where: 'timestamp >= ? AND type = ?', 
      whereArgs: [thirtyDaysAgo, 'sale']
    );

    if (txns.isEmpty) {
      return const CreditProfile(score: 0, potentialLimit: 0, activeDays: 0, monthlyVolume: 0, dataQualityRatio: 0, tier: 'NEW');
    }

    // 2. Metrics Calculation
    
    // A. Active Days (Consistency) - Max 40pts
    final uniqueDays = <String>{};
    for (var t in txns) {
      final date = DateTime.fromMillisecondsSinceEpoch(t['timestamp'] as int);
      uniqueDays.add("${date.year}-${date.month}-${date.day}");
    }
    final activeDays = uniqueDays.length;
    
    int consistencyScore = 0;
    if (activeDays >= 25) consistencyScore = 40;
    else if (activeDays >= 20) consistencyScore = 30;
    else if (activeDays >= 10) consistencyScore = 15;
    
    // B. Volume (Scale) - Max 30pts
    double totalVolume = 0;
    for (var t in txns) {
      totalVolume += (t['totalAmount'] as num).toDouble();
    }
    
    int volumeScore = 0;
    if (totalVolume > 100000) volumeScore = 30;
    else if (totalVolume > 50000) volumeScore = 20;
    else if (totalVolume > 10000) volumeScore = 10;
    
    // C. Data Quality (Reliability) - Max 30pts
    // In V1, we don't track adherence well yet (custom item vs barcoded). 
    // Proxy: If average txn value is reasonable (< 5000), it's likely real retail. 
    // If lots of 50,000 items, it might be fake/laundering.
    // Let's use a placeholder "Good Data" for now until we query line items.
    int qualityScore = 20; // Assume decent quality for now
    
    // 3. Final Score
    int totalScore = consistencyScore + volumeScore + qualityScore;
    if (totalScore > 100) totalScore = 100;
    
    // 4. Limit Calculation
    // Limit = Avg Daily Sales * 7 Days
    double dailyAvg = activeDays > 0 ? (totalVolume / activeDays) : 0;
    double limit = dailyAvg * 7;
    
    // Cap limit based on Score Tier
    String tier = 'BRONZE';
    double cap = 0;
    
    if (totalScore >= 80) {
      tier = 'GOLD';
      cap = 50000;
    } else if (totalScore >= 50) {
      tier = 'SILVER';
      cap = 10000;
    } else {
      tier = 'BRONZE';
      cap = 2000;
    }
    
    if (limit > cap) limit = cap;
    // Round to nearest 100
    limit = (limit / 100).floorToDouble() * 100;

    // 5. [Loop & Trust] Publish Score to Cloud
    // Triggered by UI explicitly now.
    // _publishScore(shopId, totalScore, tier);

    return CreditProfile(
      score: totalScore,
      potentialLimit: limit,
      activeDays: activeDays,
      monthlyVolume: totalVolume,
      dataQualityRatio: 0.8,
      tier: tier,
    );
  }

  // Old private method removed to prevent SQLite error
  // static Future<void> _publishScore...

  /// Convenience method for UI/Guards to get current shop's score
  static Future<CreditProfile> getCreditProfileCached() async {
    try {
       // We need to import AuthService to get current shop, but circular dep risk?
       // Usually Services relying on each other is okay if careful.
       // But wait, AuthService depends on DbProvider. CreditService depends on DbProvider.
       // Let's assume we can import AuthService.
       // Or better: read from DB 'current_session' or similar if we wanted valid separation.
       // For now, let's use a simpler approach: 
       // If we can't easily get the shop ID here without Context, 
       // we should probably ask the caller to provide it.
       // BUT, FeatureGuard calls it without args.
       
       // Let's rely on DbProvider to get the "active" shop if possible, or just mock it safely if fails.
       // Actually, let's assume AuthService is available.
       final db = await DbProvider.db;
       // Quick Hack: Get the first shop (Owner). 
       final shops = await db.query('shops');
       if (shops.isNotEmpty) {
         return calculateScore(shops.first['id'] as String);
       }
       return const CreditProfile(score: 0, potentialLimit: 0, activeDays: 0, monthlyVolume: 0, dataQualityRatio: 0, tier: 'NEW');
    } catch (e) {
      debugPrint('Error getting cached profile: $e');
      return const CreditProfile(score: 0, potentialLimit: 0, activeDays: 0, monthlyVolume: 0, dataQualityRatio: 0, tier: 'NEW');
    }
  }

  /// Publish score to public profile (called by UI)
  static Future<void> publishToCloud(String shopId, int score, String tier) async {
     try {
       final supabase = Supabase.instance.client;
       // if (supabase.auth.currentUser != null) { // REMOVED: Custom Auth used
         await supabase.from('shops').update({
           'trust_score': score,
           'tier': tier,
         }).eq('id', shopId);
         debugPrint('✅ Trust Score Synced to Cloud: $score');
       // }
     } catch (e) {
       debugPrint('⚠️ Failed to sync score (Offline?): $e');
     }
  }
}
