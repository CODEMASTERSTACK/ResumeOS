import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';

class PointsScreen extends ConsumerStatefulWidget {
  const PointsScreen({super.key});

  @override
  ConsumerState<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends ConsumerState<PointsScreen> {
  bool _claiming = false;
  int _activeTab = 0; // 0 = Earn Points, 1 = History

  Future<void> _claimMilestone(String milestoneId, int currentPoints, List<String> claimedList) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    if (claimedList.contains(milestoneId)) return;

    setState(() => _claiming = true);

    try {
      final updatedClaimed = [...claimedList, milestoneId];
      final newPoints = currentPoints + 5;

      await ref.read(profileRepositoryProvider).updateUser(uid, {
        'points': newPoints,
        'claimedMilestones': updatedClaimed,
      });

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error claiming points: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Widget _buildPointsCard(int points) {
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
                '$points',
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

  Widget _buildMilestoneTile({
    required String title,
    required String description,
    required int completionRequired,
    required int currentCompletion,
    required String milestoneId,
    required int currentPoints,
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
      leadingWidget = const Icon(Icons.check_circle_rounded, color: Colors.white30, size: 24);
    } else if (canClaim) {
      actionText = 'CLAIM +5 PTS';
      onTapAction = _claiming ? null : () => _claimMilestone(milestoneId, currentPoints, claimedList);
      leadingWidget = const Icon(Icons.stars_rounded, color: Color(0xFFCBE349), size: 24);
    } else {
      actionText = '$currentCompletion% / $completionRequired%';
      onTapAction = null;
      leadingWidget = const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 24);
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
                  color: canClaim
                      ? Colors.black
                      : Colors.white38,
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
          color: isActive ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
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

  Widget _buildHistoryTab(List<String> claimedList) {
    final historyItems = <Map<String, dynamic>>[];

    // 1. Welcome Bonus - always claimed
    historyItems.add({
      'title': 'Welcome Bonus',
      'subtitle': 'Created account & initiated onboarding.',
      'points': 10,
    });

    if (claimedList.contains('profile_50')) {
      historyItems.add({
        'title': 'Profile > 50% Complete',
        'subtitle': 'Completed basic details, summary & skills.',
        'points': 5,
      });
    }

    if (claimedList.contains('profile_80')) {
      historyItems.add({
        'title': 'Profile > 80% Complete',
        'subtitle': 'Added detailed education and work projects.',
        'points': 5,
      });
    }

    if (claimedList.contains('profile_100')) {
      historyItems.add({
        'title': 'Profile 100% Complete',
        'subtitle': 'Completed all optional resume details.',
        'points': 5,
      });
    }

    return Column(
      children: historyItems.map((item) {
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
                  color: const Color(0xFFCBE349).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFFCBE349),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['subtitle'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBE349).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFCBE349).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '+${item['points']} PTS',
                  style: const TextStyle(
                    color: Color(0xFFCBE349),
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
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).valueOrNull;
    final points = user?.points ?? 10;
    final claimedList = user?.claimedMilestones ?? [];
    
    final completionAsync = ref.watch(profileCompletionProvider);
    final currentCompletion = completionAsync.valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark background matching home
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
              // Welcome Bonus
              _buildMilestoneTile(
                title: 'Welcome Bonus',
                description: 'Created account & initiated onboarding.',
                completionRequired: 0,
                currentCompletion: 0,
                milestoneId: 'welcome',
                currentPoints: points,
                claimedList: [...claimedList, 'welcome'], // Always treated as claimed
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
              _buildHistoryTab(claimedList),
            ],
          ],
        ),
      ),
    );
  }
}
