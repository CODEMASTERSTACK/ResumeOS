import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/error_sanitizer.dart';
import '../../../../features/projects/data/repositories/project_repository.dart';
import '../../../../features/projects/domain/entities/project_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/ai/ai_service.dart';
import '../../../../services/ai/gemini_service.dart';
import 'generate_screen.dart';

import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../domain/services/candidate_evaluation_service.dart';

// ── Providers ─────────────────────────────────────────────

final jdAnalysisProvider = FutureProvider<JdAnalysisResult?>((ref) async {
  final jd = ref.watch(jobDescriptionProvider);
  if (jd.isEmpty) return null;
  final ai = ref.read(geminiServiceImplProvider);
  final result = await ai.analyzeJobDescription(jd);
  return JdAnalysisResult.fromJson(result);
});

final candidateEvaluationProvider =
    FutureProvider<CandidateScoreBreakdown?>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return null;
  final analysisAsync = ref.watch(jdAnalysisProvider);
  final analysis = analysisAsync.valueOrNull;
  if (analysis == null) return null;

  final profileRepo = ref.read(profileRepositoryProvider);
  final projectRepo = ref.read(projectRepositoryProvider);

  final projects = await projectRepo.getAllProjects(uid);
  final user = await profileRepo.getUser(uid);

  // Fetch subcollections safely
  List<Map<String, dynamic>> skills = [];
  List<Map<String, dynamic>> experience = [];
  List<Map<String, dynamic>> education = [];
  List<Map<String, dynamic>> certs = [];

  try {
    skills = await profileRepo.watchSkills(uid).first;
  } catch (_) {}
  try {
    experience = await profileRepo.watchExperience(uid).first;
  } catch (_) {}
  try {
    education = await profileRepo.watchEducation(uid).first;
  } catch (_) {}
  try {
    certs = await profileRepo.watchCertifications(uid).first;
  } catch (_) {}

  final profileSkillNames = skills
      .map((s) => (s['name'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toList();

  return CandidateEvaluationService.evaluate(
    analysis: analysis,
    projects: projects,
    profileSkills: profileSkillNames,
    experiences: experience,
    educations: education,
    certifications: certs,
    user: user,
  );
});

final rankedProjectsProvider =
    FutureProvider<List<(ProjectModel, double)>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return <(ProjectModel, double)>[];
  final analysisAsync = ref.watch(jdAnalysisProvider);
  final analysis = analysisAsync.valueOrNull;
  if (analysis == null) return <(ProjectModel, double)>[];
  final projects =
      await ref.read(projectRepositoryProvider).getAllProjects(uid);
  final scored = projects.map((ProjectModel p) {
    final double score = p.scoreAgainst(analysis.allKeywords);
    return (p, score);
  }).toList();
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return scored;
});

// ── AI Analysis Screen ─────────────────────────────────────

