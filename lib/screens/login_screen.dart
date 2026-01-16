import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import '../providers/auth_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/registration_screen.dart';
import '../services/expense_repository.dart';
import '../widgets/ui_feedback.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [cs.secondary, cs.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  "Smart Expense Splitter",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                ),
                const SizedBox(height: 35),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    filled: true,
                  ),
                ),
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegistrationScreen(),
                      ),
                    );
                  },
                  child: Text(
                    "Don't have an account? Register",
                    style: TextStyle(
                      fontSize: 16,
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            await auth.login(
                              emailCtrl.text.trim(),
                              passCtrl.text,
                            );

                          if (auth.error != null) {
                            UIFeedback.showDialogBox(
                              context,
                              title: "Login Failed",
                              message: auth.error!,
                            );
                              return;
                            }

                            ExpenseRepository.instance
                                .setSyncEnabled(Firebase.apps.isNotEmpty);
                            if (mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DashboardScreen(),
                                ),
                              );
                            }
                          },
                    child: const Text("Login"),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text("Sign in with Google"),
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          await auth.loginWithGoogle();

                          if (auth.error != null) {
                            UIFeedback.showDialogBox(
                              context,
                              title: "Google Login Failed",
                              message: auth.error!,
                            );
                            return;
                          }

                          ExpenseRepository.instance
                              .setSyncEnabled(Firebase.apps.isNotEmpty);
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DashboardScreen(),
                              ),
                            );
                          }
                        },
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          await auth.loginAnonymously();

                          if (auth.error != null) {
                            UIFeedback.showDialogBox(
                              context,
                              title: "Guest Login Failed",
                              message: auth.error!,
                            );
                            return;
                          }

                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DashboardScreen(),
                              ),
                            );
                          }
                        },
                  child: const Text("Continue as Guest"),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: auth.isLoading
                      ? null
                      : () {
                          ExpenseRepository.instance.setSyncEnabled(false);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const DashboardScreen(localOnly: true),
                            ),
                          );
                        },
                  child: const Text("Continue offline (SQLite only)"),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
