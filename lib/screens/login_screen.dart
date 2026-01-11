import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_splitter/providers/auth_provider.dart';
import 'package:expense_splitter/screens/registration_screen.dart';
import 'package:expense_splitter/widgets/ui_feedback.dart';

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
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              children: [
                // LOGO
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF0097A7), Color(0xFF006A6A)],
                    ),
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
                        color: const Color(0xFF006A6A),
                      ),
                ),

                const SizedBox(height: 35),

                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password"),
                ),

                const SizedBox(height: 20),

                // REGISTER LINK
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegistrationScreen(),
                      ),
                    );
                  },
                  child: const Text("Don't have an account? Register"),
                ),

                const SizedBox(height: 10),

                // LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            if (emailCtrl.text.isEmpty ||
                                passCtrl.text.isEmpty) {
                              UIFeedback.showSnack(
                                context,
                                "Please fill in all fields.",
                              );
                              return;
                            }

                            await auth.login(
                              emailCtrl.text,
                              passCtrl.text,
                            );

                            if (auth.error != null) {
                              UIFeedback.showDialogBox(
                                context,
                                title: "Login Failed",
                                message: auth.error!,
                              );
                            }
                          },
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text("Login"),
                  ),
                ),
                const SizedBox(height: 20),
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
                          }
                        },
                  child: const Text("Continue as Guest"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