class AiAnalysisScreen extends ConsumerWidget {
  const AiAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(jdAnalysisProvider);
    final rankedAsync = ref.watch(rankedProjectsProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF07060F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        title: Text(
          'AI Analysis',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Aurora background (matches app theme)
          Positioned(
            top: -60, left: -60, width: 220, height: 220,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0F6),
              ),
            ),
          ),
          Positioned(
            top: -100, left: -100, width: 260, height: 260,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFFFE0),
                    const Color(0xFFFFEE55).withValues(alpha: 0.5),
                    const Color(0xFFFFB300).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120, left: -120,
            width: screenHeight * 0.55, height: screenHeight * 0.45,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEC53B0).withValues(alpha: 0.6),
                      const Color(0xFF723FFD).withValues(alpha: 0.45),
                      const Color(0xFF1E6AFF).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -50, left: -50,
            width: screenHeight * 0.4, height: screenHeight * 0.4,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF723FFD).withValues(alpha: 0.3),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 95.0, sigmaY: 95.0),
              child: Container(
                color: const Color(0xFF07060F).withValues(alpha: 0.30),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: analysisAsync.when(
              loading: () => const _AnalyzingAnimation(),
              error: (e, _) => _ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(jdAnalysisProvider),
              ),
              data: (analysis) {
                if (analysis == null) {
                  return const Center(
                    child: Text(
                      'No job description provided',
                      style: TextStyle(color: Colors.white60),
                    ),
                  );
                }
                final breakdownAsync = ref.watch(candidateEvaluationProvider);
                return _AnalysisResult(
                  analysis: analysis,
                  rankedAsync: rankedAsync,
                  breakdownAsync: breakdownAsync,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Analyzing Animation — compact, no overflow ─────────────

class _AnalyzingAnimation extends StatefulWidget {
  const _AnalyzingAnimation();

  @override
  State<_AnalyzingAnimation> createState() => _AnalyzingAnimationState();
}

class _AnalyzingAnimationState extends State<_AnalyzingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _orbitalCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _stepCtrl;

  late Animation<double> _orbital;
  late Animation<double> _pulse;
  late Animation<double> _stepFade;

  int _step = 0;
  double _progress = 0.0;
  Timer? _progressTimer;

  final List<Map<String, dynamic>> _steps = [
    {'label': 'Reading job description', 'sub': 'Parsing structure and intent...', 'icon': Icons.article_outlined},
    {'label': 'Extracting required skills', 'sub': 'Identifying technical requirements...', 'icon': Icons.psychology_outlined},
    {'label': 'Identifying keywords', 'sub': 'Mapping ATS-critical terms...', 'icon': Icons.manage_search_rounded},
    {'label': 'Analysing experience level', 'sub': 'Calibrating seniority signals...', 'icon': Icons.signal_cellular_alt_rounded},
    {'label': 'Ranking your profile', 'sub': 'Computing best-fit score...', 'icon': Icons.leaderboard_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _orbitalCtrl = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();
    _pulseCtrl = AnimationController(duration: const Duration(milliseconds: 1800), vsync: this)..repeat(reverse: true);
    _stepCtrl = AnimationController(duration: const Duration(milliseconds: 350), vsync: this);
    _orbital = Tween<double>(begin: 0, end: 1).animate(_orbitalCtrl);
    _pulse = Tween<double>(begin: 0.88, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _stepFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut));
    _stepCtrl.forward();
    _startProgress();
  }

  void _startProgress() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() {
        if (_progress < 20) {
          _progress += 0.55;
        } else if (_progress < 42) {
          _progress += 0.40;
        } else if (_progress < 66) {
          _progress += 0.35;
        } else if (_progress < 85) {
          _progress += 0.28;
        } else if (_progress < 98.2) {
          final remaining = 99.0 - _progress;
          _progress += (remaining * 0.025).clamp(0.015, 0.06);
        }
        if (_progress > 98.2) _progress = 98.2;

        final newStep = _getStepForProgress(_progress);
        if (newStep != _step && newStep > _step) {
          _step = newStep;
          _stepCtrl.forward(from: 0.0);
        }
      });
    });
  }

  int _getStepForProgress(double p) {
    if (p < 20) return 0;
    if (p < 42) return 1;
    if (p < 66) return 2;
    if (p < 85) return 3;
    return 4;
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _orbitalCtrl.dispose();
    _pulseCtrl.dispose();
    _stepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to avoid overflow on small screens
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale the orbital size based on available height
        final orbitSize = (constraints.maxHeight * 0.28).clamp(100.0, 140.0);

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Orbital animation
                    SizedBox(
                      width: orbitSize,
                      height: orbitSize,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_orbital, _pulse]),
                        builder: (context, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: Size(orbitSize, orbitSize),
                                painter: _OrbitPainter(progress: _orbital.value),
                              ),
                              Transform.scale(
                                scale: _pulse.value,
                                child: Container(
                                  width: orbitSize * 0.45,
                                  height: orbitSize * 0.45,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFFCBE349).withValues(alpha: 0.2),
                                        const Color(0xFF723FFD).withValues(alpha: 0.1),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: orbitSize * 0.35,
                                height: orbitSize * 0.35,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF13111C),
                                  border: Border.all(
                                    color: const Color(0xFFCBE349).withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFCBE349).withValues(alpha: 0.18),
                                      blurRadius: 14,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFFCBE349),
                                  size: 22,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    SizedBox(height: constraints.maxHeight * 0.045),

                    // Step indicator
                    FadeTransition(
                      opacity: _stepFade,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _steps[_step]['label'] as String,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _steps[_step]['sub'] as String,
                            style: GoogleFonts.outfit(
                              color: Colors.white38,
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: constraints.maxHeight * 0.045),

                    // Step dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_steps.length, (i) {
                        final isActive = i == _step;
                        final isCompleted = i < _step;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 20 : (isCompleted ? 8 : 5),
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isActive
                                ? const Color(0xFFCBE349)
                                : (isCompleted
                                    ? const Color(0xFFCBE349).withValues(alpha: 0.45)
                                    : Colors.white.withValues(alpha: 0.15)),
                          ),
                        );
                      }),
                    ),

                    SizedBox(height: constraints.maxHeight * 0.04),

                    // Progress bar
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 3,
                            child: LinearProgressIndicator(
                              value: (_progress / 100.0).clamp(0.0, 1.0),
                              backgroundColor: Colors.white.withValues(alpha: 0.06),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCBE349)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_progress.toInt()}% • Step ${_step + 1} of ${_steps.length}',
                          style: GoogleFonts.outfit(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
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
      },
    );
  }
}

