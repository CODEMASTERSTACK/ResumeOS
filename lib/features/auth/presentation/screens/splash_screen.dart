import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/cache/screen_persistence.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // 1. Minimum aesthetic delay so brand splash animation plays smoothly
    final minDelayFuture = Future.delayed(const Duration(milliseconds: 1200));

    // 2. Check if a previously authenticated user UID was stored on this device
    final savedUid = await ScreenPersistence.getAuthUid();
    final savedRoute = await ScreenPersistence.getLastRoute();

    // 3. Resolve authenticated user deterministically
    User? user = ref.read(currentUserProvider) ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        // If we previously had an authenticated session, wait up to 4 seconds for Keystore decrypt
        final timeoutDuration = savedUid != null
            ? const Duration(milliseconds: 4000)
            : const Duration(milliseconds: 1500);
        user = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(timeoutDuration);
      } catch (_) {
        user = FirebaseAuth.instance.currentUser;
      }
    }

    await minDelayFuture;
    if (!mounted) return;

    if (user == null) {
      context.go(RouteNames.login);
      return;
    }

    // 4. Update saved UID
    await ScreenPersistence.saveAuthUid(user.uid);

    // 5. Determine target route (saved route if valid, or dashboard)
    final targetRoute = (savedRoute != null &&
            savedRoute.isNotEmpty &&
            !savedRoute.contains('login') &&
            !savedRoute.contains('splash') &&
            !savedRoute.contains('otp') &&
            !savedRoute.contains('account-deleted'))
        ? savedRoute
        : RouteNames.dashboard;

    // 6. Check Firestore for deletion or hold status
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 3));

      if (!mounted) return;

      final data = doc.data();
      final isDeleted = (data?['isDeleted'] as bool? ?? false) ||
          (data?['accountStatus'] == 'deleted');
      if (isDeleted) {
        await FirebaseAuth.instance.signOut();
        await ScreenPersistence.clearAll();
        if (!mounted) return;
        context.go(RouteNames.accountDeleted);
        return;
      }

      final isEmailVerified = data?['isEmailVerified'] as bool? ?? true;
      if (!isEmailVerified) {
        context.go(RouteNames.otpVerify);
        return;
      }

      // Mark onboarding complete in background to prevent ever blocking user
      if (data?['onboardingComplete'] != true) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'onboardingComplete': true}).catchError((_) {});
      }

      context.go(targetRoute);
    } catch (_) {
      // Offline mode or network timeout fallback: navigate directly to targetRoute
      if (mounted) {
        context.go(targetRoute);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF7), // Milky white
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Monogram Logo Mark styled exactly like the A in the image
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: Text(
                        'R.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 160,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF8B6B58), // Signature brand brown
                          letterSpacing: -5,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // App Name styled exactly like "The Atlantic" in italic serif
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Text(
                      'ResumeOS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5A453A), // Dark slate-brown
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 90),
                  // Subtle premium loader
                  FadeTransition(
                    opacity: _taglineFade,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF8B6B58),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
