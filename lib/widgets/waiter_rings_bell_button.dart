import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/waiter_ring_service.dart';
import '../screens/restaurant/waiter_rings_screen.dart';
import '../theme/design_system.dart';

/// Notification bell button that shows unacknowledged waiter ring count.
///
/// Place this in the AppBar actions of the restaurant POS screen.
/// Listens to [WaiterRingService] for real-time updates.
class WaiterRingsBellButton extends StatefulWidget {
  const WaiterRingsBellButton({super.key});

  @override
  State<WaiterRingsBellButton> createState() => _WaiterRingsBellButtonState();
}

class _WaiterRingsBellButtonState extends State<WaiterRingsBellButton>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<List<WaiterRing>> _sub;
  int _count = 0;
  int _lastKnownCount = 0;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _count = WaiterRingService.instance.unacknowledgedCount;
    _lastKnownCount = _count;

    // Shake animation for new rings
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _sub = WaiterRingService.instance.ringsStream.listen((rings) {
      if (!mounted) return;
      final newCount = rings.where((r) => !r.acknowledged).length;
      setState(() => _count = newCount);

      // Trigger alert if a NEW ring arrived
      if (newCount > _lastKnownCount) {
        _shakeController.forward(from: 0);
        HapticFeedback.heavyImpact();
      }
      _lastKnownCount = newCount;
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _shakeAnimation.value,
          child: child,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(
              _count > 0 ? Icons.notifications_active : Icons.notifications_none,
              color: _count > 0 ? Colors.deepOrange : null,
            ),
            tooltip: 'Customer Rings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WaiterRingsScreen()),
              );
            },
          ),
          if (_count > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  '$_count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
