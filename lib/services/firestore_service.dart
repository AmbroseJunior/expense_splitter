import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> groupsStream(String uid) {
    return _db
        .collection('groups')
        .where('members', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> createGroup({
    required String name,
    required String creatorUid,
    required List<String> memberUids,
  }) async {
    final doc = _db.collection('groups').doc();

    await doc.set({
      'name': name,
      'createdBy': creatorUid,
      'members': memberUids.toSet().toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> expensesStream(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> addExpense({
    required String groupId,
    required String title,
    required double amount,
    required String payerId,
    required List<String> participants,
    required Map<String, double> shares,
  }) async {
    await _db.collection('groups').doc(groupId).collection('expenses').add({
      'title': title,
      'amount': amount,
      'payerId': payerId,
      'participants': participants,
      'shares': shares,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
