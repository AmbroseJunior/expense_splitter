import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService? _authService;
  final bool firebaseEnabled;

  User? user;
  bool isLoading = false;
  String? error;

  AuthProvider({bool enableFirebase = true})
      : firebaseEnabled = enableFirebase,
        _authService = enableFirebase ? AuthService() : null {
    if (enableFirebase) {
      _authService!.authStateChanges().listen((firebaseUser) {
        user = firebaseUser;
        notifyListeners();
      });
    }
  }

  bool _requireFirebase() {
    if (!firebaseEnabled || _authService == null) {
      error = "Firebase is disabled in local-only mode.";
      isLoading = false;
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> register(String name, String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      if (!_requireFirebase()) return;
      await _authService!.register(name, email, password);
    } on FirebaseAuthException catch (e) {
      // THIS gives real, human-readable messages
      error = e.message ?? "Registration failed.";
    } catch (e) {
      error = "Unexpected error occurred.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      if (!_requireFirebase()) return;
      await _authService!.login(email, password);
    } on FirebaseAuthException catch (e) {
      error = e.message ?? "Login failed.";
    } catch (e) {
      error = "Unexpected error occurred.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      if (!_requireFirebase()) return;
      await _authService!.signInWithGoogle();
    } catch (e) {
      error = "Google sign-in failed.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logoutAfterRegister() async {
    if (!firebaseEnabled || _authService == null) return;
    await _authService!.logout();
  }

  Future<void> loginAnonymously() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      if (!_requireFirebase()) return;
      await _authService!.signInAnonymously();
    } catch (e) {
      error = "Anonymous login failed.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (!firebaseEnabled || _authService == null) return;
    await _authService!.logout();
  }
}
