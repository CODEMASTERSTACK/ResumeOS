import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../routes/route_names.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/profile/domain/entities/user_model.dart';

// ── Providers ─────────────────────────────────────────────

final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(profileRepositoryProvider).watchUser(uid);
});

final freshJobsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await http.get(Uri.parse('https://www.arbeitnow.com/api/job-board-api'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final list = decoded['data'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Server returned status code: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to load fresh jobs: $e');
  }
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
                          user: user,
                        ),
                        loading: () => const _GreetingShimmer(),
                        error: (_, __) => const _GreetingSection(
                          greeting: 'Hello',
                          user: null,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Generate your Resume Card
                      _GenerateHeroCard(
                        onTap: () => context.go(RouteNames.generate),
                      ),

                      const SizedBox(height: 28),

                      // Know the Resume Carousel Section
                      const _KnowTheResumeSection(),

                      const SizedBox(height: 28),

                      // Fresh Job Openings (Vertical Playlist Style list)
                      const _FreshJobOpeningsSection(),

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
  final UserModel? user;

  const _GreetingSection({required this.greeting, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? '';
    final profileImageUrl = user?.profileImageUrl ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top Avatar Row (inspired by the layout in the picture, without search/like buttons)
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFCFAF7).withValues(alpha: 0.15),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF8B6B58).withValues(alpha: 0.25),
                backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                child: profileImageUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Color(0xFFFCFAF7),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 2. Greeting Text (inspired by "Hi, Samantha" in the picture)
        Text(
          name.isNotEmpty ? 'Hi, ${name.split(' ').first}' : 'Hi there 👋',
          style: AppTypography.displaySmall.copyWith(
            color: Colors.white, // Solid high-contrast white
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'What job are you targeting today?',
          style: AppTypography.bodyMedium.copyWith(
            color: const Color(0xFFFCFAF7).withValues(alpha: 0.75), // Soft cream
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

// ── Know the Resume Section ───────────────────────────────

class _KnowTheResumeSection extends StatelessWidget {
  const _KnowTheResumeSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Know the Resume',
          style: AppTypography.headlineSmall.copyWith(
            color: const Color(0xFF5A453A),
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 190,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _TemplateScrollCard(
                  title: 'Non Technical Resume',
                  subtitle: 'Optimized for business, management, operations, and creative roles.',
                  gradientColors: const [
                    Color(0xFFF7F2EC), // Milky Cream/warm beige
                    Color(0xFFE9DEC9), // Muted tan/warm brown
                  ],
                  iconColor: const Color(0xFF8B6B58),
                  onTap: () => _showTemplateDetails(
                    context,
                    'Non Technical Resume',
                    'A non-technical resume highlights leadership, strategy, project management, business metrics, and communications. Best suited for managerial, administrative, operations, sales, and creative professions.',
                    'ATS Professional Template (single-column, high parseability)',
                  ),
                ),
                const SizedBox(width: 16),
                _TemplateScrollCard(
                  title: 'Technical Resume',
                  subtitle: 'Highlights systems, code repositories, frameworks, and engineering metrics.',
                  gradientColors: const [
                    Color(0xFFEADFCE), // Light mocha cream
                    Color(0xFFC9B6A1), // Deeper brand warm brown
                  ],
                  iconColor: const Color(0xFF5A453A),
                  onTap: () => _showTemplateDetails(
                    context,
                    'Technical Resume',
                    'A technical resume emphasizes developer tools, programming languages, database systems, architectural contributions, GitHub repositories, and quantitative engineering metrics.',
                    'Modern Minimal Template (two-column layout with sidebar)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTemplateDetails(
    BuildContext context,
    String title,
    String description,
    String recommendedTemplate,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Color(0xFFFCFAF7),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B6B58).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: AppTypography.headlineMedium.copyWith(
                  color: const Color(0xFF5A453A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  color: const Color(0xFF5A453A).withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B6B58).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8B6B58).withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFF8B6B58),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recommended: $recommendedTemplate',
                        style: AppTypography.labelMedium.copyWith(
                          color: const Color(0xFF8B6B58),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B6B58),
                    foregroundColor: const Color(0xFFFCFAF7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(RouteNames.generate);
                  },
                  child: const Text(
                    'Generate this Style',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TemplateScrollCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color iconColor;
  final VoidCallback onTap;

  const _TemplateScrollCard({
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 270,
        height: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative background curves (music/gradient glow effect)
            Positioned(
              right: -30,
              bottom: -20,
              child: Opacity(
                opacity: 0.12,
                child: Icon(
                  Icons.auto_awesome_motion_rounded,
                  size: 140,
                  color: iconColor,
                ),
              ),
            ),

            // Text and actions column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF2C1F18),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF2C1F18).withValues(alpha: 0.65),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),

                // Bottom control actions (resembles playbar in reference picture)
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconColor,
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.visibility_rounded, // Eye icon representing preview/start
                        color: Color(0xFFFCFAF7),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.star_border_rounded,
                      color: const Color(0xFF2C1F18).withValues(alpha: 0.5),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.arrow_circle_down_rounded,
                      color: const Color(0xFF2C1F18).withValues(alpha: 0.5),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.more_horiz_rounded,
                      color: const Color(0xFF2C1F18).withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

// ── Fresh Job Openings Section ────────────────────────────

class _FreshJobOpeningsSection extends ConsumerWidget {
  const _FreshJobOpeningsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(freshJobsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fresh job openings',
              style: AppTypography.headlineSmall.copyWith(
                color: const Color(0xFF5A453A),
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B6B58).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.fiber_new_rounded,
                    color: Color(0xFF8B6B58),
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Daily',
                    style: TextStyle(
                      color: Color(0xFF8B6B58),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        jobsAsync.when(
          data: (jobs) {
            if (jobs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFAF7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF8B6B58).withValues(alpha: 0.1)),
                ),
                child: const Center(
                  child: Text(
                    'No job openings available right now.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              );
            }
            final displayJobs = jobs.take(5).toList();
            return Column(
              children: displayJobs.map((job) {
                final title = job['title'] as String? ?? 'Job Title';
                final company = job['company_name'] as String? ?? 'Company';
                final url = job['url'] as String? ?? '';
                final createdAt = job['created_at'];

                return _JobPlaylistItem(
                  title: title,
                  company: company,
                  url: url,
                  createdAt: createdAt,
                );
              }).toList(),
            );
          },
          loading: () => const _CardShimmer(height: 100),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFAF7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                'Failed to load jobs: $err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _JobPlaylistItem extends StatelessWidget {
  final String title;
  final String company;
  final String url;
  final dynamic createdAt;

  const _JobPlaylistItem({
    required this.title,
    required this.company,
    required this.url,
    required this.createdAt,
  });

  Future<void> _launchJobUrl() async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String _formatPostedTime() {
    if (createdAt == null) return '';
    try {
      int seconds = 0;
      if (createdAt is int) {
        seconds = createdAt;
      } else if (createdAt is String) {
        seconds = int.tryParse(createdAt) ?? 0;
      }
      
      if (seconds == 0) return '';
      final postDate = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      final difference = DateTime.now().difference(postDate);

      if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        final minsVal = mins <= 0 ? 1 : mins;
        return 'Posted: ${minsVal}mins ago';
      } else if (difference.inHours < 24) {
        final hrs = difference.inHours;
        return 'Posted: ${hrs}${hrs == 1 ? "hr" : "hrs"} ago';
      } else if (difference.inDays == 1) {
        return 'Posted: 1 Day ago';
      } else if (difference.inDays < 30) {
        return 'Posted: ${difference.inDays} Days ago';
      } else {
        final mos = (difference.inDays / 30).round();
        return 'Posted: $mos ${mos == 1 ? "Month" : "Months"} ago';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final postedText = _formatPostedTime();

    return GestureDetector(
      onTap: _launchJobUrl,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFAF7), // Soft milky white matching background
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF8B6B58).withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Rounded corporate icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF7F2EC),
                    Color(0xFFE9DEC9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.business_rounded,
                color: Color(0xFF8B6B58),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Middle: Job Title + Company Name & "Read More"
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF2C1F18),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    company,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF2C1F18).withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (postedText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          postedText,
                          style: TextStyle(
                            color: const Color(0xFF2C1F18).withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2C1F18).withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Read More',
                          style: TextStyle(
                            color: Color(0xFF8B6B58),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Read More',
                      style: TextStyle(
                        color: Color(0xFF8B6B58),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

