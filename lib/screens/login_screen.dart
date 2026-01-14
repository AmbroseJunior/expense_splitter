import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/ui_feedback.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() action,
    AuthProvider auth, {
    required String title,
  }) async {
    await action();
    if (!mounted) return;

    if (auth.error != null) {
      UIFeedback.showDialogBox(context, title: title, message: auth.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const Icon(
                    Icons.receipt_long,
                    size: 72,
                    color: Color(0xFF006A6A),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Smart Expense Splitter",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF006A6A),
                    ),
                  ),
                  const SizedBox(height: 26),

                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => _run(
                              () async {
                                if (emailCtrl.text.trim().isEmpty ||
                                    passCtrl.text.isEmpty) {
                                  UIFeedback.showSnack(
                                    context,
                                    "Fill email & password.",
                                  );
                                  return;
                                }
                                await auth.login(
                                  emailCtrl.text.trim(),
                                  passCtrl.text,
                                );
                              },
                              auth,
                              title: "Login Failed",
                            ),
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Login"),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: auth.isLoading
                          ? null
                          : () => _run(
                              auth.signInWithGoogle,
                              auth,
                              title: "Google Login Failed",
                            ),
                      icon: const Icon(Icons.login),
                      label: const Text("Sign in with Google"),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: auth.isLoading
                        ? null
                        : () => _run(
                            auth.loginAnonymously,
                            auth,
                            title: "Guest Login Failed",
                          ),
                    child: const Text("Continue as Guest"),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: auth.isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegistrationScreen(),
                              ),
                            );
                          },
                    child: const Text("Don’t have an account? Register"),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_off),
                      label: const Text("Offline Mode"),
                      onPressed: () {
                        // 🔒 Offline logic here
                        Navigator.pop(context); //
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
