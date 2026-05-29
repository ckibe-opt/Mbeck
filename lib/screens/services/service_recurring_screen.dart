import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class ServiceRecurringScreen extends StatefulWidget {
  const ServiceRecurringScreen({super.key});

  @override
  State<ServiceRecurringScreen> createState() => _ServiceRecurringScreenState();
}

class _ServiceRecurringScreenState extends State<ServiceRecurringScreen> {
  List<Map<String, dynamic>> _recurringSeries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecurringSeries();
  }

  Future<void> _loadRecurringSeries() async {
    try {
      final db = await DbProvider.db;
      final series = await db.rawQuery('''
        SELECT b.id, b.customer_name, b.start_time, b.end_time, b.recurrence_rule,
               c.name as service_name
        FROM services_bookings b
        JOIN services_catalog c ON b.service_id = c.id
        WHERE b.recurrence_rule IS NOT NULL
        ORDER BY b.start_time DESC
      ''');
      
      if (mounted) {
        setState(() {
          _recurringSeries = List.from(series);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recurring series: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearRecurrence(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text('Are you sure you want to cancel the recurring nature of this series? The initial booking will remain isolated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Recurrence', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DbProvider.db;
      await db.update('services_bookings', {'recurrence_rule': null}, where: 'id = ?', whereArgs: [id]);
      _loadRecurringSeries();
    }
  }

  String _formatRRULE(String rrule) {
    if (rrule.contains('FREQ=DAILY')) return 'Daily Subscription';
    if (rrule.contains('FREQ=WEEKLY')) return 'Weekly Subscription';
    if (rrule.contains('FREQ=MONTHLY')) return 'Monthly Subscription';
    return 'Custom Recurring Subscription';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Recurring Bookings', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _recurringSeries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_repeat, size: 64, color: AppColors.gray300),
                      const SizedBox(height: 16),
                      Text('No Active Subscriptions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      const SizedBox(height: 8),
                      Text('Schedule an appointment on the Calendar\nand toggle repetition to create a recurring series.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recurringSeries.length,
                  itemBuilder: (context, index) {
                    final series = _recurringSeries[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(series['start_time']);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.success.withOpacity(0.1),
                          child: Icon(Icons.autorenew, color: AppColors.success),
                        ),
                        title: Text('${series['customer_name'] ?? 'Walk-in'} - ${series['service_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Started: ${DateFormat.yMd().format(date)}', style: TextStyle(color: AppColors.gray600)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(_formatRRULE(series['recurrence_rule']), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _clearRecurrence(series['id']),
                          tooltip: 'Cancel Subscription',
                        ),
                      ),
                    );
                  },
                ),
          const InteractiveHelpScroll(contextKey: 'services_recurring'),
        ],
      ),
    );
  }
}
