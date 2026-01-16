import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';
import '../models/group.dart';
import '../models/local_expense.dart';
import '../models/user.dart';
import '../services/expense_repository.dart';
import '../services/firestore_service.dart';
import '../services/local_db.dart';

class ExpenseStore extends ChangeNotifier {
  final ExpenseRepository _repo;
  final FirestoreService _remote;
  final LocalDb _localDb;

  ExpenseStore({
    ExpenseRepository? repo,
    FirestoreService? remote,
    LocalDb? localDb,
  })  : _repo = repo ?? ExpenseRepository.instance,
        _remote = remote ?? FirestoreService(),
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
    await _reloadFromDb(ownerId, displayName: displayName);
    await _syncPendingAll(ownerId);
    await _pullFromFirestore(ownerId);
    await _syncPendingAll(ownerId);
    _loading = false;
    notifyListeners();
  }

  Future<void> _reloadFromDb(
    String ownerId, {
    String? displayName,
  }) async {
    users.clear();
    _groups.clear();
    _expensesByGroupId.clear();

    final db = await _localDb.database;

    final userRows = await db.query(
      'users',
      where: 'ownerId = ? AND deleted = ?',
      whereArgs: [ownerId, 0],
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
        'pendingSync': ownerId == 'local' ? 0 : 1,
        'deleted': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      users.add(AppUser(id: userId, name: defaultName));
    }

    final userById = {for (final u in users) u.id: u};

    final groupRows = await db.query(
      'groups',
      where: 'ownerId = ? AND deleted = ?',
      whereArgs: [ownerId, 0],
      orderBy: 'updatedAt DESC',
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
    final nowMs = _nowMs();
    final group = Group(id: id, name: clean, members: members);
    _groups.add(group);
    _expensesByGroupId.putIfAbsent(id, () => []);

    if (notify) notifyListeners();

    final db = await _localDb.database;
    await db.insert('groups', {
      'id': id,
      'name': clean,
      'ownerId': ownerId,
      'createdAt': nowMs,
      'pendingSync': ownerId == 'local' ? 0 : 1,
      'deleted': 0,
      'updatedAt': nowMs,
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

    final nowMs = _nowMs();
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
      {
        'name': clean,
        'pendingSync': ownerId == 'local' ? 0 : 1,
        'updatedAt': nowMs,
      },
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
    await db.update(
      'groups',
      {
        'deleted': 1,
        'pendingSync': ownerId == 'local' ? 0 : 1,
        'updatedAt': _nowMs(),
      },
      where: 'ownerId = ? AND id = ?',
      whereArgs: [ownerId, groupId],
    );
    await db.delete(
      'group_members',
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
    await db.update(
      'expenses',
      {
        'deleted': 1,
        'pendingSync': ownerId == 'local' ? 0 : 1,
        'updatedAt': _nowMs(),
      },
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
    final nowMs = _nowMs();
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
    await _repo.updateExpense(
      LocalExpense(
        id: expenseId,
        ownerId: ownerId,
        groupId: groupId,
        title: '',
        amount: 0,
        payerId: '',
        participants: const [],
        shares: const {},
        splitMethod: SplitMethod.equal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pendingSync: ownerId == 'local' ? false : true,
        deleted: true,
      ),
    );
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
    final nowMs = _nowMs();
    final user = AppUser(id: id, name: clean);
    users.add(user);

    notifyListeners();

    final db = await _localDb.database;
    await db.insert('users', {
      'id': id,
      'name': clean,
      'ownerId': ownerId,
      'pendingSync': ownerId == 'local' ? 0 : 1,
      'deleted': 0,
      'updatedAt': nowMs,
    });
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
      {
        'name': clean,
        'pendingSync': ownerId == 'local' ? 0 : 1,
        'updatedAt': _nowMs(),
      },
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
      await _repo.updateExpense(
        LocalExpense(
          id: id,
          ownerId: ownerId,
          groupId: _findGroupIdForExpense(id) ?? '',
          title: '',
          amount: 0,
          payerId: '',
          participants: const [],
          shares: const {},
          splitMethod: SplitMethod.equal,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          pendingSync: ownerId == 'local' ? false : true,
          deleted: true,
        ),
      );
    }
    for (final expense in updates) {
      await _repo.updateExpense(_toLocalExpense(expense));
    }

    final db = await _localDb.database;
    await db.update(
      'users',
      {
        'deleted': 1,
        'pendingSync': ownerId == 'local' ? 0 : 1,
        'updatedAt': _nowMs(),
      },
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
    final now = DateTime.now();

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
      updatedAt: now,
      pendingSync: ownerId == 'local' ? false : true,
      deleted: false,
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

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<bool> hasLocalData() async {
    final db = await _localDb.database;
    final people = await db.query(
      'users',
      where: 'ownerId = ? AND deleted = ?',
      whereArgs: ['local', 0],
      limit: 1,
    );
    if (people.isNotEmpty) return true;
    final groups = await db.query(
      'groups',
      where: 'ownerId = ? AND deleted = ?',
      whereArgs: ['local', 0],
      limit: 1,
    );
    if (groups.isNotEmpty) return true;
    final expenses = await db.query(
      'expenses',
      where: 'ownerId = ? AND deleted = ?',
      whereArgs: ['local', 0],
      limit: 1,
    );
    return expenses.isNotEmpty;
  }

  Future<void> migrateLocalData({
    required String toOwnerId,
    required bool deleteLocalAfter,
  }) async {
    final db = await _localDb.database;
    final nowMs = _nowMs();

    final existingPeople = await db.query(
      'users',
      where: 'ownerId = ? AND deleted = ?',
      whereArgs: [toOwnerId, 0],
    );
    final existingByName = <String, String>{
      for (final row in existingPeople)
        (row['name'] as String): (row['id'] as String)
    };
    final idMap = <String, String>{};

    final localPeople = await db.query(
      'users',
      where: 'ownerId = ? AND deleted = ?',
      whereArgs: ['local', 0],
    );
    for (final row in localPeople) {
      final localId = row['id'] as String;
      final name = row['name'] as String;
      final existingId = existingByName[name];
      if (existingId != null) {
        idMap[localId] = existingId;
        continue;
      }
      await db.insert(
        'users',
        {
          'id': localId,
          'name': name,
          'ownerId': toOwnerId,
          'pendingSync': 1,
          'deleted': 0,
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      idMap[localId] = localId;
    }

    final localGroups = await db.query(
      'groups',
      where: 'ownerId = ? AND deleted = ?',
      whereArgs: ['local', 0],
    );
    final localGroupIds = <String>[];
    for (final row in localGroups) {
      final groupId = row['id'] as String;
      localGroupIds.add(groupId);
      await db.insert(
        'groups',
        {
          'id': groupId,
          'name': row['name'],
          'ownerId': toOwnerId,
          'createdAt': row['createdAt'] ?? nowMs,
          'pendingSync': 1,
          'deleted': 0,
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final members = await db.query(
        'group_members',
        where: 'groupId = ?',
        whereArgs: [groupId],
      );
      for (final member in members) {
        final mappedId = idMap[member['userId']] ?? member['userId'];
        await db.insert(
          'group_members',
          {
            'groupId': groupId,
            'userId': mappedId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    final localExpenses = await db.query(
      'expenses',
      where: 'ownerId = ? AND deleted = ?',
      whereArgs: ['local', 0],
    );
    for (final row in localExpenses) {
      final rawParticipants = row['participants'] as String? ?? '[]';
      final rawShares = row['shares'] as String? ?? '{}';
      final participants = (jsonDecode(rawParticipants) as List)
          .map((e) => e.toString())
          .map((id) => idMap[id] ?? id)
          .toList();
      final shares = (jsonDecode(rawShares) as Map<String, dynamic>).map(
        (key, value) => MapEntry(idMap[key] ?? key, (value as num).toDouble()),
      );
      final payerId = idMap[row['payerId']] ?? row['payerId'];
      await db.insert(
        'expenses',
        {
          ...row,
          'ownerId': toOwnerId,
          'payerId': payerId,
          'participants': jsonEncode(participants),
          'shares': jsonEncode(shares),
          'pendingSync': 1,
          'updatedAt': nowMs,
          'deleted': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await _dedupeGroups(toOwnerId);

    if (deleteLocalAfter) {
      for (final groupId in localGroupIds) {
        final otherOwnerGroups = await db.query(
          'groups',
          where: 'id = ? AND ownerId != ? AND deleted = ?',
          whereArgs: [groupId, 'local', 0],
          limit: 1,
        );
        if (otherOwnerGroups.isEmpty) {
          await db.delete(
            'group_members',
            where: 'groupId = ?',
            whereArgs: [groupId],
          );
        }
      }
      await db.delete(
        'users',
        where: 'ownerId = ?',
        whereArgs: ['local'],
      );
      await db.delete(
        'groups',
        where: 'ownerId = ?',
        whereArgs: ['local'],
      );
      await db.delete(
        'expenses',
        where: 'ownerId = ?',
        whereArgs: ['local'],
      );
    }

    await _reloadFromDb(toOwnerId);
    await _syncPendingAll(toOwnerId);
    notifyListeners();
  }

  Future<void> clearLocalData() async {
    final db = await _localDb.database;
    final localGroups = await db.query(
      'groups',
      where: 'ownerId = ?',
      whereArgs: ['local'],
    );
    for (final row in localGroups) {
      final groupId = row['id'];
      final otherOwnerGroups = await db.query(
        'groups',
        where: 'id = ? AND ownerId != ? AND deleted = ?',
        whereArgs: [groupId, 'local', 0],
        limit: 1,
      );
      if (otherOwnerGroups.isEmpty) {
        await db.delete(
          'group_members',
          where: 'groupId = ?',
          whereArgs: [groupId],
        );
      }
    }
    await db.delete('users', where: 'ownerId = ?', whereArgs: ['local']);
    await db.delete('groups', where: 'ownerId = ?', whereArgs: ['local']);
    await db.delete('expenses', where: 'ownerId = ?', whereArgs: ['local']);
    notifyListeners();
  }

  Future<void> _syncPendingAll(String ownerId) async {
    if (ownerId == 'local') return;
    await _syncPendingPeople(ownerId);
    await _syncPendingGroups(ownerId);
    await _repo.syncPendingExpenses(ownerId: ownerId);
  }

  Future<void> _dedupeGroups(String ownerId) async {
    final db = await _localDb.database;
    final groups = await db.query(
      'groups',
      where: 'ownerId = ? AND deleted = ?',
      whereArgs: [ownerId, 0],
    );
    if (groups.length < 2) return;

    final nowMs = _nowMs();
    final bestByKey = <String, Map<String, Object?>>{};
    final duplicateToKeep = <String, String>{};

    for (final row in groups) {
      final groupId = row['id'] as String;
      final name = row['name'] as String;
      final membersRows = await db.query(
        'group_members',
        where: 'groupId = ?',
        whereArgs: [groupId],
      );
      final memberIds =
          membersRows.map((m) => m['userId'] as String).toList()
            ..sort();
      final key = '$name|${memberIds.join(",")}';
      final expCount = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM expenses WHERE ownerId = ? AND groupId = ? AND deleted = 0',
              [ownerId, groupId],
            ),
          ) ??
          0;
      final updatedAt = row['updatedAt'] as int? ?? 0;

      final existing = bestByKey[key];
      if (existing == null) {
        bestByKey[key] = {
          'id': groupId,
          'updatedAt': updatedAt,
          'expCount': expCount,
        };
        continue;
      }

      final existingId = existing['id'] as String;
      final existingExp = existing['expCount'] as int? ?? 0;
      final existingUpdated = existing['updatedAt'] as int? ?? 0;
      final keepExisting = (expCount < existingExp) ||
          (expCount == existingExp && updatedAt <= existingUpdated);
      if (keepExisting) {
        duplicateToKeep[groupId] = existingId;
      } else {
        duplicateToKeep[existingId] = groupId;
        bestByKey[key] = {
          'id': groupId,
          'updatedAt': updatedAt,
          'expCount': expCount,
        };
      }
    }

    if (duplicateToKeep.isEmpty) return;

    for (final entry in duplicateToKeep.entries) {
      final dupId = entry.key;
      final keepId = entry.value;
      if (dupId == keepId) continue;
      await db.update(
        'expenses',
        {
          'groupId': keepId,
          'pendingSync': ownerId == 'local' ? 0 : 1,
          'updatedAt': nowMs,
        },
        where: 'ownerId = ? AND groupId = ?',
        whereArgs: [ownerId, dupId],
      );
      await db.delete(
        'group_members',
        where: 'groupId = ?',
        whereArgs: [dupId],
      );
      await db.update(
        'groups',
        {
          'deleted': 1,
          'pendingSync': ownerId == 'local' ? 0 : 1,
          'updatedAt': nowMs,
        },
        where: 'ownerId = ? AND id = ?',
        whereArgs: [ownerId, dupId],
      );
    }
  }

  Future<void> _syncPendingPeople(String ownerId) async {
    try {
      final db = await _localDb.database;
      final rows = await db.query(
        'users',
        where: 'ownerId = ? AND pendingSync = ?',
        whereArgs: [ownerId, 1],
      );
      for (final row in rows) {
        final id = row['id'] as String;
        final name = row['name'] as String;
        final deleted = (row['deleted'] as int? ?? 0) == 1;
        final updatedAtMs = row['updatedAt'] as int? ?? 0;
        if (deleted) {
          await _remote.deletePerson(
            ownerId: ownerId,
            id: id,
            updatedAtMs: updatedAtMs,
          );
        } else {
          await _remote.upsertPerson(
            ownerId: ownerId,
            id: id,
            name: name,
            deleted: false,
            updatedAtMs: updatedAtMs,
          );
        }
        await db.update(
          'users',
          {'pendingSync': 0},
          where: 'ownerId = ? AND id = ?',
          whereArgs: [ownerId, id],
        );
      }
    } catch (_) {
      // Ignore sync errors.
    }
  }

  Future<void> _syncPendingGroups(String ownerId) async {
    try {
      final db = await _localDb.database;
      final rows = await db.query(
        'groups',
        where: 'ownerId = ? AND pendingSync = ?',
        whereArgs: [ownerId, 1],
      );
      for (final row in rows) {
        final id = row['id'] as String;
        final name = row['name'] as String;
        final deleted = (row['deleted'] as int? ?? 0) == 1;
        final updatedAtMs = row['updatedAt'] as int? ?? 0;
        if (deleted) {
          await _remote.deleteGroup(
            ownerId: ownerId,
            groupId: id,
            updatedAtMs: updatedAtMs,
          );
        } else {
          final membersRows = await db.query(
            'group_members',
            where: 'groupId = ?',
            whereArgs: [id],
          );
          final memberIds =
              membersRows.map((m) => m['userId'] as String).toList();
          await _remote.upsertGroup(
            ownerId: ownerId,
            id: id,
            name: name,
            memberIds: memberIds,
            deleted: false,
            updatedAtMs: updatedAtMs,
          );
        }
        await db.update(
          'groups',
          {'pendingSync': 0},
          where: 'ownerId = ? AND id = ?',
          whereArgs: [ownerId, id],
        );
      }
    } catch (_) {
      // Ignore sync errors.
    }
  }

  Future<void> _pullFromFirestore(String ownerId) async {
    if (ownerId == 'local') return;
    try {
      final db = await _localDb.database;
      final people = await _remote.fetchPeople(ownerId);
      for (final doc in people.docs) {
        final data = doc.data();
        final deleted = data['deleted'] == true;
        final updatedAtMs = (data['updatedAtMs'] as int?) ?? 0;
        final local = await db.query(
          'users',
          where: 'ownerId = ? AND id = ?',
          whereArgs: [ownerId, doc.id],
          limit: 1,
        );
        final localUpdatedAt = local.isEmpty
            ? 0
            : (local.first['updatedAt'] as int? ?? 0);
        if (updatedAtMs < localUpdatedAt) continue;
        await db.insert(
          'users',
          {
            'id': doc.id,
            'name': data['name'] ?? '',
            'ownerId': ownerId,
            'pendingSync': 0,
            'deleted': deleted ? 1 : 0,
            'updatedAt': updatedAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final groups = await _remote.fetchGroups(ownerId);
      for (final doc in groups.docs) {
        final data = doc.data();
        final deleted = data['deleted'] == true;
        final updatedAtMs = (data['updatedAtMs'] as int?) ?? 0;
        final local = await db.query(
          'groups',
          where: 'ownerId = ? AND id = ?',
          whereArgs: [ownerId, doc.id],
          limit: 1,
        );
        final localUpdatedAt = local.isEmpty
            ? 0
            : (local.first['updatedAt'] as int? ?? 0);
        if (updatedAtMs < localUpdatedAt) continue;
        await db.insert(
          'groups',
          {
            'id': doc.id,
            'name': data['name'] ?? '',
            'ownerId': ownerId,
            'createdAt': updatedAtMs,
            'pendingSync': 0,
            'deleted': deleted ? 1 : 0,
            'updatedAt': updatedAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await db.delete(
          'group_members',
          where: 'groupId = ?',
          whereArgs: [doc.id],
        );

        final inferredMemberIds = <String>{};
        final expenses = await _remote.fetchExpenses(
          ownerId: ownerId,
          groupId: doc.id,
        );
        for (final exp in expenses.docs) {
          final expData = exp.data();
          final expDeleted = expData['deleted'] == true;
          final expUpdatedAtMs = (expData['updatedAtMs'] as int?) ?? 0;
          final localExp = await db.query(
            'expenses',
            where: 'ownerId = ? AND id = ?',
            whereArgs: [ownerId, exp.id],
            limit: 1,
          );
          final localExpUpdatedAt = localExp.isEmpty
              ? 0
              : (localExp.first['updatedAt'] as int? ?? 0);
          if (expUpdatedAtMs < localExpUpdatedAt) continue;
          final rawSharedWith = expData['sharedWith'];
          final rawParticipants = expData['participants'];
          List<String> participants = [];
          if (rawParticipants is List) {
            participants = rawParticipants.map((e) => e.toString()).toList();
          } else if (rawSharedWith is List) {
            participants = rawSharedWith
                .map((e) => e is Map ? e['id']?.toString() : null)
                .whereType<String>()
                .toList();
          }
          inferredMemberIds.addAll(participants);
          final payerId = (expData['paidById'] ??
                  (expData['paidBy'] is Map
                      ? (expData['paidBy'] as Map)['id']
                      : '')) ??
              '';
          if (payerId.toString().isNotEmpty) {
            inferredMemberIds.add(payerId.toString());
          }
          final sharesMap = (expData['shares'] as Map?)?.cast<String, dynamic>() ?? {};
          await db.insert(
            'expenses',
            {
              'id': exp.id,
              'ownerId': ownerId,
              'groupId': doc.id,
              'title': expData['title'] ?? '',
              'amount': (expData['amount'] as num?)?.toDouble() ?? 0.0,
              'payerId': payerId.toString(),
              'participants': jsonEncode(participants),
              'shares': jsonEncode(
                sharesMap.map(
                  (key, value) => MapEntry(key, (value as num).toDouble()),
                ),
              ),
              'splitMethod': expData['splitMethod'] ?? 'equal',
              'createdAt': DateTime.tryParse(expData['date'] ?? '')
                      ?.millisecondsSinceEpoch ??
                  expUpdatedAtMs,
              'updatedAt': expUpdatedAtMs,
              'pendingSync': 0,
              'deleted': expDeleted ? 1 : 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        final memberIds = (data['memberIds'] as List?)?.cast<String>() ?? [];
        final effectiveMemberIds =
            memberIds.isNotEmpty ? memberIds : inferredMemberIds.toList();
        for (final memberId in effectiveMemberIds) {
          await db.insert('group_members', {
            'groupId': doc.id,
            'userId': memberId,
          });
        }
      }
      await _dedupeGroups(ownerId);
      await _reloadFromDb(ownerId);
    } catch (_) {
      // Ignore pull errors; local data still works.
    }
  }
}
