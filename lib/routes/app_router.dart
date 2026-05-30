import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'route_names.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/otp_verification_screen.dart';
import '../features/auth/presentation/screens/account_deleted_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_wrapper.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/projects/presentation/screens/projects_screen.dart';
import '../features/projects/presentation/screens/add_edit_project_screen.dart';
import '../features/projects/presentation/screens/github_repo_view_screen.dart';
import '../features/resume_generator/presentation/screens/generate_screen.dart';
import '../features/resume_generator/presentation/screens/ai_analysis_screen.dart';
import '../features/resume_generator/presentation/screens/project_selection_screen.dart';
import '../features/resume_generator/presentation/screens/template_selection_screen.dart';
import '../features/resume_generator/presentation/screens/resume_preview_screen.dart';
import '../features/resume_generator/presentation/screens/resume_edit_screen.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/profile_section_edit_screen.dart';
import '../features/profile/presentation/screens/profile_skills_edit_screen.dart';
import '../features/profile/presentation/screens/profile_summary_ai_enhance_screen.dart';
import '../features/profile/presentation/screens/settings_screen.dart';
import '../shared/widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class RouterTransitionNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterTransitionNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) {
      notifyListeners();
    });
    _ref.listen(userProfileProvider, (_, __) {
      notifyListeners();
    });
  }
}

final routerTransitionNotifierProvider = Provider((ref) {
  return RouterTransitionNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(routerTransitionNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: listenable,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final isAuthenticated = user != null;
      final location = state.uri.toString();

      final isOnSplash = location == RouteNames.splash;
      final isOnAuth = location == RouteNames.login ||
          location == RouteNames.signup ||
          location == RouteNames.accountDeleted;

      if (isOnSplash) return null; // Splash handles its own redirect

      if (!isAuthenticated && !isOnAuth) {
        return RouteNames.login;
      }

      if (isAuthenticated) {
        final profileAsync = ref.read(userProfileProvider);
        final profile = profileAsync.valueOrNull;
        if (profile != null) {
          final isUnverified = !profile.isEmailVerified;
          final isOnOtpVerify = location == RouteNames.otpVerify;
          if (isUnverified) {
            if (!isOnOtpVerify) {
              return RouteNames.otpVerify;
            }
          } else {
            if (isOnOtpVerify) {
              return profile.onboardingComplete
                  ? RouteNames.dashboard
                  : RouteNames.onboarding;
            }

            final isOnOnboarding = location == RouteNames.onboarding ||
                location.startsWith('/onboarding');
            if (!profile.onboardingComplete && !isOnOnboarding) {
              return RouteNames.onboarding;
            }
          }
        }
      }

      // Let post-auth screens or splash handle the landing page redirect (dashboard vs onboarding)
      return null;
    },
    routes: [
      // ── Splash ───────────────────────────────────────────
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth ─────────────────────────────────────────────
      GoRoute(
        path: RouteNames.login,
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const LoginScreen(),
        ),
      ),

      // ── OTP Verification ─────────────────────────────────
      GoRoute(
        path: RouteNames.otpVerify,
         pageBuilder: (context, state) => _fadeTransition(
          state,
          const OtpVerificationScreen(),
        ),
      ),

      // ── Account Deleted ──────────────────────────────────
      GoRoute(
        path: RouteNames.accountDeleted,
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const AccountDeletedScreen(),
        ),
      ),

      // ── Onboarding ───────────────────────────────────────
      GoRoute(
        path: RouteNames.onboarding,
        pageBuilder: (context, state) => _slideTransition(
          state,
          const OnboardingWrapper(),
        ),
      ),

      // ── Shell (Bottom Nav) ───────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.dashboard,
            pageBuilder: (context, state) => _noTransition(
              state,
              const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.projects,
            pageBuilder: (context, state) => _noTransition(
              state,
              const ProjectsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => _slideUpTransition(
                  state,
                  const AddEditProjectScreen(),
                ),
              ),
              GoRoute(
                path: 'edit/:projectId',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => _slideUpTransition(
                  state,
                  AddEditProjectScreen(
                    projectId: state.pathParameters['projectId'],
                  ),
                ),
              ),
              GoRoute(
                path: 'github-view/:projectId',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => _slideTransition(
                  state,
                  GitHubRepoViewScreen(
                    projectId: state.pathParameters['projectId']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.generate,
            pageBuilder: (context, state) => _noTransition(
              state,
              const GenerateScreen(),
            ),
            routes: [
              GoRoute(
                path: 'analyze',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => _slideTransition(
                  state,
                  const AiAnalysisScreen(),
                ),
              ),
              GoRoute(
                path: 'select-projects',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => _slideTransition(
                  state,
                  const ProjectSelectionScreen(),
                ),
              ),
              GoRoute(
                path: 'select-template',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => _slideTransition(
                  state,
                  const TemplateSelectionScreen(),
                ),
              ),
              GoRoute(
                path: 'preview/:resumeId',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => _slideTransition(
                  state,
                  ResumePreviewScreen(
                    resumeId: state.pathParameters['resumeId']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'edit/:resumeId',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => _slideTransition(
                  state,
                  ResumeEditScreen(
                    resumeId: state.pathParameters['resumeId']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.history,
            pageBuilder: (context, state) => _noTransition(
              state,
              const HistoryScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.profile,
            pageBuilder: (context, state) => _noTransition(
              state,
              const ProfileScreen(),
            ),
            routes: [
              GoRoute(
                path: 'edit/:section',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) {
                  final section = state.pathParameters['section']!;
                  final extra = state.extra as Map<String, dynamic>?;
                  return _slideTransition(
                    state,
                    ProfileSectionEditScreen(
                      section: section,
                      editItem: extra,
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'skills',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) {
                  return _slideTransition(
                    state,
                    const ProfileSkillsEditScreen(),
                  );
                },
              ),
              GoRoute(
                path: 'summary-enhance',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) {
                  return _slideTransition(
                    state,
                    const ProfileSummaryAiEnhanceScreen(),
                  );
                },
              ),
              GoRoute(
                path: 'settings',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) {
                  return _slideTransition(
                    state,
                    const SettingsScreen(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// ── Transition Helpers ─────────────────────────────────────

CustomTransitionPage<void> _fadeTransition(
    GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}

CustomTransitionPage<void> _slideTransition(
    GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondary, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _slideUpTransition(
    GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondary, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      );
    },
  );
}

CustomTransitionPage<void> _noTransition(
    GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondary, child) => child,
  );
}
