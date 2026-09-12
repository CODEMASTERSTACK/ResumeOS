import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../services/github/github_service.dart';
import '../../../../features/profile/domain/entities/user_model.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../../../core/config/app_config.dart';
import '../../../../services/telemetry/telemetry_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/cache/screen_persistence.dart';

// ── Auth Repository ────────────────────────────────────────

abstract class AuthRepository {
  Future<UserCredential> signInWithGoogle();
  Future<UserCredential> signInWithGitHub();
  Future<UserCredential> signInWithEmail(String email, String password);
  Future<UserCredential> createAccountWithEmail(String email, String password, String name);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
  Stream<User?> get authStateChanges;
}

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;

  AuthRepositoryImpl(this._auth);

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('Google sign in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  @override
  Future<UserCredential> signInWithGitHub() async {
    final provider = GithubAuthProvider();
    provider.addScope('repo');
    provider.addScope('user:email');
    if (kIsWeb) {
      return _auth.signInWithPopup(provider);
    } else {
      return _auth.signInWithProvider(provider);
    }
  }

  @override
  Future<UserCredential> signInWithEmail(
      String email, String password) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<UserCredential> createAccountWithEmail(
      String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Update display name
    await cred.user?.updateDisplayName(name.trim());
    return cred;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> signOut() async {
    await ScreenPersistence.clearAll();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}

// ── Providers ──────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(firebaseAuthProvider));
});

/// Auth state stream — drives redirect logic in GoRouter
final authStateProvider = StreamProvider<User?>((ref) {
  final stream = ref.watch(authRepositoryProvider).authStateChanges;
  return stream.map((user) {
    if (user != null) {
      TelemetryService.instance.setUser(uid: user.uid, email: user.email);
    } else {
      TelemetryService.instance.clearUser();
    }
    return user;
  });
});

/// Current Firebase user (null if not authenticated)
/// Falls back synchronously to FirebaseAuth.instance.currentUser during initial StreamProvider loading
final currentUserProvider = Provider<User?>((ref) {
  final asyncUser = ref.watch(authStateProvider);
  return asyncUser.hasValue ? asyncUser.value : FirebaseAuth.instance.currentUser;
});

// ── Auth Notifier State ────────────────────────────────────

class AuthState {
  final bool isLoading;
  final Object? error;

