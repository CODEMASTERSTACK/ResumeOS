import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../routes/route_names.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../services/ai/ai_service.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';

// ── Step index provider ────────────────────────────────────
final onboardingStepProvider = StateProvider.autoDispose<int>((ref) => 0);

class OnboardingWrapper extends ConsumerStatefulWidget {
  const OnboardingWrapper({super.key});

  @override
  ConsumerState<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends ConsumerState<OnboardingWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _transitionController;
  late Animation<double> _bgColorAnimation;
  late Animation<double> _contentOpacityAnimation;
  late Animation<double> _contentScaleAnimation;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Radial expansion animation (using a premium cubic curve)
    _bgColorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Content fade out (slightly offset to let the wave start first)
    _contentOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );

    // Content scale down (giving it a depth/zoom-out effect)
    _contentScaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  Future<void> _startDashboardTransition() async {
    if (_isTransitioning) return;
    setState(() {
      _isTransitioning = true;
    });

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid != null) {
      try {
        await ref.read(profileRepositoryProvider).updateUser(uid, {
          'onboardingComplete': true,
        });
      } catch (e) {
        debugPrint('Error completing onboarding: $e');
      }
    }

    await _transitionController.forward();

    if (mounted) {
      context.go(RouteNames.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final step = ref.watch(onboardingStepProvider);
    final steps = [
      const _WelcomeStep(),
      const _DomainBackgroundStep(),
      const _BasicDetailsStep(),
      const _SkillsStep(),
      const _EducationStep(),
      const _SummaryStep(),
      _CompletionStep(
        onGoToDashboard: _startDashboardTransition,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: IgnorePointer(
        ignoring: _isTransitioning,
        child: AnimatedBuilder(
          animation: _transitionController,
          builder: (context, child) {
            return Stack(
              children: [
                // 1. Original gradient background
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFCFAF7),
                          Colors.white,
                        ],
                      ),
                    ),
                  ),
                ),
                // 2. Home screen background radial transition overlay (premium motion graphics)
                if (_isTransitioning)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: _bgColorAnimation.value * 2.8,
                          colors: [
                            const Color(0xFF07060F), // Rich dark indigo base
                            const Color(0xFF07060F),
                            const Color(0xFF723FFD).withValues(alpha: 0.85), // Glowing purple leading edge
                            const Color(0xFFEC53B0).withValues(alpha: 0.45), // Glowing magenta ring
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.78, 0.88, 0.96, 1.0],
                        ),
                      ),
                    ),
                  ),
                // 3. Fading and scaling onboarding content
                Positioned.fill(
                  child: Opacity(
                    opacity: _contentOpacityAnimation.value,
                    child: Transform.scale(
                      scale: _contentScaleAnimation.value,
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          },
          child: SafeArea(
            child: Column(
              children: [
                // Top Header Bar containing Back button, Step progress indicator, Skip, and Logout button
                Padding(
                  padding: const EdgeInsets.only(
                      left: 24, right: 24, top: 12, bottom: 4),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left Side: Step count and Back button
                          if (step > 0 && step < steps.length - 1)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (step > 0) ...[
                                  GestureDetector(
                                    onTap: () {
                                      ref.read(onboardingStepProvider.notifier).state--;
                                    },
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF8F5),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFE5D5C8).withValues(alpha: 0.5),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_back_ios_new_rounded,
                                          size: 12,
                                          color: Color(0xFF8B6B58),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  'Step $step of ${steps.length - 2}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8B6B58),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          else
                            const SizedBox.shrink(),

                          // Right Side: Skip button (if applicable) & Logout button
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (step > 2 && step < steps.length - 1) ...[
                                TextButton(
                                  onPressed: () async {
                                    final notifier = ref.read(onboardingStepProvider.notifier);
                                    if (step == steps.length - 2) {
                                      final uid = ref.read(currentUserProvider)?.uid;
                                      if (uid != null) {
                                        try {
                                          await ref.read(profileRepositoryProvider).updateUser(uid, {
                                            'onboardingComplete': true,
                                          });
                                        } catch (e) {
                                          debugPrint('Error updating onboardingComplete: $e');
                                        }
                                      }
                                    }
                                    notifier.state++;
                                  },
                                  child: const Text(
                                    'Skip',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF8B6B58),
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              
                              // Logout Button
                              TextButton.icon(
                                onPressed: () async {
                                  await ref.read(authNotifierProvider.notifier).signOut();
                                  if (context.mounted) {
                                    context.go(RouteNames.login);
                                  }
                                },
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  size: 14,
                                  color: Color(0xFF8B6B58),
                                ),
                                label: const Text(
                                  'Logout',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8B6B58),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: const Color(0xFFFAF8F5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: const Color(0xFFE5D5C8).withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (step > 0 && step < steps.length - 1) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: step / (steps.length - 2),
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF3EFEA),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF8B6B58)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Step content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: SizedBox(
                        width: screenWidth > 550 ? 500 : double.infinity,
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
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step Widgets ───────────────────────────────────────────

class _WelcomeIllustration extends StatefulWidget {
  const _WelcomeIllustration();

  @override
  State<_WelcomeIllustration> createState() => _WelcomeIllustrationState();
}

class _WelcomeIllustrationState extends State<_WelcomeIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          // Bobbing animation for balloon
          final double bobbing = _ctrl.value * 8.0 - 4.0;
          
          // Horizontal drifting for clouds
          final double drift1 = _ctrl.value * 24.0 - 12.0;
          final double drift2 = (1.0 - _ctrl.value) * 20.0 - 10.0;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Cloud 1 (Behind, floating left-to-right)
              Positioned(
                left: 40 + drift1,
                top: 40,
                child: _buildCloud(width: 64, height: 28, opacity: 0.4),
              ),

              // Cloud 2 (Behind, float right-to-left)
              Positioned(
                right: 50 + drift2,
                top: 80,
                child: _buildCloud(width: 80, height: 32, opacity: 0.5),
              ),

              // Hot Air Balloon (In center, bobbing vertically)
              Transform.translate(
                offset: Offset(0, bobbing),
                child: const SizedBox(
                  width: 140,
                  height: 180,
                  child: CustomPaint(
                    painter: _BalloonPainter(),
                  ),
                ),
              ),

              // Cloud 3 (In front, floating left-to-right)
              Positioned(
                left: 80 + drift2,
                bottom: 30,
                child: _buildCloud(width: 72, height: 30, opacity: 0.85),
              ),

              // Cloud 4 (In front, bottom-right)
              Positioned(
                right: 30 + drift1,
                bottom: 50,
                child: _buildCloud(width: 56, height: 26, opacity: 0.9),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCloud({required double width, required double height, required double opacity}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF3EFEA).withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A453A).withValues(alpha: 0.03 * opacity),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

class _BalloonPainter extends CustomPainter {
  const _BalloonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw balloon envelope
    final path = Path();
    final center = Offset(size.width / 2, size.height * 0.4);
    final radius = size.width * 0.35;

    // A beautiful tapered balloon shape
    path.moveTo(center.dx, center.dy - radius);
    
    // Top circle arc
    path.arcToPoint(
      Offset(center.dx + radius * 0.9, center.dy + radius * 0.2),
      radius: Radius.circular(radius),
      clockwise: true,
    );

    // Taper to bottom neck
    path.quadraticBezierTo(
      center.dx + radius * 0.8,
      center.dy + radius * 0.8,
      center.dx + radius * 0.25,
      center.dy + radius * 1.15,
    );

    // Bottom straight edge of neck
    path.lineTo(center.dx - radius * 0.25, center.dy + radius * 1.15);

    // Taper back to left
    path.quadraticBezierTo(
      center.dx - radius * 0.8,
      center.dy + radius * 0.8,
      center.dx - radius * 0.9,
      center.dy + radius * 0.2,
    );

    path.arcToPoint(
      Offset(center.dx, center.dy - radius),
      radius: Radius.circular(radius),
      clockwise: true,
    );

    path.close();

    // Fill with warm brown gradient
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFC4AB9B), // Lighter soft brown
        Color(0xFF8B6B58), // Slate brown
      ],
    );
    paint.shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, paint);

    // Draw vertical stripes to add depth
    final stripePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF5A453A).withValues(alpha: 0.15);
    
    // Center stripe
    final centerStripe = Path();
    centerStripe.moveTo(center.dx - radius * 0.1, center.dy - radius);
    centerStripe.quadraticBezierTo(
      center.dx - radius * 0.05,
      center.dy + radius * 0.3,
      center.dx - radius * 0.08,
      center.dy + radius * 1.15,
    );
    centerStripe.lineTo(center.dx + radius * 0.08, center.dy + radius * 1.15);
    centerStripe.quadraticBezierTo(
      center.dx + radius * 0.05,
      center.dy + radius * 0.3,
      center.dx + radius * 0.1,
      center.dy - radius,
    );
    centerStripe.close();
    canvas.drawPath(centerStripe, stripePaint);

    // Right stripe
    final rightStripe = Path();
    rightStripe.moveTo(center.dx + radius * 0.4, center.dy - radius * 0.82);
    rightStripe.quadraticBezierTo(
      center.dx + radius * 0.45,
      center.dy + radius * 0.2,
      center.dx + radius * 0.18,
      center.dy + radius * 1.15,
    );
    rightStripe.lineTo(center.dx + radius * 0.25, center.dy + radius * 1.15);
    rightStripe.quadraticBezierTo(
      center.dx + radius * 0.7,
      center.dy + radius * 0.2,
      center.dx + radius * 0.65,
      center.dy - radius * 0.68,
    );
    rightStripe.close();
    canvas.drawPath(rightStripe, stripePaint);

    // Left stripe
    final leftStripe = Path();
    leftStripe.moveTo(center.dx - radius * 0.4, center.dy - radius * 0.82);
    leftStripe.quadraticBezierTo(
      center.dx - radius * 0.45,
      center.dy + radius * 0.2,
      center.dx - radius * 0.18,
      center.dy + radius * 1.15,
    );
    leftStripe.lineTo(center.dx - radius * 0.25, center.dy + radius * 1.15);
    leftStripe.quadraticBezierTo(
      center.dx - radius * 0.7,
      center.dy + radius * 0.2,
      center.dx - radius * 0.65,
      center.dy - radius * 0.68,
    );
    leftStripe.close();
    canvas.drawPath(leftStripe, stripePaint);

    // Draw basket ropes
    final ropePaint = Paint()
      ..color = const Color(0xFF8B6B58)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final ropeYStart = center.dy + radius * 1.15;
    final ropeYEnd = ropeYStart + size.height * 0.12;

    canvas.drawLine(Offset(center.dx - radius * 0.2, ropeYStart), Offset(center.dx - radius * 0.12, ropeYEnd), ropePaint);
    canvas.drawLine(Offset(center.dx - radius * 0.08, ropeYStart), Offset(center.dx - radius * 0.04, ropeYEnd), ropePaint);
    canvas.drawLine(Offset(center.dx + radius * 0.08, ropeYStart), Offset(center.dx + radius * 0.04, ropeYEnd), ropePaint);
    canvas.drawLine(Offset(center.dx + radius * 0.2, ropeYStart), Offset(center.dx + radius * 0.12, ropeYEnd), ropePaint);

    // Draw basket
    final basketPaint = Paint()
      ..color = const Color(0xFF5A453A)
      ..style = PaintingStyle.fill;
    final basketRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        center.dx - radius * 0.15,
        ropeYEnd,
        radius * 0.3,
        size.height * 0.14,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(basketRect, basketPaint);

    // Draw a small decorative accent line on the basket
    final basketAccentPaint = Paint()
      ..color = const Color(0xFFE5D5C8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx - radius * 0.1, ropeYEnd + size.height * 0.07),
      Offset(center.dx + radius * 0.1, ropeYEnd + size.height * 0.07),
      basketAccentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WelcomeStep extends ConsumerWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Illustration of Hot Air Balloon with Floating Clouds
        const _WelcomeIllustration(),
        const SizedBox(height: 32),

        // Title
        const Text(
          "Let's get started",
          style: TextStyle(
            fontSize: 28,
            color: Color(0xFF5A453A),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Description 1
        const Text(
          "Welcome, Now we'll need some information to know you better and so we can give you best output.",
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF8B6B58),
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Description 2
        const Text(
          "First we need to ask you a few questions. We'll store any info you give us securely and only share it with your permission.",
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF8B6B58),
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),

        // Page Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final isActive = index == 0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 8 : 6,
              height: isActive ? 8 : 6,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF8B6B58)
                    : const Color(0xFF8B6B58).withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
        const SizedBox(height: 28),

        // Next CTA Button with springy tactile tap scale
        _TapScaleButton(
          onTap: () => ref.read(onboardingStepProvider.notifier).state = 1,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF8B6B58),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B6B58).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Next',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _DomainBackgroundStep extends ConsumerStatefulWidget {
  const _DomainBackgroundStep();

  @override
  ConsumerState<_DomainBackgroundStep> createState() =>
      _DomainBackgroundStepState();
}

class _DomainBackgroundStepState extends ConsumerState<_DomainBackgroundStep> {
  String _selectedDomain = '';
  String? _domainError;
  bool _saving = false;
  bool _showInfo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider).value;
      if (user != null) {
        _selectedDomain = user.domainBackground;
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _save() async {
    if (_selectedDomain.isEmpty) {
      setState(() {
        _domainError = 'Please select your domain background to continue';
      });
      return;
    }

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      ref.read(onboardingStepProvider.notifier).state++;
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateUser(uid, {
        'domainBackground': _selectedDomain,
      });
      if (mounted) {
        ref.read(onboardingStepProvider.notifier).state++;
      }
    } catch (e, stack) {
      debugPrint('Error saving domain background during onboarding: $e');
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving domain background: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showKnowYourDomainBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Color(0xFFFCFAF7),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5D5C8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(
                    Icons.explore_outlined,
                    color: Color(0xFF8B6B58),
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Explore Career Domains',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5A453A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Understand where your profession falls to optimize your resume and career suggestions.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8B6B58),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              
              // Flexible scroll list
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildBottomSheetDomainSection(
                        title: 'Technical Domain',
                        icon: Icons.code_rounded,
                        description: 'Engineering, software development, data systems, and quantitative scientific roles.',
                        roles: [
                          'Software Engineer / Developer',
                          'Data Scientist / Analyst',
                          'DevOps / Cloud Architect',
                          'Systems Administrator',
                          'QA / Test Engineer',
                          'Cybersecurity Specialist',
                          'Research Scientist',
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBottomSheetDomainSection(
                        title: 'Non-Technical Domain',
                        icon: Icons.palette_rounded,
                        description: 'Operations, marketing, creative design, sales, human resources, and business administration.',
                        roles: [
                          'UX/UI Designer / Graphic Designer',
                          'Marketing Manager / Content Writer',
                          'HR Specialist / Talent Acquisition',
                          'Sales Executive / Account Manager',
                          'Operations Manager / Coordinator',
                          'Customer Success Specialist',
                          'Accountant / Financial Analyst',
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBottomSheetDomainSection(
                        title: 'Both (Hybrid / Cross-functional)',
                        icon: Icons.layers_rounded,
                        description: 'Interdisciplinary roles requiring technical coordination, business leadership, or domain expertise in both areas.',
                        roles: [
                          'Product Manager / Product Owner',
                          'IT Project Manager / Scrum Master',
                          'Technical Writer / Documentation Spec',
                          'Solutions Architect / Pre-Sales',
                          'Technical Support Engineer',
                          'Technical Recruiter',
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Close button
              _TapScaleButton(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B6B58),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text(
                      'GOT IT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
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

  Widget _buildBottomSheetDomainSection({
    required String title,
    required IconData icon,
    required String description,
    required List<String> roles,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5D5C8).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF8B6B58), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5A453A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8B6B58),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: roles.map((role) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF8F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5D5C8).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  role,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5A453A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainCard(String title, String description, IconData icon) {
    final isSelected = _selectedDomain == title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _TapScaleButton(
        onTap: () {
          setState(() {
            _selectedDomain = title;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFAF8F5) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF8B6B58)
                  : const Color(0xFFE5D5C8).withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF8B6B58).withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF8B6B58).withValues(alpha: 0.1)
                      : const Color(0xFFFAF8F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? const Color(0xFF8B6B58) : const Color(0xFF8B6B58).withValues(alpha: 0.6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? const Color(0xFF5A453A) : const Color(0xFF8B6B58),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? const Color(0xFF8B6B58)
                            : const Color(0xFF8B6B58).withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8B6B58) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF8B6B58)
                        : const Color(0xFFE5D5C8),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Text(
                'What is your domain background?',
                style: TextStyle(
                  fontSize: 24,
                  color: Color(0xFF5A453A),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _showInfo = !_showInfo),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _showInfo
                      ? const Color(0xFF8B6B58).withValues(alpha: 0.1)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: _showInfo ? const Color(0xFF8B6B58) : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Select the option that best represents your career path.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF8B6B58),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_showInfo)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5D5C8), width: 1),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: Color(0xFF8B6B58),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your selected career domain allows the AI to tailor resume templates, formatting, and suggestions optimized for your specific field.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B6B58),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 28),
        _buildDomainCard('Technical', 'Software, Engineering, IT, Data Science, etc.', Icons.code_rounded),
        _buildDomainCard('Non-Technical', 'Marketing, Design, HR, Management, Finance, etc.', Icons.palette_rounded),
        _buildDomainCard('Both', 'Hybrid roles, IT Project Management, Product, etc.', Icons.layers_rounded),
        if (_domainError != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 6),
                Text(
                  _domainError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        _TapScaleButton(
          onTap: _saving ? null : _save,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8B6B58),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B6B58).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'CONTINUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () => _showKnowYourDomainBottomSheet(context),
            icon: const Icon(
              Icons.help_outline_rounded,
              size: 16,
              color: Color(0xFF8B6B58),
            ),
            label: const Text(
              'Know your domain',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF8B6B58),
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
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
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _githubCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  String _selectedGender = '';
  bool _saving = false;

  // Autofill states
  bool _isParsingResume = false;
  String? _extractedPdfName;
  String? _autofillError;

  // Rate limiter: Max 5 uploads per 10 minutes
  static final List<DateTime> _uploadTimestamps = [];

  // In-field warning error states
  String? _nameError;
  String? _phoneError;
  String? _genderError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider).value;
      if (user != null) {
        _nameCtrl.text = user.name;
        _phoneCtrl.text = user.phone;
        final locParts = _parseLocationParts(user.location);
        _cityCtrl.text = locParts['city']!;
        _stateCtrl.text = locParts['state']!;
        _pincodeCtrl.text = locParts['pincode']!;
        _githubCtrl.text = user.githubUrl;
        _linkedinCtrl.text = user.linkedinUrl;
        _selectedGender = user.gender;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _githubCtrl.dispose();
    _linkedinCtrl.dispose();
    super.dispose();
  }

  String _sanitizeInput(String input, {int maxLength = 100}) {
    return input
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  String _sanitizeUrl(String url, String expectedDomain) {
    final cleaned = url.trim();
    if (cleaned.isEmpty) return '';
    try {
      final uri = Uri.parse(cleaned.startsWith('http') ? cleaned : 'https://$cleaned');
      if (uri.host.contains(expectedDomain) && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return uri.toString();
      }
    } catch (_) {}
    return '';
  }

  Map<String, dynamic> _fallbackRegexExtract(String text) {
    final result = <String, dynamic>{};

    // Phone regex
    final phoneMatch = RegExp(r'(\+?\d{1,4}[-.\s]?)?(\(?\d{2,4}\)?[-.\s]?)?[\d\s-]{6,14}\d').firstMatch(text);
    if (phoneMatch != null) {
      result['phone'] = phoneMatch.group(0)?.trim() ?? '';
    }

    // GitHub regex
    final ghMatch = RegExp(r'(?:https?:\/\/)?(?:www\.)?github\.com\/([a-zA-Z0-9_-]+)', caseSensitive: false).firstMatch(text);
    if (ghMatch != null) {
      final raw = ghMatch.group(0) ?? '';
      result['githubUrl'] = raw.startsWith('http') ? raw : 'https://$raw';
    }

    // LinkedIn regex
    final liMatch = RegExp(r'(?:https?:\/\/)?(?:www\.)?linkedin\.com\/in\/([a-zA-Z0-9_-]+)', caseSensitive: false).firstMatch(text);
    if (liMatch != null) {
      final raw = liMatch.group(0) ?? '';
      result['linkedinUrl'] = raw.startsWith('http') ? raw : 'https://$raw';
    }

    // First clean non-link line as candidate name
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isNotEmpty) {
      final firstLine = lines.first;
      if (firstLine.length < 40 && !firstLine.contains('@') && !firstLine.contains('http') && !firstLine.contains('www.')) {
        result['name'] = firstLine;
      }
    }

    // Extract common skills via keyword dictionary
    const knownSkills = [
      'Flutter', 'Dart', 'React', 'React Native', 'Python', 'JavaScript', 'TypeScript',
      'Node.js', 'Express.js', 'Next.js', 'Java', 'C++', 'C#', 'Go', 'Rust', 'PHP',
      'HTML', 'CSS', 'Tailwind CSS', 'SQL', 'PostgreSQL', 'MySQL', 'MongoDB', 'Redis',
      'Firebase', 'AWS', 'Google Cloud', 'Azure', 'Docker', 'Kubernetes', 'Git', 'GitHub',
      'REST APIs', 'GraphQL', 'Figma', 'UI/UX Design', 'Machine Learning', 'Data Analysis'
    ];
    final foundSkills = <String>[];
    for (final skill in knownSkills) {
      final pattern = RegExp('\\b${RegExp.escape(skill)}\\b', caseSensitive: false);
      if (pattern.hasMatch(text)) {
        foundSkills.add(skill);
      }
    }
    if (foundSkills.isNotEmpty) {
      result['skills'] = foundSkills;
    }

    // Extract summary/objective section if available
    final summaryMatch = RegExp(r'(?:summary|objective|about\s+me|profile\s+summary)\s*[:\-\n]+([\s\S]{30,400}?)(?=\n\s*(?:skills|education|experience|projects|certifications|\n\n))', caseSensitive: false).firstMatch(text);
    if (summaryMatch != null) {
      final rawSum = summaryMatch.group(1)?.replaceAll('\n', ' ').trim() ?? '';
      if (rawSum.isNotEmpty) {
        result['summary'] = rawSum;
      }
    }

    return result;
  }

  Future<void> _pickAndAutofillResume() async {
    // 1. Rate Limit Enforcement: Max 5 uploads per 10 minutes
    final now = DateTime.now();
    _uploadTimestamps.removeWhere((ts) => now.difference(ts).inMinutes >= 10);
    if (_uploadTimestamps.length >= 5) {
      final oldest = _uploadTimestamps.first;
      final waitMins = 10 - now.difference(oldest).inMinutes;
      setState(() {
        _autofillError = 'Upload limit reached (max 5 in 10 min). Please try in ${waitMins <= 0 ? 1 : waitMins} min.';
      });
      return;
    }

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isEmpty) {
        return; // User cancelled
      }

      final file = files.first;
      if (file.extension?.toLowerCase() != 'pdf') {
        setState(() {
          _autofillError = 'Only genuine .pdf files are allowed.';
        });
        return;
      }

      setState(() {
        _isParsingResume = true;
        _autofillError = null;
      });

      // 2. Read in-memory only (never stored to cloud)
      final bytes = await file.readAsBytes();

      // 3. Security Check: File Size Limit (Max 5 MB)
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        throw Exception('File size exceeds 5MB limit.');
      }

      // 4. Security Check: PDF Header Signature (%PDF)
      if (bytes.length < 4 ||
          bytes[0] != 0x25 || // %
          bytes[1] != 0x50 || // P
          bytes[2] != 0x44 || // D
          bytes[3] != 0x46) { // F
        throw Exception('Invalid file format: Not a genuine PDF.');
      }

      // Record successful upload attempt for rate limiting
      _uploadTimestamps.add(now);

      // 5. In-memory Text Extraction & Immediate Document Disposal
      String extractedText = '';
      PdfDocument? document;
      try {
        document = PdfDocument(inputBytes: bytes);
        final textExtractor = PdfTextExtractor(document);
        extractedText = textExtractor.extractText();
      } finally {
        document?.dispose(); // Strict in-memory cleanup
      }

      // Sanitize extracted text
      extractedText = extractedText.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '').trim();
      if (extractedText.isEmpty) {
        throw Exception('No readable text found in PDF.');
      }

      Map<String, dynamic> parsedData = {};
      try {
        final ai = ref.read(geminiServiceProvider);
        parsedData = await ai.parseResume(extractedText);
      } catch (aiError) {
        debugPrint('AI parse failed, using secure fallback regex extraction: $aiError');
        parsedData = _fallbackRegexExtract(extractedText);
      }

      if (parsedData.isEmpty) {
        parsedData = _fallbackRegexExtract(extractedText);
      }

      // 6. Sanitize & Populate form controllers (no auto-submit)
      final rawName = _sanitizeInput(parsedData['name'] as String? ?? '', maxLength: 60);
      final rawPhone = _sanitizeInput(parsedData['phone'] as String? ?? '', maxLength: 25);
      final rawCity = _sanitizeInput(parsedData['city'] as String? ?? '', maxLength: 50);
      final rawState = _sanitizeInput(parsedData['state'] as String? ?? '', maxLength: 50);
      final rawPincode = _sanitizeInput(parsedData['pincode'] as String? ?? '', maxLength: 20);
      final rawGithub = _sanitizeUrl(parsedData['githubUrl'] as String? ?? '', 'github.com');
      final rawLinkedin = _sanitizeUrl(parsedData['linkedinUrl'] as String? ?? '', 'linkedin.com');
      final rawGender = _sanitizeInput(parsedData['gender'] as String? ?? '', maxLength: 10);
      final rawSummary = _sanitizeInput(parsedData['summary'] as String? ?? '', maxLength: 1000);
      final rawRole = _sanitizeInput(parsedData['currentRole'] as String? ?? '', maxLength: 80);

      int filledCount = 0;
      if (rawName.isNotEmpty) {
        _nameCtrl.text = rawName;
        _nameError = null;
        filledCount++;
      }
      if (rawPhone.isNotEmpty) {
        _phoneCtrl.text = rawPhone;
        _phoneError = null;
        filledCount++;
      }
      if (rawCity.isNotEmpty) {
        _cityCtrl.text = rawCity;
        filledCount++;
      }
      if (rawState.isNotEmpty) {
        _stateCtrl.text = rawState;
        filledCount++;
      }
      if (rawPincode.isNotEmpty) {
        _pincodeCtrl.text = rawPincode;
        filledCount++;
      }
      if (rawGithub.isNotEmpty) {
        _githubCtrl.text = rawGithub;
        filledCount++;
      }
      if (rawLinkedin.isNotEmpty) {
        _linkedinCtrl.text = rawLinkedin;
        filledCount++;
      }
      if (rawGender.isNotEmpty) {
        final gLower = rawGender.toLowerCase();
        if (gLower.startsWith('m')) {
          _selectedGender = 'Male';
          _genderError = null;
          filledCount++;
        } else if (gLower.startsWith('f')) {
          _selectedGender = 'Female';
          _genderError = null;
          filledCount++;
        }
      }

      // 7. Persist comprehensive extracted data (skills, education, summary, experience) to Firestore
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid != null) {
        final profileRepo = ref.read(profileRepositoryProvider);

        // Update user summary and target role
        final userUpdates = <String, dynamic>{};
        if (rawSummary.isNotEmpty) {
          userUpdates['summary'] = rawSummary;
          filledCount++;
        }
        if (rawRole.isNotEmpty) {
          userUpdates['currentRole'] = rawRole;
        }
        if (userUpdates.isNotEmpty) {
          try {
            await profileRepo.updateUser(uid, userUpdates);
          } catch (e) {
            debugPrint('Error updating user summary during resume autofill: $e');
          }
        }

        // Save extracted skills
        final rawSkills = parsedData['skills'];
        if (rawSkills is List && rawSkills.isNotEmpty) {
          try {
            final existingSkills = await profileRepo.watchSkills(uid).first;
            final existingNames = existingSkills.map((s) => (s['name'] as String? ?? '').toLowerCase().trim()).toSet();
            for (final s in rawSkills) {
              final skillStr = _sanitizeInput(s.toString(), maxLength: 40);
              if (skillStr.isNotEmpty && !existingNames.contains(skillStr.toLowerCase())) {
                await profileRepo.addSkill(uid, skillStr, 'Technical');
                existingNames.add(skillStr.toLowerCase());
                filledCount++;
              }
            }
          } catch (e) {
            debugPrint('Error saving skills during resume autofill: $e');
          }
        }

        // Save extracted education
        final rawEduList = parsedData['education'];
        if (rawEduList is List && rawEduList.isNotEmpty) {
          try {
            final existingEdu = await profileRepo.watchEducation(uid).first;
            for (final item in rawEduList) {
              if (item is Map) {
                final degree = _sanitizeInput(item['degree'] as String? ?? '', maxLength: 80);
                final inst = _sanitizeInput(item['institution'] as String? ?? '', maxLength: 100);
                final board = _sanitizeInput(item['board'] as String? ?? '', maxLength: 60);
                final pct = _sanitizeInput((item['percentage'] ?? item['cgpa'] ?? '').toString(), maxLength: 20);
                final startYr = _sanitizeInput(item['startYear'] as String? ?? '', maxLength: 10);
                final endYr = _sanitizeInput(item['endYear'] as String? ?? '', maxLength: 10);

                if (inst.isNotEmpty || degree.isNotEmpty) {
                  String standardDegree = degree;
                  final degLower = degree.toLowerCase();
                  if (degLower.contains('10th') || degLower.contains('matric') || degLower.contains('secondary school') || degLower.contains('ssc') || degLower.contains('high school')) {
                    standardDegree = '10th Standard';
                  } else if (degLower.contains('12th') || degLower.contains('intermediate') || degLower.contains('higher secondary') || degLower.contains('hsc') || degLower.contains('senior secondary') || degLower.contains('+2')) {
                    standardDegree = '12th Standard';
                  }

                  final existingMatch = existingEdu.where((e) => (e['degree'] as String? ?? '').toLowerCase() == standardDegree.toLowerCase()).firstOrNull;
                  final eduPayload = <String, dynamic>{
                    'degree': standardDegree,
                    'institution': inst,
                    'board': board,
                    'percentage': pct,
                    'startYear': startYr,
                    'endYear': endYr,
                  };

                  if (existingMatch != null) {
                    final id = existingMatch['id'] as String?;
                    if (id != null) {
                      await profileRepo.updateEducation(uid, id, eduPayload);
                    }
                  } else {
                    await profileRepo.addEducation(uid, eduPayload);
                  }
                  filledCount++;
                }
              }
            }
          } catch (e) {
            debugPrint('Error saving education during resume autofill: $e');
          }
        }

        // Save extracted experience
        final rawExpList = parsedData['experience'];
        if (rawExpList is List && rawExpList.isNotEmpty) {
          try {
            final existingExp = await profileRepo.watchExperience(uid).first;
            for (final item in rawExpList) {
              if (item is Map) {
                final role = _sanitizeInput(item['role'] as String? ?? '', maxLength: 80);
                final company = _sanitizeInput(item['company'] as String? ?? '', maxLength: 100);
                final startYr = _sanitizeInput(item['startYear'] as String? ?? '', maxLength: 10);
                final endYr = _sanitizeInput(item['endYear'] as String? ?? '', maxLength: 10);
                final desc = _sanitizeInput(item['description'] as String? ?? '', maxLength: 500);

                if (role.isNotEmpty || company.isNotEmpty) {
                  final exists = existingExp.any((e) =>
                      (e['role'] as String? ?? '').toLowerCase() == role.toLowerCase() &&
                      (e['company'] as String? ?? '').toLowerCase() == company.toLowerCase());
                  if (!exists) {
                    await profileRepo.addExperience(uid, {
                      'role': role,
                      'company': company,
                      'startYear': startYr,
                      'endYear': endYr,
                      'description': desc,
                    });
                    filledCount++;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error saving experience during resume autofill: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _isParsingResume = false;
          if (filledCount > 0) {
            _extractedPdfName = file.name;
            _autofillError = null;
          } else {
            _autofillError = 'Could not extract enough information from ${file.name}.';
          }
        });
      }
    } catch (e) {
      debugPrint('Error parsing resume in onboarding: $e');
      if (mounted) {
        setState(() {
          _isParsingResume = false;
          _autofillError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    String? nameErr;
    String? phoneErr;
    String? genderErr;

    if (name.isEmpty) {
      nameErr = 'Full name is required';
    }
    if (_selectedGender.isEmpty) {
      genderErr = 'Please select your gender';
    }
    if (phone.isEmpty) {
      phoneErr = 'Phone number is required';
    }

    if (nameErr != null || genderErr != null || phoneErr != null) {
      setState(() {
        _nameError = nameErr;
        _phoneError = phoneErr;
        _genderError = genderErr;
      });
      return; // Do NOT show any toast or snackbar
    }

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final city = _cityCtrl.text.trim();
    final state = _stateCtrl.text.trim();
    final pincode = _pincodeCtrl.text.trim();
    final capCity = city.isNotEmpty ? city[0].toUpperCase() + city.substring(1) : '';
    final capState = state.isNotEmpty ? state[0].toUpperCase() + state.substring(1) : '';
    final locationStr = city.isEmpty ? '' : '$capCity, $capState, $pincode';

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateUser(uid, {
        'name': name,
        'phone': phone,
        'location': locationStr,
        'githubUrl': _githubCtrl.text.trim(),
        'linkedinUrl': _linkedinCtrl.text.trim(),
        'gender': _selectedGender,
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

  Widget _buildAutofillBox() {
    final isExtracted = _extractedPdfName != null && _extractedPdfName!.isNotEmpty;
    final hasError = _autofillError != null && _autofillError!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TapScaleButton(
          onTap: _isParsingResume ? null : _pickAndAutofillResume,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isExtracted
                  ? const Color(0xFFF0FDF4)
                  : (hasError ? const Color(0xFFFEF2F2) : const Color(0xFFFAF8F5)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExtracted
                    ? const Color(0xFF10B981)
                    : (hasError ? const Color(0xFFEF4444) : const Color(0xFFE5D5C8)),
                width: isExtracted ? 1.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isExtracted ? const Color(0xFF10B981) : const Color(0xFF8B6B58))
                      .withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isParsingResume
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF8B6B58),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Extracting details from resume...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8B6B58),
                        ),
                      ),
                    ],
                  )
                : isExtracted
                    ? Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Extracted details from $_extractedPdfName',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF065F46),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: Color(0xFF8B6B58),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Autofill with Resume / CV (PDF)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF5A453A),
                            ),
                          ),
                        ],
                      ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFEF4444)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _autofillError!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF5A453A),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: Color(0xFF5A453A), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
            prefixIcon: Icon(icon, size: 16, color: hasError ? const Color(0xFFEF4444) : const Color(0xFF8B6B58)),
            filled: true,
            fillColor: const Color(0xFFFAF8F5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: hasError ? const BorderSide(color: Color(0xFFEF4444), width: 1.5) : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: hasError ? const BorderSide(color: Color(0xFFEF4444), width: 1.5) : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFEF4444) : const Color(0xFF8B6B58),
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFEF4444)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenderCard(String gender, IconData icon) {
    final isSelected = _selectedGender == gender;
    final hasError = _genderError != null && _genderError!.isNotEmpty;
    return _TapScaleButton(
      onTap: () {
        setState(() {
          _selectedGender = gender;
          _genderError = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAF8F5) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8B6B58)
                : (hasError ? const Color(0xFFEF4444) : const Color(0xFFE5D5C8).withValues(alpha: 0.5)),
            width: isSelected ? 1.5 : (hasError ? 1.5 : 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFF8B6B58)
                  : (hasError ? const Color(0xFFEF4444).withValues(alpha: 0.7) : const Color(0xFF8B6B58).withValues(alpha: 0.5)),
            ),
            const SizedBox(width: 8),
            Text(
              gender,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFF5A453A) : const Color(0xFF8B6B58),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 24,
            color: Color(0xFF5A453A),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'This information will appear at the top of all generated resumes.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF8B6B58),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),

        // ── Streamlined Animated Autofill Box ──
        _buildAutofillBox(),
        const SizedBox(height: 18),

        _buildStepField(
          label: 'Full Name *',
          ctrl: _nameCtrl,
          hint: 'John Doe',
          icon: Icons.person_outline_rounded,
          errorText: _nameError,
          onChanged: (val) {
            if (_nameError != null && val.trim().isNotEmpty) {
              setState(() => _nameError = null);
            }
          },
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gender *',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF5A453A),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildGenderCard('Male', Icons.male_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGenderCard('Female', Icons.female_rounded),
                ),
              ],
            ),
            if (_genderError != null && _genderError!.isNotEmpty) ...[
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    Text(
                      _genderError!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _buildStepField(
          label: 'Phone Number *',
          ctrl: _phoneCtrl,
          hint: '+1 (555) 000-0000',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          errorText: _phoneError,
          onChanged: (val) {
            if (_phoneError != null && val.trim().isNotEmpty) {
              setState(() => _phoneError = null);
            }
          },
        ),
        const SizedBox(height: 14),
        _buildStepField(
          label: 'City',
          ctrl: _cityCtrl,
          hint: 'San Francisco',
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 14),
        _buildStepField(
          label: 'State',
          ctrl: _stateCtrl,
          hint: 'CA',
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 14),
        _buildStepField(
          label: 'Pincode',
          ctrl: _pincodeCtrl,
          hint: '94103',
          icon: Icons.pin_drop_outlined,
        ),
        const SizedBox(height: 14),
        _buildStepField(
          label: 'GitHub URL',
          ctrl: _githubCtrl,
          hint: 'https://github.com/username',
          icon: Icons.code_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 14),
        _buildStepField(
          label: 'LinkedIn URL',
          ctrl: _linkedinCtrl,
          hint: 'https://linkedin.com/in/username',
          icon: Icons.work_outline_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 32),
        _TapScaleButton(
          onTap: _saving ? null : _save,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8B6B58),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B6B58).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'CONTINUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, String> _parseLocationParts(String locationStr) {
    final parts = locationStr.split(',').map((s) => s.trim()).toList();
    if (parts.length >= 3) {
      return {
        'city': parts[0],
        'state': parts[1],
        'pincode': parts[2],
      };
    } else if (parts.length == 2) {
      return {
        'city': parts[0],
        'state': parts[1],
        'pincode': '',
      };
    } else if (parts.length == 1) {
      return {
        'city': parts[0],
        'state': '',
        'pincode': '',
      };
    }
    return {
      'city': '',
      'state': '',
      'pincode': '',
    };
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
  List<Map<String, dynamic>> _dbSkillsRaw = [];
  bool _saving = false;

  final _suggestions = [
    'Flutter', 'Dart', 'React', 'Python', 'Node.js',
    'TypeScript', 'Firebase', 'AWS', 'Docker', 'Kubernetes',
    'Git', 'REST APIs', 'GraphQL', 'SQL', 'MongoDB',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid != null) {
        try {
          final dbSkillsList = await ref.read(profileRepositoryProvider).watchSkills(uid).first;
          setState(() {
            _dbSkillsRaw = dbSkillsList;
            for (final s in dbSkillsList) {
              final name = s['name'] as String? ?? '';
              if (name.isNotEmpty && !_skills.contains(name)) {
                _skills.add(name);
              }
            }
          });
        } catch (e) {
          debugPrint('Error loading skills during onboarding: $e');
        }
      }
    });
  }

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

    setState(() => _saving = true);
    try {
      final profileRepo = ref.read(profileRepositoryProvider);

      // Delete skills in database that are NOT in the local _skills list
      for (final dbSkill in _dbSkillsRaw) {
        final name = dbSkill['name'] as String? ?? '';
        final id = dbSkill['id'] as String? ?? '';
        if (name.isNotEmpty && id.isNotEmpty && !_skills.contains(name)) {
          await profileRepo.deleteSkill(uid, id);
        }
      }

      // Add skills in _skills list that are NOT already in the database list
      final dbSkillNames = _dbSkillsRaw.map((s) => s['name'] as String? ?? '').toList();
      for (final skill in _skills) {
        if (!dbSkillNames.contains(skill)) {
          await profileRepo.addSkill(uid, skill, 'General');
        }
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildSuggestionChip(String skill) {
    return GestureDetector(
      onTap: () => _add(skill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3EFEA), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 12, color: Color(0xFF8B6B58)),
            const SizedBox(width: 4),
            Text(
              skill,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF5A453A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillChip(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B6B58).withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            skill,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5A453A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _skills.remove(skill)),
            child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF8B6B58)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Professional Skills',
          style: TextStyle(
            fontSize: 24,
            color: Color(0xFF5A453A),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Add technologies, libraries, tools, and methodologies.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF8B6B58),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        
        // Search Input & Add Button Row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(fontSize: 13, color: Color(0xFF5A453A), fontWeight: FontWeight.w600),
                onSubmitted: _add,
                decoration: InputDecoration(
                  hintText: 'Type a skill and press Enter',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF8B6B58)),
                  filled: true,
                  fillColor: const Color(0xFFFAF8F5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF8B6B58), width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _TapScaleButton(
              onTap: () => _add(_ctrl.text),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B6B58),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B6B58).withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        
        // Suggestions section
        const Text(
          'SUGGESTIONS',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF5A453A),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .where((s) => !_skills.contains(s))
              .map((s) => _buildSuggestionChip(s))
              .toList(),
        ),
        const SizedBox(height: 16),
        
        // Added skills
        if (_skills.isNotEmpty) ...[
          const Text(
            'ADDED SKILLS',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF5A453A),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skills.map((s) => _buildSkillChip(s)).toList(),
          ),
          const SizedBox(height: 20),
        ] else ...[
          const SizedBox(height: 12),
        ],
        
        // Continue / Skip button
        _TapScaleButton(
          onTap: _saving ? null : _save,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: _skills.isEmpty
                  ? Colors.white
                  : (_saving ? const Color(0xFFD4C8C0) : const Color(0xFF8B6B58)),
              borderRadius: BorderRadius.circular(24),
              border: _skills.isEmpty ? Border.all(color: const Color(0xFFE5D5C8), width: 1.5) : null,
              boxShadow: _skills.isEmpty || _saving
                  ? [
                      BoxShadow(
                        color: const Color(0xFF5A453A).withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFF8B6B58).withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _skills.isEmpty ? 'SKIP FOR NOW' : 'CONTINUE',
                      style: TextStyle(
                        color: _skills.isEmpty ? const Color(0xFF5A453A) : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ],
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

  String? _id10;
  String? _id12;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _school10Ctrl.addListener(_onTextChanged);
    _board10Ctrl.addListener(_onTextChanged);
    _school12Ctrl.addListener(_onTextChanged);
    _board12Ctrl.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid != null) {
        try {
          final eduList = await ref.read(profileRepositoryProvider).watchEducation(uid).first;
          for (final edu in eduList) {
            final degree = edu['degree'] as String? ?? '';
            if (degree == '10th Standard') {
              _id10 = edu['id'] as String?;
              _school10Ctrl.text = edu['institution'] as String? ?? '';
              _board10Ctrl.text = edu['board'] as String? ?? '';
              _pct10Ctrl.text = edu['percentage'] as String? ?? '';
              _year10Ctrl.text = edu['endYear'] as String? ?? '';
            } else if (degree == '12th Standard') {
              _id12 = edu['id'] as String?;
              _school12Ctrl.text = edu['institution'] as String? ?? '';
              _board12Ctrl.text = edu['board'] as String? ?? '';
              _pct12Ctrl.text = edu['percentage'] as String? ?? '';
              _year12Ctrl.text = edu['endYear'] as String? ?? '';
            }
          }
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('Error loading education history during onboarding: $e');
        }
      }
    });
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
      
      // Save or update 10th Standard
      if (school10.isNotEmpty || board10.isNotEmpty) {
        final data10 = {
          'degree': '10th Standard',
          'institution': school10,
          'board': board10,
          'percentage': pct10,
          'endYear': year10,
        };
        if (_id10 != null) {
          await profileRepo.updateEducation(uid, _id10!, data10);
        } else {
          await profileRepo.addEducation(uid, data10);
        }
      } else if (_id10 != null) {
        await profileRepo.deleteEducation(uid, _id10!);
      }
      
      // Save or update 12th Standard
      if (school12.isNotEmpty || board12.isNotEmpty) {
        final data12 = {
          'degree': '12th Standard',
          'institution': school12,
          'board': board12,
          'percentage': pct12,
          'endYear': year12,
        };
        if (_id12 != null) {
          await profileRepo.updateEducation(uid, _id12!, data12);
        } else {
          await profileRepo.addEducation(uid, data12);
        }
      } else if (_id12 != null) {
        await profileRepo.deleteEducation(uid, _id12!);
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

  Widget _buildInstitutionField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    required double screenWidth,
  }) {
    final double labelSize = screenWidth < 500 ? 11 : 12;
    final double fontSize = screenWidth < 500 ? 13 : 14;
    final double hintSize = screenWidth < 500 ? 12 : 13;
    final double paddingVertical = screenWidth < 500 ? 12 : 14;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: labelSize,
            color: const Color(0xFF5A453A),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: TextStyle(fontSize: fontSize, color: const Color(0xFF5A453A), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: hintSize, fontWeight: FontWeight.w500),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: paddingVertical),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF3EFEA), width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF3EFEA), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF8B6B58), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSubField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    TextInputType? keyboardType,
    required double screenWidth,
  }) {
    final double labelSize = screenWidth < 500 ? 11 : 12;
    final double fontSize = screenWidth < 500 ? 13 : 14;
    final double hintSize = screenWidth < 500 ? 12 : 13;
    final double paddingVertical = screenWidth < 500 ? 12 : 14;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: labelSize,
            color: const Color(0xFF5A453A),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: fontSize, color: const Color(0xFF5A453A), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: hintSize, fontWeight: FontWeight.w500),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: paddingVertical),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF3EFEA), width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF3EFEA), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF8B6B58), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSkip = _school10Ctrl.text.trim().isEmpty &&
        _board10Ctrl.text.trim().isEmpty &&
        _school12Ctrl.text.trim().isEmpty &&
        _board12Ctrl.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Education History',
          style: TextStyle(
            fontSize: 24,
            color: Color(0xFF5A453A),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Add your qualifications to showcase on your resumes.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF8B6B58),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        
        // ── 10th Standard Card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF3EFEA), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B6B58).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_outlined, color: Color(0xFF8B6B58), size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '10th Standard (High School)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5A453A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInstitutionField(
                label: 'SCHOOL NAME',
                ctrl: _school10Ctrl,
                hint: "e.g., St. Mary's School",
                screenWidth: screenWidth,
              ),
              const SizedBox(height: 12),
              if (screenWidth < 500) ...[
                _buildFormSubField(
                  label: 'BOARD',
                  ctrl: _board10Ctrl,
                  hint: 'CBSE',
                  screenWidth: screenWidth,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormSubField(
                        label: 'PCT (%)',
                        ctrl: _pct10Ctrl,
                        hint: '92.4%',
                        screenWidth: screenWidth,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFormSubField(
                        label: 'YEAR',
                        ctrl: _year10Ctrl,
                        hint: '2020',
                        keyboardType: TextInputType.number,
                        screenWidth: screenWidth,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildFormSubField(
                        label: 'BOARD',
                        ctrl: _board10Ctrl,
                        hint: 'CBSE',
                        screenWidth: screenWidth,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildFormSubField(
                        label: 'PCT (%)',
                        ctrl: _pct10Ctrl,
                        hint: '92.4%',
                        screenWidth: screenWidth,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildFormSubField(
                        label: 'YEAR',
                        ctrl: _year10Ctrl,
                        hint: '2020',
                        keyboardType: TextInputType.number,
                        screenWidth: screenWidth,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // ── 12th Standard Card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF3EFEA), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B6B58).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_rounded, color: Color(0xFF8B6B58), size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '12th Standard (Intermediate)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5A453A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInstitutionField(
                label: 'SCHOOL / INSTITUTION NAME',
                ctrl: _school12Ctrl,
                hint: "e.g., St. Mary's Junior College",
                screenWidth: screenWidth,
              ),
              const SizedBox(height: 12),
              if (screenWidth < 500) ...[
                _buildFormSubField(
                  label: 'BOARD',
                  ctrl: _board12Ctrl,
                  hint: 'CBSE',
                  screenWidth: screenWidth,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormSubField(
                        label: 'PCT (%)',
                        ctrl: _pct12Ctrl,
                        hint: '94.8%',
                        screenWidth: screenWidth,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFormSubField(
                        label: 'YEAR',
                        ctrl: _year12Ctrl,
                        hint: '2022',
                        keyboardType: TextInputType.number,
                        screenWidth: screenWidth,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildFormSubField(
                        label: 'BOARD',
                        ctrl: _board12Ctrl,
                        hint: 'CBSE',
                        screenWidth: screenWidth,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildFormSubField(
                        label: 'PCT (%)',
                        ctrl: _pct12Ctrl,
                        hint: '94.8%',
                        screenWidth: screenWidth,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildFormSubField(
                        label: 'YEAR',
                        ctrl: _year12Ctrl,
                        hint: '2022',
                        keyboardType: TextInputType.number,
                        screenWidth: screenWidth,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Next / Skip action
        _TapScaleButton(
          onTap: _saving ? null : _save,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: isSkip ? Colors.white : const Color(0xFF8B6B58),
              borderRadius: BorderRadius.circular(24),
              border: isSkip ? Border.all(color: const Color(0xFFE5D5C8), width: 1.5) : null,
              boxShadow: isSkip
                  ? [
                      BoxShadow(
                        color: const Color(0xFF5A453A).withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFF8B6B58).withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isSkip ? 'SKIP FOR NOW' : 'CONTINUE',
                      style: TextStyle(
                        color: isSkip ? const Color(0xFF5A453A) : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ],
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
  bool _consentChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider).value;
      if (user != null && user.summary.isNotEmpty) {
        _ctrl.text = user.summary;
        if (mounted) setState(() {});
      }
    });
  }

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
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isButtonEnabled = !_saving && _consentChecked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Professional Summary',
          style: TextStyle(
            fontSize: 24,
            color: Color(0xFF5A453A),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Optional: You can generate the professional summary later with the help of AI.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF8B6B58),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _ctrl,
          maxLines: 6,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF5A453A),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'e.g., Software engineer with 3+ years experience in Flutter and Firebase, passionate about building AI-first mobile applications...',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: const Color(0xFFFAF8F5),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFF3EFEA), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFF3EFEA), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF8B6B58), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Consent Checkbox
        GestureDetector(
          onTap: () {
            setState(() {
              _consentChecked = !_consentChecked;
            });
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _consentChecked ? const Color(0xFF8B6B58) : const Color(0xFFFAF8F5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _consentChecked
                            ? const Color(0xFF8B6B58)
                            : const Color(0xFFE5D5C8),
                        width: 1.5,
                      ),
                    ),
                    child: _consentChecked
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'The information i have provided is correct and it can be used for my purpose.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5A453A),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        
        _TapScaleButton(
          onTap: isButtonEnabled ? _save : null,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: isButtonEnabled
                  ? const Color(0xFF8B6B58)
                  : const Color(0xFFD4C8C0), // Premium disabled gray-brown
              borderRadius: BorderRadius.circular(24),
              boxShadow: isButtonEnabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFF8B6B58).withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'FINISH & COMPLETE',
                      style: TextStyle(
                        color: isButtonEnabled ? Colors.white : const Color(0xFF9E8E85),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}


class _CompletionStep extends ConsumerWidget {
  final VoidCallback? onGoToDashboard;
  const _CompletionStep({this.onGoToDashboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        const _SuccessAnimation(),
        const SizedBox(height: 28),
        const Text(
          'All Set!',
          style: TextStyle(
            fontSize: 26,
            color: Color(0xFF5A453A),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'Your profile is ready. Let\'s explore customized career paths and tailored job recommendations generated by AI.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF8B6B58),
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        _TapScaleButton(
          onTap: onGoToDashboard,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8B6B58),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B6B58).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'GO TO DASHBOARD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
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
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0xFF8B6B58).withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF8B6B58).withValues(alpha: 0.2), width: 1.5),
        ),
        child: Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF8B6B58),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B6B58).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tap Scale Micro-Animation Wrapper ───────────────────────

class _TapScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TapScaleButton({required this.child, this.onTap});

  @override
  State<_TapScaleButton> createState() => _TapScaleButtonState();
}

class _TapScaleButtonState extends State<_TapScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.onTap != null ? _ctrl.forward() : null,
      onTapUp: (_) {
        if (widget.onTap != null) {
          _ctrl.reverse();
          widget.onTap!();
        }
      },
      onTapCancel: () => widget.onTap != null ? _ctrl.reverse() : null,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
