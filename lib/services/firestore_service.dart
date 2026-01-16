import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<void> upsertPerson({
    required String ownerId,
    required String id,
    required String name,
    required bool deleted,
    required int updatedAtMs,
  }) async {
    await _db.collection('users').doc(ownerId).collection('people').doc(id).set(
      {
        'name': name,
        'deleted': deleted,
        'updatedAtMs': updatedAtMs,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deletePerson({
    required String ownerId,
    required String id,
    required int updatedAtMs,
  }) async {
    await _db.collection('users').doc(ownerId).collection('people').doc(id).set(
      {
        'deleted': true,
        'updatedAtMs': updatedAtMs,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> upsertGroup({
    required String ownerId,
    required String id,
    required String name,
    required List<String> memberIds,
    required bool deleted,
    required int updatedAtMs,
  }) async {
    await _db.collection('users').doc(ownerId).collection('groups').doc(id).set(
      {
        'name': name,
        'memberIds': memberIds,
        'deleted': deleted,
        'updatedAtMs': updatedAtMs,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteGroup({
    required String ownerId,
    required String groupId,
    required int updatedAtMs,
  }) async {
    await _db.collection('users').doc(ownerId).collection('groups').doc(groupId).set(
      {
        'deleted': true,
        'updatedAtMs': updatedAtMs,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> upsertExpense({
    required String ownerId,
    required String groupId,
    required String id,
    required String title,
    required double amount,
    required Map<String, dynamic> paidBy,
    required List<Map<String, dynamic>> sharedWith,
    required List<String> participants,
    required Map<String, double> shares,
    required String splitMethod,
    required String dateIso,
    required int updatedAtMs,
  }) async {
    await _db
        .collection('users')
        .doc(ownerId)
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(id)
        .set(
      {
        'title': title,
        'amount': amount,
        'paidBy': paidBy,
        'paidById': paidBy['id'],
        'sharedWith': sharedWith,
        'participants': participants,
        'shares': shares,
        'splitMethod': splitMethod,
        'date': dateIso,
        'deleted': false,
        'updatedAtMs': updatedAtMs,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteExpense({
    required String ownerId,
    required String groupId,
    required String expenseId,
    required int updatedAtMs,
  }) async {
    await _db
        .collection('users')
        .doc(ownerId)
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expenseId)
        .set(
      {
        'deleted': true,
        'updatedAtMs': updatedAtMs,
      },
      SetOptions(merge: true),
    );
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchPeople(String ownerId) {
    return _db.collection('users').doc(ownerId).collection('people').get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchGroups(String ownerId) {
    return _db.collection('users').doc(ownerId).collection('groups').get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchExpenses({
    required String ownerId,
    required String groupId,
  }) {
    return _db
        .collection('users')
        .doc(ownerId)
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .get();
  }
}
