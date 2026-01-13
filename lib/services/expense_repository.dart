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

  Future<List<LocalExpense>> listExpenses({required String groupId}) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'expenses',
      where: 'groupId = ?',
      whereArgs: [groupId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(LocalExpense.fromDbMap).toList();
  }

  Future<int> addExpense(LocalExpense expense, {bool trySync = true}) async {
    final db = await _localDb.database;
    final id = await db.insert('expenses', expense.toDbMap());
    if (trySync && _syncEnabled) {
      await syncPendingExpenses();
    }
    return id;
  }

  Future<void> syncPendingExpenses() async {
    if (!_syncEnabled) return;
    if (_syncDisabledMissingDb) return;
    if (Firebase.apps.isEmpty) return;
    final db = await _localDb.database;
    final rows = await db.query(
      'expenses',
      where: 'pendingSync = ?',
      whereArgs: [1],
      orderBy: 'createdAt ASC',
    );

    for (final row in rows) {
      final expense = LocalExpense.fromDbMap(row);
      try {
        await _remote.addExpense(
          groupId: expense.groupId,
          title: expense.title,
          amount: expense.amount,
          payerId: expense.payerId,
          participants: expense.participants,
          shares: expense.shares,
        );
        await db.update(
          'expenses',
          {'pendingSync': 0},
          where: 'id = ?',
          whereArgs: [expense.id],
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
}
