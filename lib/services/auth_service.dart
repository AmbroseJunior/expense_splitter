import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔹 Listen to auth state (login / logout)
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  // 🔹 Email & Password Registration
  Future<void> register(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await cred.user!.updateDisplayName(name);
    await cred.user!.reload();
  }

  // 🔹 Email & Password Login
  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  // 🔹 Google Sign-In (WEB + ANDROID FIXED)
  Future<void> signInWithGoogle() async {
    // 🌐 WEB (Firebase popup — REQUIRED)
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      await _auth.signInWithPopup(googleProvider);
      return;
    }

    // 🤖 ANDROID / IOS (Google Play Services)
    final googleSignIn = GoogleSignIn();

    // 🔴 IMPORTANT: clear any cached session
    await googleSignIn.signOut();

    final googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      throw Exception("Google sign-in cancelled");
    }

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _auth.signInWithCredential(credential);
  }

  // 🔹 Anonymous Login
  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }

  // 🔹 Logout (ALL PLATFORMS)
  Future<void> logout() async {
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    await _auth.signOut();
  }
}
