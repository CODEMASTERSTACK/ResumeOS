import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/projects/data/repositories/project_repository.dart';
import '../../../../features/projects/domain/entities/project_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/ai/ai_service.dart';
import '../../../../services/ai/gemini_service.dart';
import '../../../../services/ai/openrouter_service.dart';
import 'generate_screen.dart';

// ── Providers ─────────────────────────────────────────────

final jdAnalysisProvider = FutureProvider<JdAnalysisResult?>((ref) async {
  final jd = ref.watch(jobDescriptionProvider);
  if (jd.isEmpty) return null;

  final ai = ResilientAIService(
    ref.read(geminiServiceImplProvider),
    ref.read(openRouterServiceProvider),
  );

  final result = await ai.analyzeJobDescription(jd);
  return JdAnalysisResult.fromJson(result);
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('AI Analysis'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: analysisAsync.when(
        loading: () => const _AnalyzingAnimation(),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(jdAnalysisProvider),
        ),
        data: (analysis) {
          if (analysis == null) {
            return const Center(child: Text('No job description provided'));
          }
          return _AnalysisResult(
            analysis: analysis,
            rankedAsync: rankedAsync,
          );
        },
      ),
    );
  }
}

// ── Analyzing Animation ───────────────────────────────────

class _AnalyzingAnimation extends StatefulWidget {
  const _AnalyzingAnimation();

  @override
  State<_AnalyzingAnimation> createState() => _AnalyzingAnimationState();
}

class _AnalyzingAnimationState extends State<_AnalyzingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotation;
  int _step = 0;

  final _steps = [
    'Reading job description...',
    'Extracting required skills...',
    'Identifying keywords...',
    'Analyzing experience level...',
    'Ranking your profile...',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _rotation = Tween<double>(begin: 0, end: 1).animate(_ctrl);

    // Cycle through steps
    _cycleSteps();
  }

  void _cycleSteps() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        setState(() => _step = (_step + 1) % _steps.length);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            RotationTransition(
              turns: _rotation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.accentShadow,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              AppStrings.aiAnalyzing,
              style: AppTypography.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _steps[_step],
                key: ValueKey(_step),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.accent,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.accentContainer,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Analysis Result ───────────────────────────────────────

class _AnalysisResult extends ConsumerWidget {
  final JdAnalysisResult analysis;
  final AsyncValue<List<(ProjectModel, double)>> rankedAsync;

  const _AnalysisResult({
    required this.analysis,
    required this.rankedAsync,
  });

  Color _matchColor(int pct) {
    if (pct >= 70) return AppColors.success;
    if (pct >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return rankedAsync.when(
      loading: () => const _AnalyzingAnimation(),
      error: (e, _) => _ErrorState(message: e.toString(), onRetry: () {}),
      data: (ranked) {
        // Compute match percentage from ranked projects
        final topScore =
            ranked.isNotEmpty ? ranked.first.$2 : 0.0;
        final matchPct = (topScore * 100).round().clamp(0, 100);
        final matchColor = _matchColor(matchPct);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Detected Role
              _SectionHeader(title: AppStrings.detectedRole),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Icon(Icons.work_outline_rounded,
                        size: 16, color: AppColors.accent),
                    Text(
                      analysis.role,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        analysis.experienceLevel.toUpperCase(),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Match Score
              _SectionHeader(title: AppStrings.matchPercentage),
              const SizedBox(height: 12),
              _MatchScoreCard(
                percent: matchPct,
                color: matchColor,
              ),

              const SizedBox(height: 24),

              // Required Skills
              _SectionHeader(title: AppStrings.requiredSkills),
              const SizedBox(height: 10),
              _SkillsGrid(skills: analysis.requiredSkills, isRequired: true),

              if (analysis.preferredSkills.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SkillsGrid(
                    skills: analysis.preferredSkills, isRequired: false),
              ],

              const SizedBox(height: 24),

              // Keywords
              _SectionHeader(title: 'Extracted Keywords'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: analysis.keywords.map((kw) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(kw, style: AppTypography.labelSmall),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // CTA
              ElevatedButton(
                onPressed: () =>
                    context.push(RouteNames.generateSelectProjects),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Select Projects',
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _MatchScoreCard extends StatefulWidget {
  final int percent;
  final Color color;

  const _MatchScoreCard({required this.percent, required this.color});

  @override
  State<_MatchScoreCard> createState() => _MatchScoreCardState();
}

class _MatchScoreCardState extends State<_MatchScoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _anim = Tween<double>(begin: 0, end: widget.percent / 100).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final displayPct = (_anim.value * 100).round();
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$displayPct%',
                      style: AppTypography.displayMedium.copyWith(
                        color: widget.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      displayPct >= 70
                          ? 'Strong match! Great fit for this role.'
                          : displayPct >= 40
                              ? 'Good match. AI will optimize for best fit.'
                              : 'Some gaps. AI will highlight your strengths.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      value: _anim.value,
                      strokeWidth: 8,
                      backgroundColor:
                          widget.color.withOpacity(0.15),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(widget.color),
                    ),
                    Center(
                      child: Icon(
                        displayPct >= 70
                            ? Icons.check_circle_rounded
                            : displayPct >= 40
                                ? Icons.auto_awesome_rounded
                                : Icons.trending_up_rounded,
                        color: widget.color,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SkillsGrid extends StatelessWidget {
  final List<String> skills;
  final bool isRequired;

  const _SkillsGrid({required this.skills, required this.isRequired});

  @override
  Widget build(BuildContext context) {
    final color = isRequired ? AppColors.success : AppColors.warning;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((skill) {
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRequired
                    ? Icons.star_rounded
                    : Icons.add_circle_outline_rounded,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                skill,
                style: AppTypography.labelMedium.copyWith(color: color),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTypography.headlineSmall);
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(AppStrings.aiError, style: AppTypography.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Trying fallback AI provider...',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
