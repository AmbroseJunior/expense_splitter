import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../models/group.dart';
import '../models/user.dart';

class ExpenseStore extends ChangeNotifier {
  //modifiable (ne const), ker bomo dodajali/brisali/spreminjali člane
  final List<AppUser> users = [
    const AppUser(id: 'u1', name: 'Ana'),
    const AppUser(id: 'u2', name: 'Bor'),
    const AppUser(id: 'u3', name: 'Cene'),
  ];

  final List<Group> _groups = [];
  final Map<String, List<Expense>> _expensesByGroupId = {};

  List<Group> get groups => List.unmodifiable(_groups);

  ExpenseStore() {
    _seedDefaultGroups();
  }

  void _seedDefaultGroups() {
    addGroup(name: "Roommates", members: users, notify: false);
    addGroup(name: "Trip to Paris", members: users, notify: false);
    addGroup(name: "Project Team", members: users, notify: false);
    notifyListeners();
  }

  Group? getGroupById(String groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  AppUser? getUserById(String userId) {
    try {
      return users.firstWhere((u) => u.id == userId);
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

    final id =
        'g_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final group = Group(id: id, name: clean, members: members);

    _groups.add(group);
    _expensesByGroupId.putIfAbsent(id, () => []);

    if (notify) notifyListeners();
  }

  void updateGroup({
    required String groupId,
    required String name,
    required List<AppUser> members,
  }) {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) return;

    final clean = name.trim();
    if (clean.isEmpty) return;

    //posodobi group
    _groups[idx] = Group(id: groupId, name: clean, members: members);

    //če si koga odstranil iz memberjev, delete stroške:
    final memberIds = members.map((m) => m.id).toSet();
    final list = _expensesByGroupId[groupId] ?? [];

    for (var i = list.length - 1; i >= 0; i--) {
      final e = list[i];

      if (!memberIds.contains(e.paidBy.id)) {
        list.removeAt(i);
        continue;
      }

      final filteredShared =
          e.sharedWith.where((u) => memberIds.contains(u.id)).toList();

      if (filteredShared.isEmpty) {
        list.removeAt(i);
        continue;
      }

      if (filteredShared.length != e.sharedWith.length) {
        list[i] = Expense(
          id: e.id,
          title: e.title,
          amount: e.amount,
          date: e.date,
          paidBy: e.paidBy,
          sharedWith: filteredShared,
        );
      }
    }

    _expensesByGroupId[groupId] = list;
    notifyListeners();
  }

  void deleteGroup(String groupId) {
    _groups.removeWhere((g) => g.id == groupId);
    _expensesByGroupId.remove(groupId);
    notifyListeners();
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

    final id =
        'e_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

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

  void deleteExpenseFromGroup({
    required String groupId,
    required String expenseId,
  }) {
    final list = _expensesByGroupId[groupId];
    if (list == null) return;

    list.removeWhere((e) => e.id == expenseId);
    notifyListeners();
  }

  void updateExpenseInGroup({
    required String groupId,
    required String expenseId,
    required String title,
    required double amount,
    required DateTime date,
    required AppUser paidBy,
    required List<AppUser> sharedWith,
  }) {
    final list = _expensesByGroupId[groupId];
    if (list == null) return;

    final idx = list.indexWhere((e) => e.id == expenseId);
    if (idx == -1) return;

    list[idx] = Expense(
      id: expenseId,
      title: title.trim(),
      amount: amount,
      date: date,
      paidBy: paidBy,
      sharedWith: sharedWith,
    );

    notifyListeners();
  }

  void addUser(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;

    final id =
        'u_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    users.add(AppUser(id: id, name: clean));
    notifyListeners();
  }

  void renameUser(String userId, String newName) {
    final clean = newName.trim();
    if (clean.isEmpty) return;

    final idx = users.indexWhere((u) => u.id == userId);
    if (idx == -1) return;

    final updated = AppUser(id: userId, name: clean);
    users[idx] = updated;

    // update v grupah
    for (var gi = 0; gi < _groups.length; gi++) {
      final g = _groups[gi];
      final updatedMembers =
          g.members.map((m) => m.id == userId ? updated : m).toList();
      _groups[gi] = Group(id: g.id, name: g.name, members: updatedMembers);
    }

    for (final key in _expensesByGroupId.keys) {
      final list = _expensesByGroupId[key]!;
      for (var ei = 0; ei < list.length; ei++) {
        final e = list[ei];

        final paidBy = e.paidBy.id == userId ? updated : e.paidBy;
        final shared =
            e.sharedWith.map((m) => m.id == userId ? updated : m).toList();

        list[ei] = Expense(
          id: e.id,
          title: e.title,
          amount: e.amount,
          date: e.date,
          paidBy: paidBy,
          sharedWith: shared,
        );
      }
    }

    notifyListeners();
  }

  ///Delete user
  ///če je user "paidBy" v kateremkoli expense - ne dovolimo (vrne false)
  
  bool deleteUser(String userId) {
    // blokiraj, če je payer kjerkoli
    for (final list in _expensesByGroupId.values) {
      for (final e in list) {
        if (e.paidBy.id == userId) return false;
      }
    }

    users.removeWhere((u) => u.id == userId);

    for (var gi = 0; gi < _groups.length; gi++) {
      final g = _groups[gi];
      final updatedMembers = g.members.where((m) => m.id != userId).toList();
      _groups[gi] = Group(id: g.id, name: g.name, members: updatedMembers);
    }

    for (final key in _expensesByGroupId.keys) {
      final list = _expensesByGroupId[key]!;
      for (var i = list.length - 1; i >= 0; i--) {
        final e = list[i];
        final shared = e.sharedWith.where((m) => m.id != userId).toList();

        if (shared.isEmpty) {
          list.removeAt(i);
        } else {
          list[i] = Expense(
            id: e.id,
            title: e.title,
            amount: e.amount,
            date: e.date,
            paidBy: e.paidBy,
            sharedWith: shared,
          );
        }
      }
    }

    notifyListeners();
    return true;
  }
}
