import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../routes/route_names.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/profile/domain/entities/user_model.dart';
import '../../../../shared/providers/firebase_providers.dart';

// ── Providers ─────────────────────────────────────────────

final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(profileRepositoryProvider).watchUser(uid);
});

final profileCompletionProvider = FutureProvider<int>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return 0;
  return ref.read(profileRepositoryProvider).getProfileCompletionPercent(uid);
});

// ── Dashboard Screen ───────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.goodMorning;
    if (hour < 17) return AppStrings.goodAfternoon;
    return AppStrings.goodEvening;
  }

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final completionAsync = ref.watch(profileCompletionProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF7), // Milky White base
      body: Stack(
        children: [
          // 1. Revolut-style Immersive Top Gradient Backdrop
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.52,
            child: ClipPath(
              clipper: _BottomCurveClipper(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.55, 1.0],
                    colors: [
                      Color(0xFF2C1F18), // Deep espresso at the very top
                      Color(0xFF8B6B58), // Warm signature brand brown in the middle
                      Color(0xFFFCFAF7), // Fades into milky white at the base
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Subtle radial glow overlay for depth (like Revolut's inner highlight)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.36,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.3),
                  radius: 0.9,
                  colors: [
                    const Color(0xFF8B6B58).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 2. Scrollable Foreground Layer
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Minimal SliverAppBar — keeps safe area but collapses height
                const SliverAppBar(
                  backgroundColor: Colors.transparent,
                  floating: true,
                  snap: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  toolbarHeight: 30, // Collapse to almost nothing so greeting sits high
                ),

                // Content list
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Personalized User Greeting (styled in high-contrast white/cream)
                      userAsync.when(
                        data: (user) => _GreetingSection(
                          greeting: _greeting(),
                          name: user?.name ?? '',
                        ),
                        loading: () => const _GreetingShimmer(),
                        error: (_, __) => const _GreetingSection(
                          greeting: 'Hello',
                          name: '',
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Dark Chocolate Slate Hero Generate Card
                      _GenerateHeroCard(
                        onTap: () => context.go(RouteNames.generate),
                      ),

                      const SizedBox(height: 24),

                      // Profile Completion Card (pops with a soft shadow on the white base)
                      completionAsync.when(
                        data: (pct) => _ProfileCompletionCard(
                          percent: pct,
                          onTap: () => context.go(RouteNames.profile),
                        ),
                        loading: () => const _CardShimmer(height: 100),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 24),

                      // Quick Stats Row
                      const _QuickStatsRow(),

                      const SizedBox(height: 24),

                      // Recent Resumes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.recentResumes,
                            style: AppTypography.headlineSmall.copyWith(
                              color: const Color(0xFF5A453A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(RouteNames.history),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF8B6B58), // Signature Brand Active Brown
                            ),
                            child: const Text('View all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const _RecentResumesSection(),

                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Greeting Section ──────────────────────────────────────

class _GreetingSection extends StatelessWidget {
  final String greeting;
  final String name;

  const _GreetingSection({required this.greeting, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isNotEmpty ? '$greeting, ${name.split(' ').first} 👋' : '$greeting 👋',
          style: AppTypography.displaySmall.copyWith(
            color: Colors.white, // Solid high-contrast white
            fontWeight: FontWeight.w800,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'What job are you targeting today?',
          style: AppTypography.bodyMedium.copyWith(
            color: const Color(0xFFFCFAF7).withValues(alpha: 0.8), // Soft cream
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Hero Generate Card ────────────────────────────────────

class _GenerateHeroCard extends StatefulWidget {
  final VoidCallback onTap;
  const _GenerateHeroCard({required this.onTap});

  @override
  State<_GenerateHeroCard> createState() => _GenerateHeroCardState();
}

class _GenerateHeroCardState extends State<_GenerateHeroCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF3E2F26), // Dark warm chocolate brown
                Color(0xFF261D17), // Rich warm charcoal
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B6B58).withValues(alpha: 0.3),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    )
                  ]
                : AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B6B58).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 12, color: Color(0xFFC4AB9B)),
                          const SizedBox(width: 4),
                          Text(
                            'AI-Powered',
                            style: AppTypography.caption.copyWith(
                              color: const Color(0xFFC4AB9B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.generateResumeHero,
                      style: AppTypography.headlineLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.generateResumeHeroSub,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B6B58), // signature brand brown
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B6B58).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Start Now',
                            style: AppTypography.labelLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // AI sparkle icon cluster
              Column(
                children: [
                  _SparkleIcon(size: 48, opacity: 1.0),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SparkleIcon(size: 28, opacity: 0.5),
                      const SizedBox(width: 6),
                      _SparkleIcon(size: 20, opacity: 0.3),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparkleIcon extends StatelessWidget {
  final double size;
  final double opacity;
  const _SparkleIcon({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size,
        color: const Color(0xFFC4AB9B), // Warm cream/light brown matching the theme perfectly
      ),
    );
  }
}

// ── Profile Completion Card ───────────────────────────────

class _ProfileCompletionCard extends StatelessWidget {
  final int percent;
  final VoidCallback onTap;

  const _ProfileCompletionCard(
      {required this.percent, required this.onTap});

  Color get _color {
    if (percent >= 80) return AppColors.success;
    if (percent >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.profileCompletion,
                  style: AppTypography.titleMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$percent%',
                    style: AppTypography.labelMedium.copyWith(
                      color: _color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 6,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(_color),
              ),
            ),
            if (percent < 100) ...[
              const SizedBox(height: 8),
              Text(
                percent < 50
                    ? 'Complete your profile to get better AI matches'
                    : 'Almost there! A complete profile improves match quality.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Quick Stats ───────────────────────────────────────────

class _QuickStatsRow extends ConsumerWidget {
  const _QuickStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    return Row(
      children: [
        _StatCard(
          label: 'Resumes',
          icon: Icons.description_outlined,
          color: AppColors.accent,
          streamFuture: ref
              .watch(firestoreProvider)
              .collection('users')
              .doc(uid)
              .collection('resumes')
              .count()
              .get()
              .then((s) => s.count ?? 0),
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Projects',
          icon: Icons.code_outlined,
          color: const Color(0xFF22C55E),
          streamFuture: ref
              .watch(firestoreProvider)
              .collection('users')
              .doc(uid)
              .collection('projects')
              .count()
              .get()
              .then((s) => s.count ?? 0),
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Skills',
          icon: Icons.bolt_outlined,
          color: const Color(0xFFF59E0B),
          streamFuture: ref
              .watch(firestoreProvider)
              .collection('users')
              .doc(uid)
              .collection('skills')
              .count()
              .get()
              .then((s) => s.count ?? 0),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Future<int> streamFuture;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.streamFuture,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FutureBuilder<int>(
        future: streamFuture,
        builder: (context, snap) {
          final count = snap.data ?? 0;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Recent Resumes ────────────────────────────────────────

class _RecentResumesSection extends ConsumerWidget {
  const _RecentResumesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    return StreamBuilder(
      stream: ref
          .watch(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('resumes')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _CardShimmer(height: 80);
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.description_outlined,
                    size: 32, color: AppColors.textMuted),
                const SizedBox(height: 8),
                Text(AppStrings.noResumesYet,
                    style: AppTypography.titleMedium),
                const SizedBox(height: 4),
                Text(
                  AppStrings.noResumesYetSub,
                  style: AppTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final role = data['jobRole'] as String? ?? 'Unknown Role';
            final score = data['atsScore'] as int? ?? 0;
            final created = (data['createdAt'] as dynamic)?.toDate() as DateTime?;
            return _ResumeHistoryItem(
              role: role,
              atsScore: score,
              createdAt: created,
              onTap: () => context.go('/generate/preview/${doc.id}'),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ResumeHistoryItem extends StatelessWidget {
  final String role;
  final int atsScore;
  final DateTime? createdAt;
  final VoidCallback onTap;

  const _ResumeHistoryItem({
    required this.role,
    required this.atsScore,
    required this.createdAt,
    required this.onTap,
  });

  Color get _scoreColor {
    if (atsScore >= 80) return AppColors.success;
    if (atsScore >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_outlined, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role,
                      style: AppTypography.titleMedium,
                      overflow: TextOverflow.ellipsis),
                  if (createdAt != null)
                    Text(
                      _formatDate(createdAt!),
                      style: AppTypography.caption,
                    ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _scoreColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$atsScore%',
                style: AppTypography.labelSmall.copyWith(
                  color: _scoreColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Shimmer Placeholders ──────────────────────────────────

class _GreetingShimmer extends StatelessWidget {
  const _GreetingShimmer();

  @override
  Widget build(BuildContext context) {
    return const _CardShimmer(height: 56);
  }
}

class _CardShimmer extends StatelessWidget {
  final double height;
  const _CardShimmer({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ── Bottom Curve Clipper ──────────────────────────────────

/// Clips the gradient backdrop with a smooth downward Bezier arc at the bottom,
/// giving the Revolut-style immersive panel effect.
class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 48); // left side drops down
    path.quadraticBezierTo(
      size.width / 2, size.height + 48, // control point curves down in the center
      size.width, size.height - 48,     // right side comes back up
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_BottomCurveClipper oldClipper) => false;
}
