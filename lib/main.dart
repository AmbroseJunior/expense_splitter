import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'state/expense_store.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        // 🔐 Authentication
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),

        // 💸 Expense Store (bound to logged-in user)
        ChangeNotifierProxyProvider<AuthProvider, ExpenseStore>(
          create: (_) => ExpenseStore(),
          update: (_, auth, store) {
            final uid = auth.user?.uid;

            if (uid == null) {
              // 🚪 User logged out → wipe local data
              store?.clear();
            } else {
              // 🔑 User logged in → bind Firestore to THIS user only
              if (store?.ownerUid != uid) {
                store?.bindToUser(uid);
              }
            }

            return store!;
          },
        ),
      ],
      child: const ExpenseSplitterApp(),
    ),
  );
}

class ExpenseSplitterApp extends StatelessWidget {
  const ExpenseSplitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense Splitter',
      theme: buildTheme(),
      home: auth.user == null ? const LoginScreen() : const DashboardScreen(),
    );
  }
}