// Custom painter for orbital ring
class _OrbitPainter extends CustomPainter {
  final double progress;
  _OrbitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final ringPaint = Paint()
      ..color = const Color(0xFFCBE349).withValues(alpha: 0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, ringPaint);

    final angle = progress * 2 * math.pi - math.pi / 2;
    final dotX = center.dx + radius * math.cos(angle);
    final dotY = center.dy + radius * math.sin(angle);
    final dotCenter = Offset(dotX, dotY);

    final glowPaint = Paint()
      ..color = const Color(0xFFCBE349).withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(dotCenter, 8, glowPaint);

    final dotPaint = Paint()..color = const Color(0xFFCBE349);
    canvas.drawCircle(dotCenter, 4, dotPaint);

    final angle2 = angle + math.pi;
    final dot2X = center.dx + radius * math.cos(angle2);
    final dot2Y = center.dy + radius * math.sin(angle2);
    final dot2Paint = Paint()..color = const Color(0xFF723FFD).withValues(alpha: 0.5);
    canvas.drawCircle(Offset(dot2X, dot2Y), 2.5, dot2Paint);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.progress != progress;
}

// ── Analysis Result — Designer Edition ────────────────────
// Design principles applied:
//   • Typography does the heavy lifting — not boxes
//   • One clear visual anchor (the score)
//   • Whitespace is intentional, not just filler
//   • Color is used sparingly — white for hierarchy, lime for CTAs only
//   • Dividers instead of cards wherever possible
//   • Skills are inline tags, not floating cards
//   • No gratuitous icon-in-a-box pattern for every section

class _AnalysisResult extends ConsumerStatefulWidget {
  final JdAnalysisResult analysis;
  final AsyncValue<List<(ProjectModel, double)>> rankedAsync;
  final AsyncValue<CandidateScoreBreakdown?> breakdownAsync;

  const _AnalysisResult({
    required this.analysis,
    required this.rankedAsync,
    required this.breakdownAsync,
  });

  @override
  ConsumerState<_AnalysisResult> createState() => _AnalysisResultState();
}

class _AnalysisResultState extends ConsumerState<_AnalysisResult> {
  int _activeTab = 0; // 0: Match Breakdown, 1: Skills Matrix, 2: Strategy

