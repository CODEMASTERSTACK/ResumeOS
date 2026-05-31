import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../routes/route_names.dart';
import '../providers/auth_provider.dart';

// ── Mode provider ──────────────────────────────────────────
enum _AuthMode { signIn, signUp }

final _authModeProvider = StateProvider((_) => _AuthMode.signIn);

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

  // Form controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Focus Nodes for Bear Animation
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _nameFocusNode = FocusNode();

  bool _obscure = true;
  bool _showEmailForm = false; // Landing vs Email Form State
  bool _coverEyes = false;
  double _eyeShift = 0.0;

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

    // Listeners for Bear Animation
    _emailFocusNode.addListener(_onEmailFocusChange);
    _passwordFocusNode.addListener(_onPasswordFocusChange);
    _emailCtrl.addListener(_onEmailTextChange);

    // Start high five prompt timer
    _startHighFiveTimer();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();

    _emailFocusNode.removeListener(_onEmailFocusChange);
    _passwordFocusNode.removeListener(_onPasswordFocusChange);
    _emailCtrl.removeListener(_onEmailTextChange);

    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _nameFocusNode.dispose();

    _highFiveTimer?.cancel();
    _highFiveResetTimer?.cancel();
    super.dispose();
  }

  void _onEmailFocusChange() {
    setState(() {
      if (_emailFocusNode.hasFocus) {
        _coverEyes = false;
        _onEmailTextChange();
      } else {
        _eyeShift = 0.0;
      }
    });
  }

  void _onPasswordFocusChange() {
    setState(() {
      _coverEyes = _passwordFocusNode.hasFocus;
      if (_coverEyes) {
        _askingForHighFive = false;
        _highFiveTimer?.cancel();
        _highFiveResetTimer?.cancel();
      } else {
        _startHighFiveTimer();
      }
    });
  }

  void _startHighFiveTimer({bool isRepeat = false}) {
    _highFiveTimer?.cancel();
    _highFiveResetTimer?.cancel();
    final delay = isRepeat ? const Duration(minutes: 3) : const Duration(seconds: 2);
    _highFiveTimer = Timer(delay, () {
      if (mounted && !_highFiveClicked && !_coverEyes) {
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
          _startHighFiveTimer(isRepeat: true); // Repeat in 3 minutes after successful click!
        });
      }
    });
  }

  void _onEmailTextChange() {
    if (_emailFocusNode.hasFocus) {
      final len = _emailCtrl.text.length;
      setState(() {
        // Shift pupil horizontally based on typed character count
        // 15 is roughly the center character count for emails
        _eyeShift = ((len.toDouble() - 15.0) / 12.0).clamp(-4.0, 4.0);
      });
    }
  }

  Future<void> _navigateOnSuccess() async {
    if (!mounted) return;
    final error = ref.read(authNotifierProvider).error;
    if (error == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        context.go(RouteNames.login);
        return;
      }
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final onboardingComplete =
            doc.data()?['onboardingComplete'] as bool? ?? false;

        if (!mounted) return;
        if (onboardingComplete) {
          context.go(RouteNames.dashboard);
        } else {
          context.go(RouteNames.onboarding);
        }
      } catch (_) {
        if (mounted) context.go(RouteNames.onboarding);
      }
    } else {
      _showError(_friendlyError(error.toString()));
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('user-not-found')) return 'No account found with that email.';
    if (raw.contains('email-already-in-use') || raw.contains('account-exists-with-different-credential')) {
      return 'An account already exists with this email using a different sign-in method. Try logging in with your password or Google, or delete the old user in the Firebase Console.';
    }
    if (raw.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    }
    if (raw.contains('invalid-email')) return 'Please enter a valid email address.';
    if (raw.contains('network')) return 'Network error. Check your connection.';
    if (raw.contains('cancelled') || raw.contains('aborted')) {
      return 'Sign in was cancelled.';
    }
    return 'Something went wrong. Please try again.\nDetails: $raw';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    _navigateOnSuccess();
  }

  Future<void> _submitEmailForm() async {
    if (!_formKey.currentState!.validate()) return;
    final mode = ref.read(_authModeProvider);
    if (mode == _AuthMode.signIn) {
      await ref.read(authNotifierProvider.notifier).signInWithEmail(
            _emailCtrl.text,
            _passwordCtrl.text,
          );
      _navigateOnSuccess();
    } else {
      await ref.read(authNotifierProvider.notifier).createAccount(
            _emailCtrl.text,
            _passwordCtrl.text,
            _nameCtrl.text,
          );
      if (!mounted) return;
      final error = ref.read(authNotifierProvider).error;
      if (error == null) {
        context.go(RouteNames.onboarding);
      } else {
        _showError(_friendlyError(error.toString()));
      }
    }
  }

  void _forgotPassword() {
    context.push(RouteNames.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(_authModeProvider);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFCFAF7), // Soft premium warm top
              Colors.white,       // Clean white base
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Container(
                    width: screenWidth > 500 ? 450 : double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(screenWidth > 500 ? 28 : 0),
                      border: screenWidth > 500
                          ? Border.all(color: const Color(0xFFF3EFEA), width: 1.5)
                          : null,
                      boxShadow: screenWidth > 500
                          ? [
                              BoxShadow(
                                color: const Color(0xFF5A453A).withValues(alpha: 0.04),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Styled Text Logo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'smartresume',
                              style: TextStyle(
                                fontSize: 32,
                                color: const Color(0xFF5A453A),
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                              ),
                            ),
                            Text(
                              '.',
                              style: TextStyle(
                                fontSize: 32,
                                color: const Color(0xFF7E57C2), // Purple dot matching hat
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        Text(
                          'ANALYSE. CREATE. ACE', // Fixed typo with parenthesis
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8B6B58),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Interactive Bear Animation
                        _InteractiveBear(
                          coverEyes: _coverEyes,
                          eyeShift: _eyeShift,
                          showHi: !_showEmailForm,
                          askingForHighFive: _askingForHighFive,
                          highFiveClicked: _highFiveClicked,
                          onHighFiveTapped: _onHighFiveTapped,
                        ),
                        const SizedBox(height: 36),

                        // Layout switcher based on Landing vs Form state
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 300),
                          firstCurve: Curves.easeInOut,
                          secondCurve: Curves.easeInOut,
                          crossFadeState: _showEmailForm
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: _buildLandingButtons(isLoading, mode),
                          secondChild: _buildEmailForm(isLoading, mode),
                        ),
                      ],
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
  Widget _buildLandingButtons(bool isLoading, _AuthMode mode) {
    return Column(
      children: [
        // 1. Email Button (pill, brown)
        _TapScaleButton(
          onTap: () {
            setState(() => _showEmailForm = true);
          },
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
                Icon(Icons.email_rounded, color: Colors.white, size: 18),
                SizedBox(width: 12),
                Text(
                  'CONTINUE WITH EMAIL',
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

        // 2. Branded Google Button (pill, clean white with border and official branding)
        _TapScaleButton(
          onTap: isLoading ? null : _signInWithGoogle,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5D5C8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5A453A).withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CustomPaint(painter: _GooglePainter()),
                ),
                const SizedBox(width: 12),
                const Text(
                  'CONTINUE WITH GOOGLE',
                  style: TextStyle(
                    color: Color(0xFF5A453A),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Sign In / Sign Up Mode toggle link
        _ModeToggleLink(
          mode: mode,
          onToggle: () {
            setState(() {
              _showEmailForm = true;
            });
          },
        ),
        const SizedBox(height: 36),

        // Active Legal Links
        _LegalLinks(),
      ],
    );
  }

  // SCREEN 2: Email & Password Form Inputs
  Widget _buildEmailForm(bool isLoading, _AuthMode mode) {
    return Column(
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              if (mode == _AuthMode.signUp) ...[
                _buildFormField(
                  key: 'field_name',
                  ctrl: _nameCtrl,
                  focusNode: _nameFocusNode,
                  hint: 'Name',
                  icon: Icons.person_outline_rounded,
                  validator: (v) => (v ?? '').isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 12),
              ],
              _buildFormField(
                key: 'field_email',
                ctrl: _emailCtrl,
                focusNode: _emailFocusNode,
                hint: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Email required';
                  if (!v!.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildFormField(
                key: 'field_password',
                ctrl: _passwordCtrl,
                focusNode: _passwordFocusNode,
                hint: 'Password',
                icon: Icons.vpn_key_outlined,
                obscure: _obscure,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.grey.shade500,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Password required';
                  if (mode == _AuthMode.signUp && v!.length < 6) {
                    return 'Minimum 6 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Primary Submit Button with spring scale
        _TapScaleButton(
          onTap: isLoading ? null : _submitEmailForm,
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
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      mode == _AuthMode.signIn ? 'LOGIN WITH EMAIL' : 'CREATE ACCOUNT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (mode == _AuthMode.signIn) ...[
          // Forgot Password Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Forgot Password ? ',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
              GestureDetector(
                onTap: _forgotPassword,
                child: const Text(
                  'Click Here',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5A453A),
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Sign In / Sign Up Mode toggle link inside form
        _ModeToggleLink(mode: mode),
        const SizedBox(height: 24),

        // Back to landing options link
        GestureDetector(
          onTap: () {
            setState(() {
              _showEmailForm = false;
              _coverEyes = false;
              _eyeShift = 0.0;
            });
            _emailFocusNode.unfocus();
            _passwordFocusNode.unfocus();
          },
          child: const Text(
            '← Other Login Options',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF8B6B58),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // Helper widget to construct beautifully rounded inputs matching reference
  Widget _buildFormField({
    required String key,
    required TextEditingController ctrl,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: Key(key),
      controller: ctrl,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 13, color: Color(0xFF5A453A), fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, size: 16, color: const Color(0xFF8B6B58)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFFAF8F5), // Cleaner, softer warm cream color
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.error, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}

// ── Interactive Bear Rendering ─────────────────────────────

class _InteractiveBear extends StatefulWidget {
  final bool coverEyes;
  final double eyeShift;
  final bool showHi;
  final bool askingForHighFive;
  final bool highFiveClicked;
  final VoidCallback onHighFiveTapped;

  const _InteractiveBear({
    required this.coverEyes,
    required this.eyeShift,
    required this.showHi,
    required this.askingForHighFive,
    required this.highFiveClicked,
    required this.onHighFiveTapped,
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
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOutSine),
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
        tween: Tween<double>(begin: 1.0, end: 1.08).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 0.96).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
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
    final showBubble = widget.askingForHighFive || widget.highFiveClicked || widget.showHi;

    return SizedBox(
      width: 200,
      height: 230, // Increased to fully allocate vertical space and prevent overlap
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
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5D5C8), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5A453A).withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.highFiveClicked
                              ? "Nice to meet you!\nLet's start your journey"
                              : (widget.askingForHighFive ? "High Five! 🖐️" : "Hi! 👋"),
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
                // Organic breathing squash & stretch combined with high five bounce scale
                final breathingVal = _breathingAnim.value;
                final scaleY = (1.0 + breathingVal * 0.015) * _clapAnim.value;
                final scaleX = (1.0 - breathingVal * 0.008) * _clapAnim.value;
                final yTranslation = breathingVal * 2.5;

                return Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..translate(0.0, yTranslation)
                    ..scale(scaleX, scaleY),
                  child: child,
                );
              },
              child: SizedBox(
                width: 160,
                height: 155,
                child: Stack(
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
                          border: Border.all(color: const Color(0xFF70452E), width: 1.5),
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
                                    color: const Color(0xFFE5D5C8).withValues(alpha: 0.5),
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
                                    border: Border.all(color: const Color(0xFF70452E), width: 1.5),
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
                                    border: Border.all(color: const Color(0xFF70452E), width: 1.5),
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
                                border: Border.all(color: const Color(0xFF70452E), width: 1.5),
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
                                  border: Border.all(color: const Color(0xFF70452E), width: 1.0),
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
                                  border: Border.all(color: const Color(0xFF70452E), width: 1.0),
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
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF9575CD),
                                          Color(0xFF7E57C2),
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.only(
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
                                  border: Border.all(color: const Color(0xFFE5D5C8), width: 1.0),
                                ),
                                child: CustomPaint(
                                  painter: _SnoutPainter(highFiveClicked: widget.highFiveClicked),
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
                                      Colors.pink.withValues(alpha: widget.highFiveClicked ? 0.65 : 0.35),
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
                                      Colors.pink.withValues(alpha: widget.highFiveClicked ? 0.65 : 0.35),
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
                      bottom: widget.coverEyes ? 42 : -36, // Cozy resting at torso base!
                      left: widget.coverEyes ? 16 : 14,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: widget.coverEyes ? 0.15 : 0.0),
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
                            painter: _BearArmPainter(isLeft: true, isHighFiveActive: false),
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
                          : ((widget.askingForHighFive || widget.highFiveClicked) ? 48 : -36),
                      right: widget.coverEyes
                          ? 16
                          : ((widget.askingForHighFive || widget.highFiveClicked) ? -12 : 14),
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
                          onTap: (widget.askingForHighFive || widget.highFiveClicked)
                              ? widget.onHighFiveTapped
                              : null,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 32,
                            height: 76,
                            child: CustomPaint(
                              painter: _BearArmPainter(
                                isLeft: false,
                                isHighFiveActive: widget.askingForHighFive || widget.highFiveClicked,
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
        ],
      ),
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
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width / 2));
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
      final pupilY = (size.height - pupilHeight) / 2 + eyeLookUp.clamp(-2.0, 2.0);
      
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
      canvas.drawLine(Offset(0, lidHeight), Offset(size.width, lidHeight), paint);
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
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.width / 2)));
    canvas.drawShadow(shadowPath, Colors.black.withValues(alpha: 0.1), 3.0, true);

    // 1. Draw fuzzy connection arm sleeve (linear gradient fur)
    paint.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Color(0xFF6E412A),
        Color(0xFF8A593D),
      ],
    ).createShader(rect);
    
    final armRRect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.45));
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
    canvas.drawCircle(Offset(size.width * 0.26, size.height * 0.1), fingerRadius, fingerPaint);
    // Middle finger pad (slightly taller)
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.07), fingerRadius * 1.15, fingerPaint);
    // Right finger pad
    canvas.drawCircle(Offset(size.width * 0.74, size.height * 0.1), fingerRadius, fingerPaint);

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
    return oldDelegate.isLeft != isLeft || oldDelegate.isHighFiveActive != isHighFiveActive;
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
    canvas.drawLine(Offset(size.width / 2, 16), Offset(size.width / 2, 21), linePaint);

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


// ── Mode Toggle Link ────────────────────────────────────────

class _ModeToggleLink extends ConsumerWidget {
  final _AuthMode mode;
  final VoidCallback? onToggle;
  const _ModeToggleLink({required this.mode, this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          mode == _AuthMode.signIn ? "Didn't have an account ? " : "Already have an account ? ",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
        GestureDetector(
          onTap: () {
            ref.read(_authModeProvider.notifier).state =
                mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn;
            if (onToggle != null) {
              onToggle!();
            }
          },
          child: Text(
            mode == _AuthMode.signIn ? 'Sign Up' : 'Sign In',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5A453A),
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Legal Active Hyperlinks ─────────────────────────────────

class _LegalLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'By continue you agree to our',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => context.push(RouteNames.terms),
              child: const Text(
                'Terms',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF5A453A),
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              ' & ',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            GestureDetector(
              onTap: () => context.push(RouteNames.privacy),
              child: const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF5A453A),
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
