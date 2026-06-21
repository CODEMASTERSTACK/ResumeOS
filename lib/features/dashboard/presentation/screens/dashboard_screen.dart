import 'dart:convert';
import 'dart:ui';
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

// ── India Relevance Tier ──────────────────────────────────
// Tier 4: India explicitly in location
// Tier 3: Worldwide / Global / APAC / Asia — open to India
// Tier 2: Empty or plain "Remote" — unrestricted
// Tier 1: Region-locked (US, EU, UK, etc.) — lowest priority

const List<String> _kIndiaCities = [
  'india', 'mumbai', 'delhi', 'bangalore', 'bengaluru', 'hyderabad',
  'chennai', 'pune', 'kolkata', 'ahmedabad', 'jaipur', 'noida',
  'gurgaon', 'gurugram', 'chandigarh', 'kochi', 'surat', 'vadodara',
];

const List<String> _kOpenKeywords = [
  'worldwide', 'global', 'anywhere', 'apac', 'asia',
  'international', 'all countries', 'everywhere',
];

const List<String> _kExcludeKeywords = [
  'us only', 'usa only', 'united states only', 'eu only',
  'europe only', 'uk only', 'canada only', 'australia only',
  'must be based in us', 'authorized to work in the us',
];


int _indiaRelevanceScore(Map<String, dynamic> job) {
  final loc = (job['location'] as String? ?? '').toLowerCase();
  if (_kIndiaCities.any((c) => loc.contains(c))) return 4;
  if (_kOpenKeywords.any((k) => loc.contains(k))) return 3;
  if (loc.isEmpty || loc == 'remote') return 2;
  return 1; // region-locked
}

// Normalize an Adzuna India job into the common field schema used by the UI
Map<String, dynamic> _normalizeAdzuna(Map<String, dynamic> j) {
  final company  = j['company']  as Map<String, dynamic>? ?? {};
  final location = j['location'] as Map<String, dynamic>? ?? {};
  final category = j['category'] as Map<String, dynamic>? ?? {};
  return {
    'title':        j['title'] ?? '',
    'company_name': company['display_name'] ?? '',
    'url':          j['redirect_url'] ?? '',
    // display_name is like "Bangalore, Karnataka, India"
    'location':     location['display_name'] ?? 'India',
    'created_at':   j['created'] ?? '', // ISO string e.g. "2024-06-15T10:30:00Z"
    'tags': <String>[
      if ((category['label'] as String?)?.isNotEmpty == true)
        category['label'] as String,
    ],
  };
}

// Normalize a Remotive job (used as fallback)
Map<String, dynamic> _normalizeRemotive(Map<String, dynamic> j) => {
  'title':        j['title'] ?? '',
  'company_name': j['company_name'] ?? '',
  'url':          j['url'] ?? '',
  'location':     j['candidate_required_location'] ?? '',
  'created_at':   j['publication_date'] ?? '',
  'tags':         (j['tags'] as List<dynamic>? ?? []).cast<String>(),
};

final freshJobsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // ── Primary: Adzuna India — via Cloudflare Worker proxy ────────────
  try {
    final uri = Uri.parse(
      'https://smartresume-backend.kanasingh974.workers.dev/v1/jobs/india'
      '?page=1&results_per_page=50',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 14));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (decoded['results'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(_normalizeAdzuna)
          .toList();

      // All Adzuna /in/ results are already India jobs, but sort by tier
      // so jobs with specific cities (Bangalore, Mumbai…) float to very top
      results.sort((a, b) => _indiaRelevanceScore(b).compareTo(_indiaRelevanceScore(a)));
      return results;
    }
    throw Exception('Adzuna proxy ${res.statusCode}');
  } catch (_) {
    // ── Fallback 1: Remotive remote jobs ────────────────────────────────
    try {
      final res2 = await http
          .get(Uri.parse(
              'https://remotive.com/api/remote-jobs?category=software-dev&limit=100'))
          .timeout(const Duration(seconds: 12));
      if (res2.statusCode == 200) {
        final decoded = jsonDecode(res2.body) as Map<String, dynamic>;
        final jobs = (decoded['jobs'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .map(_normalizeRemotive)
            .toList();
        jobs.removeWhere((j) {
          final loc = (j['location'] as String).toLowerCase();
          return _kExcludeKeywords.any((k) => loc.contains(k));
        });
        jobs.sort((a, b) => _indiaRelevanceScore(b).compareTo(_indiaRelevanceScore(a)));
        return jobs;
      }
    } catch (_) {}

    // ── Fallback 2: arbeitnow ─────────────────────────────────────────
    try {
      final res3 = await http
          .get(Uri.parse('https://www.arbeitnow.com/api/job-board-api'))
          .timeout(const Duration(seconds: 10));
      if (res3.statusCode == 200) {
        final decoded = jsonDecode(res3.body) as Map<String, dynamic>;
        final list =
            (decoded['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        list.sort((a, b) => _indiaRelevanceScore(b).compareTo(_indiaRelevanceScore(a)));
        return list;
      }
    } catch (_) {}

    throw Exception('Failed to load jobs. Check your internet connection.');
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
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF07060F), // Rich dark indigo base
      body: Stack(
        children: [
          // 1. Core Bright focal light source (top-left) - almost white-pink bloom
          Positioned(
            top: -60,
            left: -60,
            width: 220,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0F6), // White-pink core bloom
              ),
            ),
          ),

          // 2. Neon Sunlight effect (bright warm golden sunlight leak)
          Positioned(
            top: -100,
            left: -100,
            width: 260,
            height: 260,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    const Color(0xFFFFFFE0), // Hot golden white sun core
                    const Color(0xFFFFEE55).withValues(alpha: 0.5), // Vibrant neon yellow bloom
                    const Color(0xFFFFB300).withValues(alpha: 0.25), // Neon amber halo
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // 2. Volumetric Diagonal Light Leak / Spotlight beam
          Positioned(
            top: -120,
            left: -120,
            width: screenHeight * 0.55,
            height: screenHeight * 0.45,
            child: Transform.rotate(
              angle: -0.15, // Soft diagonal sweep toward center-right
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEC53B0).withValues(alpha: 0.6), // Magenta highlight
                      const Color(0xFF723FFD).withValues(alpha: 0.45), // Purple highlight
                      const Color(0xFF1E6AFF).withValues(alpha: 0.25), // Blue accent
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Layered ambient purple glow layer for surrounding bloom
          Positioned(
            top: -50,
            left: -50,
            width: screenHeight * 0.4,
            height: screenHeight * 0.4,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF723FFD).withValues(alpha: 0.3),
              ),
            ),
          ),

          // 4. Secondary soft blue highlight (extends center-right)
          Positioned(
            top: 60,
            left: 100,
            width: screenHeight * 0.4,
            height: screenHeight * 0.3,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E6AFF).withValues(alpha: 0.22),
              ),
            ),
          ),

          // 5. Cinematic Blur overlay to blend layers into an immersive aurora bloom
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 95.0, sigmaY: 95.0),
              child: Container(
                color: const Color(0xFF07060F).withValues(alpha: 0.30), // Integrated background overlay
              ),
            ),
          ),

          // 5. Scrollable Foreground Layer
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
                      // Personalized User Greeting (styled in high-contrast white)
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

                      const SizedBox(height: 110),
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
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF723FFD).withValues(alpha: 0.15),
                backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                child: profileImageUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
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
            color: Colors.white.withValues(alpha: 0.5), // Soft white
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
                Color(0xFF161324), // Highly desaturated dark violet
                Color(0xFF0E0B14), // Almost black
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1.0,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF723FFD).withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
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
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            'AI-Powered',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white70,
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
                        color: const Color(0xFFCBE349).withValues(alpha: 0.08), // Desaturated lime glass
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCBE349).withValues(alpha: 0.25),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFCBE349).withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Start Now',
                            style: AppTypography.labelLarge.copyWith(
                              color: const Color(0xFFCBE349),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: Color(0xFFCBE349)),
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
        color: Colors.white,
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
            color: Colors.white,
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
                    Color(0xFF2C253B), // Pastel lavender light desaturated
                    Color(0xFF1E1929), // Pastel lavender dark desaturated
                  ],
                  iconColor: const Color(0xFFBE97E8), // Desaturated violet/purple accent
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
                    Color(0xFF2A2E1A), // Pastel/Neon lime green light desaturated
                    Color(0xFF1C1E11), // Pastel/Neon lime green dark desaturated
                  ],
                  iconColor: const Color(0xFFCBE349), // Desaturated olive/forest green accent
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
            color: Color(0xFF0F0E15), // Luxury dark bottom sheet background
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black38,
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
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: AppTypography.headlineMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF723FFD).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF723FFD).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFC39BEF),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recommended: $recommendedTemplate',
                        style: AppTypography.labelMedium.copyWith(
                          color: const Color(0xFFC39BEF),
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
                    backgroundColor: const Color(0xFF723FFD), // Vibrant violet button
                    foregroundColor: Colors.white,
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
            colors: [
              gradientColors[0].withValues(alpha: 0.25),
              gradientColors[1].withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.04),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withValues(alpha: 0.08),
              blurRadius: 20,
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
                opacity: 0.08,
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
                        color: Colors.white,
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
                        color: Colors.white.withValues(alpha: 0.65),
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
                        color: iconColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        Icons.visibility_rounded, // Eye icon representing preview/start
                        color: iconColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.star_border_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.arrow_circle_down_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
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
        color: const Color(0xFF1E1C2B),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
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
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFCBE349).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.fiber_new_rounded,
                    color: Color(0xFFCBE349),
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Daily',
                    style: TextStyle(
                      color: Color(0xFFCBE349),
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
                  color: const Color(0xFF15141F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Center(
                  child: Text(
                    'No job openings available right now.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              );
            }
            final displayJobs = jobs.take(5).toList();
            return Column(
              children: [
                ...displayJobs.map((job) {
                  final title = job['title'] as String? ?? 'Job Title';
                  final company = job['company_name'] as String? ?? 'Company';
                  final url = job['url'] as String? ?? '';
                  final createdAt = job['created_at'];
                  final location = job['location'] as String? ?? '';

                  return _JobPlaylistItem(
                    title: title,
                    company: company,
                    url: url,
                    createdAt: createdAt,
                    location: location,
                  );
                }),
                // ── More Openings Button ──
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => context.push(RouteNames.jobOpenings),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF723FFD).withValues(alpha: 0.18),
                          const Color(0xFFEC53B0).withValues(alpha: 0.12),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF723FFD).withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'More Openings',
                          style: TextStyle(
                            color: Color(0xFFB89EFF),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFFB89EFF),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const _CardShimmer(height: 100),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF15141F),
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
  final String location;

  const _JobPlaylistItem({
    required this.title,
    required this.company,
    required this.url,
    required this.createdAt,
    this.location = '',
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
      DateTime? postDate;
      if (createdAt is int) {
        postDate = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
      } else if (createdAt is String) {
        final s = createdAt as String;
        // Try ISO 8601 first (Remotive: "2024-01-15T10:30:00")
        postDate = DateTime.tryParse(s);
        // Then try Unix timestamp string (arbeitnow fallback)
        if (postDate == null) {
          final secs = int.tryParse(s) ?? 0;
          if (secs > 0) postDate = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
        }
      }
      if (postDate == null) return '';

      final difference = DateTime.now().difference(postDate);
      if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        final minsVal = mins <= 0 ? 1 : mins;
        return 'Posted: ${minsVal}mins ago';
      } else if (difference.inHours < 24) {
        final hrs = difference.inHours;
        return 'Posted: $hrs${hrs == 1 ? "hr" : "hrs"} ago';
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
          color: const Color(0xFF111018).withValues(alpha: 0.6), // Translucent dark surface
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.04), // Ultra-soft border
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
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
                    Color(0xFF252335), // Dark violet gray
                    Color(0xFF1E1C2B), // Deep violet slate
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.business_rounded,
                color: Color(0xFFCBE349), // Neon accent
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
                      color: Colors.white, // Crisp white for title
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          company,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (location.isNotEmpty) ...[         
                        Text(
                          '  ·  ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 11,
                          ),
                        ),
                        const Icon(
                          Icons.location_on_rounded,
                          size: 11,
                          color: Color(0xFF9D7FEF),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9D7FEF),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (postedText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          postedText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4), // Soft grey text
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
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Read More',
                          style: TextStyle(
                            color: Color(0xFFCBE349), // Neon accent matching the image layout
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
                        color: Color(0xFFCBE349), // Neon accent matching the image layout
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

