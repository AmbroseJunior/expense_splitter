import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'theme.dart';
import 'state/expense_store.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ExpenseStore(),
      child: const ExpenseSplitterApp(),
    ),
  );
}

class ExpenseSplitterApp extends StatelessWidget {
  const ExpenseSplitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense Splitter',
      theme: buildTheme(),
      home: const LoginScreen(),
    );
  }
}
