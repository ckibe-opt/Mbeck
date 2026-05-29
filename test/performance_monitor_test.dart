import 'package:flutter_test/flutter_test.dart';
import 'package:mbeck_business/services/performance_monitor.dart'; // Adjust package name if needed

void main() {
  test('PerformanceMonitor traces duration correctly', () async {
    final monitor = PerformanceMonitor();
    
    monitor.startTrace('test_trace');
    await Future.delayed(const Duration(milliseconds: 100));
    final duration = monitor.endTrace('test_trace');
    
    expect(duration, greaterThanOrEqualTo(90)); // Allow some tolerance
    expect(duration, lessThan(200));
  });

  test('PerformanceMonitor handles missing traces gracefully', () {
    final monitor = PerformanceMonitor();
    final duration = monitor.endTrace('non_existent_trace');
    expect(duration, equals(-1));
  });
  
  test('PerformanceMonitor generates report correctly', () {
    final monitor = PerformanceMonitor();
    monitor.clear();
    
    monitor.startTrace('trace_1');
    monitor.endTrace('trace_1');
    
    monitor.addMetric('test_metric', 42);
    
    final report = monitor.getReport();
    expect(report.containsKey('trace_1'), isTrue);
    expect(report['custom_metrics']['test_metric'], contains(42));
  });
}
