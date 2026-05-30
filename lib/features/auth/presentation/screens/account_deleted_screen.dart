import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import 'package:go_router/go_router.dart';
import '../../../../routes/route_names.dart';
import '../providers/auth_provider.dart';

class AccountDeletedScreen extends ConsumerStatefulWidget {
  const AccountDeletedScreen({super.key});

  @override
  ConsumerState<AccountDeletedScreen> createState() => _AccountDeletedScreenState();
}

class _AccountDeletedScreenState extends ConsumerState<AccountDeletedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );
    _ctrl.forward();

    // Trigger local sign out after the screen is loaded so the router does not intercept mid-flight
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).signOut();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background subtle design circles
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fade.value,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: screenWidth > 500 ? 460 : double.infinity,
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(28.0),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Torn Resume Icon Cluster
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red.withValues(alpha: 0.2), width: 1.5),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Left half of the torn resume
                              Transform.translate(
                                offset: const Offset(-8, -4),
                                child: Transform.rotate(
                                  angle: -0.15,
                                  child: Icon(
                                    Icons.article_rounded,
                                    color: Colors.red.withValues(alpha: 0.45),
                                    size: 38,
                                  ),
                                ),
                              ),
                              // Right half of the torn resume
                              Transform.translate(
                                offset: const Offset(8, 4),
                                child: Transform.rotate(
                                  angle: 0.18,
                                  child: const Icon(
                                    Icons.article_rounded,
                                    color: Colors.red,
                                    size: 38,
                                  ),
                                ),
                              ),
                              // Cut overlay icon in center
                              const Center(
                                child: Icon(
                                  Icons.content_cut_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        Text(
                          'Account Deleted',
                          style: AppTypography.displaySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'Your profile & data are gone permanently',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        Text(
                          "We're truly sorry to see you go. All of your personal details, resumes, synced repositories, and career records have been permanently cleared from our servers and can never be recovered.\n\nThank you for choosing and experimenting with AI Career OS. We wish you the absolute best on your professional journey, and if you ever need to craft tailored, ATS-compliant resumes again, you're always welcome back.",
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),

                        // Back to Sign In button
                        AppButton(
                          label: 'Back to Sign In',
                          onTap: () {
                            context.go(RouteNames.login);
                          },
                          variant: AppButtonVariant.accent,
                          icon: Icons.arrow_back_rounded,
                        ),
                      ],
                    ),
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
