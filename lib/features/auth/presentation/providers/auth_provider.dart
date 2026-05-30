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
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}

// ── Providers ──────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(firebaseAuthProvider));
});

/// Auth state stream — drives redirect logic in GoRouter
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Current Firebase user (null if not authenticated)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
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

  Future<void> _ensureUserProfile(UserCredential cred) async {
    final user = cred.user;
    if (user == null) return;

    final profileRepo = _ref.read(profileRepositoryProvider);
    try {
      final existing = await profileRepo.getUser(user.uid);
      if (existing == null) {
        final newUser = UserModel(
          uid: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          createdAt: DateTime.now(),
        );
        await profileRepo.createUser(newUser);
      }
    } catch (e) {
      // Log/print the error; DO NOT perform a write that could overwrite an existing profile document!
      debugPrint('Error ensuring user profile exists: $e');
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
        Uri.parse('https://smartresume-backend.kanasingh974.workers.dev/v1/auth/delete-account'),
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
