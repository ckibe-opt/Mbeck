import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../server/local_server.dart';
import '../services/lan_snapshot_client.dart';
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';

/// Data Share Screen — allows owner to share data or employee to receive data
///
/// Two modes:
/// 1. Share Mode (for owner/leader): Shows the device's IP address so employees
///    can connect and pull a full data snapshot.
/// 2. Receive Mode (for employee/follower): Allows entering the leader's IP
///    and pulling a full data snapshot over LAN.
class DataShareScreen extends StatefulWidget {
  final bool isReceiveMode;

  const DataShareScreen({super.key, this.isReceiveMode = false});

  @override
  State<DataShareScreen> createState() => _DataShareScreenState();
}

class _DataShareScreenState extends State<DataShareScreen> {
  final _ipController = TextEditingController();
  bool _isPulling = false;
  String? _statusMessage;
  bool _success = false;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _pullFromDevice() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() => _statusMessage = 'Please enter the IP address');
      return;
    }

    // Add port if missing
    final host = ip.contains(':') ? ip : '$ip:8080';

    setState(() {
      _isPulling = true;
      _statusMessage = 'Connecting to $host...';
      _success = false;
    });

    try {
      final result = await LanSnapshotClient.pullFromLeader(host);
      if (mounted) {
        setState(() {
          _isPulling = false;
          _success = result;
          _statusMessage = result
              ? 'Data received successfully! All menu items, inventory, and settings have been synced.'
              : 'Connection failed. Make sure both devices are on the same WiFi and the IP is correct.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPulling = false;
          _success = false;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(title: 'Share Data'),
      body: widget.isReceiveMode ? _buildReceiveMode() : _buildShareMode(),
    );
  }

  Widget _buildShareMode() {
    final ip = ShopServer.ipAddress;
    final port = ShopServer.port;
    final isRunning = ShopServer.isRunning;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Icon(
            Icons.share,
            size: 64,
            color: AppColors.primaryGreen.withOpacity(0.7),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Share Your Data',
            style: AppTypography.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your team member can receive all your shop data (menu items, inventory, orders, and settings) by entering the address below on their device.',
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: AppColors.gray600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          if (!isRunning) ...[
            // Server not running
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Server is not running. Make sure you are the shop leader device.',
                      style: AppTypography.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // IP Address card
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Device Address',
                    style: AppTypography.textTheme.labelLarge?.copyWith(
                      color: AppColors.gray600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$ip:$port',
                    style: AppTypography.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '$ip:$port'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Address'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Instructions
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions for your team member:',
                    style: AppTypography.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildStep('1', 'Make sure both devices are on the same WiFi'),
                  _buildStep('2', 'On their device, go to Settings > Receive Data'),
                  _buildStep('3', 'Enter the address shown above'),
                  _buildStep('4', 'Tap "Receive Data" and wait for sync'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiveMode() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Icon(
            Icons.download,
            size: 64,
            color: AppColors.primaryGreen.withOpacity(0.7),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Receive Data',
            style: AppTypography.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter the address shown on the owner\'s device to download all shop data (menu items, inventory, orders, and settings).',
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: AppColors.gray600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          // IP input
          TextField(
            controller: _ipController,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'Device Address',
              hintText: 'e.g. 192.168.1.5:8080',
              prefixIcon: const Icon(Icons.wifi),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              filled: true,
              fillColor: AppColors.gray50,
            ),
            enabled: !_isPulling,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Pull button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isPulling ? null : _pullFromDevice,
              icon: _isPulling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(_isPulling ? 'Receiving...' : 'Receive Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Status message
          if (_statusMessage != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _success
                    ? AppColors.success.withOpacity(0.1)
                    : _isPulling
                        ? AppColors.gray100
                        : AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  Icon(
                    _success ? Icons.check_circle : _isPulling ? Icons.hourglass_empty : Icons.error_outline,
                    color: _success ? AppColors.success : _isPulling ? AppColors.gray700 : AppColors.danger,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: AppTypography.textTheme.bodyMedium?.copyWith(
                        color: _success
                            ? AppColors.success
                            : _isPulling
                                ? AppColors.gray700
                                : AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
