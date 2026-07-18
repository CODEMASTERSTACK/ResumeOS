import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../routes/route_names.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/profile/domain/entities/user_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

// Returns today's date as a stable cache-key ("YYYY-MM-DD").
// The provider family is keyed on this string, so it automatically
// fetches a fresh batch of jobs whenever the calendar date changes.
String todayJobCacheKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

final freshJobsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, dateKey) async {
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



final profileCompletionProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(0);
  return ref.read(profileRepositoryProvider).watchProfileCompletionPercent(uid);
});

final resumesCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(0);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('resumes')
      .snapshots()
      .map((snap) => snap.docs.length);
});

// ── Dashboard Screen ───────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 22 || hour < 5) return AppStrings.goodNight;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting,',
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name.isNotEmpty ? name : 'Professional',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PointsIndicatorWidget(),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => context.push('/profile/settings'),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'What job are you targeting today?',
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PointsIndicatorWidget extends ConsumerStatefulWidget {
  const _PointsIndicatorWidget();

  @override
  ConsumerState<_PointsIndicatorWidget> createState() => _PointsIndicatorWidgetState();
}

class _PointsIndicatorWidgetState extends ConsumerState<_PointsIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).valueOrNull;
    final completionPercent = ref.watch(profileCompletionProvider).valueOrNull ?? 0;
    final points = user?.points ?? 10.0;
    final claimed = user?.claimedMilestones ?? [];

    final canClaim50 = completionPercent > 50 && !claimed.contains('profile_50');
    final canClaim80 = completionPercent > 80 && !claimed.contains('profile_80');
    final canClaim100 = completionPercent == 100 && !claimed.contains('profile_100');
    final isEligible = canClaim50 || canClaim80 || canClaim100;

    return GestureDetector(
      onTap: () {
        context.push('/profile/points');
      },
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isEligible
                    ? const Color(0xFFFFD60A).withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.08),
                width: isEligible ? 1.5 : 1.0,
              ),
              boxShadow: isEligible
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD60A).withValues(alpha: 0.3),
                        blurRadius: _glowAnimation.value,
                        spreadRadius: _glowAnimation.value / 4,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  color: points < 4
                      ? const Color(0xFFE53935)
                      : (isEligible ? const Color(0xFFFFD60A) : const Color(0xFFFFD60A).withValues(alpha: 0.8)),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  points.toStringAsFixed(points % 1 == 0 ? 0 : 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


// ── Hero Generate Card ────────────────────────────────────

class _GenerateHeroCard extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  const _GenerateHeroCard({required this.onTap});

  @override
  ConsumerState<_GenerateHeroCard> createState() => _GenerateHeroCardState();
}

