import 'dart:convert';

enum SplitMethod { equal, percentage, amount }

String splitMethodToString(SplitMethod method) {
  switch (method) {
    case SplitMethod.equal:
      return 'equal';
    case SplitMethod.percentage:
      return 'percentage';
    case SplitMethod.amount:
      return 'amount';
  }
}

SplitMethod splitMethodFromString(String value) {
  switch (value) {
    case 'percentage':
      return SplitMethod.percentage;
    case 'amount':
      return SplitMethod.amount;
    case 'equal':
    default:
      return SplitMethod.equal;
  }
}

class LocalExpense {
  final String id;
  final String ownerId;
  final String groupId;
  final String title;
  final double amount;
  final String payerId;
  final List<String> participants;
  final Map<String, double> shares;
  final SplitMethod splitMethod;
  final DateTime createdAt;
  final bool pendingSync;

  LocalExpense({
    required this.id,
    required this.ownerId,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.payerId,
    required this.participants,
    required this.shares,
    required this.splitMethod,
    required this.createdAt,
    required this.pendingSync,
  });

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'payerId': payerId,
      'participants': jsonEncode(participants),
      'shares': jsonEncode(shares),
      'splitMethod': splitMethodToString(splitMethod),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'pendingSync': pendingSync ? 1 : 0,
    };
  }

  factory LocalExpense.fromDbMap(Map<String, dynamic> map) {
    final rawParticipants = map['participants'];
    final rawShares = map['shares'];
    final rawSplitMethod = map['splitMethod'];

    final participants = (rawParticipants == null || rawParticipants == 'null')
        ? <String>[]
        : (jsonDecode(rawParticipants as String) as List)
            .map((e) => e.toString())
            .toList();

    final decodedShares = (rawShares == null || rawShares == 'null')
        ? <String, dynamic>{}
        : (jsonDecode(rawShares as String) as Map<String, dynamic>);

    final splitMethod = (rawSplitMethod == null)
        ? SplitMethod.equal
        : splitMethodFromString(rawSplitMethod as String);

    return LocalExpense(
      id: map['id'] as String,
      ownerId: map['ownerId'] as String,
      groupId: map['groupId'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      payerId: map['payerId'] as String,
      participants: participants,
      shares: decodedShares.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      splitMethod: splitMethod,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int? ?? 0),
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1,
    );
  }
}
