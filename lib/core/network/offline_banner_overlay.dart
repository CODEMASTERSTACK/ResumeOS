import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'network_info.dart';

/// A non-intrusive floating connectivity banner overlaid at the top of the app
class OfflineBannerOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const OfflineBannerOverlay({super.key, required this.child});

  @override
  ConsumerState<OfflineBannerOverlay> createState() => _OfflineBannerOverlayState();
}

class _OfflineBannerOverlayState extends ConsumerState<OfflineBannerOverlay> {
  bool _wasOffline = false;
  bool _showRestored = false;
  Timer? _restoredTimer;

  @override
  void dispose() {
    _restoredTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkAsync = ref.watch(networkStatusProvider);
    final status = networkAsync.valueOrNull ?? NetworkStatus.online;
    final isOffline = status == NetworkStatus.offline;

    if (isOffline) {
      _wasOffline = true;
      _showRestored = false;
      _restoredTimer?.cancel();
    } else if (_wasOffline) {
      // Transition from offline to online
      _wasOffline = false;
      _showRestored = true;
      _restoredTimer?.cancel();
      _restoredTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showRestored = false;
          });
        }
      });
    }

    final showBanner = isOffline || _showRestored;

    return Stack(
      children: [
        widget.child,

        // Animated Top Banner
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          top: showBanner ? 0 : -90,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isOffline
                          ? const Color(0xFF1F1216) // Deep warm dark red
                          : const Color(0xFF0C1F16), // Deep rich dark green
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isOffline
                            ? const Color(0xFFF43F5E).withValues(alpha: 0.6)
                            : const Color(0xFF10B981).withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isOffline ? const Color(0xFFF43F5E) : const Color(0xFF10B981))
                              .withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                          color: isOffline ? const Color(0xFFF43F5E) : const Color(0xFF34D399),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isOffline
                              ? 'Offline Mode • Local Cache Active'
                              : 'Connection Restored',
                          style: TextStyle(
                            color: isOffline ? const Color(0xFFFECDD3) : const Color(0xFFD1FAE5),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (isOffline) ...[
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              ref.invalidate(networkStatusProvider);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh_rounded, color: Color(0xFFFECDD3), size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    'Retry',
                                    style: TextStyle(
                                      color: Color(0xFFFECDD3),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
