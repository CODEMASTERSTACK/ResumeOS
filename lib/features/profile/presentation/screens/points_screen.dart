import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../shared/widgets/custom_toast.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';

final pointsHistoryProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(profileRepositoryProvider).watchPointsHistory(uid);
});

class PointsScreen extends ConsumerStatefulWidget {
  const PointsScreen({super.key});

  @override
  ConsumerState<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends ConsumerState<PointsScreen> {
  bool _claiming = false;
  int _activeTab = 0; // 0 = Earn Points, 1 = History
  bool _checkingSunday = true;
  bool _isSunday = false;
  String _sundayDateStr = '';

  @override
  void initState() {
    super.initState();
    _checkSundayState();
  }

  Future<void> _checkSundayState() async {
    if (mounted) {
      setState(() => _checkingSunday = true);
    }
    final result = await _checkSunday();
    if (mounted) {
      setState(() {
        _isSunday = result['isSunday'] as bool;
        _sundayDateStr = result['dateStr'] as String;
        _checkingSunday = false;
      });
    }
  }

  Future<Map<String, dynamic>> _checkSunday() async {
    try {
      final response = await http
          .get(Uri.parse(
              'https://timeapi.io/api/Time/current/zone?timeZone=UTC'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final dateTimeStr = data['dateTime'] as String;
        final utcTime = DateTime.parse(dateTimeStr);
        final localTime = utcTime.toLocal();
        final isSunday = localTime.weekday == DateTime.sunday;
        final dateStr =
            "${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}";
        return {'isSunday': isSunday, 'dateStr': dateStr};
      }
    } catch (_) {
      try {
        final response = await http
            .get(Uri.parse('https://worldtimeapi.org/api/timezone/Etc/UTC'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final utcDateTime = data['utc_datetime'] as String;
          final utcTime = DateTime.parse(utcDateTime);
          final localTime = utcTime.toLocal();
          final isSunday = localTime.weekday == DateTime.sunday;
          final dateStr =
              "${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}";
          return {'isSunday': isSunday, 'dateStr': dateStr};
        }
      } catch (_) {}
    }
    // Final fallback: local clock
    final now = DateTime.now();
    final isSunday = now.weekday == DateTime.sunday;
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    return {'isSunday': isSunday, 'dateStr': dateStr};
  }

  Future<void> _claimSundayReward(
      double currentPoints, String lastClaimedSunday) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    if (_sundayDateStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot verify Sunday date. Please check connection.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (lastClaimedSunday == _sundayDateStr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already claimed points for this Sunday.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _claiming = true);

    try {
      final userRef = ref.read(firestoreProvider).collection('users').doc(uid);
      final historyRef = userRef.collection('points_history').doc();

      await ref.read(firestoreProvider).runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw Exception('User profile not found');
        }

        final userData = userSnapshot.data() as Map<String, dynamic>;
        final pointsVal = (userData['points'] as num? ?? 10.0).toDouble();
        final claimedSunday = userData['lastClaimedSunday'] as String? ?? '';

        if (claimedSunday == _sundayDateStr) {
          throw Exception('Already claimed');
        }

        // Add points
        transaction.update(userRef, {
          'points': pointsVal + 5.0,
          'lastClaimedSunday': _sundayDateStr,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Write points history
        transaction.set(historyRef, {
          'title': 'Sunday Weekly Reward',
          'description':
              'Claimed weekly bonus points for Sunday $_sundayDateStr',
          'points': 5.0,
          'type': 'reward',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.stars_rounded, color: Color(0xFFCBE349)),
                SizedBox(width: 8),
                Text('Claimed weekly Sunday +5 Points successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF1E1C2B),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Error claiming Sunday points: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _claimMilestone(String milestoneId, double currentPoints,
      List<String> claimedList) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    if (claimedList.contains(milestoneId)) return;

    setState(() => _claiming = true);

    try {
      final updatedClaimed = [...claimedList, milestoneId];
      final newPoints = currentPoints + 5.0;

      final batch = ref.read(firestoreProvider).batch();
      final userRef = ref.read(firestoreProvider).collection('users').doc(uid);
      final historyRef = userRef.collection('points_history').doc();

      batch.update(userRef, {
        'points': newPoints,
        'claimedMilestones': updatedClaimed,
      });

      String desc = 'Completed profile milestone';
      if (milestoneId == 'welcome')
        desc = 'Initiated account onboarding';
      else if (milestoneId == 'profile_50')
        desc = 'Profile completed above 50%';
      else if (milestoneId == 'profile_80')
        desc = 'Profile completed above 80%';
      else if (milestoneId == 'profile_100') desc = 'Profile completed to 100%';

      batch.set(historyRef, {
        'title': milestoneId == 'welcome'
            ? 'Welcome Bonus'
            : 'Profile Milestone Completed',
        'description': desc,
        'points': 5.0,
        'type': 'reward',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.stars_rounded, color: Color(0xFFCBE349)),
                SizedBox(width: 8),
                Text('Claimed +5 Points successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF1E1C2B),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Error claiming points: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Widget _buildPointsCard(double points) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFCBE349).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              color: Color(0xFFCBE349),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'TOTAL BALANCE',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                points.toStringAsFixed(points % 1 == 0 ? 0 : 1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'PTS',
                style: TextStyle(
                  color: Color(0xFFCBE349),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete milestones below to earn points and level up.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSundayRewardTile(double points, String lastClaimedSunday) {
    if (_checkingSunday) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCBE349)),
            ),
          ),
        ),
      );
    }

    final hasClaimed =
        lastClaimedSunday == _sundayDateStr && _sundayDateStr.isNotEmpty;
    final isSundayToday = _isSunday;

    String title;
    String description;
    String actionText;
    VoidCallback? onTapAction;
    Widget leadingWidget;

    if (hasClaimed) {
      title = 'Sunday Reward';
      description =
          'Claimed for this Sunday ($_sundayDateStr). Come back next week!';
      actionText = 'CLAIMED';
      onTapAction = null;
      leadingWidget = const Icon(Icons.check_circle_rounded,
          color: Colors.white30, size: 24);
    } else if (isSundayToday) {
      title = 'Sunday Weekly Reward';
      description = 'Claim your weekly 5 bonus points today!';
      actionText = 'CLAIM +5 PTS';
      onTapAction = _claiming
          ? null
          : () => _claimSundayReward(points, lastClaimedSunday);
      leadingWidget =
          const Icon(Icons.stars_rounded, color: Color(0xFFCBE349), size: 24);
    } else {
      title = 'Sunday Weekly Reward';
      description = 'Claim 5 bonus points every Sunday! Check back soon.';
      actionText = 'LOCKED';
      onTapAction = null;
      leadingWidget = const Icon(Icons.lock_outline_rounded,
          color: Colors.white24, size: 24);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasClaimed
            ? Colors.white.withValues(alpha: 0.02)
            : (isSundayToday
                ? const Color(0xFFCBE349).withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSundayToday && !hasClaimed
              ? const Color(0xFFCBE349).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          width: isSundayToday && !hasClaimed ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSundayToday && !hasClaimed
                  ? const Color(0xFFCBE349).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: leadingWidget,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onTapAction != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCBE349),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onTapAction,
              child: Text(
                actionText,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                actionText,
                style: GoogleFonts.outfit(
                  color: Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMilestoneTile({
    required String title,
    required String description,
    required int completionRequired,
    required int currentCompletion,
    required String milestoneId,
    required double currentPoints,
    required List<String> claimedList,
  }) {
    final hasMetRequirement = currentCompletion >= completionRequired;
    final isClaimed = claimedList.contains(milestoneId);
    final canClaim = hasMetRequirement && !isClaimed;

    String actionText;
    VoidCallback? onTapAction;
    Widget leadingWidget;

    if (isClaimed) {
      actionText = 'CLAIMED';
      onTapAction = null;
      leadingWidget = const Icon(Icons.check_circle_rounded,
          color: Colors.white30, size: 24);
    } else if (canClaim) {
      actionText = 'CLAIM +5 PTS';
      onTapAction = _claiming
          ? null
          : () => _claimMilestone(milestoneId, currentPoints, claimedList);
      leadingWidget =
          const Icon(Icons.stars_rounded, color: Color(0xFFCBE349), size: 24);
    } else {
      actionText = '$currentCompletion% / $completionRequired%';
      onTapAction = null;
      leadingWidget = const Icon(Icons.lock_outline_rounded,
          color: Colors.white24, size: 24);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canClaim
              ? const Color(0xFFCBE349).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          width: canClaim ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: canClaim
                  ? const Color(0xFFCBE349).withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: leadingWidget,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isClaimed ? Colors.white38 : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isClaimed ? Colors.white24 : Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTapAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: canClaim
                    ? const Color(0xFFCBE349)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: canClaim
                      ? const Color(0xFFCBE349)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                actionText,
                style: TextStyle(
                  color: canClaim ? Colors.black : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(AsyncValue<List<Map<String, dynamic>>> historyAsync,
      List<String> claimedList) {
    return historyAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCBE349)),
          ),
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'Failed to load history: $err',
            style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
          ),
        ),
      ),
      data: (historyList) {
        final displayItems = <Map<String, dynamic>>[];

        if (historyList.isEmpty) {
          // Fallback legacy milestone population for backward compatibility
          displayItems.add({
            'title': 'Welcome Bonus',
            'description': 'Created account & initiated onboarding.',
            'points': 10.0,
            'type': 'reward',
            'createdAt': DateTime.now().subtract(const Duration(days: 1)),
          });
          if (claimedList.contains('profile_50')) {
            displayItems.add({
              'title': 'Profile > 50% Complete',
              'description': 'Completed basic details, summary & skills.',
              'points': 5.0,
              'type': 'reward',
              'createdAt': DateTime.now().subtract(const Duration(hours: 12)),
            });
          }
          if (claimedList.contains('profile_80')) {
            displayItems.add({
              'title': 'Profile > 80% Complete',
              'description': 'Added detailed education and work projects.',
              'points': 5.0,
              'type': 'reward',
              'createdAt': DateTime.now().subtract(const Duration(hours: 6)),
            });
          }
          if (claimedList.contains('profile_100')) {
            displayItems.add({
              'title': 'Profile 100% Complete',
              'description': 'Completed all optional resume details.',
              'points': 5.0,
              'type': 'reward',
              'createdAt': DateTime.now().subtract(const Duration(hours: 1)),
            });
          }
        } else {
          for (final item in historyList) {
            final dateVal = (item['createdAt'] as Timestamp?)?.toDate();
            displayItems.add({
              'title': item['title'] as String? ?? 'Points Activity',
              'description': item['description'] as String? ?? '',
              'points': (item['points'] as num? ?? 0.0).toDouble(),
              'type': item['type'] as String? ?? 'reward',
              'createdAt': dateVal,
            });
          }
        }

        return Column(
          children: displayItems.map((item) {
            final isDeduction = item['type'] == 'deduction';
            final pts = item['points'] as double;
            final date = item['createdAt'] as DateTime?;

            String formattedDate = '';
            if (date != null) {
              formattedDate =
                  "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDeduction
                          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                          : const Color(0xFFCBE349).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDeduction
                          ? Icons.remove_circle_outline_rounded
                          : Icons.stars_rounded,
                      color: isDeduction
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFCBE349),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['description'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (formattedDate.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              color: Colors.white30,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDeduction
                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                          : const Color(0xFFCBE349).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDeduction
                            ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                            : const Color(0xFFCBE349).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isDeduction
                          ? "${pts.toStringAsFixed(1)} PTS"
                          : "+${pts.toStringAsFixed(pts % 1 == 0 ? 0 : 1)} PTS",
                      style: TextStyle(
                        color: isDeduction
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFCBE349),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).valueOrNull;
    final points = user?.points ?? 10.0;
    final claimedList = user?.claimedMilestones ?? [];
    final lastClaimedSunday = user?.lastClaimedSunday ?? '';

    final completionAsync = ref.watch(profileCompletionProvider);
    final currentCompletion = completionAsync.valueOrNull ?? 0;
    final historyAsync = ref.watch(pointsHistoryProvider);

    return Scaffold(
      backgroundColor:
          const Color(0xFF07060F), // Rich dark background matching home
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Rewards',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPointsCard(points),
            const SizedBox(height: 32),

            // Tab Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      title: 'Earn Points',
                      isActive: _activeTab == 0,
                      onTap: () => setState(() => _activeTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      title: 'History',
                      isActive: _activeTab == 1,
                      onTap: () => setState(() => _activeTab = 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_activeTab == 0) ...[
              _buildSundayRewardTile(points, lastClaimedSunday),
              // Welcome Bonus
              _buildMilestoneTile(
                title: 'Welcome Bonus',
                description: 'Created account & initiated onboarding.',
                completionRequired: 0,
                currentCompletion: 0,
                milestoneId: 'welcome',
                currentPoints: points,
                claimedList: [
                  ...claimedList,
                  'welcome'
                ], // Always treated as claimed
              ),

              // Profile > 50%
              _buildMilestoneTile(
                title: 'Profile > 50% Complete',
                description: 'Complete basic details, summary & skills.',
                completionRequired: 51,
                currentCompletion: currentCompletion,
                milestoneId: 'profile_50',
                currentPoints: points,
                claimedList: claimedList,
              ),

              // Profile > 80%
              _buildMilestoneTile(
                title: 'Profile > 80% Complete',
                description: 'Add detailed education and work projects.',
                completionRequired: 81,
                currentCompletion: currentCompletion,
                milestoneId: 'profile_80',
                currentPoints: points,
                claimedList: claimedList,
              ),

              // Profile 100%
              _buildMilestoneTile(
                title: 'Profile 100% Complete',
                description: 'Complete all optional resume details.',
                completionRequired: 100,
                currentCompletion: currentCompletion,
                milestoneId: 'profile_100',
                currentPoints: points,
                claimedList: claimedList,
              ),
            ] else ...[
              _buildHistoryTab(historyAsync, claimedList),
            ],
          ],
        ),
      ),
    );
  }
}
