// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_service.dart';
import '../crypto/vault_crypto.dart';

// ── AUTH STATE PROVIDER ───────────────────────────────────────────────────────

/// Streams the Firebase Auth state — null means signed out.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.authStateChanges;
});

/// True once Firebase is initialized and auth state is known.
final authReadyProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).hasValue;
});

// ── AUTH NOTIFIER ─────────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Register a new account:
  ///  1. Generate RSA-2048 key pair
  ///  2. Create Firebase Auth user
  ///  3. Store private key in Keychain
  ///  4. Write public key + profile to Firestore
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Generate RSA key pair (this takes ~1 second)
      final pair = await Future.microtask(() => VaultCrypto.generateRSAKeyPair());
      final pubPem  = VaultCrypto.exportPublicKey(pair.publicKey);
      final privPem = VaultCrypto.exportPrivateKey(pair.privateKey);

      await FirebaseService.register(
        email: email,
        password: password,
        displayName: displayName,
        publicKeyPem: pubPem,
        privateKeyPem: privPem,
      );

      state = const AsyncValue.data(null);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(_authError(e), StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  /// Sign in with email/password.
  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseService.signIn(email: email, password: password);
      state = const AsyncValue.data(null);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(_authError(e), StackTrace.current);
      return false;
    }
  }

  Future<void> signOut() async {
    await FirebaseService.signOut();
    state = const AsyncValue.data(null);
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return 'This email is already registered.';
      case 'invalid-email':        return 'Invalid email address.';
      case 'weak-password':        return 'Password must be at least 6 characters.';
      case 'user-not-found':       return 'No account found with this email.';
      case 'wrong-password':       return 'Incorrect password.';
      case 'too-many-requests':    return 'Too many attempts. Try again later.';
      default:                     return e.message ?? 'Authentication failed.';
    }
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(
  AuthNotifier.new,
);
