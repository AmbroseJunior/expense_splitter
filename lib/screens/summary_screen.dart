import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/expense_repository.dart';

class SummaryScreen extends StatelessWidget {
  final String groupId;
  final List<String> members;

  const SummaryScreen({
    super.key,
    required this.groupId,
    required this.members,
  });

  Map<String, double> _calculateBalances(List<Expense> expenses) {
    final balances = <String, double>{};
    for (final member in members) {
      balances[member] = 0;
    }

    for (final expense in expenses) {
      balances[expense.payerId] = (balances[expense.payerId] ?? 0) + expense.amount;
      if (expense.shares.isNotEmpty) {
        for (final entry in expense.shares.entries) {
          balances[entry.key] = (balances[entry.key] ?? 0) - entry.value;
        }
      } else if (expense.participants.isNotEmpty) {
        final each = expense.amount / expense.participants.length;
        for (final participant in expense.participants) {
          balances[participant] = (balances[participant] ?? 0) - each;
        }
      }
    }

    return balances;
  }

  List<_Transfer> _calculateTransfers(Map<String, double> balances) {
    final creditors = <_TransferEntry>[];
    final debtors = <_TransferEntry>[];

    for (final entry in balances.entries) {
      if (entry.value > 0.01) {
        creditors.add(_TransferEntry(entry.key, entry.value));
      } else if (entry.value < -0.01) {
        debtors.add(_TransferEntry(entry.key, -entry.value));
      }
    }

    final transfers = <_Transfer>[];
    var i = 0;
    var j = 0;
    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];
      final amount = debtor.amount < creditor.amount ? debtor.amount : creditor.amount;

      transfers.add(_Transfer(from: debtor.name, to: creditor.name, amount: amount));

      debtor.amount -= amount;
      creditor.amount -= amount;
      if (debtor.amount <= 0.01) i++;
      if (creditor.amount <= 0.01) j++;
    }

    return transfers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settlement Summary")),
      body: FutureBuilder<List<Expense>>(
        future: ExpenseRepository.instance.listExpenses(groupId: groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading summary"));
          }
          final expenses = snapshot.data ?? [];
          final balances = _calculateBalances(expenses);
          final transfers = _calculateTransfers(balances);

          if (transfers.isEmpty) {
            return const Center(child: Text("All settled"));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView.separated(
              itemCount: transfers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final t = transfers[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(18),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0097A7).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.swap_horiz,
                        color: Color(0xFF006A6A),
                      ),
                    ),
                    title: Text(
                      "${t.from} -> ${t.to}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    trailing: Text(
                      "${t.amount.toStringAsFixed(2)} EUR",
                      style: const TextStyle(
                        color: Color(0xFF006A6A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TransferEntry {
  final String name;
  double amount;

  _TransferEntry(this.name, this.amount);
}

class _Transfer {
  final String from;
  final String to;
  final double amount;

  const _Transfer({
    required this.from,
    required this.to,
    required this.amount,
  });
}
