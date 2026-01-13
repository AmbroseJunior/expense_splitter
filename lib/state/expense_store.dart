import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../models/group.dart';
import '../models/local_expense.dart';
import '../models/user.dart';
import '../services/expense_repository.dart';
import '../services/local_db.dart';

class ExpenseStore extends ChangeNotifier {
  final ExpenseRepository _repo;
  final LocalDb _localDb;

  ExpenseStore({
    ExpenseRepository? repo,
    LocalDb? localDb,
  })  : _repo = repo ?? ExpenseRepository.instance,
        _localDb = localDb ?? LocalDb.instance;

  final List<AppUser> users = [];
  final List<Group> _groups = [];
  final Map<String, List<Expense>> _expensesByGroupId = {};

  String? _ownerId;
  bool _loading = false;

  List<Group> get groups => List.unmodifiable(_groups);
  bool get isLoading => _loading;

  void ensureLoaded(String ownerId, {String? displayName}) {
    if (_ownerId == ownerId && !_loading) return;
    if (_ownerId == ownerId && _loading) return;
    _ownerId = ownerId;
    _loading = true;
    notifyListeners();
    Future.microtask(() => _load(ownerId, displayName: displayName));
  }

  Future<void> _load(String ownerId, {String? displayName}) async {
    users.clear();
    _groups.clear();
    _expensesByGroupId.clear();

    final db = await _localDb.database;

    final userRows = await db.query(
      'users',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
      orderBy: 'name ASC',
    );

    for (final row in userRows) {
      users.add(AppUser(id: row['id'] as String, name: row['name'] as String));
    }

    if (users.isEmpty) {
      final defaultName = (displayName == null || displayName.trim().isEmpty)
          ? 'Me'
          : displayName.trim();
      final userId = _newId('u');
      await db.insert('users', {
        'id': userId,
        'name': defaultName,
        'ownerId': ownerId,
      });
      users.add(AppUser(id: userId, name: defaultName));
    }

    final userById = {for (final u in users) u.id: u};

    final groupRows = await db.query(
      'groups',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
      orderBy: 'createdAt DESC',
    );

    for (final row in groupRows) {
      final groupId = row['id'] as String;
      final membersRows = await db.query(
        'group_members',
        where: 'groupId = ?',
        whereArgs: [groupId],
      );
      final members = membersRows
          .map((m) => userById[m['userId'] as String])
          .whereType<AppUser>()
          .toList();
      _groups.add(
        Group(
          id: groupId,
          name: row['name'] as String,
          members: members,
        ),
      );

      final localExpenses =
          await _repo.listExpenses(ownerId: ownerId, groupId: groupId);
      _expensesByGroupId[groupId] =
          localExpenses.map((e) => _toUiExpense(e, userById)).toList();
    }

    await _repo.syncPendingExpenses(ownerId: ownerId);
    _loading = false;
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

  String _newId(String prefix) {
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  Map<String, double> _equalShares(List<AppUser> sharedWith, double amount) {
    if (sharedWith.isEmpty) return {};
    final each = amount / sharedWith.length;
    return {for (final u in sharedWith) u.id: each};
  }

  Map<String, double> _normalizeShares({
    required Map<String, double> shares,
    required List<AppUser> sharedWith,
    required double amount,
    required SplitMethod splitMethod,
  }) {
    if (sharedWith.isEmpty) return {};
    if (splitMethod == SplitMethod.equal) {
      return _equalShares(sharedWith, amount);
    }

    final filtered = {
      for (final u in sharedWith) u.id: shares[u.id] ?? 0.0,
    };
    final total = filtered.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) {
      return _equalShares(sharedWith, amount);
    }

    final factor = amount / total;
    return filtered.map((k, v) => MapEntry(k, v * factor));
  }

  Future<void> addGroup({
    required String name,
    required List<AppUser> members,
    bool notify = true,
  }) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    final clean = name.trim();
    if (clean.isEmpty) return;

    if (members.isEmpty) {
      return;
    }

    final id = _newId('g');
    final group = Group(id: id, name: clean, members: members);
    _groups.add(group);
    _expensesByGroupId.putIfAbsent(id, () => []);

    if (notify) notifyListeners();

    final db = await _localDb.database;
    await db.insert('groups', {
      'id': id,
      'name': clean,
      'ownerId': ownerId,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    for (final member in members) {
      await db.insert('group_members', {
        'groupId': id,
        'userId': member.id,
      });
    }
  }

  Future<void> updateGroup({
    required String groupId,
    required String name,
    required List<AppUser> members,
  }) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;

    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) return;

    final clean = name.trim();
    if (clean.isEmpty) return;
    if (members.isEmpty) return;

    _groups[idx] = Group(id: groupId, name: clean, members: members);

    final deletes = <String>[];
    final updates = <Expense>[];
    final memberIds = members.map((m) => m.id).toSet();
    final list = _expensesByGroupId[groupId] ?? [];
    for (var i = list.length - 1; i >= 0; i--) {
      final e = list[i];
      if (!memberIds.contains(e.paidBy.id)) {
        deletes.add(e.id);
        list.removeAt(i);
        continue;
      }

      final filteredShared =
          e.sharedWith.where((u) => memberIds.contains(u.id)).toList();
      if (filteredShared.isEmpty) {
        deletes.add(e.id);
        list.removeAt(i);
        continue;
      }

      if (filteredShared.length != e.sharedWith.length) {
        final normalizedShares = _normalizeShares(
          shares: e.shares,
          sharedWith: filteredShared,
          amount: e.amount,
          splitMethod: e.splitMethod,
        );
        final updated = Expense(
          id: e.id,
          title: e.title,
          amount: e.amount,
          date: e.date,
          paidBy: e.paidBy,
          sharedWith: filteredShared,
          shares: normalizedShares,
          splitMethod: e.splitMethod,
        );
        list[i] = updated;
        updates.add(updated);
      }
    }

    _expensesByGroupId[groupId] = list;
    notifyListeners();

    final db = await _localDb.database;
    await db.update(
      'groups',
      {'name': clean},
      where: 'ownerId = ? AND id = ?',
      whereArgs: [ownerId, groupId],
    );
    await db.delete(
      'group_members',
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
    for (final member in members) {
      await db.insert('group_members', {
        'groupId': groupId,
        'userId': member.id,
      });
    }
    for (final id in deletes) {
      await _repo.deleteExpense(ownerId: ownerId, id: id);
    }
    for (final expense in updates) {
      await _repo.updateExpense(_toLocalExpense(expense));
    }
  }

  Future<void> deleteGroup(String groupId) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;

    _groups.removeWhere((g) => g.id == groupId);
    _expensesByGroupId.remove(groupId);

    notifyListeners();

    final db = await _localDb.database;
    await db.delete(
      'groups',
      where: 'ownerId = ? AND id = ?',
      whereArgs: [ownerId, groupId],
    );
    await db.delete(
      'group_members',
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
    await db.delete(
      'expenses',
      where: 'ownerId = ? AND groupId = ?',
      whereArgs: [ownerId, groupId],
    );
  }

  Future<void> addExpenseToGroup({
    required String groupId,
    required String title,
    required double amount,
    required DateTime date,
    required AppUser paidBy,
    required List<AppUser> sharedWith,
    required Map<String, double> shares,
    required SplitMethod splitMethod,
  }) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;

    if (!_expensesByGroupId.containsKey(groupId)) {
      _expensesByGroupId[groupId] = [];
    }

    final id = _newId('e');
    final normalizedShares = _normalizeShares(
      shares: shares,
      sharedWith: sharedWith,
      amount: amount,
      splitMethod: splitMethod,
    );
    final expense = Expense(
      id: id,
      title: title.trim(),
      amount: amount,
      date: date,
      paidBy: paidBy,
      sharedWith: sharedWith,
      shares: normalizedShares,
      splitMethod: splitMethod,
    );

    _expensesByGroupId[groupId]!.insert(0, expense);
    notifyListeners();
    await _repo.addExpense(_toLocalExpense(expense, groupId: groupId));
  }

