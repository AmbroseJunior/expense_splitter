import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../models/group.dart';
import '../models/user.dart';

class ExpenseStore extends ChangeNotifier {
  // Demo users (lahko kasneje zamenjaš z login uporabniki)
  final List<AppUser> users = const [
    AppUser(id: 'u1', name: 'Ana'),
    AppUser(id: 'u2', name: 'Bor'),
    AppUser(id: 'u3', name: 'Cene'),
  ];

  final List<Group> _groups = [];
  final Map<String, List<Expense>> _expensesByGroupId = {};

  List<Group> get groups => List.unmodifiable(_groups);

  ExpenseStore() {
    // default grupe (da ti UI ostane kot prej)
    _seedDefaultGroups();
  }

  void _seedDefaultGroups() {
    addGroup(
      name: "Roommates",
      members: users,
      notify: false,
    );
    addGroup(
      name: "Trip to Paris",
      members: users,
      notify: false,
    );
    addGroup(
      name: "Project Team",
      members: users,
      notify: false,
    );
    notifyListeners();
  }

  Group? getGroupById(String groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  List<Expense> expensesForGroup(String groupId) {
    return List.unmodifiable(_expensesByGroupId[groupId] ?? []);
  }
  List<Expense> get allExpenses {
  return _expensesByGroupId.values.expand((list) => list).toList();
}

  void addGroup({
    required String name,
    required List<AppUser> members,
    bool notify = true,
  }) {
    final clean = name.trim();
    if (clean.isEmpty) return;

    final id = 'g_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final group = Group(id: id, name: clean, members: members);

    _groups.add(group);
    _expensesByGroupId.putIfAbsent(id, () => []);

    if (notify) notifyListeners();
  }

  void addExpenseToGroup({
    required String groupId,
    required String title,
    required double amount,
    required DateTime date,
    required AppUser paidBy,
    required List<AppUser> sharedWith,
  }) {
    if (!_expensesByGroupId.containsKey(groupId)) {
      _expensesByGroupId[groupId] = [];
    }

    final id = 'e_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    _expensesByGroupId[groupId]!.add(
      Expense(
        id: id,
        title: title.trim(),
        amount: amount,
        date: date,
        paidBy: paidBy,
        sharedWith: sharedWith,
      ),
    );

    notifyListeners();
  }
}
