import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/expense_store.dart';
import '../logic/settlement.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();

    final net = calculateNet(store.users, store.expenses);
    final settlements = minimize(store.users, net);

    return Scaffold(
      appBar: AppBar(title: const Text("Settlement Summary")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              "Net balances",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            ...store.users.map((u) {
              final b = net[u.id]!;
              final sign = b >= 0 ? "+" : "";
              return ListTile(
                title: Text(u.name),
                trailing: Text(
                  "$sign${b.toStringAsFixed(2)}€",
                  style: TextStyle(
                    color: b >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            const Text(
              "Who pays who",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (settlements.isEmpty)
              const Text("No settlements needed 🎉"),

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
                    child: const Icon(Icons.swap_horiz,
                        color: Color(0xFF006A6A)),
                  ),
                  title: Text(
                    "${s.from.name} → ${s.to.name}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
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
      ),
    );
  }
}
