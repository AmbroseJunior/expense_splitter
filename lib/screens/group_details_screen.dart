import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/expense_store.dart';
import '../logic/settlement.dart';
import '../widgets/expense_tile.dart';
import 'add_expense_screen.dart';

class GroupDetailsScreen extends StatelessWidget {
  final String groupId;
  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final group = store.getGroupById(groupId);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Group")),
        body: const Center(child: Text("Group not found")),
      );
    }

    final expenses = store.expensesForGroup(groupId);

    // settlement samo za člane grupe + stroške grupe
    final net = calculateNet(group.members, expenses);
    final settlements = minimize(group.members, net);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddExpenseScreen(groupId: groupId),
            ),
          );
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Expenses",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 20),
              child: Text("No expenses yet."),
            ),

          ...expenses.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ExpenseTile(
                  title: e.title,
                  amount: e.amount,
                  payer: e.paidBy.name,
                ),
              )),

          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),

          const Text(
            "Settlement",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          const Text(
            "Net balances",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...group.members.map((u) {
            final b = net[u.id] ?? 0.0;
            final sign = b >= 0 ? "+" : "";
            return ListTile(
              dense: true,
              title: Text(u.name),
              trailing: Text(
                "$sign${b.toStringAsFixed(2)}€",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: b >= 0 ? Colors.green : Colors.red,
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 10),

          const Text(
            "Who pays who",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (settlements.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text("No settlements needed 🎉"),
            ),

          ...settlements.map((s) {
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0097A7).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.swap_horiz, color: Color(0xFF006A6A)),
                ),
                title: Text(
                  "${s.from.name} → ${s.to.name}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                trailing: Text(
                  "${s.amount.toStringAsFixed(2)}€",
                  style: const TextStyle(
                    color: Color(0xFF006A6A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