  Widget _buildTabBar() {
    final tabs = ['Match Breakdown', 'Skills Matrix', 'Strategy'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = _activeTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFCBE349).withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? const Color(0xFFCBE349).withValues(alpha: 0.2) : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    style: GoogleFonts.outfit(
                      color: isActive ? const Color(0xFFCBE349) : Colors.white60,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBreakdownTab(CandidateScoreBreakdown breakdown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seniority & Career Context Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Icon(
                breakdown.isEarlyCareerAdjusted
                    ? Icons.school_rounded
                    : Icons.work_history_rounded,
                color: const Color(0xFFCBE349),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      breakdown.seniorityVerdict.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      breakdown.isEarlyCareerAdjusted
                          ? 'Early career mode active — score balanced across your verified skills & projects'
                          : 'Seniority calibrated against target role specifications',
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 4 Pillars Card Breakdown
        _BodySection(
          label: 'ATS Evaluation Pillars',
          trailing: 'Holistic 360° Score',
          child: Column(
            children: [
              _PillarMeter(
                label: 'Core Skills Match',
                percent: breakdown.skillsPercentage,
                weight: '${(breakdown.skillsWeight * 100).round()}% weight',
                color: const Color(0xFF10B981),
                subtitle: '${breakdown.matchedSkills.length} required skills verified in your profile',
                icon: Icons.psychology_rounded,
              ),
              const SizedBox(height: 12),
              _PillarMeter(
                label: 'Project Portfolio Proof',
                percent: breakdown.projectsPercentage,
                weight: '${(breakdown.projectsWeight * 100).round()}% weight',
                color: const Color(0xFF3B82F6),
                subtitle: 'Evaluates GitHub links, live demos, and linked skills',
                icon: Icons.folder_special_rounded,
              ),
              if (!breakdown.isEarlyCareerAdjusted) ...[
                const SizedBox(height: 12),
                _PillarMeter(
                  label: 'Experience & Seniority',
                  percent: breakdown.experiencePercentage,
                  weight: '${(breakdown.experienceWeight * 100).round()}% weight',
                  color: const Color(0xFFF59E0B),
                  subtitle: 'Role relevance & tenure calibration',
                  icon: Icons.history_edu_rounded,
                ),
                const SizedBox(height: 12),
                _PillarMeter(
                  label: 'Education & Credentials',
                  percent: breakdown.credentialsPercentage,
                  weight: '${(breakdown.credentialsWeight * 100).round()}% weight',
                  color: const Color(0xFFEC4899),
                  subtitle: 'Relevant degree & professional certifications',
                  icon: Icons.verified_user_rounded,
                ),
              ],
            ],
          ),
        ),

        const _Divider(),

        // Actionable Recommendations
        if (breakdown.gapRecommendations.isNotEmpty) ...[
          _BodySection(
            label: 'Actionable ATS Optimizations',
            trailing: '${breakdown.gapRecommendations.length} recommendations',
            child: Column(
              children: breakdown.gapRecommendations.map((rec) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBE349).withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFCBE349).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.tips_and_updates_rounded,
                        color: Color(0xFFCBE349),
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          rec,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const _Divider(),
        ],

        // Matched vs Missing Skills
        if (breakdown.missingSkills.isNotEmpty) ...[
          _BodySection(
            label: 'Identified Skill Gaps',
            trailing: '${breakdown.missingSkills.length} missing',
            child: _InlineSkillTags(
              skills: breakdown.missingSkills,
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 20),
        ],

        if (breakdown.matchedSkills.isNotEmpty) ...[
          _BodySection(
            label: 'Verified Matching Skills',
            trailing: '${breakdown.matchedSkills.length} matched',
            child: _InlineSkillTags(
              skills: breakdown.matchedSkills,
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildListSection(String title, List<String> items, IconData icon) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFCBE349), size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: GoogleFonts.outfit(
                  color: Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white60,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTabContent(CandidateScoreBreakdown? breakdown) {
    switch (_activeTab) {
      case 0:
        if (breakdown != null) {
          return _buildBreakdownTab(breakdown);
        }
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(color: Color(0xFFCBE349)),
          ),
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role & Seniority
            _BodySection(
              label: 'Target Role',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.analysis.role,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.analysis.experienceLevel.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const _Divider(),

            // Non-Negotiable Skills
            if (widget.analysis.nonNegotiableSkills.isNotEmpty) ...[
              _BodySection(
                label: 'Non-Negotiable Skills',
                child: _InlineSkillTags(
                  skills: widget.analysis.nonNegotiableSkills,
                  color: const Color(0xFFEC4899),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // High-Demand/Trending Skills
            if (widget.analysis.highDemandSkills.isNotEmpty) ...[
              _BodySection(
                label: 'High-Demand/Trending Skills',
                child: _InlineSkillTags(
                  skills: widget.analysis.highDemandSkills,
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Required Skills
            _BodySection(
              label: 'Required Skills',
              trailing: '${widget.analysis.requiredSkills.length}',
              child: _InlineSkillTags(
                skills: widget.analysis.requiredSkills,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 24),

            // Preferred Skills
            if (widget.analysis.preferredSkills.isNotEmpty) ...[
              _BodySection(
                label: 'Preferred Skills',
                trailing: '${widget.analysis.preferredSkills.length}',
                child: _InlineSkillTags(
                  skills: widget.analysis.preferredSkills,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Positioning Strategy description
            if (widget.analysis.roleStrategy.isNotEmpty) ...[
              _BodySection(
                label: 'Resume Positioning Strategy',
                child: Text(
                  widget.analysis.roleStrategy,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),
              const _Divider(),
            ],

            // ATS Keywords
            _BodySection(
              label: 'ATS Keywords / Phrases',
              trailing: '${widget.analysis.keywords.length + widget.analysis.topKeywords.length} detected',
              child: _KeywordFlow(
                keywords: [
                  ...widget.analysis.topKeywords,
                  ...widget.analysis.keywords,
                ],
              ),
            ),
            const _Divider(),

            // Standout Projects
            _buildListSection(
              'Standout Portfolio Projects',
              widget.analysis.standoutProjects,
              Icons.terminal_rounded,
            ),
            const SizedBox(height: 12),

            // High-Impact Bullets
            _buildListSection(
              'High-Impact Bullets (Action + Context + Metric)',
              widget.analysis.highImpactBullets,
              Icons.star_purple500_rounded,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.rankedAsync.when(
      loading: () => const _AnalyzingAnimation(),
      error: (e, _) => _ErrorState(message: e.toString(), onRetry: () {}),
      data: (ranked) {
        final breakdown = widget.breakdownAsync.valueOrNull;
        final topScore = ranked.isNotEmpty ? ranked.first.$2 : 0.0;
        final fallbackPct = (topScore * 100).round().clamp(0, 100);
        final matchPct = breakdown != null ? breakdown.overallPercentage : fallbackPct;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HERO SCORE SECTION ─────────────────────────────────
              _ScoreHero(
                percent: matchPct,
                breakdown: breakdown,
              ),
              const SizedBox(height: 24),

              // ── NAVIGATION TABS ─────────────────────────────────────
              _buildTabBar(),

              // ── BODY CONTENT ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabContent(breakdown),
                    const SizedBox(height: 40),

                    // CTA
                    _CTAButton(
                      onTap: () => context.push(RouteNames.generateSelectProjects),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Pillar Progress Meter ──────────────────────────────────

class _PillarMeter extends StatelessWidget {
  final String label;
  final int percent;
  final String weight;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _PillarMeter({
    required this.label,
    required this.percent,
    required this.weight,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  weight,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100.0).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Score Hero — the visual anchor of the screen ──────────

class _ScoreHero extends StatefulWidget {
  final int percent;
  final CandidateScoreBreakdown? breakdown;
  const _ScoreHero({
    required this.percent,
    this.breakdown,
  });

  @override
  State<_ScoreHero> createState() => _ScoreHeroState();
}

class _ScoreHeroState extends State<_ScoreHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _scoreColor {
    if (widget.percent >= 70) return const Color(0xFF10B981);
    if (widget.percent >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _verdict {
    if (widget.breakdown != null) {
      return widget.breakdown!.verdictSubtitle;
    }
    if (widget.percent >= 70) return 'Strong match for this role';
    if (widget.percent >= 40) return 'Good match — AI will optimise';
    return 'Partial match — AI highlights your strengths';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final displayPct = (widget.percent * _anim.value).round();
        final arcValue = _anim.value * widget.percent / 100;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: large number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label
                    Text(
                      widget.breakdown != null ? 'REALISTIC ATS MATCH' : 'MATCH SCORE',
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // The number
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$displayPct',
                            style: GoogleFonts.outfit(
                              color: _scoreColor,
                              fontSize: 68,
                              fontWeight: FontWeight.w900,
                              height: 0.95,
                              letterSpacing: -2,
                            ),
                          ),
                          TextSpan(
                            text: '%',
                            style: GoogleFonts.outfit(
                              color: _scoreColor.withValues(alpha: 0.5),
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Thin progress line
                    SizedBox(
                      width: 160,
                      child: Stack(
                        children: [
                          Container(
                            height: 2,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            height: 2,
                            width: 160 * arcValue,
                            decoration: BoxDecoration(
                              color: _scoreColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _verdict,
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Right: arc indicator
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: _ArcPainter(
                    progress: arcValue,
                    color: _scoreColor,
                  ),
                  child: Center(
                    child: Icon(
                      widget.percent >= 70
                          ? Icons.verified_rounded
                          : widget.percent >= 40
                              ? Icons.trending_up_rounded
                              : Icons.show_chart_rounded,
                      color: _scoreColor.withValues(alpha: 0.7),
                      size: 22,
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


// Clean arc painter — just a thin stroke, no card
class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const startAngle = -math.pi * 0.75;
    const sweepFull = math.pi * 1.5;

    // Track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepFull, false, trackPaint,
    );

    // Fill
    if (progress > 0) {
      final fillPaint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepFull * progress, false, fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Body Section — label + content, no card ───────────────

class _BodySection extends StatelessWidget {
  final String label;
  final String? trailing;
  final Widget child;

  const _BodySection({
    required this.label,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.outfit(
                  color: Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(
                '· $trailing',
                style: GoogleFonts.outfit(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// ── Thin divider ──────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Container(
        height: 1,
        color: Colors.white.withValues(alpha: 0.06),
      ),
    );
  }
}

// ── Skill Tags — inline, not boxed ────────────────────────
// Each skill is a tight pill with the color as a left accent line.

class _InlineSkillTags extends StatelessWidget {
  final List<String> skills;
  final Color color;

  const _InlineSkillTags({required this.skills, required this.color});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(color: color, width: 2),
            ),
          ),
          child: Text(
            skill,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Keyword Flow — plain text flow, very minimal ──────────
// Keywords rendered as a flowing line of comma-separated spans
// with the accent color on the keyword itself. No borders.

class _KeywordFlow extends StatelessWidget {
  final List<String> keywords;
  const _KeywordFlow({required this.keywords});

  @override
  Widget build(BuildContext context) {
    if (keywords.isEmpty) {
      return const Text(
        'No keywords detected.',
        style: TextStyle(color: Colors.white24, fontSize: 13),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: keywords.map((kw) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            kw,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── CTA Button ────────────────────────────────────────────

class _CTAButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CTAButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFCBE349),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFCBE349).withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Select Projects',
              style: GoogleFonts.outfit(
                color: const Color(0xFF07060F),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF07060F),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error State ───────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
            const SizedBox(height: 20),
            Text(
              ErrorSanitizer.sanitize(message),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message.contains('Insufficient points') || message.contains('points')
                  ? 'Earn or claim points in My Rewards tab'
                  : 'Please check your internet connection or try again later.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBE349),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF07060F),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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
