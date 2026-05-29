import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/entertainment_service.dart';
import '../../theme/design_system.dart';
import '../../widgets/standard_app_bar.dart';
import '../../widgets/interactive_help_scroll.dart';
import 'asset_management_screen.dart';

/// Live Sessions Dashboard — the main screen for the entertainment module.
///
/// Shows a real-time board of all assets with their current status:
/// - FREE (green) — tap to start a new session
/// - IN USE (orange) — shows active session count, running cost; tap to manage
///
/// Supports multiple concurrent sessions per asset (e.g., swimming pool
/// can have many swimmers at once).
///
/// Auto-refreshes every 30 seconds to keep timers accurate.
class SessionsDashboardScreen extends StatefulWidget {
  const SessionsDashboardScreen({super.key});

  @override
  State<SessionsDashboardScreen> createState() =>
      _SessionsDashboardScreenState();
}

class _SessionsDashboardScreenState extends State<SessionsDashboardScreen> {
  List<Map<String, dynamic>> _board = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  double _todayRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadBoard();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadBoard();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBoard() async {
    try {
      final board = await EntertainmentService.getAssetStatusBoard();
      final revenue = await EntertainmentService.getTodayRevenue();

      if (mounted) {
        setState(() {
          _board = board;
          _todayRevenue = revenue;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading session board: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Start Session ───────────────────────────────────────────────

  void _startSession(Map<String, dynamic> asset) {
    final customerController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_categoryIcon(asset['category'] as String),
                    color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Customer',
                          style: AppTypography.textTheme.titleLarge),
                      Text(asset['name'] as String,
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_money,
                      size: 18, color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Text(_formatRate(asset),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen)),
                  const Spacer(),
                  // Show current occupancy
                  if ((asset['active_count'] as int? ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${asset['active_count']} active',
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: customerController,
              decoration: const InputDecoration(
                labelText: 'Customer Name (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await EntertainmentService.startSession(
                    assetId: asset['id'] as int,
                    customerName: customerController.text.trim().isNotEmpty
                        ? customerController.text.trim()
                        : null,
                    notes: notesController.text.trim().isNotEmpty
                        ? notesController.text.trim()
                        : null,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadBoard();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Session started on ${asset['name']}'),
                      backgroundColor: AppColors.primaryGreen,
                    ));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red));
                  }
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Session'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      customerController.dispose();
      notesController.dispose();
    });
  }

  // ─── Manage Sessions (drill-down for multi-session assets) ───────

