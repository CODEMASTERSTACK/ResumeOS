import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart';

// ── Constants ──────────────────────────────────────────────

const int _kJobsPerPage = 10;
const int _kMaxPages = 5;
const int _kDashboardPreview = 5; // jobs already shown on dashboard

// ── India Relevance Helpers (mirrors dashboard_screen.dart) ──

const List<String> _kJobIndiaCities = [
  'india', 'mumbai', 'delhi', 'bangalore', 'bengaluru', 'hyderabad',
  'chennai', 'pune', 'kolkata', 'ahmedabad', 'jaipur', 'noida',
  'gurgaon', 'gurugram', 'chandigarh', 'kochi', 'surat', 'vadodara',
];

const List<String> _kJobOpenKeywords = [
  'worldwide', 'global', 'anywhere', 'apac', 'asia',
  'international', 'all countries', 'everywhere',
];

bool _isIndiaJob(Map<String, dynamic> job) {
  final loc = (job['location'] as String? ?? '').toLowerCase();
  return _kJobIndiaCities.any((city) => loc.contains(city));
}

// Worldwide/APAC jobs are accessible from India — show them with India badge
bool _isIndiaEligible(Map<String, dynamic> job) {
  final loc = (job['location'] as String? ?? '').toLowerCase();
  if (_kJobIndiaCities.any((c) => loc.contains(c))) return true;
  if (_kJobOpenKeywords.any((k) => loc.contains(k))) return true;
  if (loc.isEmpty || loc == 'remote') return true;
  return false;
}

// ── Job Openings Screen ────────────────────────────────────

class JobOpeningsScreen extends ConsumerStatefulWidget {
  const JobOpeningsScreen({super.key});

  @override
  ConsumerState<JobOpeningsScreen> createState() => _JobOpeningsScreenState();
}

