
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/user.dart';

class ExpenseStore extends ChangeNotifier {
  final List<AppUser> users = const [
    AppUser(id: 'u1', name: 'Ana'),
    AppUser(id: 'u2', name: 'Bor'),
    AppUser(id: 'u3', name: 'Cene'),
  ];

  final List<Expense> _expenses = [];
  List<Expense> get expenses => _expenses;

  void addExpense({
    required String title,
    required double amount,
    required DateTime date,
    required AppUser paidBy,
    required List<AppUser> sharedWith,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();

    _expenses.add(
      Expense(
        id: id,
        title: title,
        amount: amount,
        date: date,
        paidBy: paidBy,
        sharedWith: sharedWith,
      ),
    );

    notifyListeners();
  }
}
