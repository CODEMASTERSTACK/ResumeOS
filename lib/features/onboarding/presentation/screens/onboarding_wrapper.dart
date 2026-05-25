import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../routes/route_names.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../shared/widgets/app_button.dart';

// ── Step index provider ────────────────────────────────────
final onboardingStepProvider = StateProvider<int>((ref) => 0);

class OnboardingWrapper extends ConsumerWidget {
  const OnboardingWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(onboardingStepProvider);
    final steps = [
      const _WelcomeStep(),
      const _BasicDetailsStep(),
      const _SkillsStep(),
      const _EducationStep(),
      const _SummaryStep(),
      const _CompletionStep(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            if (step > 0 && step < steps.length - 1)
              Padding(
                padding: const EdgeInsets.only(
                    left: 24, right: 24, top: 12, bottom: 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step $step of ${steps.length - 2}',
                          style: AppTypography.caption,
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(onboardingStepProvider.notifier)
                              .state++,
                          child: Text(AppStrings.skip,
                              style: AppTypography.labelMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: step / (steps.length - 2),
                        minHeight: 4,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            // Step content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: SizedBox(
                  key: ValueKey(step),
                  width: double.infinity,
                  child: steps[step],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step Widgets ───────────────────────────────────────────

class _WelcomeStep extends ConsumerWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppColors.accentShadow,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 32),
          Text(
            AppStrings.welcome,
            style: AppTypography.displaySmall.copyWith(height: 1.1),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.welcomeSubtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          // Feature highlights
          ...const [
            ('🎯', 'One profile, unlimited resumes'),
            ('🤖', 'AI tailors every resume to the job'),
            ('📄', 'ATS-optimized PDF in seconds'),
          ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Text(item.$1,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 16),
                    Text(item.$2,
                        style: AppTypography.bodyMedium),
                  ],
                ),
              )),
          const SizedBox(height: 48),
          AppButton(
            label: AppStrings.getStarted,
            onTap: () =>
                ref.read(onboardingStepProvider.notifier).state = 1,
            variant: AppButtonVariant.accent,
            icon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }
}

class _BasicDetailsStep extends ConsumerStatefulWidget {
  const _BasicDetailsStep();

  @override
  ConsumerState<_BasicDetailsStep> createState() =>
      _BasicDetailsStepState();
}

class _BasicDetailsStepState extends ConsumerState<_BasicDetailsStep> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _githubCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _githubCtrl.dispose();
    _linkedinCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateUser(uid, {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'githubUrl': _githubCtrl.text.trim(),
        'linkedinUrl': _linkedinCtrl.text.trim(),
      });
      if (mounted) {
        ref.read(onboardingStepProvider.notifier).state++;
      }
    } catch (e, stack) {
      debugPrint('Error saving basic details during onboarding: $e');
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving details: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tell us about yourself',
              style: AppTypography.displaySmall),
          const SizedBox(height: 8),
          Text('This info will appear on every resume.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: 28),
          _OnboardingField(
              label: 'Full Name *', ctrl: _nameCtrl, hint: 'John Doe'),
          const SizedBox(height: 14),
          _OnboardingField(
              label: 'Phone',
              ctrl: _phoneCtrl,
              hint: '+1 (555) 000-0000',
              keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
          _OnboardingField(
              label: 'Location',
              ctrl: _locationCtrl,
              hint: 'San Francisco, CA'),
          const SizedBox(height: 14),
          _OnboardingField(
              label: 'GitHub URL',
              ctrl: _githubCtrl,
              hint: 'https://github.com/username',
              keyboardType: TextInputType.url),
          const SizedBox(height: 14),
          _OnboardingField(
              label: 'LinkedIn URL',
              ctrl: _linkedinCtrl,
              hint: 'https://linkedin.com/in/username',
              keyboardType: TextInputType.url),
          const SizedBox(height: 32),
          AppButton(
            label: AppStrings.next,
            onTap: _saving ? null : _save,
            isLoading: _saving,
            variant: AppButtonVariant.accent,
          ),
        ],
      ),
    );
  }
}

class _SkillsStep extends ConsumerStatefulWidget {
  const _SkillsStep();

  @override
  ConsumerState<_SkillsStep> createState() => _SkillsStepState();
}

class _SkillsStepState extends ConsumerState<_SkillsStep> {
  final _ctrl = TextEditingController();
  final _skills = <String>[];

