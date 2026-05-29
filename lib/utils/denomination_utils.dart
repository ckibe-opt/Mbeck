// lib/utils/denomination_utils.dart
int computeDenominationTotal(Map<String,int> counts) {
  int total = 0;
  counts.forEach((denomStr, qty) {
    final denom = int.tryParse(denomStr) ?? 0;
    total += denom * (qty);
  });
  return total;
}
