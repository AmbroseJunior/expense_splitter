import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_splitter/providers/auth_provider.dart';
import 'package:expense_splitter/widgets/ui_feedback.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.person_add,
                    size: 80,
                    color: Color(0xFF006A6A),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Join Smart Expense Splitter",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF006A6A),
                        ),
                  ),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Full Name"),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 30),
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirm Password",
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              if (nameCtrl.text.isEmpty ||
                                  emailCtrl.text.isEmpty ||
                                  passCtrl.text.isEmpty ||
                                  confirmCtrl.text.isEmpty) {
                                UIFeedback.showSnack(
                                  context,
                                  "All fields are required.",
                                );
                                return;
                              }

                              if (passCtrl.text.length < 6) {
                                UIFeedback.showSnack(
                                  context,
                                  "Password must be at least 6 characters.",
                                );
                                return;
                              }

                              if (passCtrl.text != confirmCtrl.text) {
                                UIFeedback.showSnack(
                                  context,
                                  "Passwords do not match.",
                                );
                                return;
                              }

                              await auth.register(
                                nameCtrl.text,
                                emailCtrl.text,
                                passCtrl.text,
                              );

                              if (auth.error == null) {
                                UIFeedback.showSnack(
                                  context,
                                  "Registration successful! Please log in.",
                                );

                                await auth.logoutAfterRegister();

                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              } else {
                                UIFeedback.showDialogBox(
                                  context,
                                  title: "Registration Failed",
                                  message: auth.error!,
                                );
                              }
                            },
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Create Account"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text("Already have an account? Login"),
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