  final _suggestions = [
    'Flutter', 'Dart', 'React', 'Python', 'Node.js',
    'TypeScript', 'Firebase', 'AWS', 'Docker', 'Kubernetes',
    'Git', 'REST APIs', 'GraphQL', 'SQL', 'MongoDB',
  ];

  void _add(String skill) {
    final s = skill.trim();
    if (s.isNotEmpty && !_skills.contains(s)) {
      setState(() => _skills.add(s));
      _ctrl.clear();
    }
  }

  Future<void> _save() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      ref.read(onboardingStepProvider.notifier).state++;
      return;
    }
    try {
      for (final skill in _skills) {
        await ref
            .read(profileRepositoryProvider)
            .addSkill(uid, skill, 'General');
      }
      if (mounted) {
        ref.read(onboardingStepProvider.notifier).state++;
      }
    } catch (e, stack) {
      debugPrint('Error saving skills during onboarding: $e');
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving skills: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What are your skills?',
              style: AppTypography.displaySmall),
          const SizedBox(height: 6),
          Text('Add technologies, tools, and frameworks.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: 18),
          // Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                      hintText: 'Type a skill and press Enter'),
                  onSubmitted: _add,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _add(_ctrl.text),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Suggestions
          Text('Suggestions:', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .where((s) => !_skills.contains(s))
                .map((s) => GestureDetector(
                      onTap: () => _add(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded,
                                size: 12,
                                color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(s,
                                style: AppTypography.labelSmall),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          // Added skills
          if (_skills.isNotEmpty) ...[
            Text('Added:', style: AppTypography.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills.map((s) {
                return Chip(
                  label: Text(s),
                  deleteIcon:
                      const Icon(Icons.close, size: 14),
                  onDeleted: () =>
                      setState(() => _skills.remove(s)),
                  backgroundColor: AppColors.accentContainer,
                  labelStyle:
                      AppTypography.labelMedium.copyWith(
                    color: AppColors.accent,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          AppButton(
            label: _skills.isEmpty ? 'Skip →' : AppStrings.next,
            onTap: _save,
            variant: _skills.isEmpty
                ? AppButtonVariant.ghost
                : AppButtonVariant.accent,
          ),
        ],
      ),
    );
  }
}

class _EducationStep extends ConsumerStatefulWidget {
  const _EducationStep();

  @override
  ConsumerState<_EducationStep> createState() => _EducationStepState();
}

class _EducationStepState extends ConsumerState<_EducationStep> {
  final _school10Ctrl = TextEditingController();
  final _board10Ctrl = TextEditingController();
  final _pct10Ctrl = TextEditingController();
  final _year10Ctrl = TextEditingController();

  final _school12Ctrl = TextEditingController();
  final _board12Ctrl = TextEditingController();
  final _pct12Ctrl = TextEditingController();
  final _year12Ctrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _school10Ctrl.addListener(_onTextChanged);
    _board10Ctrl.addListener(_onTextChanged);
    _school12Ctrl.addListener(_onTextChanged);
    _board12Ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _school10Ctrl.dispose();
    _board10Ctrl.dispose();
    _pct10Ctrl.dispose();
    _year10Ctrl.dispose();
    _school12Ctrl.dispose();
    _board12Ctrl.dispose();
    _pct12Ctrl.dispose();
    _year12Ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      ref.read(onboardingStepProvider.notifier).state++;
      return;
    }

    final school10 = _school10Ctrl.text.trim();
    final board10 = _board10Ctrl.text.trim();
    final pct10 = _pct10Ctrl.text.trim();
    final year10 = _year10Ctrl.text.trim();

    final school12 = _school12Ctrl.text.trim();
    final board12 = _board12Ctrl.text.trim();
    final pct12 = _pct12Ctrl.text.trim();
    final year12 = _year12Ctrl.text.trim();

    if (school10.isEmpty && board10.isEmpty && school12.isEmpty && board12.isEmpty) {
      ref.read(onboardingStepProvider.notifier).state++;
      return;
    }

    setState(() => _saving = true);
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      
      if (school10.isNotEmpty || board10.isNotEmpty) {
        await profileRepo.addEducation(uid, {
          'degree': '10th Standard',
          'institution': school10,
          'board': board10,
          'percentage': pct10,
          'endYear': year10,
        });
      }
      
      if (school12.isNotEmpty || board12.isNotEmpty) {
        await profileRepo.addEducation(uid, {
          'degree': '12th Standard',
          'institution': school12,
          'board': board12,
          'percentage': pct12,
          'endYear': year12,
        });
      }
      
      if (mounted) {
        ref.read(onboardingStepProvider.notifier).state++;
      }
    } catch (e, stack) {
      debugPrint('Error saving education during onboarding: $e');
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving education: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSkip = _school10Ctrl.text.trim().isEmpty &&
        _board10Ctrl.text.trim().isEmpty &&
        _school12Ctrl.text.trim().isEmpty &&
        _board12Ctrl.text.trim().isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Education', style: AppTypography.displaySmall),
          const SizedBox(height: 6),
          Text('Add your degrees and qualifications.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: 18),
          
          // ── 10th Standard Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_outlined, color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text('10th Standard (High School)', style: AppTypography.titleMedium),
                  ],
                ),
                const SizedBox(height: 14),
                _OnboardingField(
                  label: 'School Name',
                  ctrl: _school10Ctrl,
                  hint: 'St. Mary\'s School',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _OnboardingField(
                        label: 'Board (e.g. CBSE)',
                        ctrl: _board10Ctrl,
                        hint: 'CBSE',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _OnboardingField(
                        label: 'Pct (%)',
                        ctrl: _pct10Ctrl,
                        hint: '92.4%',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _OnboardingField(
                        label: 'Year',
                        ctrl: _year10Ctrl,
                        hint: '2020',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // ── 12th Standard Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_rounded, color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text('12th Standard (Intermediate)', style: AppTypography.titleMedium),
                  ],
                ),
                const SizedBox(height: 14),
                _OnboardingField(
                  label: 'School / Institution Name',
                  ctrl: _school12Ctrl,
                  hint: 'St. Mary\'s Junior College',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _OnboardingField(
                        label: 'Board (e.g. CBSE)',
                        ctrl: _board12Ctrl,
                        hint: 'CBSE',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _OnboardingField(
                        label: 'Pct (%)',
                        ctrl: _pct12Ctrl,
                        hint: '94.8%',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _OnboardingField(
                        label: 'Year',
                        ctrl: _year12Ctrl,
                        hint: '2022',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 28),
          AppButton(
            label: _saving ? 'Saving...' : (isSkip ? 'Skip →' : AppStrings.next),
            onTap: _saving ? null : _save,
            isLoading: _saving,
            variant: isSkip ? AppButtonVariant.ghost : AppButtonVariant.accent,
          ),
        ],
      ),
    );
  }
}

class _SummaryStep extends ConsumerStatefulWidget {
  const _SummaryStep();

  @override
  ConsumerState<_SummaryStep> createState() => _SummaryStepState();
}

class _SummaryStepState extends ConsumerState<_SummaryStep> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      if (_ctrl.text.trim().isNotEmpty) {
        await ref.read(profileRepositoryProvider).updateUser(uid, {
          'summary': _ctrl.text.trim(),
          'onboardingComplete': true,
        });
      } else {
        await ref.read(profileRepositoryProvider).updateUser(uid, {
          'onboardingComplete': true,
        });
      }
      if (mounted) {
        ref.read(onboardingStepProvider.notifier).state++;
      }
    } catch (e, stack) {
      debugPrint('Error completing onboarding: $e');
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Professional Summary',
              style: AppTypography.displaySmall),
          const SizedBox(height: 8),
          Text('Optional — AI can also generate this from your profile.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: 24),
          TextField(
            controller: _ctrl,
            maxLines: 6,
            decoration: InputDecoration(
              hintText:
                  'e.g., Software engineer with 3+ years experience in Flutter and Firebase, passionate about building AI-first mobile applications...',
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 32),
          AppButton(
            label: AppStrings.finish,
            onTap: _saving ? null : _save,
            isLoading: _saving,
            variant: AppButtonVariant.accent,
          ),
        ],
      ),
    );
  }
}

class _CompletionStep extends ConsumerWidget {
  const _CompletionStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _SuccessAnimation(),
          const SizedBox(height: 32),
          Text(
            AppStrings.profileComplete,
            style: AppTypography.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.profileCompleteSubtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          AppButton(
            label: 'Go to Dashboard',
            onTap: () => context.go(RouteNames.dashboard),
            variant: AppButtonVariant.accent,
            icon: Icons.home_rounded,
          ),
        ],
      ),
    );
  }
}

class _SuccessAnimation extends StatefulWidget {
  const _SuccessAnimation();

  @override
  State<_SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<_SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
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
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.successLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded,
            size: 48, color: AppColors.success),
      ),
    );
  }
}

class _OnboardingField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? keyboardType;

  const _OnboardingField({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
