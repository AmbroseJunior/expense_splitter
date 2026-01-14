import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  get error => null;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> register(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await cred.user!.updateDisplayName(name.trim());
    await cred.user!.reload();
  }

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }

  Future<void> signInWithGoogle() async {
    // ✅ Web uses Firebase popup (NOT google_sign_in plugin)
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      await _auth.signInWithPopup(provider);
      return;
    }

    // ✅ Android/iOS uses google_sign_in plugin
    final googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);

    // 🔥 Fix "works once then never again"
    // Clear previous session completely:
    try {
      await googleSignIn.signOut();
      await googleSignIn.disconnect();
    } catch (_) {}

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'CANCELLED',
        message: 'Google sign-in cancelled.',
      );
    }

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _auth.signInWithCredential(credential);
  }

  Future<void> logout() async {
    if (!kIsWeb) {
      final googleSignIn = GoogleSignIn();
      try {
        await googleSignIn.signOut();
        await googleSignIn.disconnect();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  Future<void> logoutAfterRegister() async {}
}
