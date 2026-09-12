import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Global Gatekeeper that watches user status in real time and automatically
/// logs out users placed on hold or deleted, rendering an informative obsidian barrier.
class AccountStatusGate extends ConsumerStatefulWidget {
  final Widget child;

  const AccountStatusGate({super.key, required this.child});

  @override
  ConsumerState<AccountStatusGate> createState() => _AccountStatusGateState();
}

class _AccountStatusGateState extends ConsumerState<AccountStatusGate> {
  bool _hasLoggedOut = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final user = userAsync.valueOrNull;

    if (user == null) {
      _hasLoggedOut = false;
      return widget.child;
    }

    // 1. Account Deactivated / Deleted
    final isDeleted = user.isDeleted || user.accountStatus == 'deleted';
    if (isDeleted) {
      if (!_hasLoggedOut) {
        _hasLoggedOut = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(authNotifierProvider.notifier).signOut();
        });
      }

      return _buildDeletedScreen(context, user.email, user.deletionReason);
    }

    // 2. Account Placed On Hold
    final isHold = user.accountStatus == 'hold';
    if (isHold) {
      final isStillHeld = user.holdUntil == null ||
          DateTime.now().isBefore(user.holdUntil!);

      if (isStillHeld) {
        if (!_hasLoggedOut) {
          _hasLoggedOut = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(authNotifierProvider.notifier).signOut();
          });
        }

        return _buildHoldScreen(context, user.holdReason, user.holdUntil);
      }
    }

    _hasLoggedOut = false;
    return widget.child;
  }

  Widget _buildDeletedScreen(
      BuildContext context, String email, String reason) {
    final displayReason = reason.isNotEmpty
        ? reason
        : 'Administrative action due to detected unauthorized activity.';

    return Scaffold(
      backgroundColor: const Color(0xFF07060F),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: const Color(0xFF13111C),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.block_rounded,
                      color: Color(0xFFF43F5E),
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Account Deactivated',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your account with this email ($email) was deleted by our team.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reason: $displayReason',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'You cannot access your account or create a new account with this email ID.',
                  style: TextStyle(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(authNotifierProvider.notifier).signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF43F5E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Back to Login',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHoldScreen(
      BuildContext context, String reason, DateTime? holdUntil) {
    final displayReason = reason.isNotEmpty
        ? reason
        : 'Detected unauthorized activity.';

    final holdDurationText = holdUntil != null
        ? 'On hold until ${holdUntil.toLocal().toString().split('.').first}'
        : 'Indefinitely pending administrative review';

    return Scaffold(
      backgroundColor: const Color(0xFF07060F),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: const Color(0xFF13111C),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.pause_circle_filled_rounded,
                      color: Color(0xFFF59E0B),
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Account On Hold',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your account has been placed on hold due to detected unauthorized activity. During this time, no activity is allowed.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        holdDurationText,
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reason: $displayReason',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final uri = Uri.parse('mailto:support@resumeos.app?subject=Account%20Hold%20Inquiry');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Contact Support'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(authNotifierProvider.notifier).signOut();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
