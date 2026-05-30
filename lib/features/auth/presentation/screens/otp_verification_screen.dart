import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
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
            content: Text('Email verified successfully! Welcome to SmartResume.'),
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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background subtle gradients
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  width: screenWidth > 500 ? 460 : double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Immersive Icon Header
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.accentShadow,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Verify Your Account',
                        style: AppTypography.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      Text(
                        'We sent a 6-digit One-Time Password (OTP) to your registered email address:',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      Text(
                        email,
                        style: AppTypography.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Countdown clock
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: _secondsRemaining > 60 ? AppColors.textSecondary : AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatTimer(_secondsRemaining),
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _secondsRemaining > 60 ? AppColors.textPrimary : AppColors.error,
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
                              focusNode: FocusNode(), // Dummy focus node to capture key events
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
                                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                                maxLength: 1,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.accent, width: 2),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    if (index < 5) {
                                      _focusNodes[index + 1].requestFocus();
                                    } else {
                                      _focusNodes[index].unfocus();
                                      _submitOtp(); // Auto submit when last digit is filled
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
                      ElevatedButton(
                        onPressed: _isVerifyingOtp || _isSendingOtp ? null : _submitOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isVerifyingOtp
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text(
                                'Verify Code',
                                style: AppTypography.labelLarge.copyWith(color: Colors.white),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Resend Code text trigger
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive the code? ",
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                          GestureDetector(
                            onTap: _canResend && !_isSendingOtp ? _resendCode : null,
                            child: Text(
                              _isSendingOtp ? 'Sending...' : 'Resend Code',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _canResend && !_isSendingOtp ? AppColors.accent : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 48, color: AppColors.border),

                      // Escape button / Sign Out
                      TextButton.icon(
                        onPressed: () {
                          ref.read(authNotifierProvider.notifier).signOut();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.textSecondary),
                        label: Text(
                          'Back to Login',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
