import 'dart:async';
import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class EntertainmentPauseScreen extends StatefulWidget {
  const EntertainmentPauseScreen({super.key});

  @override
  State<EntertainmentPauseScreen> createState() => _EntertainmentPauseScreenState();
}

class _EntertainmentPauseScreenState extends State<EntertainmentPauseScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadSessions());
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

  Future<void> _togglePause(Map<String, dynamic> session) async {
    final db = await DbProvider.db;
    final id = session['id'];
    final status = session['status'];
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (status == 'active') {
      // Pause it
      await db.update('entertainment_sessions', {
        'status': 'paused',
        'last_paused_at': now,
      }, where: 'id = ?', whereArgs: [id]);
    } else {
      // Resume it
      final lastPausedAt = session['last_paused_at'] as int? ?? now;
      final totalPaused = session['total_paused_seconds'] as int? ?? 0;
      final addPaused = ((now - lastPausedAt) / 1000).floor();
      
      await db.update('entertainment_sessions', {
        'status': 'active',
        'total_paused_seconds': totalPaused + addPaused,
        'last_paused_at': null,
      }, where: 'id = ?', whereArgs: [id]);
    }
    
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
        title: const Text('Session Pausing', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
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
                          Icon(Icons.pause_circle_outline, size: 64, color: AppColors.gray300),
                          const SizedBox(height: 16),
                          Text('No Active Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                          const SizedBox(height: 8),
                          Text('Start a session from the Dashboard first\nbefore pausing or resuming it here.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final isPaused = session['status'] == 'paused';
                        
                        final start = session['started_at'] as int;
                        final totalPaused = session['total_paused_seconds'] as int? ?? 0;
                        final lastPaused = session['last_paused_at'] as int?;
                        
                        int currentPaused = totalPaused;
                        if (isPaused && lastPaused != null) {
                          currentPaused += ((DateTime.now().millisecondsSinceEpoch - lastPaused) / 1000).floor();
                        }
                        
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final totalActiveSecs = ((now - start) / 1000).floor() - currentPaused;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isPaused ? AppColors.gray50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isPaused ? Colors.orange.withOpacity(0.5) : AppColors.gray200, width: isPaused ? 2 : 1),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Row(
                              children: [
                                Text(session['asset_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Spacer(),
                                if (isPaused)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                    child: const Text('PAUSED', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Customer: ${session['customer_name'] ?? 'Walk-in'}', style: TextStyle(color: AppColors.gray700)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.timer, size: 14, color: AppColors.primaryGreen),
                                      const SizedBox(width: 4),
                                      Text('Active: ${_formatDuration(totalActiveSecs)}', style: TextStyle(color: AppColors.gray800, fontWeight: FontWeight.w500)),
                                      const SizedBox(width: 16),
                                      Icon(Icons.pause, size: 14, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text('Paused: ${_formatDuration(currentPaused)}', style: TextStyle(color: AppColors.gray800, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            trailing: FloatingActionButton.extended(
                              heroTag: 'pause_${session['id']}',
                              backgroundColor: isPaused ? AppColors.primaryGreen : Colors.orange,
                              elevation: 0,
                              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 18),
                              label: Text(isPaused ? 'Resume' : 'Pause', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () => _togglePause(session),
                            ),
                          ),
                        );
                      },
                    ),
          const InteractiveHelpScroll(contextKey: 'entertainment_pause'),
        ],
      ),
    );
  }
}
