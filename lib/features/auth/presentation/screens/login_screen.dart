import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/cache/screen_persistence.dart';
import '../providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/utils/error_sanitizer.dart';
import 'package:url_launcher/url_launcher.dart';

// Restricting login to Google Sign-In only

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  StreamSubscription<User?>? _authSubscription;

  // Timers and states for interactive bear high-five feature
  bool _askingForHighFive = false;
  bool _highFiveClicked = false;
  Timer? _highFiveTimer;
  Timer? _highFiveResetTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(_fade);
    _ctrl.forward();

    // Active auth listener: if background authentication resolves while on login screen, forward immediately
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        _navigateOnSuccess();
      }
    });

    // Safety check: if user is already authenticated, forward immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          _navigateOnSuccess();
        }
      }
    });

    // Start high five prompt timer
    _startHighFiveTimer();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _ctrl.dispose();
    _highFiveTimer?.cancel();
    _highFiveResetTimer?.cancel();
    super.dispose();
  }

  void _startHighFiveTimer({bool isRepeat = false}) {
    _highFiveTimer?.cancel();
    _highFiveResetTimer?.cancel();
    final delay =
        isRepeat ? const Duration(minutes: 3) : const Duration(seconds: 2);
    _highFiveTimer = Timer(delay, () {
      if (mounted && !_highFiveClicked) {
        setState(() {
          _askingForHighFive = true;
        });
        // Auto-lower the paw after 8 seconds if not clicked
        _highFiveResetTimer?.cancel();
        _highFiveResetTimer = Timer(const Duration(seconds: 8), () {
          if (mounted && !_highFiveClicked) {
            setState(() {
              _askingForHighFive = false;
            });
            // Lowered paw, repeat again in 3 minutes!
            _startHighFiveTimer(isRepeat: true);
          }
        });
      }
    });
  }

  void _onHighFiveTapped() {
    _highFiveTimer?.cancel();
    _highFiveResetTimer?.cancel();
    setState(() {
      _askingForHighFive = false;
      _highFiveClicked = true;
    });
    _highFiveResetTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _highFiveClicked = false;
          _startHighFiveTimer(
              isRepeat: true); // Repeat in 3 minutes after successful click!
        });
      }
    });
  }

  Future<void> _navigateOnSuccess() async {
    if (!mounted) return;
    final error = ref.read(authNotifierProvider).error;
    if (error != null) {
      final errStr = error.toString();
      if (errStr.contains('ACCOUNT_DELETED:')) {
        final msg = errStr.split('ACCOUNT_DELETED:').last.trim();
        _showAccountStatusDialog(
          isDeleted: true,
          title: 'Account Deactivated',
          message: msg,
        );
        return;
      }
      if (errStr.contains('ACCOUNT_ON_HOLD:')) {
        final msg = errStr.split('ACCOUNT_ON_HOLD:').last.trim();
        _showAccountStatusDialog(
          isDeleted: false,
          title: 'Account On Hold',
          message: msg,
        );
        return;
      }
      _showError(_friendlyError(errStr));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go(RouteNames.login);
      return;
    }

    await ScreenPersistence.saveAuthUid(user.uid);
    final savedRoute = await ScreenPersistence.getLastRoute();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};

      // Check if account has been deleted
      final isDeleted = (data['isDeleted'] as bool? ?? false) || (data['accountStatus'] == 'deleted');
      if (isDeleted) {
        await FirebaseAuth.instance.signOut();
        await ScreenPersistence.clearAll();
        final reason = (data['deletionReason'] as String?)?.isNotEmpty == true
            ? data['deletionReason'] as String
            : 'Unauthorized activity';
        _showAccountStatusDialog(
          isDeleted: true,
          title: 'Account Deactivated',
          message: 'Your account with this email (${user.email}) was deleted by our team for the reason: $reason. You cannot access your account or create an account with this email ID.',
        );
        return;
      }

      // Check if account is on hold
      final isHold = data['accountStatus'] == 'hold';
      if (isHold) {
        DateTime? holdUntil;
        final hu = data['holdUntil'];
        if (hu is Timestamp) {
          holdUntil = hu.toDate();
        } else if (hu is String && hu.isNotEmpty) {
          holdUntil = DateTime.tryParse(hu);
        }
        final isStillHeld = holdUntil == null || DateTime.now().isBefore(holdUntil);
        if (isStillHeld) {
          await FirebaseAuth.instance.signOut();
          await ScreenPersistence.clearAll();
          final reason = (data['holdReason'] as String?)?.isNotEmpty == true
              ? data['holdReason'] as String
              : 'Detected unauthorized activity';
          final holdUntilStr = holdUntil != null
              ? ' until ${holdUntil.toLocal().toString().split('.').first}'
              : ' indefinitely pending administrative review';
          _showAccountStatusDialog(
            isDeleted: false,
            title: 'Account On Hold',
            message: 'Your account has been placed on hold$holdUntilStr due to detected unauthorized activity. During this time, no activity is allowed. Reason: $reason.',
          );
          return;
        }
      }

      // Mark onboarding complete in background to prevent ever locking user into onboarding
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'onboardingComplete': true}).catchError((_) {});

      final targetRoute = (savedRoute != null &&
              savedRoute.isNotEmpty &&
              !savedRoute.contains('login') &&
              !savedRoute.contains('splash') &&
              !savedRoute.contains('otp') &&
              !savedRoute.contains('account-deleted'))
          ? savedRoute
          : RouteNames.dashboard;

      if (!mounted) return;
      context.go(targetRoute);
    } catch (_) {
      if (mounted) {
        final targetRoute = (savedRoute != null &&
                savedRoute.isNotEmpty &&
                !savedRoute.contains('login') &&
                !savedRoute.contains('splash') &&
                !savedRoute.contains('otp'))
            ? savedRoute
            : RouteNames.dashboard;
        context.go(targetRoute);
      }
    }
  }

  void _showAccountStatusDialog({
    required bool isDeleted,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13111C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDeleted
                ? const Color(0xFFF43F5E).withValues(alpha: 0.4)
                : const Color(0xFFF59E0B).withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            Icon(
              isDeleted ? Icons.block_rounded : Icons.pause_circle_filled_rounded,
              color: isDeleted ? const Color(0xFFF43F5E) : const Color(0xFFF59E0B),
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDeleted
                    ? const Color(0xFFF43F5E).withValues(alpha: 0.08)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDeleted
                      ? const Color(0xFFF43F5E).withValues(alpha: 0.2)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!isDeleted)
            TextButton(
              onPressed: () async {
                final uri = Uri.parse('mailto:support@resumeos.app?subject=Account%20Hold%20Inquiry');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: const Text(
                'Contact Support',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDeleted ? const Color(0xFFF43F5E) : const Color(0xFFF59E0B),
              foregroundColor: isDeleted ? Colors.white : Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('wrong-password') || raw.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('user-not-found')) {
      return 'No account found with that email.';
    }
    if (raw.contains('email-already-in-use') ||
        raw.contains('account-exists-with-different-credential')) {
      return 'An account already exists with this email using a different sign-in method. Try logging in with your password or Google, or delete the old user in the Firebase Console.';
    }
    if (raw.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    }
    if (raw.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (raw.contains('network')) {
      return 'Network error. Check your connection.';
    }
    if (raw.contains('cancelled') || raw.contains('aborted')) {
      return 'Sign in was cancelled.';
    }
    return 'Something went wrong. Please try again.\nDetails: $raw';
  }

  void _showError(String msg) {
    final sanitizedMsg = ErrorSanitizer.sanitize(msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(sanitizedMsg)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    _navigateOnSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final screenWidth = MediaQuery.of(context).size.width;

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF8B6B58),
          selectionHandleColor: Color(0xFF8B6B58),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFCFAF7),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFCFAF7), // Soft premium warm ivory top
                Color(0xFFF9F6F0), // Clean warm base
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 440),
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth > 500 ? 36 : 24,
                        vertical: screenWidth > 500 ? 36 : 28,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(screenWidth > 500 ? 28 : 20),
                        border: Border.all(
                          color: const Color(0xFFF0EAE3),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5A453A).withValues(alpha: 0.04),
                            blurRadius: 32,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. ResumeOS Brand Lockup (Refined R. ResumeOS)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'R.',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF8B6B58),
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ResumeOS',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                  color: const Color(0xFF2D231E),
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28), // 24-32px spacing

                          // 2. Clear Value Proposition
                          Text(
                            'Build a resume that\ngets noticed.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2D231E),
                              height: 1.22,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 10), // 8-12px spacing

                          // 3. Supporting Description
                          Text(
                            'Analyze the job. Tailor your resume.\nApply with confidence.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF7A6E65),
                              height: 1.45,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 24), // 20-28px spacing

                          // 4. Subtle Supporting Mascot Element (~45% footprint reduction)
                          _InteractiveBear(
                            compact: true,
                            coverEyes: false,
                            eyeShift: 0.0,
                            showHi: false,
                            askingForHighFive: _askingForHighFive,
                            highFiveClicked: _highFiveClicked,
                            onHighFiveTapped: _onHighFiveTapped,
                          ),
                          const SizedBox(height: 28), // 24-32px spacing

                          // 5 & 6. Google Login CTA & Legal Links
                          _buildLandingButtons(isLoading),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // SCREEN 1: Choose Auth Provider
  Widget _buildLandingButtons(bool isLoading) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Branded Google Button (pill shape, 54px height, sentence-case)
        _TapScaleButton(
          onTap: isLoading ? null : _signInWithGoogle,
          child: Container(
            width: double.infinity,
            height: 54, // within 52-58px
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(27), // pill shape
              border: Border.all(
                color: const Color(0xFFE5DDD5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2D231E).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B6B58)),
                    ),
                  )
                else ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(painter: _GooglePainter()),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF2D231E),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 26), // 24-28px spacing

        // Active Legal Links
        _LegalLinks(),
      ],
    );
  }
}

