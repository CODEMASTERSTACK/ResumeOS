import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../services/github/github_service.dart';
import '../../../../features/profile/domain/entities/user_model.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';

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
    return _auth.signInWithProvider(provider);
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
        );
        await profileRepo.createUser(newUser);
      }
      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e);
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
      // Safe fallback: try setting the document to ensure it exists
      try {
        final newUser = UserModel(
          uid: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          createdAt: DateTime.now(),
        );
        await profileRepo.createUser(newUser);
      } catch (_) {}
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _repo.sendPasswordReset(email);
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