class _JobOpeningsScreenState extends ConsumerState<JobOpeningsScreen> {
  int _currentPage = 0; // 0-indexed

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(freshJobsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF07060F),
      body: Stack(
        children: [
          // ── Ambient Background Glows ──
          Positioned(
            top: -80,
            left: -80,
            width: 280,
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF723FFD).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            width: 220,
            height: 220,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEC53B0).withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: const Color(0xFF07060F).withValues(alpha: 0.55)),
            ),
          ),

          // ── Foreground ──
          SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Job Openings',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              'Fresh listings — updated daily',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // India-first badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF9933).withValues(alpha: 0.20),
                              const Color(0xFF138808).withValues(alpha: 0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFF9933).withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🇮🇳', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 4),
                            Text(
                              'India First',
                              style: TextStyle(
                                color: Color(0xFFFF9933),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Content ──
                Expanded(
                  child: jobsAsync.when(
                    data: (allJobs) {
                      // Provider already sorts by India relevance tier—use directly
                      final pool = allJobs.skip(_kDashboardPreview).toList();
                      final totalPages = (pool.length / _kJobsPerPage)
                          .ceil()
                          .clamp(1, _kMaxPages);

                      final startIdx = _currentPage * _kJobsPerPage;
                      final endIdx = (startIdx + _kJobsPerPage).clamp(0, pool.length);
                      final pageJobs = pool.sublist(
                        startIdx.clamp(0, pool.length),
                        endIdx,
                      );

                      final isLastPage = _currentPage >= _kMaxPages - 1 ||
                          _currentPage >= totalPages - 1;

                      return Column(
                        children: [
                          // Page indicator
                          _PageIndicator(
                            currentPage: _currentPage,
                            totalPages: totalPages.clamp(1, _kMaxPages),
                          ),
                          const SizedBox(height: 16),

                          // Job list
                          Expanded(
                            child: pageJobs.isEmpty
                                ? _EmptyJobsView()
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    itemCount: pageJobs.length +
                                        (isLastPage ? 1 : 0),
                                    itemBuilder: (context, idx) {
                                      if (idx == pageJobs.length) {
                                        // "That's it for today" footer
                                        return _TodayEndBanner();
                                      }
                                      final job = pageJobs[idx];
                                      return _JobCard(job: job);
                                    },
                                  ),
                          ),

                          // Pagination controls
                          _PaginationBar(
                            currentPage: _currentPage,
                            totalPages: totalPages.clamp(1, _kMaxPages),
                            onPrev: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                            onNext: (!isLastPage)
                                ? () => setState(() => _currentPage++)
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF723FFD),
                        strokeWidth: 2.5,
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.white38,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Unable to load jobs',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please check your connection and try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
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
}

// ── Job Card ───────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;

  const _JobCard({required this.job});

  Future<void> _launch() async {
    final url = job['url'] as String? ?? '';
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  bool get _isIndia => _isIndiaJob(job);
  bool get _isEligible => _isIndiaEligible(job);

  String _formatPostedTime() {
    final createdAt = job['created_at'];
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
      final diff = DateTime.now().difference(postDate);
      if (diff.inMinutes < 60) {
        final m = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
        return '$m min ago';
      } else if (diff.inHours < 24) {
        final h = diff.inHours;
        return '$h ${h == 1 ? "hr" : "hrs"} ago';
      } else if (diff.inDays == 1) {
        return '1 day ago';
      } else if (diff.inDays < 30) {
        return '${diff.inDays} days ago';
      } else {
        final mos = (diff.inDays / 30).round();
        return '$mos ${mos == 1 ? "month" : "months"} ago';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = job['title'] as String? ?? 'Job Title';
    final company = job['company_name'] as String? ?? 'Company';
    final location = job['location'] as String? ?? '';
    final postedText = _formatPostedTime();
    final tags = (job['tags'] as List<dynamic>? ?? []).take(2).cast<String>().toList();

    return GestureDetector(
      onTap: _launch,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111018).withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: _isEligible ? 0.10 : 0.04),
            width: _isEligible ? 1.0 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isEligible
                      ? const Color(0xFF723FFD)
                      : Colors.black)
                  .withValues(alpha: _isEligible ? 0.08 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _isEligible
                            ? const Color(0xFF2A1F40)
                            : const Color(0xFF252335),
                        const Color(0xFF1E1C2B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_isEligible
                              ? const Color(0xFF723FFD)
                              : Colors.white)
                          .withValues(alpha: 0.10),
                    ),
                  ),
                  child: Icon(
                    Icons.business_rounded,
                    color: _isEligible
                        ? const Color(0xFF9D7FEF)
                        : const Color(0xFFCBE349),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Title + Company
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              company,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
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
                    ],
                  ),
                ),

                // India / Worldwide badge
                if (_isEligible)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (_isIndia
                              ? const Color(0xFFFF9933)
                              : const Color(0xFF9D7FEF))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_isIndia
                                ? const Color(0xFFFF9933)
                                : const Color(0xFF9D7FEF))
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _isIndia ? '🇮🇳' : '🌐',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),

            // Tags row
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
            ],

            const SizedBox(height: 12),

            // Footer row: posted time + apply button
            Row(
              children: [
                if (postedText.isNotEmpty) ...[
                  const Icon(
                    Icons.access_time_rounded,
                    size: 11,
                    color: Color(0xFF666480),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    postedText,
                    style: const TextStyle(
                      color: Color(0xFF666480),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: _launch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF723FFD).withValues(alpha: 0.85),
                          const Color(0xFFEC53B0).withValues(alpha: 0.75),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF723FFD).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Apply',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page Indicator ─────────────────────────────────────────

class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const _PageIndicator({
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'Page ${currentPage + 1} of ${totalPages.clamp(1, _kMaxPages)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: List.generate(totalPages.clamp(1, _kMaxPages), (i) {
              final isActive = i == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 5),
                width: isActive ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF723FFD)
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCBE349).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_new_rounded,
                    color: Color(0xFFCBE349), size: 12),
                SizedBox(width: 3),
                Text(
                  'Daily',
                  style: TextStyle(
                    color: Color(0xFFCBE349),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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

// ── Pagination Bar ─────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Prev button
          _NavButton(
            icon: Icons.arrow_back_ios_new_rounded,
            label: 'Prev',
            enabled: onPrev != null,
            onTap: onPrev,
          ),
          const Spacer(),

          // Page numbers
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              totalPages.clamp(1, _kMaxPages),
              (i) => GestureDetector(
                onTap: () {
                  // Cannot directly call setState here; handled by parent
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == currentPage
                        ? const Color(0xFF723FFD)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: i == currentPage
                          ? const Color(0xFF723FFD)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i == currentPage
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Next button
          _NavButton(
            icon: Icons.arrow_forward_ios_rounded,
            label: 'Next',
            enabled: onNext != null,
            onTap: onNext,
            iconAfter: true,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final bool iconAfter;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.iconAfter = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!iconAfter) ...[
                Icon(icon, size: 12, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (iconAfter) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 12, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Today End Banner ───────────────────────────────────────

class _TodayEndBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1630).withValues(alpha: 0.7),
            const Color(0xFF0F0E15).withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF723FFD).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF723FFD).withValues(alpha: 0.35),
                  const Color(0xFFEC53B0).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
            child: const Center(
              child: Text('🎉', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "That's it for today.",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check back tomorrow for fresh new\njob openings!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFCBE349).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFCBE349).withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_new_rounded,
                    color: Color(0xFFCBE349), size: 13),
                SizedBox(width: 5),
                Text(
                  'Refreshes daily at midnight',
                  style: TextStyle(
                    color: Color(0xFFCBE349),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

// ── Empty Jobs View ────────────────────────────────────────

class _EmptyJobsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.work_off_outlined,
              color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          Text(
            'No more openings today',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Come back tomorrow for fresh listings!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
