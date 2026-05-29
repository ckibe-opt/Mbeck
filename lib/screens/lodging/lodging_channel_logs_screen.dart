import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class LodgingChannelLogsScreen extends StatefulWidget {
  const LodgingChannelLogsScreen({super.key});

  @override
  State<LodgingChannelLogsScreen> createState() => _LodgingChannelLogsScreenState();
}

class _LodgingChannelLogsScreenState extends State<LodgingChannelLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; 

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final db = await DbProvider.db;
      
      String query = '''
        SELECT l.*, r.room_number, r.type as room_type
        FROM lodging_channel_logs l
        LEFT JOIN lodging_rooms r ON l.room_id = r.id
      ''';
      
      List<Object?> whereArgs = [];
      if (_filterStatus != 'all') {
        query += " WHERE l.status = ?";
        whereArgs.add(_filterStatus);
      }
      
      query += " ORDER BY l.synced_at DESC LIMIT 100";
      
      final logsData = await db.rawQuery(query, whereArgs);
      
      if (mounted) {
        setState(() {
          _logs = List.from(logsData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading channel logs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPayloadDetails(String payload) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Webhook Payload', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Text(
            payload, 
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12)
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Logs?'),
        content: const Text('This will permanently delete all channel sync history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final db = await DbProvider.db;
        await db.delete('lodging_channel_logs');
        _loadLogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logs cleared successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Channel Sync Logs', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Success', 'success'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Failed', 'failed'),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sync_disabled, size: 64, color: AppColors.gray300),
                            const SizedBox(height: 16),
                            Text('No Sync Logs Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                            const SizedBox(height: 8),
                            Text('Events triggered by check-ins, check-outs, or\nreservation updates will appear here to push to OTAs.',
                                textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final eventType = log['event_type'] as String;
                          final status = log['status'] as String;
                          final timestamp = DateTime.fromMillisecondsSinceEpoch(log['synced_at'] as int);
                          final roomName = log['room_number'] != null ? '${log['room_number']} (${log['room_type']})' : 'Unknown Room';
                          
                          Color statusColor = AppColors.gray500;
                          IconData statusIcon = Icons.hourglass_empty;
                          if (status == 'success') {
                            statusColor = AppColors.primaryGreen;
                            statusIcon = Icons.check_circle;
                          } else if (status == 'failed') {
                            statusColor = Colors.red;
                            statusIcon = Icons.error;
                          } else if (status == 'pending') {
                            statusColor = Colors.orange;
                            statusIcon = Icons.schedule;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.1),
                                child: Icon(statusIcon, color: statusColor, size: 20),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(eventType.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                  Text(DateFormat('MMM d, h:mm a').format(timestamp), style: TextStyle(color: AppColors.gray500, fontSize: 12)),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Room trigger: $roomName', style: TextStyle(color: AppColors.gray700, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => _showPayloadDetails(log['payload']),
                                      child: Text(
                                        'View JSON Payload',
                                        style: TextStyle(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      const InteractiveHelpScroll(contextKey: 'lodging_channel_logs'),
      ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
          _isLoading = true;
        });
        _loadLogs();
      },
      selectedColor: AppColors.primaryGreen.withOpacity(0.2),
      checkmarkColor: AppColors.primaryGreen,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryGreen : AppColors.gray700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: AppColors.gray100,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
