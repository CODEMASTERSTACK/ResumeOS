import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/app_button.dart';

// ── Provider ───────────────────────────────────────────────

final jobDescriptionProvider = StateProvider<String>((ref) => '');

// ── Generate Screen ────────────────────────────────────────

class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen>
    with SingleTickerProviderStateMixin {
  final _jdCtrl = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Restore previous JD if any
    final existing = ref.read(jobDescriptionProvider);
    if (existing.isNotEmpty) _jdCtrl.text = existing;
  }

  @override
  void dispose() {
    _jdCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _analyze() {
    final jd = _jdCtrl.text.trim();
    if (jd.length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste a complete job description (at least 50 characters)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    ref.read(jobDescriptionProvider.notifier).state = jd;
    context.push(RouteNames.generateAnalyze);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(AppStrings.generateResume),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _GenerateHeader(pulseAnim: _pulseAnim),
            const SizedBox(height: 28),

            // JD Input
            Text('Paste Job Description', style: AppTypography.labelLarge),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: TextField(
                controller: _jdCtrl,
                maxLines: 16,
                decoration: InputDecoration(
                  hintText: AppStrings.jobDescriptionHint,
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                    height: 1.7,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: AppTypography.bodyMedium.copyWith(height: 1.7),
              ),
            ),
            const SizedBox(height: 8),
            // Character count
            ValueListenableBuilder(
              valueListenable: _jdCtrl,
              builder: (_, __, ___) => Text(
                '${_jdCtrl.text.length} characters',
                style: AppTypography.caption,
              ),
            ),

            const SizedBox(height: 24),

            // Tips card
            _TipsCard(),
            const SizedBox(height: 24),

            // CTA
            AppButton(
              label: AppStrings.analyzeJD,
              icon: Icons.auto_awesome_rounded,
              variant: AppButtonVariant.accent,
              onTap: _analyze,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _GenerateHeader extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _GenerateHeader({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate Your\nPerfect Resume',
                style: AppTypography.displaySmall.copyWith(height: 1.15),
              ),
              const SizedBox(height: 8),
              Text(
                'Paste any job description. AI handles the rest.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ScaleTransition(
          scale: pulseAnim,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppColors.accentShadow,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tips = [
      ('🎯', 'Paste the complete JD — the more context, the better the match'),
      ('⚡', 'AI extracts keywords, skills, and experience level automatically'),
      ('✅', 'You review and adjust before generating the final PDF'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'How it works',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.$1, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip.$2,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
