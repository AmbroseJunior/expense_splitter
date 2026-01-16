import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/expense_repository.dart';
import 'state/expense_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseAvailable = true;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    firebaseAvailable = false;
  }

  ExpenseRepository.instance.setSyncEnabled(firebaseAvailable);

  runApp(ExpenseSplitterApp(firebaseAvailable: firebaseAvailable));
}

class ExpenseSplitterApp extends StatelessWidget {
  final bool firebaseAvailable;

  const ExpenseSplitterApp({super.key, required this.firebaseAvailable});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseStore()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(enableFirebase: firebaseAvailable),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final store = context.read<ExpenseStore>();
          final loggedIn =
              auth.user != null && auth.user!.isAnonymous == false;
          final ownerId = loggedIn ? auth.user!.uid : 'local';
          final displayName = auth.user?.displayName;
          ExpenseRepository.instance
              .setSyncEnabled(firebaseAvailable && loggedIn);
          store.ensureLoaded(ownerId, displayName: displayName);

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Expense Splitter',
            theme: buildTheme(),
            home: firebaseAvailable
                ? (auth.user == null
                    ? const LoginScreen()
                    : const DashboardScreen())
                : const DashboardScreen(localOnly: true),
          );
        },
      ),
    );
  }
}