  const AuthState({this.isLoading = false, this.error});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref) : super(const AuthState());

  Future<void> signInWithGoogle() async {
    state = const AuthState(isLoading: true);
    try {
      final cred = await _repo.signInWithGoogle();
      await _ensureUserProfile(cred);
      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e);
    }
  }

  Future<void> signInWithGitHub() async {
    state = const AuthState(isLoading: true);
    try {
      final cred = await _repo.signInWithGitHub();
      // Capture GitHub OAuth access token for repo fetching
      final token = cred.credential?.accessToken;
      if (token != null) {
        _ref.read(gitHubTokenProvider.notifier).state = token;
      }
      await _ensureUserProfile(cred);
      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e);
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AuthState(isLoading: true);
    try {
      final cred = await _repo.signInWithEmail(email, password);
      await _ensureUserProfile(cred);
      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e);
    }
  }

  Future<void> createAccount(String email, String password, String name) async {
    state = const AuthState(isLoading: true);
    try {
      // Check if this email was previously deleted/archived
      final emailMatches = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (emailMatches.docs.isNotEmpty) {
        final docData = emailMatches.docs.first.data();
        final isDel = (docData['isDeleted'] as bool? ?? false) ||
            (docData['accountStatus'] == 'deleted');
        if (isDel) {
          final reason = (docData['deletionReason'] as String?)?.isNotEmpty == true
              ? docData['deletionReason'] as String
              : 'Detected unauthorized activity and violation of platform terms.';
          throw Exception(
              'ACCOUNT_DELETED: Your account with this email (${email.trim()}) was deleted by our team for the reason: $reason. You cannot access your account or create an account with this email ID.');
        }
      }

      final cred = await _repo.createAccountWithEmail(email, password, name);
      final user = cred.user;
      if (user != null) {
        final profileRepo = _ref.read(profileRepositoryProvider);
        final newUser = UserModel(
          uid: user.uid,
          name: name.trim(),
          email: email.trim(),
          createdAt: DateTime.now(),
          isEmailVerified: false,
        );
        await profileRepo.createUser(newUser);
      }
      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e);
    }
  }

  Future<void> sendVerificationOtp() async {
    state = const AuthState(isLoading: true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      final idToken = await user.getIdToken();
      
      final response = await http.post(
        Uri.parse('https://smartresume-backend.kanasingh974.workers.dev/v1/auth/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode != 200) {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(err['error'] ?? 'Failed to send verification code');
      }
      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e);
      rethrow;
    }
  }

  Future<void> verifyOtp(String code) async {
    state = const AuthState(isLoading: true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      final idToken = await user.getIdToken();
      
      final response = await http.post(
        Uri.parse('https://smartresume-backend.kanasingh974.workers.dev/v1/auth/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'code': code}),
      );

      if (response.statusCode != 200) {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(err['error'] ?? 'Invalid or expired verification code');
      }
      
      // Force refresh user profile to trigger router state update immediately
      _ref.invalidate(userProfileProvider);
      
      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e);
      rethrow;
    }
  }

  Future<void> sendForgotPasswordOtp(String email) async {
    state = const AuthState(isLoading: true);
    try {
      final response = await http.post(
        Uri.parse('https://smartresume-backend.kanasingh974.workers.dev/v1/auth/forgot-password/send-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email.trim()}),
      );

      if (response.statusCode != 200) {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(err['error'] ?? 'Failed to send reset code');
      }
      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e);
      rethrow;
    }
  }

  Future<void> verifyForgotPasswordAndReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = const AuthState(isLoading: true);
    try {
      final response = await http.post(
        Uri.parse('https://smartresume-backend.kanasingh974.workers.dev/v1/auth/forgot-password/verify-and-reset'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(err['error'] ?? 'Failed to reset password');
      }
      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e);
      rethrow;
    }
  }

  Future<void> _ensureUserProfile(UserCredential cred) async {
    final user = cred.user;
    if (user == null) return;

    final profileRepo = _ref.read(profileRepositoryProvider);
    final existing = await profileRepo.getUser(user.uid);

    if (existing != null) {
      if (existing.isDeleted || existing.accountStatus == 'deleted') {
        await _repo.signOut();
        final reason = existing.deletionReason.isNotEmpty
            ? existing.deletionReason
            : 'Detected unauthorized activity and violation of platform terms.';
        throw Exception(
            'ACCOUNT_DELETED: Your account with this email (${existing.email.isNotEmpty ? existing.email : user.email}) was deleted by our team for the reason: $reason. You cannot access your account or create an account with this email ID.');
      }

      if (existing.accountStatus == 'hold') {
        final isStillOnHold = existing.holdUntil == null ||
            DateTime.now().isBefore(existing.holdUntil!);
        if (isStillOnHold) {
          await _repo.signOut();
          final holdUntilStr = existing.holdUntil != null
              ? ' until ${existing.holdUntil!.toLocal()}'
              : ' indefinitely pending administrative review';
          final reason = existing.holdReason.isNotEmpty
              ? existing.holdReason
              : 'Detected unauthorized activity.';
          throw Exception(
              'ACCOUNT_ON_HOLD: Your account has been placed on hold$holdUntilStr due to detected unauthorized activity. During this time, no activity is allowed. Reason: $reason.');
        }
      }
    } else if (user.email != null && user.email!.isNotEmpty) {
      // Check if an archived document exists with this email address
      try {
        final emailMatches = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: user.email!.trim())
            .limit(1)
            .get();
        if (emailMatches.docs.isNotEmpty) {
          final docData = emailMatches.docs.first.data();
          final isDel = (docData['isDeleted'] as bool? ?? false) ||
              (docData['accountStatus'] == 'deleted');
          if (isDel) {
            await _repo.signOut();
            final reason = (docData['deletionReason'] as String?)?.isNotEmpty == true
                ? docData['deletionReason'] as String
                : 'Detected unauthorized activity and violation of platform terms.';
            throw Exception(
                'ACCOUNT_DELETED: Your account with this email (${user.email}) was deleted by our team for the reason: $reason. You cannot access your account or create an account with this email ID.');
          }
        }
      } catch (e) {
        if (e.toString().contains('ACCOUNT_DELETED')) rethrow;
      }

      final newUser = UserModel(
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        createdAt: DateTime.now(),
      );
      await profileRepo.createUser(newUser);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _repo.sendPasswordReset(email);
  }

  Future<void> deleteAccount() async {
    state = const AuthState(isLoading: true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(AppConfig.deleteAccountUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode != 200) {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(err['error'] ?? 'Failed to delete account from backend');
      }

      // Invalidate the profile locally
      _ref.invalidate(userProfileProvider);

      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AuthState(isLoading: true);
    try {
      await _repo.signOut();
      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e);
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});
