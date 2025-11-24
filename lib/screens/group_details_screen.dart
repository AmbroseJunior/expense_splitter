import 'package:flutter/material.dart';
import 'add_expense_screen.dart';
import '../widgets/expense_tile.dart';
import 'summary_screen.dart';

class GroupDetailsScreen extends StatelessWidget {
  final String groupName;
  const GroupDetailsScreen({super.key, required this.groupName});

  @override
  Widget build(BuildContext context) {
    final expenses = [
      {"title": "Groceries", "amount": 30.0, "payer": "Matej"},
      {"title": "Taxi", "amount": 12.0, "payer": "Nnamdi"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SummaryScreen()),
              );
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
        },
      ),

      body: ListView.builder(
        itemCount: expenses.length,
        itemBuilder: (_, i) => ExpenseTile(
          title: expenses[i]["title"] as String,
          amount: expenses[i]["amount"] as double,
          payer: expenses[i]["payer"] as String,
        ),
      ),
    );
  }
}