  Future<void> deleteExpenseFromGroup({
    required String groupId,
    required String expenseId,
  }) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;

    final list = _expensesByGroupId[groupId];
    if (list == null) return;

    list.removeWhere((e) => e.id == expenseId);
    notifyListeners();
    await _repo.deleteExpense(ownerId: ownerId, id: expenseId);
  }

  Future<void> updateExpenseInGroup({
    required String groupId,
    required String expenseId,
    required String title,
    required double amount,
    required DateTime date,
    required AppUser paidBy,
    required List<AppUser> sharedWith,
    Map<String, double>? shares,
    SplitMethod? splitMethod,
  }) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;

    final list = _expensesByGroupId[groupId];
    if (list == null) return;

    final idx = list.indexWhere((e) => e.id == expenseId);
    if (idx == -1) return;

    final method = splitMethod ?? SplitMethod.equal;
    final normalizedShares = _normalizeShares(
      shares: shares ?? {},
      sharedWith: sharedWith,
      amount: amount,
      splitMethod: method,
    );
    final updated = Expense(
      id: expenseId,
      title: title.trim(),
      amount: amount,
      date: date,
      paidBy: paidBy,
      sharedWith: sharedWith,
      shares: normalizedShares,
      splitMethod: method,
    );
    list[idx] = updated;
    notifyListeners();
    await _repo.updateExpense(_toLocalExpense(updated, groupId: groupId));
  }

  Future<void> addUser(String name) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    final clean = name.trim();
    if (clean.isEmpty) return;

    final id = _newId('u');
    final user = AppUser(id: id, name: clean);
    users.add(user);

    notifyListeners();

    final db = await _localDb.database;
    await db.insert('users', {'id': id, 'name': clean, 'ownerId': ownerId});
  }

  Future<void> renameUser(String userId, String newName) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    final clean = newName.trim();
    if (clean.isEmpty) return;

    final idx = users.indexWhere((u) => u.id == userId);
    if (idx == -1) return;

    final updated = AppUser(id: userId, name: clean);
    users[idx] = updated;

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
          shares: e.shares,
          splitMethod: e.splitMethod,
        );
      }
    }

    notifyListeners();

    final db = await _localDb.database;
    await db.update(
      'users',
      {'name': clean},
      where: 'ownerId = ? AND id = ?',
      whereArgs: [ownerId, userId],
    );
  }

  Future<bool> deleteUser(String userId) async {
    final ownerId = _ownerId;
    if (ownerId == null) return false;

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

    final deletes = <String>[];
    final updates = <Expense>[];
    for (final key in _expensesByGroupId.keys) {
      final list = _expensesByGroupId[key]!;
      for (var i = list.length - 1; i >= 0; i--) {
        final e = list[i];
        final shared = e.sharedWith.where((m) => m.id != userId).toList();

        if (shared.isEmpty) {
          deletes.add(e.id);
          list.removeAt(i);
        } else {
          final normalizedShares = _normalizeShares(
            shares: e.shares,
            sharedWith: shared,
            amount: e.amount,
            splitMethod: e.splitMethod,
          );
          list[i] = Expense(
            id: e.id,
            title: e.title,
            amount: e.amount,
            date: e.date,
            paidBy: e.paidBy,
            sharedWith: shared,
            shares: normalizedShares,
            splitMethod: e.splitMethod,
          );
          updates.add(list[i]);
        }
      }
    }

    notifyListeners();

    for (final id in deletes) {
      await _repo.deleteExpense(ownerId: ownerId, id: id);
    }
    for (final expense in updates) {
      await _repo.updateExpense(_toLocalExpense(expense));
    }

    final db = await _localDb.database;
    await db.delete(
      'users',
      where: 'ownerId = ? AND id = ?',
      whereArgs: [ownerId, userId],
    );
    await db.delete(
      'group_members',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    return true;
  }

  LocalExpense _toLocalExpense(Expense expense, {String? groupId}) {
    final ownerId = _ownerId ?? 'local';
    final participants = expense.sharedWith.map((u) => u.id).toList();
    final shares = Map<String, double>.from(expense.shares);

    return LocalExpense(
      id: expense.id,
      ownerId: ownerId,
      groupId: groupId ?? _findGroupIdForExpense(expense.id) ?? '',
      title: expense.title,
      amount: expense.amount,
      payerId: expense.paidBy.id,
      participants: participants,
      shares: shares,
      splitMethod: expense.splitMethod,
      createdAt: expense.date,
      pendingSync: true,
    );
  }

  Expense _toUiExpense(LocalExpense expense, Map<String, AppUser> userById) {
    final paidBy = userById[expense.payerId] ??
        AppUser(id: expense.payerId, name: 'Unknown');
    final sharedWith = expense.participants
        .map((id) => userById[id] ?? AppUser(id: id, name: 'Unknown'))
        .toList();
    return Expense(
      id: expense.id,
      title: expense.title,
      amount: expense.amount,
      date: expense.createdAt,
      paidBy: paidBy,
      sharedWith: sharedWith,
      shares: Map<String, double>.from(expense.shares),
      splitMethod: expense.splitMethod,
    );
  }

  String? _findGroupIdForExpense(String expenseId) {
    for (final entry in _expensesByGroupId.entries) {
      if (entry.value.any((e) => e.id == expenseId)) {
        return entry.key;
      }
    }
    return null;
  }
}
