import 'package:expense_splitter/state/expense_store.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? user;
  bool isLoading = false;
  String? error;

  AuthProvider() {
    _authService.authStateChanges().listen((firebaseUser) {
      user = firebaseUser;
      notifyListeners();
    });
  }

  Future<void> register(String name, String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _authService.register(name, email, password);
    } on FirebaseAuthException catch (e) {
      error = e.message ?? "${e.code}: Registration failed.";
    } catch (e) {
      error = e.toString();
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
      await _authService.login(email, password);
    } on FirebaseAuthException catch (e) {
      error = e.message ?? "${e.code}: Login failed.";
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      error = e.message ?? "${e.code}: Google sign-in failed.";
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginAnonymously() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _authService.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      error = e.message ?? "${e.code}: Anonymous login failed.";
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    // IMPORTANT: notifyListeners triggers UI reset
    notifyListeners();
  }
}
