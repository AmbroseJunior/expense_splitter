import 'package:flutter/material.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = [
      {"from": "Miha", "to": "Matej", "amount": 10.0},
      {"from": "Nnamdi", "to": "Matej", "amount": 10.0},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Settlement Summary")),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: summary.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final s = summary[i];
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
                  "${s["from"]} → ${s["to"]}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                trailing: Text(
                  "${s["amount"]}€",
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
      ),
    );
  }
}
