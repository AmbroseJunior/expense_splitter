
import '../models/expense.dart';
import '../models/user.dart';

Map<String, double> calculateNet(List<AppUser> users, List<Expense> expenses) {
  final map = {for (var u in users) u.id: 0.0};

  for (final e in expenses) {
    map[e.paidBy.id] = map[e.paidBy.id]! + e.amount;

    final hasShares = e.shares.isNotEmpty;
    final fallbackShare = e.sharedWith.isEmpty
        ? 0.0
        : e.amount / e.sharedWith.length;

    for (final u in e.sharedWith) {
      final share = hasShares ? (e.shares[u.id] ?? fallbackShare) : fallbackShare;
      map[u.id] = map[u.id]! - share;
    }
  }

  return map;
}

class Settlement {
  final AppUser from;
  final AppUser to;
  final double amount;

  Settlement(this.from, this.to, this.amount);
}

List<Settlement> minimize(List<AppUser> users, Map<String, double> net) {
  final debtors = <MapEntry<AppUser, double>>[];
  final creditors = <MapEntry<AppUser, double>>[];

  for (final u in users) {
    final v = net[u.id]!;
    if (v < 0) debtors.add(MapEntry(u, v));
    if (v > 0) creditors.add(MapEntry(u, v));
  }

  final result = <Settlement>[];
  int i = 0, j = 0;

  while (i < debtors.length && j < creditors.length) {
    final pay = (-debtors[i].value < creditors[j].value)
        ? -debtors[i].value
        : creditors[j].value;

    result.add(Settlement(debtors[i].key, creditors[j].key, pay));

    debtors[i] = MapEntry(debtors[i].key, debtors[i].value + pay);
    creditors[j] = MapEntry(creditors[j].key, creditors[j].value - pay);

    if (debtors[i].value == 0) i++;
    if (creditors[j].value == 0) j++;
  }

  return result;
}
