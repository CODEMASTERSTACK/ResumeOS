import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  // Page states
  bool _otpSent = false;
  String _email = '';

  // Timing
  static const int _totalTime = 600; // 10 minutes
  int _secondsRemaining = _totalTime;
  Timer? _timer;
  bool _canResend = false;

  // Controllers & Focus Nodes
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    for (var ctrl in _otpControllers) {
      ctrl.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = _totalTime;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        _timer?.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }

    try {
      await ref.read(authNotifierProvider.notifier).sendForgotPasswordOtp(email);
      setState(() {
        _email = email;
        _otpSent = true;
      });
      _startTimer();
      _showSuccess('Password reset code sent to your email.');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;
    try {
      await ref.read(authNotifierProvider.notifier).sendForgotPasswordOtp(_email);
      _startTimer();
      _showSuccess('A fresh reset code has been sent to your email.');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _otpControllers.map((c) => c.text.trim()).join();
    if (code.length != 6) {
      _showError('Please enter the 6-digit verification code.');
      return;
    }

    final newPassword = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (newPassword != confirmPassword) {
      _showError('Passwords do not match.');
      return;
    }

    try {
      await ref.read(authNotifierProvider.notifier).verifyForgotPasswordAndReset(
            email: _email,
            code: code,
            newPassword: newPassword,
          );
      
      if (mounted) {
        _showSuccess('Password updated successfully! Please sign in with your new password.');
        Navigator.pop(context); // Go back to login screen
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
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

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Container(
                width: screenWidth > 500 ? 450 : double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _otpSent
                      ? _buildResetPasswordForm(screenWidth, isLoading)
                      : _buildEmailRequestForm(isLoading),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailRequestForm(bool isLoading) {
    return Column(
      key: const ValueKey('email_request'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing Icon Cluster replaced with clean warm icon
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFF8B6B58).withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF8B6B58).withValues(alpha: 0.15), width: 1.5),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: Color(0xFF8B6B58),
            size: 32,
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Forgot Password?',
          style: TextStyle(
            fontSize: 28,
            color: Color(0xFF5A453A),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        const Text(
          'Enter your email address and we will send you a 6-digit OTP code to verify and reset your password.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF8B6B58),
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Email Field
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 13, color: Color(0xFF5A453A), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Email Address',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
            prefixIcon: const Icon(Icons.email_outlined, size: 16, color: Color(0xFF8B6B58)),
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
        const SizedBox(height: 28),

        // Send OTP Button
        _TapScaleButton(
          onTap: isLoading ? null : _sendOtp,
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
                  : const Text(
                      'SEND VERIFICATION CODE',
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
        const SizedBox(height: 24),

        // Back to Login Link
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            '← Back to Sign In',
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

  Widget _buildResetPasswordForm(double screenWidth, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('reset_password'),
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon Header
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF8B6B58).withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF8B6B58).withValues(alpha: 0.15), width: 1.5),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF8B6B58),
              size: 28,
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Verify & Reset',
            style: TextStyle(
              fontSize: 28,
              color: Color(0xFF5A453A),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          const Text(
            'We sent a 6-digit verification code to:',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8B6B58),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _email,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF5A453A),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Countdown clock
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: _secondsRemaining > 60 ? const Color(0xFF8B6B58) : AppColors.error,
              ),
              const SizedBox(width: 6),
              Text(
                _formatTimer(_secondsRemaining),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _secondsRemaining > 60 ? const Color(0xFF5A453A) : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // OTP Digit Boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: (screenWidth > 500 ? 380 : screenWidth - 96) / 7.5,
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                      if (_otpControllers[index].text.isEmpty && index > 0) {
                        _otpFocusNodes[index - 1].requestFocus();
                      }
                    }
                  },
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF5A453A),
                      fontWeight: FontWeight.bold,
                    ),
                    maxLength: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                      filled: true,
                      fillColor: const Color(0xFFFAF8F5),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF8B6B58), width: 1.5),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        if (index < 5) {
                          _otpFocusNodes[index + 1].requestFocus();
                        } else {
                          _otpFocusNodes[index].unfocus();
                        }
                      }
                    },
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // New Password Field
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            style: const TextStyle(fontSize: 13, color: Color(0xFF5A453A), fontWeight: FontWeight.w600),
            validator: (val) {
              if (val == null || val.length < 6) {
                return 'Password must be at least 6 characters.';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'New Password',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.lock_outline, size: 16, color: Color(0xFF8B6B58)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.error, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.error, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Confirm Password Field
          TextFormField(
            controller: _confirmPasswordCtrl,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(fontSize: 13, color: Color(0xFF5A453A), fontWeight: FontWeight.w600),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please confirm your new password.';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Confirm New Password',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.lock_clock_outlined, size: 16, color: Color(0xFF8B6B58)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.error, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.error, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Reset Password Button
          _TapScaleButton(
            onTap: isLoading ? null : _resetPassword,
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
                    : const Text(
                        'RESET PASSWORD',
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
          const SizedBox(height: 20),

          // Resend / Back triggers
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't receive the code? ",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
              GestureDetector(
                onTap: _canResend && !isLoading ? _resendCode : null,
                child: Text(
                  'Resend Code',
                  style: TextStyle(
                    fontSize: 12,
                    color: _canResend && !isLoading ? const Color(0xFF8B6B58) : Colors.grey.shade400,
                    fontWeight: FontWeight.w700,
                    decoration: _canResend && !isLoading ? TextDecoration.underline : TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextButton(
            onPressed: () => setState(() => _otpSent = false),
            child: const Text(
              'Change Email Address',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8B6B58),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
