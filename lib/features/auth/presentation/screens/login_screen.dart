import 'package:flutter/material.dart';
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

  // Form fields
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(_fade);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
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
    if (raw.contains('email-already-in-use')) {
      return 'An account already exists with this email.';
    }
    if (raw.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    }
    if (raw.contains('invalid-email')) return 'Please enter a valid email address.';
    if (raw.contains('network')) return 'Network error. Check your connection.';
    if (raw.contains('cancelled') || raw.contains('aborted')) {
      return 'Sign in was cancelled.';
    }
    return 'Something went wrong. Please try again.';
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
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(msg),
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

  Future<void> _signInWithGitHub() async {
    await ref.read(authNotifierProvider.notifier).signInWithGitHub();
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

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email above first.');
      return;
    }
    try {
      await ref.read(authNotifierProvider.notifier).sendPasswordReset(email);
      _showSuccess('Reset link sent to $email');
    } catch (e) {
      _showError(_friendlyError(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(_authModeProvider);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isWide
            ? _buildWideLayout(isLoading, mode)
            : _buildNarrowLayout(isLoading, mode),
      ),
    );
  }

  Widget _buildWideLayout(bool isLoading, _AuthMode mode) {
    return Row(
      children: [
        // Left: branding panel
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF3730A3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Logo(dark: false),
                const Spacer(),
                _BrandingContent(),
                const SizedBox(height: 40),
                _FeatureBadges(),
              ],
            ),
          ),
        ),
        // Right: auth form
        Expanded(
          flex: 4,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(
                    horizontal: 52, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ModeToggle(mode: mode),
                    const SizedBox(height: 32),
                    _buildForm(isLoading, mode),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(bool isLoading, _AuthMode mode) {
    return FadeTransition(
      opacity: _fade,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            _Logo(dark: true),
            const SizedBox(height: 36),
            _ModeToggle(mode: mode),
            const SizedBox(height: 28),
            _buildForm(isLoading, mode),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool isLoading, _AuthMode mode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Social auth
        _SocialButton(
          id: 'btn_google_signin',
          label: AppStrings.signInWithGoogle,
          icon: const _GoogleLogo(),
          onTap: isLoading ? null : _signInWithGoogle,
          isLoading: isLoading,
        ),
        const SizedBox(height: 10),
        _SocialButton(
          id: 'btn_github_signin',
          label: AppStrings.signInWithGitHub,
          icon: const _GitHubLogo(),
          onTap: isLoading ? null : _signInWithGitHub,
          isDark: true,
        ),
        const SizedBox(height: 24),
        // Divider
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('or continue with email',
                style: AppTypography.labelSmall),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 24),
        // Email form
        Form(
          key: _formKey,
          child: Column(
            children: [
              if (mode == _AuthMode.signUp) ...[
                _FormField(
                  id: 'field_name',
                  ctrl: _nameCtrl,
                  label: 'Full Name',
                  hint: 'John Doe',
                  icon: Icons.person_outline_rounded,
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 14),
              ],
              _FormField(
                id: 'field_email',
                ctrl: _emailCtrl,
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Email required';
                  if (!v!.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _FormField(
                id: 'field_password',
                ctrl: _passwordCtrl,
                label: 'Password',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscure = !_obscure),
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
        if (mode == _AuthMode.signIn) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              child: Text('Forgot password?',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.accent,
                  )),
            ),
          ),
        ],
        const SizedBox(height: 20),
        // Submit
        _PrimaryButton(
          id: 'btn_submit',
          label: mode == _AuthMode.signIn ? 'Sign In' : 'Create Account',
          isLoading: isLoading,
          onTap: isLoading ? null : _submitEmailForm,
        ),
        const SizedBox(height: 20),
        Text(
          'By continuing, you agree to our Terms of Service. We never store your job descriptions.',
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Mode Toggle ────────────────────────────────────────────

class _ModeToggle extends ConsumerWidget {
  final _AuthMode mode;
  const _ModeToggle({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mode == _AuthMode.signIn ? 'Welcome back' : 'Create your account',
          style: AppTypography.displaySmall,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              mode == _AuthMode.signIn
                  ? "Don't have an account? "
                  : 'Already have an account? ',
              style: AppTypography.bodySmall,
            ),
            GestureDetector(
              onTap: () => ref.read(_authModeProvider.notifier).state =
                  mode == _AuthMode.signIn
                      ? _AuthMode.signUp
                      : _AuthMode.signIn,
              child: Text(
                mode == _AuthMode.signIn ? 'Sign up free' : 'Sign in',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.accent,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Social Button ──────────────────────────────────────────

class _SocialButton extends StatefulWidget {
  final String id;
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDark;

  const _SocialButton({
    required this.id,
    required this.label,
    required this.icon,
    this.onTap,
    this.isLoading = false,
    this.isDark = false,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark
        ? (_hovered ? const Color(0xFF0D1117) : const Color(0xFF161B22))
        : (_hovered ? AppColors.surfaceVariant : AppColors.surface);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDark ? Colors.transparent : AppColors.border,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: Key(widget.id),
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            width: 20, height: 20, child: widget.icon),
                        const SizedBox(width: 10),
                        Text(
                          widget.label,
                          style: AppTypography.labelLarge.copyWith(
                            color: widget.isDark
                                ? Colors.white
                                : AppColors.textPrimary,
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

// ── Form Field ─────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final String id;
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.id,
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: Key(id),
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ── Primary Button ─────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String id;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _PrimaryButton({
    required this.id,
    required this.label,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        key: Key(id),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                )),
      ),
    );
  }
}

// ── Branding widgets ───────────────────────────────────────

class _Logo extends StatelessWidget {
  final bool dark;
  const _Logo({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: dark ? AppColors.accent : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Icon(Icons.auto_awesome_rounded,
              size: 18, color: Colors.white),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        AppStrings.appName,
        style: AppTypography.headlineMedium.copyWith(
          color: dark ? AppColors.textPrimary : Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ]);
  }
}

class _BrandingContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your career,\nrun by AI.',
          style: AppTypography.displayMedium.copyWith(
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Build your profile once.\nLet AI craft tailored, ATS-optimized\nresumes for every job.',
          style: AppTypography.bodyLarge.copyWith(
            color: Colors.white.withValues(alpha: 0.65),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _FeatureBadges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      '🎯 ATS-Optimized',
      '🤖 Gemini AI',
      '📄 PDF Export',
      '🔒 Private & Secure',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((label) {
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Icon widgets ───────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GooglePainter());
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), -1.57, 3.14, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), 1.57, 1.57, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), 3.14, 0.78, true, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), -1.57, -1.57, true, paint);
    paint.color = Colors.white;
    canvas.drawCircle(c, r * 0.6, paint);
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - r * 0.3, r * 0.85, r * 0.6),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _GitHubLogo extends StatelessWidget {
  const _GitHubLogo();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.code_rounded, color: Colors.white, size: 18);
  }
}
