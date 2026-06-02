import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const int _totalTime = 600; // 10 minutes in seconds
  int _secondsRemaining = _totalTime;
  Timer? _timer;
  bool _canResend = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _startTimer();
    _autoSendOtp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var ctrl in _controllers) {
      ctrl.dispose();
    }
    for (var node in _focusNodes) {
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

  Future<void> _autoSendOtp() async {
    setState(() => _isSendingOtp = true);
    try {
      await ref.read(authNotifierProvider.notifier).sendVerificationOtp();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your email.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification code: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isSendingOtp) return;
    _startTimer();
    await _autoSendOtp();
  }

  Future<void> _submitOtp() async {
    final code = _controllers.map((c) => c.text.trim()).join();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 6-digit verification code.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      await ref.read(authNotifierProvider.notifier).verifyOtp(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully! Welcome to ResumeOS.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider)?.email ?? '';
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Immersive Icon Header
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B6B58).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF8B6B58).withValues(alpha: 0.15), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_rounded,
                        color: Color(0xFF8B6B58),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Verify Your Account',
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
                      'We sent a 6-digit One-Time Password (OTP) to your registered email address:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8B6B58),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),

                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5A453A),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

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
                    const SizedBox(height: 24),

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
                                if (_controllers[index].text.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                              }
                            },
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                color: Color(0xFF5A453A),
                                fontWeight: FontWeight.bold,
                              ),
                              maxLength: 1,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                                filled: true,
                                fillColor: const Color(0xFFFAF8F5),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF8B6B58), width: 1.5),
                                ),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  if (index < 5) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else {
                                    _focusNodes[index].unfocus();
                                    _submitOtp();
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),

                    // Submit Verification button
                    _TapScaleButton(
                      onTap: _isVerifyingOtp || _isSendingOtp ? null : _submitOtp,
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
                          child: _isVerifyingOtp
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'VERIFY CODE',
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

                    // Resend Code text trigger
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the code? ",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                        ),
                        GestureDetector(
                          onTap: _canResend && !_isSendingOtp ? _resendCode : null,
                          child: Text(
                            _isSendingOtp ? 'Sending...' : 'Resend Code',
                            style: TextStyle(
                              fontSize: 12,
                              color: _canResend && !_isSendingOtp ? const Color(0xFF8B6B58) : Colors.grey.shade400,
                              fontWeight: FontWeight.w700,
                              decoration: _canResend && !_isSendingOtp ? TextDecoration.underline : TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 48, color: Color(0xFFF3EFEA), thickness: 1.5),

                    // Escape button / Sign Out
                    TextButton.icon(
                      onPressed: () {
                        ref.read(authNotifierProvider.notifier).signOut();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF8B6B58)),
                      label: const Text(
                        'Back to Login',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8B6B58),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