// Interactive Bear Rendering
class _InteractiveBear extends StatefulWidget {
  final bool coverEyes;
  final double eyeShift;
  final bool showHi;
  final bool askingForHighFive;
  final bool highFiveClicked;
  final VoidCallback onHighFiveTapped;

  final bool compact;

  const _InteractiveBear({
    required this.coverEyes,
    required this.eyeShift,
    required this.showHi,
    required this.askingForHighFive,
    required this.highFiveClicked,
    required this.onHighFiveTapped,
    this.compact = true,
  });

  @override
  State<_InteractiveBear> createState() => _InteractiveBearState();
}

class _InteractiveBearState extends State<_InteractiveBear>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnim;

  late AnimationController _waveController;
  late Animation<double> _waveAnim;

  late AnimationController _blinkController;
  late AnimationController _clapController;
  late Animation<double> _clapAnim;

  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();

    // 1. Squash and stretch idle breathing loop
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    );
    _breathingAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _breathingController, curve: Curves.easeInOutSine),
    );
    _breathingController.repeat(reverse: true);

    // 2. Paw waving rotation loop (asking for high five)
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    _waveAnim = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOutSine),
    );
    _waveController.repeat(reverse: true);

    // 3. Eyelid blink controller (140ms duration)
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 140),
      vsync: this,
    );

    // 4. Spring clap reaction bounce controller
    _clapController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _clapAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
    ]).animate(_clapController);

    // Start natural random-interval blinking timer
    _startBlinkingTimer();
  }

  @override
  void didUpdateWidget(covariant _InteractiveBear oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highFiveClicked && !oldWidget.highFiveClicked) {
      _clapController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _waveController.dispose();
    _blinkController.dispose();
    _clapController.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _startBlinkingTimer() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 4000), (timer) {
      if (mounted && !widget.coverEyes && !widget.highFiveClicked) {
        _blinkController.forward().then((_) {
          if (mounted) _blinkController.reverse();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return GestureDetector(
        onTap: widget.onHighFiveTapped,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 110,
          height: 100,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: Listenable.merge([_breathingAnim, _clapAnim]),
              builder: (context, child) {
                final breathingVal = _breathingAnim.value;
                final scaleY = (1.0 + breathingVal * 0.015) * _clapAnim.value;
                final scaleX = (1.0 - breathingVal * 0.008) * _clapAnim.value;
                final yTranslation = breathingVal * 2.5;

                return Transform.translate(
                  offset: Offset(0.0, yTranslation),
                  child: Transform.scale(
                    scaleX: scaleX,
                    scaleY: scaleY,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: 160,
                height: 155,
                child: _buildBearContent(),
              ),
            ),
          ),
        ),
      );
    }

    final showBubble =
        widget.askingForHighFive || widget.highFiveClicked || widget.showHi;

    return SizedBox(
      width: 200,
      height:
          230, // Increased to fully allocate vertical space and prevent overlap
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Speech Bubble - situated safely inside the widget box to prevent overlapping subtitle
          Positioned(
            left: 0,
            right: 0,
            top: widget.highFiveClicked ? 0 : 15,
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: widget.coverEyes ? 0.0 : 1.0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: showBubble ? 1.0 : 0.0,
                  ),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.elasticOut, // Springy bounce entry
                  builder: (context, scaleVal, child) {
                    if (scaleVal == 0.0) return const SizedBox.shrink();
                    return Transform.scale(
                      scale: scaleVal,
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: const Color(0xFFE5D5C8), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5A453A)
                                  .withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.highFiveClicked
                              ? "Nice to meet you!\nLet's start your journey"
                              : (widget.askingForHighFive
                                  ? "High Five! 🖐️"
                                  : "Hi! 👋"),
                          style: TextStyle(
                            color: const Color(0xFF5A453A),
                            fontWeight: FontWeight.w900,
                            fontSize: widget.highFiveClicked ? 11 : 13,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Pointer Tail
                      CustomPaint(
                        size: const Size(12, 7),
                        painter: _BubbleTailPainter(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bear Body & Head Base
          Positioned(
            bottom: 0,
            child: AnimatedBuilder(
              animation: Listenable.merge([_breathingAnim, _clapAnim]),
              builder: (context, child) {
                final breathingVal = _breathingAnim.value;
                final scaleY = (1.0 + breathingVal * 0.015) * _clapAnim.value;
                final scaleX = (1.0 - breathingVal * 0.008) * _clapAnim.value;
                final yTranslation = breathingVal * 2.5;

                return Transform.translate(
                  offset: Offset(0.0, yTranslation),
                  child: Transform.scale(
                    scaleX: scaleX,
                    scaleY: scaleY,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: 160,
                height: 155,
                child: _buildBearContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBearContent() {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
                    // 1. Torso/Body of the bear at the bottom
                    Positioned(
                      bottom: 0,
                      child: Container(
                        width: 104,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF8A593D),
                              Color(0xFF6E432C),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          border: Border.all(
                              color: const Color(0xFF70452E), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // Cream Belly Patch
                            Positioned(
                              bottom: 0,
                              child: Container(
                                width: 58,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFF7F3EE),
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFE5D5C8)
                                        .withValues(alpha: 0.5),
                                    width: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. Head sitting/overlapping torso
                    Positioned(
                      bottom: 38,
                      child: SizedBox(
                        width: 114,
                        height: 104,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Ears
                            // Left Ear
                            Positioned(
                              top: -2,
                              left: 2,
                              child: AnimatedRotation(
                                duration: const Duration(milliseconds: 300),
                                turns: widget.highFiveClicked ? -0.06 : 0.0,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    gradient: const RadialGradient(
                                      colors: [
                                        Color(0xFFA8775B),
                                        Color(0xFF8A593D),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(
                                        color: const Color(0xFF70452E),
                                        width: 1.5),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFFFFD1D1),
                                            Color(0xFFFFB7B2),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Right Ear
                            Positioned(
                              top: -2,
                              right: 2,
                              child: AnimatedRotation(
                                duration: const Duration(milliseconds: 300),
                                turns: widget.highFiveClicked ? 0.06 : 0.0,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    gradient: const RadialGradient(
                                      colors: [
                                        Color(0xFFA8775B),
                                        Color(0xFF8A593D),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(
                                        color: const Color(0xFF70452E),
                                        width: 1.5),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFFFFD1D1),
                                            Color(0xFFFFB7B2),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Head Shape
                            Container(
                              width: 114,
                              height: 104,
                              decoration: BoxDecoration(
                                gradient: const RadialGradient(
                                  center: Alignment(0.0, -0.2),
                                  radius: 0.85,
                                  colors: [
                                    Color(0xFFA8775B),
                                    Color(0xFF8A593D),
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(48),
                                  topRight: Radius.circular(48),
                                  bottomLeft: Radius.circular(24),
                                  bottomRight: Radius.circular(24),
                                ),
                                border: Border.all(
                                    color: const Color(0xFF70452E), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),

                            // Cute Hair Tuft on top of head
                            Positioned(
                              top: -6,
                              left: 45,
                              child: Container(
                                width: 9,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8A593D),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                    topRight: Radius.circular(2),
                                  ),
                                  border: Border.all(
                                      color: const Color(0xFF70452E),
                                      width: 1.0),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -9,
                              left: 53,
                              child: Container(
                                width: 12,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8A593D),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                    topRight: Radius.circular(4),
                                  ),
                                  border: Border.all(
                                      color: const Color(0xFF70452E),
                                      width: 1.0),
                                ),
                              ),
                            ),

                            // Purple Cap (Hat) - scaled down beautifully
                            Positioned(
                              top: -12,
                              child: Transform.rotate(
                                angle: -0.05,
                                child: AnimatedRotation(
                                  duration: const Duration(milliseconds: 300),
                                  turns: widget.highFiveClicked ? 0.02 : 0.0,
                                  child: Container(
                                    width: 34,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF9575CD),
                                          Color(0xFF7E57C2),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        topRight: Radius.circular(20),
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.topCenter,
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          top: -5,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              gradient: RadialGradient(
                                                colors: [
                                                  Color(0xFFEDE7F6),
                                                  Color(0xFFD1C4E9),
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Snout/Muzzle
                            Positioned(
                              bottom: 10,
                              child: Container(
                                width: 52,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFF7F3EE),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: const Color(0xFFE5D5C8),
                                      width: 1.0),
                                ),
                                child: CustomPaint(
                                  painter: _SnoutPainter(
                                      highFiveClicked: widget.highFiveClicked),
                                ),
                              ),
                            ),

                            // Eyebrows
                            Positioned(
                              top: 22,
                              left: 24,
                              child: Transform.rotate(
                                angle: 0.08,
                                child: Container(
                                  width: 13,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5E4131),
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 22,
                              right: 24,
                              child: Transform.rotate(
                                angle: -0.08,
                                child: Container(
                                  width: 13,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5E4131),
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                              ),
                            ),

                            // Eye Blinking & Trackers (Left and Right Eyes)
                            Positioned(
                              top: 30,
                              left: 24,
                              child: AnimatedBuilder(
                                animation: _blinkController,
                                builder: (context, _) {
                                  double shiftX = widget.eyeShift;
                                  double shiftY = 0.0;

                                  if (widget.coverEyes) {
                                    shiftX = 0.0;
                                  } else if (widget.askingForHighFive) {
                                    shiftX = 2.0;
                                    shiftY = -1.8;
                                  } else if (widget.eyeShift != 0.0) {
                                    shiftY = 1.6;
                                  }

                                  return CustomPaint(
                                    size: const Size(14, 19),
                                    painter: _BearEyePainter(
                                      blinkProgress: _blinkController.value,
                                      eyeShift: shiftX,
                                      eyeLookUp: shiftY,
                                      isHappy: widget.highFiveClicked,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 30,
                              right: 24,
                              child: AnimatedBuilder(
                                animation: _blinkController,
                                builder: (context, _) {
                                  double shiftX = widget.eyeShift;
                                  double shiftY = 0.0;

                                  if (widget.coverEyes) {
                                    shiftX = 0.0;
                                  } else if (widget.askingForHighFive) {
                                    shiftX = 2.0;
                                    shiftY = -1.8;
                                  } else if (widget.eyeShift != 0.0) {
                                    shiftY = 1.6;
                                  }

                                  return CustomPaint(
                                    size: const Size(14, 19),
                                    painter: _BearEyePainter(
                                      blinkProgress: _blinkController.value,
                                      eyeShift: shiftX,
                                      eyeLookUp: shiftY,
                                      isHappy: widget.highFiveClicked,
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Soft Airbrushed Cheeks
                            Positioned(
                              top: 46,
                              left: 8,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: widget.highFiveClicked ? 26 : 20,
                                height: widget.highFiveClicked ? 14 : 10,
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.pink.withValues(
                                          alpha: widget.highFiveClicked
                                              ? 0.65
                                              : 0.35),
                                      Colors.pink.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 46,
                              right: 8,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: widget.highFiveClicked ? 26 : 20,
                                height: widget.highFiveClicked ? 14 : 10,
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.pink.withValues(
                                          alpha: widget.highFiveClicked
                                              ? 0.65
                                              : 0.35),
                                      Colors.pink.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Left connected organic arm - attached to body
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutBack,
                      bottom: widget.coverEyes
                          ? 42
                          : -36, // Cozy resting at torso base!
                      left: widget.coverEyes ? 16 : 14,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                            begin: 0.0, end: widget.coverEyes ? 0.15 : 0.0),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        builder: (context, angle, child) {
                          return Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()..rotateZ(angle),
                            child: child,
                          );
                        },
                        child: SizedBox(
                          width: 32,
                          height: 76,
                          child: CustomPaint(
                            painter: _BearArmPainter(
                                isLeft: true, isHighFiveActive: false),
                          ),
                        ),
                      ),
                    ),

                    // 4. Right connected organic arm (Waving hand!)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutBack,
                      bottom: widget.coverEyes
                          ? 42
                          : ((widget.askingForHighFive ||
                                  widget.highFiveClicked)
                              ? 48
                              : -36),
                      right: widget.coverEyes
                          ? 16
                          : ((widget.askingForHighFive ||
                                  widget.highFiveClicked)
                              ? -12
                              : 14),
                      child: AnimatedBuilder(
                        animation: _waveAnim,
                        builder: (context, child) {
                          double angle = 0.0;
                          if (widget.coverEyes) {
                            angle = -0.15;
                          } else if (widget.highFiveClicked) {
                            angle = -0.4;
                          } else if (widget.askingForHighFive) {
                            angle = -0.55 + _waveAnim.value;
                          }
                          return Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()..rotateZ(angle),
                            child: child!,
                          );
                        },
                        child: GestureDetector(
                          onTap: (widget.askingForHighFive ||
                                  widget.highFiveClicked)
                              ? widget.onHighFiveTapped
                              : null,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 32,
                            height: 76,
                            child: CustomPaint(
                              painter: _BearArmPainter(
                                isLeft: false,
                                isHighFiveActive: widget.askingForHighFive ||
                                    widget.highFiveClicked,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
  }
}

// ── Eyelid & Pupil custom painter ───────────────────────────

class _BearEyePainter extends CustomPainter {
  final double blinkProgress;
  final double eyeShift;
  final double eyeLookUp;
  final bool isHappy;

  _BearEyePainter({
    required this.blinkProgress,
    required this.eyeShift,
    required this.eyeLookUp,
    required this.isHappy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..isAntiAlias = true;

    if (isHappy) {
      // Adorable happy crescent smiling eye arches (^^)
      paint
        ..color = const Color(0xFF352219)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;

      final path = Path()
        ..moveTo(2, size.height - 4)
        ..quadraticBezierTo(size.width / 2, 4, size.width - 2, size.height - 4);
      canvas.drawPath(path, paint);
      return;
    }

    // 1. Draw Sclera (White eye backing shape)
    paint
      ..color = const Color(0xFFF7F3EE)
      ..style = PaintingStyle.fill;
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(size.width / 2));
    canvas.drawRRect(rrect, paint);

    // Subtle inner shadow for eye depth
    paint
      ..color = const Color(0xFF70452E).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, paint);
    paint.style = PaintingStyle.fill;

    // 2. Draw Pupil (if not fully closed by eyelids)
    if (blinkProgress < 0.85) {
      final pupilWidth = size.width * 0.7;
      final pupilHeight = size.height * 0.75;

      // Horizontal and vertical look gaze adjustment with clamping
      final pupilX = (size.width - pupilWidth) / 2 + eyeShift.clamp(-2.0, 2.0);
      final pupilY =
          (size.height - pupilHeight) / 2 + eyeLookUp.clamp(-2.0, 2.0);

      final pupilRect = Rect.fromLTWH(pupilX, pupilY, pupilWidth, pupilHeight);
      paint.color = const Color(0xFF352219);
      canvas.drawRRect(
        RRect.fromRectAndRadius(pupilRect, Radius.circular(pupilWidth / 2)),
        paint,
      );

      // Eye gloss highlight reflection dot
      paint.color = Colors.white;
      canvas.drawCircle(Offset(pupilX + 2.5, pupilY + 3.0), 1.6, paint);
    }

    // 3. Draw Fur Eyelid (sliding down from top based on blinkProgress)
    if (blinkProgress > 0.0) {
      paint.color = const Color(0xFF8A593D); // Matching brown fur

      final lidHeight = size.height * blinkProgress;
      final lidRect = Rect.fromLTWH(0, 0, size.width, lidHeight);

      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(lidRect, paint);

      // Eyelash dividing border line
      paint
        ..color = const Color(0xFF352219)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawLine(
          Offset(0, lidHeight), Offset(size.width, lidHeight), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BearEyePainter oldDelegate) {
    return oldDelegate.blinkProgress != blinkProgress ||
        oldDelegate.eyeShift != eyeShift ||
        oldDelegate.eyeLookUp != eyeLookUp ||
        oldDelegate.isHappy != isHappy;
  }
}

// ── Connected Fluffy Organic Arm Custom Painter ──────────────

class _BearArmPainter extends CustomPainter {
  final bool isLeft;
  final bool isHighFiveActive;

  _BearArmPainter({required this.isLeft, required this.isHighFiveActive});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..isAntiAlias = true;

    // Outer soft drop shadow for limb separation
    final shadowPath = Path()
      ..addRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(size.width / 2)));
    canvas.drawShadow(
        shadowPath, Colors.black.withValues(alpha: 0.1), 3.0, true);

    // 1. Draw fuzzy connection arm sleeve (linear gradient fur)
    paint.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Color(0xFF6E412A),
        Color(0xFF8A593D),
      ],
    ).createShader(rect);

    final armRRect =
        RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.45));
    canvas.drawRRect(armRRect, paint);
    paint.shader = null;

    // Claymorphic highlights
    paint
      ..color = const Color(0xFFA8775B).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(armRRect, paint);
    paint.style = PaintingStyle.fill;

    // 2. Draw Fleshy Pink Palm Pad
    final palmWidth = size.width * 0.65;
    final palmHeight = size.height * 0.25;
    final palmRect = Rect.fromLTWH(
      (size.width - palmWidth) / 2,
      size.height * 0.15,
      palmWidth,
      palmHeight,
    );
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFD1D1),
        Color(0xFFFFB7B2),
      ],
    ).createShader(palmRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(palmRect, Radius.circular(palmWidth * 0.45)),
      paint,
    );
    paint.shader = null;

    // 3. Draw 3 round fleshy finger pads at top of paw
    final fingerRadius = size.width * 0.12;
    final fingerPaint = Paint()
      ..color = const Color(0xFFFFB7B2)
      ..style = PaintingStyle.fill;

    // Left finger pad
    canvas.drawCircle(Offset(size.width * 0.26, size.height * 0.1),
        fingerRadius, fingerPaint);
    // Middle finger pad (slightly taller)
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.07),
        fingerRadius * 1.15, fingerPaint);
    // Right finger pad
    canvas.drawCircle(Offset(size.width * 0.74, size.height * 0.1),
        fingerRadius, fingerPaint);

    // 4. Draw tiny cute organic claws at the top tip of each finger pad
    final clawPaint = Paint()
      ..color = const Color(0xFF352219)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.26, size.height * 0.1 - fingerRadius),
      Offset(size.width * 0.26, size.height * 0.1 - fingerRadius - 2.5),
      clawPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.07 - fingerRadius * 1.15),
      Offset(size.width * 0.5, size.height * 0.07 - fingerRadius * 1.15 - 3.0),
      clawPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.74, size.height * 0.1 - fingerRadius),
      Offset(size.width * 0.74, size.height * 0.1 - fingerRadius - 2.5),
      clawPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BearArmPainter oldDelegate) {
    return oldDelegate.isLeft != isLeft ||
        oldDelegate.isHighFiveActive != isHighFiveActive;
  }
}

// ── Speech Bubble Pointed Pointer custom painter ─────────────

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFE5D5C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
    // Draw only sides so it merges seamlessly with speech bubble container bottom border!
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Reusable Premium Tap Scaling Button ─────────────────────

class _TapScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TapScaleButton({required this.child, this.onTap});

  @override
  State<_TapScaleButton> createState() => _TapScaleButtonState();
}

class _TapScaleButtonState extends State<_TapScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null;

    return GestureDetector(
      onTapDown: isInteractive ? (_) => _controller.forward() : null,
      onTapUp: isInteractive
          ? (_) {
              _controller.reverse();
              widget.onTap!();
            }
          : null,
      onTapCancel: isInteractive ? () => _controller.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// ── Interactive Snout / Muzzle ──────────────────────────────

class _SnoutPainter extends CustomPainter {
  final bool highFiveClicked;
  _SnoutPainter({required this.highFiveClicked});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF352219)
      ..style = PaintingStyle.fill;

    // Curved nose shape
    final nosePath = Path()
      ..moveTo(size.width / 2 - 5, 11)
      ..quadraticBezierTo(size.width / 2, 7, size.width / 2 + 5, 11)
      ..quadraticBezierTo(size.width / 2 + 4, 16, size.width / 2, 16)
      ..quadraticBezierTo(size.width / 2 - 4, 16, size.width / 2 - 5, 11);
    canvas.drawPath(nosePath, paint);

    // Nose glossy reflection highlight dot
    final shinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2 - 1.5, 10), 1.0, shinePaint);

    // Mouth smile lines
    final linePaint = Paint()
      ..color = const Color(0xFF352219)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // Small vertical divider
    canvas.drawLine(
        Offset(size.width / 2, 16), Offset(size.width / 2, 21), linePaint);

    if (highFiveClicked) {
      // Adorable open happy mouth with tongue!
      final mouthPaint = Paint()
        ..color = const Color(0xFFEA4335) // Red open mouth backdrop
        ..style = PaintingStyle.fill;
      final mouthPath = Path()
        ..moveTo(size.width / 2 - 8, 20)
        ..quadraticBezierTo(size.width / 2, 32, size.width / 2 + 8, 20)
        ..close();
      canvas.drawPath(mouthPath, mouthPaint);

      final tonguePaint = Paint()
        ..color = const Color(0xFFFFB7B2) // Rosy tongue
        ..style = PaintingStyle.fill;
      final tonguePath = Path()
        ..moveTo(size.width / 2 - 5, 25)
        ..quadraticBezierTo(size.width / 2, 32, size.width / 2 + 5, 25)
        ..close();
      canvas.drawPath(tonguePath, tonguePaint);
    } else {
      // Lips smile curves
      final smilePath = Path()
        ..moveTo(size.width / 2 - 6, 20)
        ..quadraticBezierTo(size.width / 2 - 3, 23, size.width / 2, 21)
        ..quadraticBezierTo(size.width / 2 + 3, 23, size.width / 2 + 6, 20);
      canvas.drawPath(smilePath, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnoutPainter oldDelegate) =>
      oldDelegate.highFiveClicked != highFiveClicked;
}

// ── Google Logo Vector Drawing ──────────────────────────────

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final Offset c = Offset(r, r);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final rect = Rect.fromCircle(center: c, radius: r);

    // 1. Red Top Arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.8, true, paint);

    // 2. Yellow Left Arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -3.8, 1.4, true, paint);

    // 3. Green Bottom Arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.8, 1.6, true, paint);

    // 4. Blue Right Arc & Horizontal Bar
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.6, 1.4, true, paint);

    final barRect = Rect.fromLTWH(c.dx, c.dy - r * 0.2, r * 0.95, r * 0.4);
    canvas.drawRect(barRect, paint);

    // Cover the center to form clean cutout
    paint.color = Colors.white;
    canvas.drawCircle(c, r * 0.6, paint);

    // Cut out top right to expose horizontal blue bar perfectly
    final wedgePath = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + r, c.dy - r * 0.25)
      ..lineTo(c.dx + r, c.dy + r * 0.2)
      ..close();
    canvas.drawPath(wedgePath, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Legal Active Hyperlinks ─────────────────────────────────

class _LegalLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'By continuing, you agree to our',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF8C827A),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GestureDetector(
              onTap: () => context.push(RouteNames.terms),
              child: Text(
                'Terms of Service',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF5A453A),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: const Color(0xFF8B6B58).withValues(alpha: 0.5),
                ),
              ),
            ),
            Text(
              ' and ',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF8C827A),
              ),
            ),
            GestureDetector(
              onTap: () => context.push(RouteNames.privacy),
              child: Text(
                'Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF5A453A),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: const Color(0xFF8B6B58).withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
