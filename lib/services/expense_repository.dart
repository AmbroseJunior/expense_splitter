import 'package:sqflite/sqflite.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/local_expense.dart';
import 'firestore_service.dart';
import 'local_db.dart';

class ExpenseRepository {
  ExpenseRepository._();

  static final ExpenseRepository instance = ExpenseRepository._();

  final LocalDb _localDb = LocalDb.instance;
  final FirestoreService _remote = FirestoreService();
  bool _syncDisabledMissingDb = false;
  bool _syncEnabled = true;

  void setSyncEnabled(bool enabled) {
    _syncEnabled = enabled;
  }

  Future<List<LocalExpense>> listExpenses({
    required String ownerId,
    required String groupId,
  }) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'expenses',
      where: 'ownerId = ? AND groupId = ? AND deleted = ?',
      whereArgs: [ownerId, groupId, 0],
      orderBy: 'updatedAt DESC',
    );
    return rows.map(LocalExpense.fromDbMap).toList();
  }

  Future<int> addExpense(LocalExpense expense, {bool trySync = true}) async {
    final db = await _localDb.database;
    await db.insert('expenses', expense.toDbMap());
    if (trySync && _syncEnabled) {
      await syncPendingExpenses(ownerId: expense.ownerId);
    }
    return 1;
  }

  Future<void> syncPendingExpenses({required String ownerId}) async {
    if (!_syncEnabled) return;
    if (_syncDisabledMissingDb) return;
    if (Firebase.apps.isEmpty) return;
    final db = await _localDb.database;
    final rows = await db.query(
      'expenses',
      where: 'ownerId = ? AND pendingSync = ?',
      whereArgs: [ownerId, 1],
      orderBy: 'updatedAt ASC',
    );
    final userRows = await db.query(
      'users',
      where: 'ownerId = ? AND deleted = ?',
      whereArgs: [ownerId, 0],
    );
    final userNames = {
      for (final row in userRows) row['id'] as String: row['name'] as String
    };

    for (final row in rows) {
      final expense = LocalExpense.fromDbMap(row);
      try {
        if (expense.deleted) {
          await _remote.deleteExpense(
            ownerId: ownerId,
            groupId: expense.groupId,
            expenseId: expense.id,
            updatedAtMs: expense.updatedAt.millisecondsSinceEpoch,
          );
        } else {
          final paidByName = userNames[expense.payerId] ?? '';
          final paidBy = {'id': expense.payerId, 'name': paidByName};
          final sharedWith = expense.participants
              .map((id) => {'id': id, 'name': userNames[id] ?? ''})
              .toList();
          await _remote.upsertExpense(
            ownerId: ownerId,
            groupId: expense.groupId,
            id: expense.id,
            title: expense.title,
            amount: expense.amount,
            paidBy: paidBy,
            sharedWith: sharedWith,
            participants: expense.participants,
            shares: expense.shares,
            splitMethod: splitMethodToString(expense.splitMethod),
            dateIso: expense.createdAt.toIso8601String(),
            updatedAtMs: expense.updatedAt.millisecondsSinceEpoch,
          );
        }
        await db.update(
          'expenses',
          {'pendingSync': 0},
          where: 'ownerId = ? AND id = ?',
          whereArgs: [ownerId, expense.id],
        );
      } on FirebaseException catch (e) {
        if (e.code == 'not-found' ||
            e.message?.contains('database (default) does not exist') == true) {
          _syncDisabledMissingDb = true;
        }
        // Keep pending when offline or sync fails.
        break;
      } catch (_) {
        // Keep pending when offline or sync fails.
        break;
      }
    }
  }

  Future<void> updateExpense(LocalExpense expense) async {
    final db = await _localDb.database;
    await db.update(
      'expenses',
      expense.toDbMap(),
      where: 'ownerId = ? AND id = ?',
      whereArgs: [expense.ownerId, expense.id],
    );
  }

  Future<void> deleteExpense({
    required String ownerId,
    required String id,
  }) async {
    final db = await _localDb.database;
    await db.delete(
      'expenses',
      where: 'ownerId = ? AND id = ?',
      whereArgs: [ownerId, id],
    );
  }
}
