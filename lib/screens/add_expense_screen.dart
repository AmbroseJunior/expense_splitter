import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/expense_store.dart';
import '../models/user.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId; // obvezno: dodajamo v določeno grupo
  const AddExpenseScreen({super.key, required this.groupId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final titleCtrl = TextEditingController();
  final amountCtrl = TextEditingController();

  AppUser? payer;
  final Set<String> selectedUserIds = {};

  @override
  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final group = store.getGroupById(widget.groupId);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Add Expense")),
        body: const Center(child: Text("Group not found")),
      );
    }

    payer ??= group.members.first;

    return Scaffold(
      appBar: AppBar(title: Text("Add Expense (${group.name})")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: "Expense title"),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: "Amount (€)"),
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<AppUser>(
                        value: payer,
                        items: group.members
                            .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                            .toList(),
                        onChanged: (v) => setState(() => payer = v),
                        decoration: const InputDecoration(labelText: "Paid by"),
                      ),

                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Shared with:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),

                      ...group.members.map((u) {
                        final checked = selectedUserIds.contains(u.id);
                        return CheckboxListTile(
                          dense: true,
                          value: checked,
                          title: Text(u.name),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                selectedUserIds.add(u.id);
                              } else {
                                selectedUserIds.remove(u.id);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));

                    if (title.isEmpty || amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Enter valid title and amount")),
                      );
                      return;
                    }

                    if (selectedUserIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Select at least one person")),
                      );
                      return;
                    }

                    final sharedWith =
                        group.members.where((u) => selectedUserIds.contains(u.id)).toList();

                    context.read<ExpenseStore>().addExpenseToGroup(
                          groupId: widget.groupId,
                          title: title,
                          amount: amount,
                          date: DateTime.now(),
                          paidBy: payer!,
                          sharedWith: sharedWith,
                        );

                    Navigator.pop(context);
                  },
                  child: const Text("Save Expense"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
