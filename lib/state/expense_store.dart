import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../models/group.dart';
import '../models/user.dart';

class ExpenseStore extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ✅ KEEP users list name + type (as requested)
  final List<AppUser> users = [
    const AppUser(id: 'u1', name: ''),
    const AppUser(id: 'u2', name: ''),
    const AppUser(id: 'u3', name: ''),
  ];

  String? ownerUid;

  StreamSubscription? _groupsSub;
  StreamSubscription? _peopleSub;
  final Map<String, StreamSubscription> _expensesSubs = {};

  final List<Group> _groups = [];
  final Map<String, List<Expense>> _expensesByGroupId = {};

  List<Group> get groups => List.unmodifiable(_groups);

  ExpenseStore();

  // ==========================
  // 🔑 USER BINDING (CRITICAL)
  // ==========================
  void bindToUser(String uid) {
    // stop any previous listeners & clear local cache
    clear();
    ownerUid = uid;

    _groupsSub?.cancel();
    _peopleSub?.cancel();
    for (final sub in _expensesSubs.values) {
      sub.cancel();
    }
    _expensesSubs.clear();

    // ✅ PEOPLE realtime sync (this fixes "new user sees old user data")
    _peopleSub = _db
        .collection('users')
        .doc(uid)
        .collection('people')
        .snapshots()
        .listen((snapshot) {
          // keep the list object, only update its contents
          users.clear();

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString();
            users.add(AppUser(id: doc.id, name: name));
          }

          notifyListeners();
        });

    // ✅ GROUPS realtime sync
    _groupsSub = _db
        .collection('users')
        .doc(uid)
        .collection('groups')
        .snapshots()
        .listen((snapshot) {
          _groups.clear();
          _expensesByGroupId.clear();

          // cancel previous expense listeners (groups could have changed)
          for (final sub in _expensesSubs.values) {
            sub.cancel();
          }
          _expensesSubs.clear();

          for (final doc in snapshot.docs) {
            final data = doc.data();

            final membersRaw = (data['members'] as List?) ?? [];
            final members = membersRaw.map((m) {
              final mm = Map<String, dynamic>.from(m as Map);
              return AppUser(
                id: (mm['id'] ?? '').toString(),
                name: (mm['name'] ?? '').toString(),
              );
            }).toList();

            final group = Group(
              id: doc.id,
              name: (data['name'] ?? '').toString(),
              members: members,
            );

            _groups.add(group);
            _expensesByGroupId[group.id] = [];

            // ✅ EXPENSES realtime sync for this group
            _expensesSubs[group.id] = doc.reference
                .collection('expenses')
                .snapshots()
                .listen((expSnap) {
                  _expensesByGroupId[group.id] = expSnap.docs.map((e) {
                    final d = e.data();

                    final paidByMap = Map<String, dynamic>.from(
                      (d['paidBy'] ?? {}) as Map,
                    );
                    final sharedRaw = (d['sharedWith'] as List?) ?? [];

                    return Expense(
                      id: e.id,
                      title: (d['title'] ?? '').toString(),
                      amount: (d['amount'] as num).toDouble(),
                      date: DateTime.parse((d['date'] ?? '').toString()),
                      paidBy: AppUser(
                        id: (paidByMap['id'] ?? '').toString(),
                        name: (paidByMap['name'] ?? '').toString(),
                      ),
                      sharedWith: sharedRaw.map((u) {
                        final uu = Map<String, dynamic>.from(u as Map);
                        return AppUser(
                          id: (uu['id'] ?? '').toString(),
                          name: (uu['name'] ?? '').toString(),
                        );
                      }).toList(),
                    );
                  }).toList();

                  notifyListeners();
                });
          }

          notifyListeners();
        });
  }

  // ==========================
  // 🔍 GETTERS (unchanged)
  // ==========================
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

  List<Expense> expensesForGroup(String groupId) =>
      List.unmodifiable(_expensesByGroupId[groupId] ?? []);

  List<Expense> get allExpenses =>
      _expensesByGroupId.values.expand((e) => e).toList();

  // ==========================
  // 🧩 GROUPS (SYNCED)
  // ==========================
  void addGroup({
    required String name,
    required List<AppUser> members,
    bool notify = true,
  }) {
    if (ownerUid == null) return;

    final clean = name.trim();
    if (clean.isEmpty) return;

    final groupId =
        'g_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    _db.collection('users').doc(ownerUid).collection('groups').doc(groupId).set(
      {
        'name': clean,
        'members': members.map((m) => {'id': m.id, 'name': m.name}).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  void updateGroup({
    required String groupId,
    required String name,
    required List<AppUser> members,
  }) {
    if (ownerUid == null) return;

    _db
        .collection('users')
        .doc(ownerUid)
        .collection('groups')
        .doc(groupId)
        .update({
          'name': name.trim(),
          'members': members.map((m) => {'id': m.id, 'name': m.name}).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  void deleteGroup(String groupId) {
    if (ownerUid == null) return;

    _db
        .collection('users')
        .doc(ownerUid)
        .collection('groups')
        .doc(groupId)
        .delete();
  }

  // ==========================
  // 💸 EXPENSES (SYNCED)
  // ==========================
  void addExpenseToGroup({
    required String groupId,
    required String title,
    required double amount,
    required DateTime date,
    required AppUser paidBy,
    required List<AppUser> sharedWith,
  }) {
    if (ownerUid == null) return;

    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return;

    final expenseId =
        'e_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    _db
        .collection('users')
        .doc(ownerUid)
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expenseId)
        .set({
          'title': cleanTitle,
          'amount': amount,
          'date': date.toIso8601String(),
          'paidBy': {'id': paidBy.id, 'name': paidBy.name},
          'sharedWith': sharedWith
              .map((u) => {'id': u.id, 'name': u.name})
              .toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  void deleteExpenseFromGroup({
    required String groupId,
    required String expenseId,
  }) {
    if (ownerUid == null) return;

    _db
        .collection('users')
        .doc(ownerUid)
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
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
    if (ownerUid == null) return;

    _db
        .collection('users')
        .doc(ownerUid)
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expenseId)
        .update({
          'title': title.trim(),
          'amount': amount,
          'date': date.toIso8601String(),
          'paidBy': {'id': paidBy.id, 'name': paidBy.name},
          'sharedWith': sharedWith
              .map((u) => {'id': u.id, 'name': u.name})
              .toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // ==========================
  // 👥 PEOPLE (SYNCED)
  // ==========================
  void addUser(String name) {
    if (ownerUid == null) return;

    final clean = name.trim();
    if (clean.isEmpty) return;

    final id =
        'u_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    _db.collection('users').doc(ownerUid).collection('people').doc(id).set({
      'name': clean,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void renameUser(String userId, String newName) {
    if (ownerUid == null) return;

    final clean = newName.trim();
    if (clean.isEmpty) return;

    // update in people collection
    _db
        .collection('users')
        .doc(ownerUid)
        .collection('people')
        .doc(userId)
        .update({'name': clean});

    // also update in all group members + expenses (fire-and-forget)
    Future.microtask(() async {
      final groupsSnap = await _db
          .collection('users')
          .doc(ownerUid)
          .collection('groups')
          .get();

      for (final g in groupsSnap.docs) {
        final data = g.data();
        final membersRaw = (data['members'] as List?) ?? [];

        final updatedMembers = membersRaw.map((m) {
          final mm = Map<String, dynamic>.from(m as Map);
          if ((mm['id'] ?? '').toString() == userId) {
            mm['name'] = clean;
          }
          return mm;
        }).toList();

        await g.reference.update({'members': updatedMembers});

        final expensesSnap = await g.reference.collection('expenses').get();
        for (final e in expensesSnap.docs) {
          final d = e.data();

          final paidByMap = Map<String, dynamic>.from(
            (d['paidBy'] ?? {}) as Map,
          );
          if ((paidByMap['id'] ?? '').toString() == userId) {
            paidByMap['name'] = clean;
          }

          final sharedRaw = (d['sharedWith'] as List?) ?? [];
          final updatedShared = sharedRaw.map((u) {
            final uu = Map<String, dynamic>.from(u as Map);
            if ((uu['id'] ?? '').toString() == userId) {
              uu['name'] = clean;
            }
            return uu;
          }).toList();

          await e.reference.update({
            'paidBy': paidByMap,
            'sharedWith': updatedShared,
          });
        }
      }
    });
  }

  /// ✅ EXACT same rule as your original:
  /// if user is "paidBy" anywhere -> cannot delete (return false)
  bool deleteUser(String userId) {
    // local check based on realtime cache
    for (final list in _expensesByGroupId.values) {
      for (final e in list) {
        if (e.paidBy.id == userId) return false;
      }
    }

    if (ownerUid == null) return false;

    // fire-and-forget updates
    Future.microtask(() async {
      // remove from people
      await _db
          .collection('users')
          .doc(ownerUid)
          .collection('people')
          .doc(userId)
          .delete();

      // remove from groups + from sharedWith in expenses
      final groupsSnap = await _db
          .collection('users')
          .doc(ownerUid)
          .collection('groups')
          .get();

      for (final g in groupsSnap.docs) {
        final data = g.data();
        final membersRaw = (data['members'] as List?) ?? [];

        final updatedMembers = membersRaw
            .where(
              (m) =>
                  (Map<String, dynamic>.from(m as Map)['id'] ?? '')
                      .toString() !=
                  userId,
            )
            .toList();

        await g.reference.update({'members': updatedMembers});

        final expensesSnap = await g.reference.collection('expenses').get();
        for (final e in expensesSnap.docs) {
          final d = e.data();

          final paidByMap = Map<String, dynamic>.from(
            (d['paidBy'] ?? {}) as Map,
          );

          // if user is payer (shouldn't happen because we blocked), skip
          if ((paidByMap['id'] ?? '').toString() == userId) continue;

          final sharedRaw = (d['sharedWith'] as List?) ?? [];
          final updatedShared = sharedRaw
              .where(
                (u) =>
                    (Map<String, dynamic>.from(u as Map)['id'] ?? '')
                        .toString() !=
                    userId,
              )
              .toList();

          if (updatedShared.isEmpty) {
            await e.reference.delete();
          } else {
            await e.reference.update({'sharedWith': updatedShared});
          }
        }
      }
    });

    return true;
  }

  // ==========================
  // 🧹 CLEANUP (FIXED)
  // ==========================
  void clearAll() {
    // IMPORTANT: cancel listeners so next user does not reuse old streams
    _groupsSub?.cancel();
    _peopleSub?.cancel();
    _groupsSub = null;
    _peopleSub = null;

    for (final sub in _expensesSubs.values) {
      sub.cancel();
    }
    _expensesSubs.clear();

    ownerUid = null;

    users.clear();
    _groups.clear();
    _expensesByGroupId.clear();

    notifyListeners();
  }

  void clear() {
    clearAll();
  }

  @override
  void dispose() {
    _groupsSub?.cancel();
    _peopleSub?.cancel();
    for (final sub in _expensesSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
