import 'package:flutter/foundation.dart';

/// PerformanceMonitor - Singleton service for tracking application performance
class PerformanceMonitor {
  // Singleton instance
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  // Storage for active traces
  final Map<String, int> _activeTraces = {};
  
  // Storage for completed metrics
  // Map<Category, Map<MetricName, List<Value>>>
  final Map<String, List<int>> _durations = {};
  final Map<String, List<dynamic>> _customMetrics = {};

  /// Start a performance trace
  /// Returns a trace ID that can be used to end the trace specifically,
  /// though usually just calling endTrace with the same name is sufficient for
  /// non-overlapping serial flows.
  void startTrace(String name) {
    if (_activeTraces.containsKey(name)) {
      debugPrint('⚠️ PerformanceMonitor: Trace "$name" already started. Overwriting start time.');
    }
    _activeTraces[name] = DateTime.now().millisecondsSinceEpoch;
  }

  /// End a performance trace and record the duration
  /// Returns the duration in milliseconds, or -1 if trace was not found
  int endTrace(String name, {Map<String, dynamic>? metadata}) {
    if (!_activeTraces.containsKey(name)) {
      debugPrint('⚠️ PerformanceMonitor: Trace "$name" not found.');
      return -1;
    }

    final startTime = _activeTraces.remove(name)!;
    final endTime = DateTime.now().millisecondsSinceEpoch;
    final duration = endTime - startTime;

    _recordDuration(name, duration);
    
    if (metadata != null) {
      debugPrint('⏱️ Perf: $name = ${duration}ms | $metadata');
    } else {
      debugPrint('⏱️ Perf: $name = ${duration}ms');
    }

    return duration;
  }

  /// Record a custom metric value
  void addMetric(String name, dynamic value) {
    if (!_customMetrics.containsKey(name)) {
      _customMetrics[name] = [];
    }
    _customMetrics[name]!.add(value);
  }
  
  void _recordDuration(String name, int duration) {
    if (!_durations.containsKey(name)) {
      _durations[name] = [];
    }
    _durations[name]!.add(duration);
  }

  /// Get a summary report of all recorded metrics
  Map<String, dynamic> getReport() {
    final report = <String, dynamic>{};
    
    // Calculate stats for durations
    _durations.forEach((name, values) {
      if (values.isEmpty) return;
      
      values.sort();
      final min = values.first;
      final max = values.last;
      final avg = values.reduce((a, b) => a + b) / values.length;
      final p50 = values[(values.length * 0.5).floor()];
      final p95 = values[(values.length * 0.95).floor()];
      
      report[name] = {
        'count': values.length,
        'min_ms': min,
        'max_ms': max,
        'avg_ms': avg.toStringAsFixed(2),
        'p50_ms': p50,
        'p95_ms': p95,
      };
    });

    report['custom_metrics'] = _customMetrics;
    
    return report;
  }

  /// Clear all collected metrics
  void clear() {
    _activeTraces.clear();
    _durations.clear();
    _customMetrics.clear();
  }
}