  void _showSessionManager(Map<String, dynamic> asset) {
    final assetId = asset['id'] as int;
    final assetName = asset['name'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SessionManagerSheet(
        assetId: assetId,
        assetName: assetName,
        asset: asset,
        onChanged: () => _loadBoard(),
        onAddSession: () => _startSession(asset),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(
        title: 'Sessions',
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Manage Assets',
            onPressed: () {
              Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AssetManagementScreen()),
              ).then((_) => _loadBoard());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBoard,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _board.isEmpty
                  ? _buildEmptyState()
                  : _buildBoard(),
          const InteractiveHelpScroll(contextKey: 'entertainment_sessions'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_esports_outlined,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No assets configured',
                style: AppTypography.textTheme.titleMedium
                    ?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            const Text(
              'Add your pool tables, gaming stations, or other entertainment assets to get started.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AssetManagementScreen()),
                ).then((_) => _loadBoard());
              },
              icon: const Icon(Icons.add),
              label: const Text('Set Up Assets'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _board) {
      final cat = item['category'] as String;
      grouped.putIfAbsent(cat, () => []);
      grouped[cat]!.add(item);
    }

    // Total active sessions across all assets
    int totalActiveSessions = 0;
    int occupiedAssets = 0;
    for (final item in _board) {
      final count = (item['active_count'] as int?) ?? 0;
      totalActiveSessions += count;
      if (count > 0) occupiedAssets++;
    }

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.primaryGreen.withOpacity(0.05),
          child: Row(
            children: [
              _statChip(
                icon: Icons.people,
                label: 'Sessions',
                value: '$totalActiveSessions',
                color: Colors.orange,
              ),
              const SizedBox(width: 16),
              _statChip(
                icon: Icons.check_circle,
                label: 'Free',
                value: '${_board.length - occupiedAssets}',
                color: AppColors.primaryGreen,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Today's Revenue",
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                  Text(
                    'KSH ${_todayRevenue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Asset grid
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBoard,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(_categoryIcon(entry.key),
                              size: 18, color: AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          Text(
                            entry.key.toUpperCase(),
                            style: AppTypography.textTheme.labelLarge
                                ?.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.15,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: entry.value.length,
                      itemBuilder: (ctx, index) =>
                          _buildAssetCard(entry.value[index]),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> item) {
    final assetName = item['name'] as String;
    final activeCount = (item['active_count'] as int?) ?? 0;
    final isOccupied = activeCount > 0;

    if (isOccupied) {
      final earliestStart = item['earliest_start'] as int?;
      final duration = earliestStart != null
          ? EntertainmentService.formatDuration(earliestStart)
          : '—';

      return GestureDetector(
        onTap: () => _showSessionManager(item),
        onLongPress: () => _startSession(item), // long-press to add another
        child: Card(
          color: Colors.orange.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange.shade300, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.play_circle_filled,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(assetName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const Spacer(),
                // Show session count prominently
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$activeCount',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        activeCount == 1 ? 'user' : 'users',
                        style: TextStyle(
                            fontSize: 13, color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Since $duration ago',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // FREE asset
    return GestureDetector(
      onTap: () => _startSession(item),
      child: Card(
        color: Colors.green.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(assetName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Text('FREE',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700)),
              ),
              const Spacer(),
              Center(
                child: Text(_formatRate(item),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$value $label',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: color, fontSize: 13)),
      ],
    );
  }

  String _formatRate(Map<String, dynamic> asset) {
    final assetType = asset['asset_type'] as String;
    if (assetType == 'flat') {
      final rate = (asset['flat_rate'] as num).toDouble();
      return 'KSH ${rate.toStringAsFixed(0)}/entry';
    }
    final rate = (asset['rate_per_hour'] as num).toDouble();
    return 'KSH ${rate.toStringAsFixed(0)}/hr';
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'pool':
        return Icons.sports_bar;
      case 'gaming':
        return Icons.sports_esports;
      case 'swimming':
        return Icons.pool;
      case 'karaoke':
        return Icons.mic;
      case 'bowling':
        return Icons.sports_cricket;
      case 'vr':
        return Icons.vrpano;
      default:
        return Icons.attractions;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Session Manager Sheet — drill-down for an asset with active sessions
// ═══════════════════════════════════════════════════════════════════════════

class _SessionManagerSheet extends StatefulWidget {
  final int assetId;
  final String assetName;
  final Map<String, dynamic> asset;
  final VoidCallback onChanged;
  final VoidCallback? onAddSession;

  const _SessionManagerSheet({
    required this.assetId,
    required this.assetName,
    required this.asset,
    required this.onChanged,
    this.onAddSession,
  });

  @override
  State<_SessionManagerSheet> createState() => _SessionManagerSheetState();
}

class _SessionManagerSheetState extends State<_SessionManagerSheet> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions =
        await EntertainmentService.getActiveSessionsForAsset(widget.assetId);
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  Future<void> _stopOne(int sessionId) async {
    try {
      final result = await EntertainmentService.stopSession(sessionId);
      widget.onChanged();
      await _loadSessions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${widget.assetName}: KSH ${(result['total_amount'] as double).toStringAsFixed(0)} '
            '(${result['duration_minutes']}min)',
          ),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 4),
        ));
      }

      // Close sheet if no more active sessions
      if (_sessions.isEmpty && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _stopAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End All Sessions?'),
        content: Text(
            'This will bill and close all ${_sessions.length} active sessions on ${widget.assetName}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final results = await EntertainmentService.stopAllSessionsForAsset(
            widget.assetId);
        final totalBilled =
            results.fold<double>(0, (sum, r) => sum + (r['total_amount'] as double));
        widget.onChanged();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${results.length} sessions ended — Total: KSH ${totalBilled.toStringAsFixed(0)}'),
            backgroundColor: AppColors.primaryGreen,
          ));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.assetName,
                          style: AppTypography.textTheme.titleLarge),
                      Text('${_sessions.length} active sessions',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                // Add another session
                IconButton(
                  icon: const Icon(Icons.person_add, color: AppColors.primaryGreen),
                  tooltip: 'Add customer',
                  onPressed: () {
                    Navigator.pop(context);
                    // Use the callback to add another session
                    widget.onAddSession?.call();
                  },
                ),
                // End all
                if (_sessions.length > 1)
                  IconButton(
                    icon: const Icon(Icons.stop_circle, color: Colors.red),
                    tooltip: 'End all sessions',
                    onPressed: _stopAll,
                  ),
              ],
            ),
          ),

          const Divider(),

          // Session list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _sessions.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (ctx, index) {
                      final session = _sessions[index];
                      final startedAt = session['started_at'] as int;
                      
                      final totalPausedSec = session['total_paused_seconds'] as int? ?? 0;
                      final lastPausedAt = session['last_paused_at'] as int?;
                      int currentPausedSec = totalPausedSec;
                      if (session['status'] == 'paused' && lastPausedAt != null) {
                        currentPausedSec += ((DateTime.now().millisecondsSinceEpoch - lastPausedAt) / 1000).floor();
                      }
                      final pausedMs = currentPausedSec * 1000;

                      final duration =
                          EntertainmentService.formatDuration(startedAt, pausedMs: pausedMs);
                      final billingType = session['billing_type'] as String;
                      final rate = (session['rate'] as num).toDouble();
                      final runningCost =
                          EntertainmentService.calculateRunningCost(
                        startedAtMs: startedAt,
                        billingType: billingType,
                        rate: rate,
                        pausedMs: pausedMs,
                      );
                      final customer =
                          session['customer_name'] as String? ?? 'Walk-in';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(customer,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text('$duration  •  KSH ${runningCost.toStringAsFixed(0)}'),
                          trailing: FilledButton.tonal(
                            onPressed: () =>
                                _stopOne(session['id'] as int),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange.shade100,
                              foregroundColor: Colors.orange.shade800,
                            ),
                            child: const Text('End'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
