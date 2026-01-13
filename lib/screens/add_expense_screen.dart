import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/local_expense.dart';
import '../models/user.dart';
import '../state/expense_store.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  const AddExpenseScreen({super.key, required this.groupId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final titleCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final Map<String, TextEditingController> splitCtrls = {};

  AppUser? payer;
  final Set<String> selectedUserIds = {};
  SplitMethod splitMethod = SplitMethod.equal;
  bool _initialized = false;

  @override
  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
    for (final ctrl in splitCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  double? _parseAmount(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  Map<String, double>? _buildShares(
    double amount,
    List<AppUser> sharedWith,
  ) {
    if (sharedWith.isEmpty) return null;

    if (splitMethod == SplitMethod.equal) {
      final each = amount / sharedWith.length;
      return {for (final u in sharedWith) u.id: each};
    }

    double total = 0;
    final raw = <String, double>{};
    for (final u in sharedWith) {
      final ctrl = splitCtrls[u.id];
      final value = ctrl == null ? null : _parseAmount(ctrl.text);
      if (value == null) return null;
      raw[u.id] = value;
      total += value;
    }

    if (splitMethod == SplitMethod.percentage) {
      if ((total - 100).abs() > 0.01) return null;
      return raw.map((k, v) => MapEntry(k, amount * v / 100));
    }

    if ((total - amount).abs() > 0.01) return null;
    return raw;
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

    if (!_initialized) {
      payer ??= group.members.isNotEmpty ? group.members.first : null;
      selectedUserIds.addAll(group.members.map((u) => u.id));
      for (final u in group.members) {
        splitCtrls.putIfAbsent(u.id, () => TextEditingController());
      }
      _initialized = true;
    }

    final selectedUsers =
        group.members.where((u) => selectedUserIds.contains(u.id)).toList();

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
                        decoration:
                            const InputDecoration(labelText: "Expense title"),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: "Amount"),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<AppUser>(
                        value: payer,
                        items: group.members
                            .map((u) =>
                                DropdownMenuItem(value: u, child: Text(u.name)))
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
              Card(
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Split method",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      RadioListTile(
                        title: const Text("Equal"),
                        value: SplitMethod.equal,
                        groupValue: splitMethod,
                        onChanged: (value) =>
                            setState(() => splitMethod = value!),
                      ),
                      RadioListTile(
                        title: const Text("Percentage"),
                        value: SplitMethod.percentage,
                        groupValue: splitMethod,
                        onChanged: (value) =>
                            setState(() => splitMethod = value!),
                      ),
                      RadioListTile(
                        title: const Text("Amount"),
                        value: SplitMethod.amount,
                        groupValue: splitMethod,
                        onChanged: (value) =>
                            setState(() => splitMethod = value!),
                      ),
                      if (splitMethod != SplitMethod.equal) ...[
                        const SizedBox(height: 8),
                        ...selectedUsers.map((u) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TextField(
                              controller: splitCtrls[u.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: splitMethod ==
                                        SplitMethod.percentage
                                    ? "${u.name} (%)"
                                    : "${u.name} (amount)",
                              ),
                            ),
                          );
                        }),
                      ],
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
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    final amount = _parseAmount(amountCtrl.text);

                    if (title.isEmpty || amount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Enter valid title and amount"),
                        ),
                      );
                      return;
                    }

                    if (selectedUsers.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Select at least one person"),
                        ),
                      );
                      return;
                    }

                    final shares = _buildShares(amount, selectedUsers);
                    if (shares == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Check the split values"),
                        ),
                      );
                      return;
                    }

                    if (payer == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Select who paid"),
                        ),
                      );
                      return;
                    }

                    await context.read<ExpenseStore>().addExpenseToGroup(
                          groupId: widget.groupId,
                          title: title,
                          amount: amount,
                          date: DateTime.now(),
                          paidBy: payer!,
                          sharedWith: selectedUsers,
                          shares: shares,
                          splitMethod: splitMethod,
                        );

                    if (mounted) Navigator.pop(context);
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