class _GenerateHeroCardState extends ConsumerState<_GenerateHeroCard> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _promptController;
  late Animation<double> _animationCurve;
  Timer? _animationTimer;
  bool _isAnimationTriggered = false;

  // Track animation only once per session
  static bool _hasAnimatedThisSession = false;

  @override
  void initState() {
    super.initState();
    _promptController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animationCurve = CurvedAnimation(
      parent: _promptController,
      curve: Curves.easeInOutBack,
    );
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _promptController.dispose();
    super.dispose();
  }

  void _startTimerIfNeeded(int completionPercent) {
    if (_animationTimer == null && completionPercent < 80 && !_isAnimationTriggered && !_hasAnimatedThisSession) {
      _animationTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          _hasAnimatedThisSession = true;
          setState(() {
            _isAnimationTriggered = true;
          });
          _promptController.forward().then((_) {
            if (mounted) {
              _animationTimer = Timer(const Duration(seconds: 5), () {
                if (mounted) {
                  _promptController.reverse().then((_) {
                    if (mounted) {
                      setState(() {
                        _isAnimationTriggered = false;
                      });
                    }
                  });
                }
              });
            }
          });
        }
      });
    }
  }

  static const String _kGithubSvg = '''
<svg viewBox="0 0 24 24">
  <path fill="currentColor" d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.865 8.166 6.839 9.489.5.092.682-.217.682-.482 0-.237-.008-.866-.013-1.7-2.782.603-3.369-1.34-3.369-1.34-.454-1.156-1.11-1.464-1.11-1.464-.908-.62.069-.608.069-.608 1.003.07 1.531 1.03 1.531 1.03.892 1.529 2.341 1.087 2.91.831.092-.646.35-1.086.636-1.336-2.22-.253-4.555-1.11-4.555-4.943 0-1.091.39-1.984 1.029-2.683-.103-.253-.446-1.27.098-2.647 0 0 .84-.269 2.75 1.025A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.294 2.747-1.025 2.747-1.025.546 1.377.203 2.394.1 2.647.64.699 1.028 1.592 1.028 2.683 0 3.842-2.339 4.687-4.566 4.935.359.309.678.919.678 1.852 0 1.336-.012 2.415-.012 2.743 0 .267.18.579.688.481C19.137 20.162 22 16.418 22 12c0-5.523-4.477-10-10-10z"/>
</svg>
''';

  static const String _kLinkedinSvg = '''
<svg viewBox="0 0 24 24">
  <path fill="currentColor" d="M19 0h-14c-2.761 0-5 2.239-5 5v14c0 2.761 2.239 5 5 5h14c2.762 0 5-2.239 5-5v-14c0-2.761-2.238-5-5-5zm-11 19h-3v-11h3v11zm-1.5-12.268c-.966 0-1.75-.779-1.75-1.75s.784-1.75 1.75-1.75 1.75.779 1.75 1.75-.784 1.75-1.75 1.75zm13.5 12.268h-3v-5.604c0-3.368-4-3.113-4 0v5.604h-3v-11h3v1.765c1.396-2.586 7-2.777 7 2.476v6.759z"/>
</svg>
''';

  String _extractUsername(String urlOrUsername, bool isLinkedIn) {
    if (urlOrUsername.isEmpty) return '';
    var clean = urlOrUsername.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.toLowerCase().contains('github.com/') || clean.toLowerCase().contains('linkedin.com/')) {
      final parts = clean.split('/');
      if (parts.isNotEmpty) {
        final last = parts.last;
        if (last.isNotEmpty) return last;
      }
    }
    if (clean.toLowerCase().contains('/in/')) {
      final parts = clean.split('/in/');
      if (parts.length > 1) {
        final sub = parts[1].split('/')[0].split('?')[0];
        if (sub.isNotEmpty) return sub;
      }
    }
    final uri = Uri.tryParse(clean);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => clean);
      return last;
    }
    return clean;
  }

  Widget _buildContactInfo(UserModel user) {
    final github = _extractUsername(user.githubUrl, false);
    final linkedin = _extractUsername(user.linkedinUrl, true);
    final phone = user.phone.trim();

    final List<Widget> items = [];

    if (github.isNotEmpty) {
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(
              _kGithubSvg,
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(
                Color(0xFF1E1C24),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              github,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      );
    }

    if (linkedin.isNotEmpty) {
      if (items.isNotEmpty) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '|',
              style: TextStyle(
                color: Color(0xFFD1D5DB),
                fontSize: 11,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        );
      }
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(
              _kLinkedinSvg,
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(
                Color(0xFF0A66C2),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              linkedin,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      );
    }

    if (phone.isNotEmpty) {
      if (items.isNotEmpty) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '|',
              style: TextStyle(
                color: Color(0xFFD1D5DB),
                fontSize: 11,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        );
      }
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.phone_rounded,
              size: 13,
              color: Color(0xFF10B981),
            ),
            const SizedBox(width: 4),
            Text(
              phone,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).valueOrNull;
    final completionPercent = ref.watch(profileCompletionProvider).valueOrNull ?? 0;
    final resumesCount = ref.watch(resumesCountProvider).valueOrNull ?? 0;

    final Color completionColor;
    if (completionPercent < 60) {
      completionColor = const Color(0xFFFF5B5C); // Premium soft red
    } else if (completionPercent < 80) {
      completionColor = const Color(0xFFF59E0B); // Amber / yellow
    } else {
      completionColor = const Color(0xFF10B981); // Emerald green for high completion (>= 80%)
    }

    _startTimerIfNeeded(completionPercent);

    final fadeOutAnim = Tween<double>(begin: 1.0, end: 0.0).animate(_animationCurve);
    final scaleOutAnim = Tween<double>(begin: 1.0, end: 0.0).animate(_animationCurve);

    final name = user?.name ?? 'Your name';
    final String title;
    if (user != null && user.domainBackground.isNotEmpty) {
      if (user.domainBackground.toLowerCase() == 'both') {
        title = 'Technical + Non-Technical';
      } else {
        title = user.domainBackground;
      }
    } else {
      title = (user?.currentRole.isNotEmpty == true)
          ? user!.currentRole
          : 'Your selected domain';
    }
    final profileImageUrl = user?.profileImageUrl ?? '';

    ImageProvider? avatarImage;
    if (profileImageUrl.isNotEmpty) {
      avatarImage = NetworkImage(profileImageUrl);
    } else if (user?.gender.toLowerCase() == 'female') {
      avatarImage = const AssetImage('assets/images/female.png');
    } else if (user?.gender.toLowerCase() == 'male') {
      avatarImage = const AssetImage('assets/images/male.png');
    }

    final showPlaceholderText = avatarImage == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          transform: _hovered 
              ? (Matrix4.identity()..translate(0, -4)..scale(1.008))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.18 : 0.08),
                blurRadius: _hovered ? 24 : 16,
                offset: Offset(0, _hovered ? 12 : 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: SizedBox(
              height: 342,
              child: Stack(
                children: [
                  // 1. Top half landscape image
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 140,
                    child: Image.network(
                      'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=800&q=80',
                      fit: BoxFit.cover,
                    ),
                  ),

                  // 2. Soft fade overlay on top of the image to blend it down
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 140,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.2),
                            Colors.white,
                          ],
                          stops: const [0.6, 0.9, 1.0],
                        ),
                      ),
                    ),
                  ),



                  // 4. Overlapping Profile Avatar
                  Positioned(
                    top: 104,
                    left: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFFFE8D6),
                        backgroundImage: avatarImage,
                        child: showPlaceholderText
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Color(0xFF5A4A42),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),

                  // 5. Card Body (positioned underneath the avatar)
                  Positioned(
                    top: 168,
                    left: 24,
                    right: 24,
                    bottom: 12,
                    child: Builder(
                      builder: (context) {
                        final Widget contactInfoWidget;
                        if (user != null) {
                          final baseContact = _buildContactInfo(user);
                          if (_isAnimationTriggered) {
                            contactInfoWidget = SizeTransition(
                              sizeFactor: Tween<double>(begin: 1.0, end: 0.0).animate(_animationCurve),
                              child: FadeTransition(
                                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_animationCurve),
                                child: baseContact,
                              ),
                            );
                          } else {
                            contactInfoWidget = baseContact;
                          }
                        } else {
                          contactInfoWidget = const SizedBox.shrink();
                        }

                        final Widget bottomRowWidget;
                        if (!_isAnimationTriggered) {
                          bottomRowWidget = Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Stats Section (Profile Completed + Resume Created)
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      // Profile Completed
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                '★ ',
                                                style: TextStyle(
                                                  color: completionColor,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                '$completionPercent%',
                                                style: TextStyle(
                                                  color: completionColor,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'profile completed',
                                            style: TextStyle(
                                              color: Color(0xFF8A8894),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Vertical Divider
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 10),
                                        height: 28,
                                        width: 1,
                                        color: Colors.black.withValues(alpha: 0.08),
                                      ),

                                      // Resume Created
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            resumesCount.toString(),
                                            style: const TextStyle(
                                              color: Color(0xFF1E1C24),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'resume created',
                                            style: TextStyle(
                                              color: Color(0xFF8A8894),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Design Resume Button
                              GestureDetector(
                                onTap: widget.onTap,
                                behavior: HitTestBehavior.opaque,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF07060F), // Sleek black
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: _hovered
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: const Text(
                                    'Design Resume',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          bottomRowWidget = Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Stats Section (Profile Completed + Resume Created)
                              Flexible(
                                child: Row(
                                  children: [
                                    // Profile Completed
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          AnimatedBuilder(
                                            animation: _animationCurve,
                                            builder: (context, child) {
                                              return Transform.scale(
                                                scale: 1.0 + (1.2 * _animationCurve.value),
                                                alignment: Alignment.bottomLeft,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerLeft,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        '★ ',
                                                        style: TextStyle(
                                                          color: completionColor,
                                                          fontSize: 18,
                                                        ),
                                                      ),
                                                      Text(
                                                        '$completionPercent%',
                                                        style: TextStyle(
                                                          color: completionColor,
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 6),
                                          Stack(
                                            children: [
                                              FadeTransition(
                                                opacity: fadeOutAnim,
                                                child: SizeTransition(
                                                  sizeFactor: fadeOutAnim,
                                                  child: const SizedBox(
                                                    height: 12,
                                                    child: Text(
                                                      'profile completed',
                                                      style: TextStyle(
                                                        color: Color(0xFF8A8894),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              FadeTransition(
                                                opacity: _animationCurve,
                                                child: SizeTransition(
                                                  sizeFactor: _animationCurve,
                                                  child: SizedBox(
                                                    height: 18,
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        'Complete your profile to get best results',
                                                        style: GoogleFonts.outfit(
                                                          color: completionColor,
                                                          fontSize: 14, // Clearly visible warning size
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Spacer & Divider & Resume count
                                    SizeTransition(
                                      axis: Axis.horizontal,
                                      axisAlignment: -1.0,
                                      sizeFactor: fadeOutAnim,
                                      child: ScaleTransition(
                                        scale: scaleOutAnim,
                                        child: FadeTransition(
                                          opacity: fadeOutAnim,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 10),
                                                height: 28,
                                                width: 1,
                                                color: Colors.black.withValues(alpha: 0.08),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    resumesCount.toString(),
                                                    style: const TextStyle(
                                                      color: Color(0xFF1E1C24),
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  const Text(
                                                    'resume created',
                                                    style: TextStyle(
                                                      color: Color(0xFF8A8894),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Design Resume Button
                              SizeTransition(
                                axis: Axis.horizontal,
                                axisAlignment: 1.0,
                                sizeFactor: fadeOutAnim,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _promptController.value > 0.5 ? null : widget.onTap,
                                      behavior: HitTestBehavior.opaque,
                                      child: ScaleTransition(
                                        scale: scaleOutAnim,
                                        child: FadeTransition(
                                          opacity: fadeOutAnim,
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF07060F), // Sleek black
                                              borderRadius: BorderRadius.circular(30),
                                              boxShadow: _hovered
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.15),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: const Text(
                                              'Design Resume',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Color(0xFF1E1C24),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Color(0xFF8A8894),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                contactInfoWidget,
                              ],
                            ),
                            const Spacer(),
                            bottomRowWidget,
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Know the Resume',
              style: AppTypography.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF723FFD).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFFB89EFF),
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Guides',
                    style: TextStyle(
                      color: Color(0xFFB89EFF),
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
                    Color(0xFF2C253B),
                    Color(0xFF1E1929),
                  ],
                  accentColor: const Color(0xFFBE97E8),
                  onTap: () => context.push('/profile/resume-guide/non_technical'),
                ),
                const SizedBox(width: 16),
                _TemplateScrollCard(
                  title: 'Technical Resume',
                  subtitle: 'Highlights systems, code repositories, frameworks, and engineering metrics.',
                  gradientColors: const [
                    Color(0xFF2A2E1A),
                    Color(0xFF1C1E11),
                  ],
                  accentColor: const Color(0xFFCBE349),
                  onTap: () => context.push('/profile/resume-guide/technical'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateScrollCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color accentColor;
  final VoidCallback onTap;

  const _TemplateScrollCard({
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.accentColor,
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
        child: Column(
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Text(
                'Read Guide',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
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

  void _showJobSourceInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13111C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFCBE349), size: 24),
            const SizedBox(width: 10),
            Text(
              'Job Openings Info',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where are these jobs from?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'Jobs are aggregated live daily from Adzuna (primarily focused on job markets in India) with automatic failovers to Remotive and Arbeitnow for international remote roles.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'How are they filtered?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'We prioritize tech openings in top Indian cities (Bangalore, Pune, Noida, Mumbai) and remote positions that explicitly welcome Indian and APAC applicants.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Good to know:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '• Click any job card to navigate directly to the application link.\n• Fresh lists populate dynamically every 24 hours.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Got it',
              style: TextStyle(color: Color(0xFFCBE349), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(freshJobsProvider(todayJobCacheKey()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Fresh job openings',
                  style: AppTypography.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showJobSourceInfoDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white60,
                      size: 14,
                    ),
                  ),
                ),
              ],
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

