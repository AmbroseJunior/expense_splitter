import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/expense_store.dart';

class FirestoreSyncService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Manual backup (optional)
  Future<void> saveStoreSnapshot(ExpenseStore store) async {
    final uid = _uid;
    if (uid == null) return;

    final userRef = _db.collection('users').doc(uid);

    for (final group in store.groups) {
      final groupRef = userRef.collection('groups').doc(group.id);

      await groupRef.set({
        'name': group.name,
        'members': group.members
            .map((m) => {'id': m.id, 'name': m.name})
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (final e in store.expensesForGroup(group.id)) {
        await groupRef.collection('expenses').doc(e.id).set({
          'title': e.title,
          'amount': e.amount,
          'date': e.date.toIso8601String(),
          'paidBy': {'id': e.paidBy.id, 'name': e.paidBy.name},
          'sharedWith': e.sharedWith
              .map((u) => {'id': u.id, 'name': u.name})
              .toList(),
        });
      }
    }
  }
}
