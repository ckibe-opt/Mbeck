import 'dart:async';
import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class EntertainmentPrepaidScreen extends StatefulWidget {
  const EntertainmentPrepaidScreen({super.key});

  @override
  State<EntertainmentPrepaidScreen> createState() => _EntertainmentPrepaidScreenState();
}

class _EntertainmentPrepaidScreenState extends State<EntertainmentPrepaidScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadSessions());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final db = await DbProvider.db;
      final sessions = await db.rawQuery('''
        SELECT s.*, a.name as asset_name 
        FROM entertainment_sessions s 
        JOIN entertainment_assets a ON s.asset_id = a.id 
        WHERE s.status IN ('active', 'paused')
        ORDER BY s.started_at DESC
      ''');
      
      if (mounted) {
        setState(() {
          _sessions = List.from(sessions);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSetLimitModal(Map<String, dynamic> session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SetLimitSheet(
        session: session,
        onSave: () {
          Navigator.pop(context);
          _loadSessions();
        },
      ),
    );
  }

  void _removeLimit(int sessionId) async {
    final db = await DbProvider.db;
    await db.update('entertainment_sessions', {'max_duration_seconds': null}, where: 'id = ?', whereArgs: [sessionId]);
    _loadSessions();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Pre-paid Limits', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading && _sessions.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_off_outlined, size: 64, color: AppColors.gray300),
                          const SizedBox(height: 16),
                          Text('No Active Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                          const SizedBox(height: 8),
                          Text('Start a session from the Dashboard first\nto assign Pre-paid limits.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final maxDuration = session['max_duration_seconds'] as int?;
                        
                        final start = session['started_at'] as int;
                        final totalPaused = session['total_paused_seconds'] as int? ?? 0;
                        final lastPaused = session['last_paused_at'] as int?;
                        
                        int currentPaused = totalPaused;
                        if (session['status'] == 'paused' && lastPaused != null) {
                          currentPaused += ((DateTime.now().millisecondsSinceEpoch - lastPaused) / 1000).floor();
                        }
                        
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final totalActiveSecs = ((now - start) / 1000).floor() - currentPaused;
                        
                        final hasLimit = maxDuration != null;
                        final isExpired = hasLimit && totalActiveSecs >= maxDuration;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isExpired ? Colors.red.withOpacity(0.5) : AppColors.gray200, width: isExpired ? 2 : 1),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(session['asset_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (isExpired)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: const Text('TIME UP', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Customer: ${session['customer_name'] ?? 'Walk-in'}', style: TextStyle(color: AppColors.gray700)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.play_circle_outline, size: 16, color: AppColors.gray500),
                                      const SizedBox(width: 4),
                                      Text('Running: ${_formatDuration(totalActiveSecs)}', style: TextStyle(color: AppColors.gray800, fontWeight: FontWeight.w500)),
                                      const Spacer(),
                                      if (hasLimit) ...[
                                        Icon(Icons.timer_off, size: 16, color: isExpired ? Colors.red : AppColors.primaryGreen),
                                        const SizedBox(width: 4),
                                        Text('Limit: ${_formatDuration(maxDuration)}', style: TextStyle(color: isExpired ? Colors.red : AppColors.gray800, fontWeight: FontWeight.bold)),
                                      ] else ...[
                                        const Text('Open Session', style: TextStyle(color: AppColors.gray500, fontStyle: FontStyle.italic)),
                                      ]
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'set') _showSetLimitModal(session);
                                if (val == 'remove') _removeLimit(session['id']);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'set', child: Text('Set/Update Limit')),
                                if (hasLimit) const PopupMenuItem(value: 'remove', child: Text('Remove Limit', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          const InteractiveHelpScroll(contextKey: 'entertainment_prepaid'),
        ],
      ),
    );
  }
}

class _SetLimitSheet extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback onSave;

  const _SetLimitSheet({required this.session, required this.onSave});

  @override
  State<_SetLimitSheet> createState() => _SetLimitSheetState();
}

class _SetLimitSheetState extends State<_SetLimitSheet> {
  final _hoursCtrl = TextEditingController(text: '0');
  final _minsCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    final maxDuration = widget.session['max_duration_seconds'] as int?;
    if (maxDuration != null) {
      _hoursCtrl.text = (maxDuration ~/ 3600).toString();
      _minsCtrl.text = ((maxDuration % 3600) ~/ 60).toString();
    }
  }

  Future<void> _save() async {
    final hours = int.tryParse(_hoursCtrl.text) ?? 0;
    final mins = int.tryParse(_minsCtrl.text) ?? 0;
    
    if (hours == 0 && mins == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid duration.')));
      return;
    }

    final totalSeconds = (hours * 3600) + (mins * 60);
    final db = await DbProvider.db;
    
    await db.update(
      'entertainment_sessions', 
      {'max_duration_seconds': totalSeconds}, 
      where: 'id = ?', 
      whereArgs: [widget.session['id']]
    );
    
    widget.onSave();
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _minsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Set Pre-paid Time Limit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Session will automatically flag as expired once the limit is reached.', style: TextStyle(color: AppColors.gray500, fontSize: 13)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hoursCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Hours', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _minsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutes', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _save,
              child: const Text('Apply Pre-paid Limit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
