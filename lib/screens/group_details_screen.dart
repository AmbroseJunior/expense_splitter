import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/expense_repository.dart';
import '../widgets/expense_tile.dart';
import 'add_expense_screen.dart';
import 'summary_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  late Future<List<Expense>> _expensesFuture;
  final List<String> _members = const ["Matej", "Miha", "Nnamdi"];

  @override
  void initState() {
    super.initState();
    _expensesFuture = _loadExpenses();
  }

  Future<List<Expense>> _loadExpenses() async {
    await ExpenseRepository.instance.syncPendingExpenses();
    return ExpenseRepository.instance.listExpenses(groupId: widget.groupId);
  }

  Future<void> _refresh() async {
    setState(() {
      _expensesFuture = _loadExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SummaryScreen(
                    groupId: widget.groupId,
                    members: _members,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddExpenseScreen(
                groupId: widget.groupId,
                members: _members,
              ),
            ),
          );
          if (added == true) {
            await _refresh();
          }
        },
      ),
      body: FutureBuilder<List<Expense>>(
        future: _expensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading expenses"));
          }
          final expenses = snapshot.data ?? [];
          if (expenses.isEmpty) {
            return const Center(child: Text("No expenses yet"));
          }
          return ListView.builder(
            itemCount: expenses.length,
            itemBuilder: (_, i) {
              final expense = expenses[i];
              return ExpenseTile(
                title: expense.title,
                amount: expense.amount,
                payer: expense.payerId,
                isPending: expense.pendingSync,
              );
            },
          );
        },
      ),
    );
  }
}
