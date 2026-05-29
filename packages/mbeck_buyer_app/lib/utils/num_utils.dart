/// Safe numeric parsing utilities for the Mbeck Buyer App.
///
/// The cloud API (Supabase JSON over HTTP) may return numeric fields as
/// Strings instead of [num] depending on the Postgres column type and the
/// PostgREST serializer version. These helpers prevent [TypeError] crashes
/// by accepting either a [num] or a [String] and parsing gracefully.

/// Converts [v] to a [double]. Accepts [num] or [String].
/// Returns [fallback] (default 0.0) when [v] is null or unparseable.
double toDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

/// Converts [v] to an [int]. Accepts [num] or [String].
/// Returns [fallback] (default 0) when [v] is null or unparseable.
int toInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

/// Converts [v] to an [int] or null. Accepts [num] or [String].
int? toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Converts [v] to a [double] or null. Accepts [num] or [String].
double? toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
