import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart';

// ── Constants ──────────────────────────────────────────────

const int _kJobsPerPage = 10;
const int _kMaxPages = 5;
const int _kDashboardPreview = 5;

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

bool _isIndiaEligible(Map<String, dynamic> job) {
  final loc = (job['location'] as String? ?? '').toLowerCase();
  if (_kJobIndiaCities.any((c) => loc.contains(c))) return true;
  if (_kJobOpenKeywords.any((k) => loc.contains(k))) return true;
  if (loc.isEmpty || loc == 'remote') return true;
  return false;
}

// ── Job Filters Enum ───────────────────────────────────────

enum _JobFilter { all, indiaFirst, worldwide }

// ── Job Openings Screen ────────────────────────────────────

class JobOpeningsScreen extends ConsumerStatefulWidget {
  const JobOpeningsScreen({super.key});

  @override
  ConsumerState<JobOpeningsScreen> createState() => _JobOpeningsScreenState();
}

class _JobOpeningsScreenState extends ConsumerState<JobOpeningsScreen> {
  int _currentPage = 0;
  _JobFilter _selectedFilter = _JobFilter.all;

  void _showJobSourceInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C0B14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCBE349).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Color(0xFFCBE349), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Job Source Info',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where are these jobs from?',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Jobs are aggregated live daily from Adzuna (primarily focused on job markets in India) with automatic failovers to Remotive and Arbeitnow for international remote roles.',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'How are they filtered?',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We prioritize tech openings in top Indian cities (Bangalore, Pune, Noida, Mumbai) and remote positions that explicitly welcome Indian and APAC applicants.',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Good to know:',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• Click any job card to navigate directly to the application link.\n• Fresh lists populate dynamically every 24 hours.',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBE349),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Got it',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF07060F),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(freshJobsProvider(todayJobCacheKey()));

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
                color: const Color(0xFF723FFD).withValues(alpha: 0.15),
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
                color: const Color(0xFFEC53B0).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(color: const Color(0xFF07060F).withValues(alpha: 0.45)),
            ),
          ),

          // ── Foreground Content ──
          SafeArea(
            child: Column(
              children: [
                // ── App Bar ──
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
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Job Openings',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _showJobSourceInfoDialog(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.white.withValues(alpha: 0.4),
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Fresh listings tailored to your profile',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Sleek Accent info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBE349).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFCBE349).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🇮🇳', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              'India First',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFCBE349),
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

                const SizedBox(height: 16),

                // ── Filter Pills ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildFilterPill(_JobFilter.all, 'All Roles'),
                      const SizedBox(width: 8),
                      _buildFilterPill(_JobFilter.indiaFirst, '🇮🇳 India First'),
                      const SizedBox(width: 8),
                      _buildFilterPill(_JobFilter.worldwide, '🌐 Global Remote'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Content Area ──
                Expanded(
                  child: jobsAsync.when(
                    data: (allJobs) {
                      // Filter and search logic
                      var pool = allJobs.skip(_kDashboardPreview).toList();

                      // Apply category filters
                      if (_selectedFilter == _JobFilter.indiaFirst) {
                        pool = pool.where(_isIndiaJob).toList();
                      } else if (_selectedFilter == _JobFilter.worldwide) {
                        pool = pool.where((job) => !_isIndiaJob(job)).toList();
                      }



                      final totalPages = (pool.length / _kJobsPerPage).ceil().clamp(1, _kMaxPages);
                      final startIdx = _currentPage * _kJobsPerPage;
                      final endIdx = (startIdx + _kJobsPerPage).clamp(0, pool.length);
                      
                      final pageJobs = pool.isEmpty
                          ? <Map<String, dynamic>>[]
                          : pool.sublist(startIdx.clamp(0, pool.length), endIdx);

                      final isLastPage = pool.isEmpty ||
                          _currentPage >= _kMaxPages - 1 ||
                          _currentPage >= totalPages - 1;

                      return Column(
                        children: [
                          if (pool.isNotEmpty) ...[
                            _PageIndicator(
                              currentPage: _currentPage,
                              totalPages: totalPages.clamp(1, _kMaxPages),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Expanded(
                            child: pool.isEmpty
                                ? _EmptyJobsView(hasActiveFilters: _selectedFilter != _JobFilter.all)
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    itemCount: pageJobs.length + (isLastPage ? 1 : 0),
                                    itemBuilder: (context, idx) {
                                      if (idx == pageJobs.length) {
                                        return _TodayEndBanner();
                                      }
                                      final job = pageJobs[idx];
                                      return _JobCard(job: job);
                                    },
                                  ),
                          ),
                          if (pool.isNotEmpty) ...[
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
                        ],
                      );
                    },
                    loading: () => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFFCBE349),
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Fetching live listings...',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                          ),
                        ],
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
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please check your connection and try again.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
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

  Widget _buildFilterPill(_JobFilter filter, String label) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
          _currentPage = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCBE349).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCBE349).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? const Color(0xFFCBE349) : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
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
    final raw = createdAt.toString().trim();
    if (raw.isEmpty) return '';
    try {
      DateTime? postDate;
      if (createdAt is int) {
        postDate = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
      } else {
        postDate = DateTime.tryParse(raw);
        if (postDate == null) {
          final secs = int.tryParse(raw) ?? 0;
          if (secs > 0) postDate = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
        }
      }
      if (postDate == null) return '';

      final diff = DateTime.now().difference(postDate);
      if (diff.isNegative || diff.inMinutes < 2) return 'Just now';

      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        final h = diff.inHours;
        return '$h ${h == 1 ? "hr" : "hrs"} ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
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

    // Visual configuration based on category
    final accentColor = _isIndia
        ? const Color(0xFFCBE349)
        : (_isEligible ? const Color(0xFF9D7FEF) : Colors.white24);

    return GestureDetector(
      onTap: _launch,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Stack(
          children: [
            // Outer Card Background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111018).withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: _isEligible ? 0.08 : 0.04),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon/Logo Container
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _isEligible
                                  ? const Color(0xFF2A1F40).withValues(alpha: 0.5)
                                  : const Color(0xFF252335).withValues(alpha: 0.3),
                              const Color(0xFF1E1C2B).withValues(alpha: 0.6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.business_rounded,
                          color: _isEligible ? accentColor : Colors.white30,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title & Company Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                height: 1.25,
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
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (location.isNotEmpty) ...[
                                  Text(
                                    '  ·  ',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      fontSize: 10,
                                    ),
                                  ),
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 11,
                                    color: accentColor.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: accentColor.withValues(alpha: 0.85),
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

                      // Location Category Tag
                      if (_isEligible)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _isIndia ? 'DOMESTIC' : 'GLOBAL',
                            style: GoogleFonts.outfit(
                              color: accentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Tags Row
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),

                  const SizedBox(height: 12),

                  // Footer: Time & Apply Button
                  Row(
                    children: [
                      if (postedText.isNotEmpty) ...[
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          postedText,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: _launch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBE349),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFCBE349).withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Apply',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF07060F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_outward_rounded,
                                size: 12,
                                color: Color(0xFF07060F),
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

            // Left Highlight bar overlay (avoid nonuniform border crash)
            if (_isEligible)
              Positioned(
                left: 0,
                top: 20,
                bottom: 20,
                width: 3.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
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
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.35),
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
                      ? const Color(0xFFCBE349)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCBE349).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFFCBE349), size: 12),
                const SizedBox(width: 3),
                Text(
                  'Daily Refresh',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFCBE349),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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
          _NavButton(
            icon: Icons.arrow_back_ios_new_rounded,
            label: 'Prev',
            enabled: onPrev != null,
            onTap: onPrev,
          ),
          const Spacer(),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              totalPages.clamp(1, _kMaxPages),
              (i) => Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == currentPage
                      ? const Color(0xFFCBE349).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == currentPage
                        ? const Color(0xFFCBE349)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.outfit(
                      color: i == currentPage ? const Color(0xFFCBE349) : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

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
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.02),
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
                style: GoogleFonts.outfit(
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
        color: const Color(0xFF111018).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFCBE349).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFCBE349).withValues(alpha: 0.1),
            ),
            child: const Center(
              child: Icon(Icons.celebration_rounded, color: Color(0xFFCBE349), size: 24),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "That's it for today.",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check back tomorrow for fresh new job openings!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.update_rounded, color: Color(0xFFCBE349), size: 13),
                const SizedBox(width: 5),
                Text(
                  'Refreshes daily at midnight',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFCBE349),
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
  final bool hasActiveFilters;

  const _EmptyJobsView({this.hasActiveFilters = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasActiveFilters ? Icons.search_off_rounded : Icons.work_off_outlined,
            color: Colors.white24,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            hasActiveFilters ? 'No matches found' : 'No openings today',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasActiveFilters
                ? 'Try adjusting your search query or filter settings.'
                : 'Come back tomorrow for fresh listings!',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
