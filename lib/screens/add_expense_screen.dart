import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/expense_repository.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final List<String> members;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.members,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final titleCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  late String payer;
  late List<String> selectedMembers;
  SplitMethod splitMethod = SplitMethod.equal;
  final Map<String, TextEditingController> splitCtrls = {};
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    payer = widget.members.first;
    selectedMembers = List.of(widget.members);
    for (final member in widget.members) {
      splitCtrls[member] = TextEditingController();
    }
  }

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

  Map<String, double>? _buildShares(double amount) {
    if (selectedMembers.isEmpty) return null;
    final shares = <String, double>{};

    if (splitMethod == SplitMethod.equal) {
      final each = amount / selectedMembers.length;
      for (final member in selectedMembers) {
        shares[member] = each;
      }
      return shares;
    }

    double total = 0;
    for (final member in selectedMembers) {
      final ctrl = splitCtrls[member];
      final value = ctrl == null ? null : _parseAmount(ctrl.text);
      if (value == null) return null;
      total += value;
      shares[member] = value;
    }

    if (splitMethod == SplitMethod.percentage) {
      if ((total - 100).abs() > 0.01) return null;
      return shares.map((key, value) => MapEntry(key, amount * value / 100));
    }

    if ((total - amount).abs() > 0.01) return null;
    return shares;
  }

  Future<void> _save() async {
    final title = titleCtrl.text.trim();
    final amount = _parseAmount(amountCtrl.text);
    if (title.isEmpty || amount == null) {
      _showError('Vnesi naziv in veljaven znesek.');
      return;
    }
    final shares = _buildShares(amount);
    if (shares == null) {
      _showError('Preveri udeležence in vnesene deleže.');
      return;
    }

    setState(() => isSaving = true);
    try {
      final expense = Expense(
        groupId: widget.groupId,
        title: title,
        amount: amount,
        payerId: payer,
        participants: List.of(selectedMembers),
        shares: shares,
        splitMethod: splitMethod,
        createdAt: DateTime.now(),
        pendingSync: true,
      );
      await ExpenseRepository.instance.addExpense(expense);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _showError('Shranjevanje ni uspelo. Poskusi znova.');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Expense")),
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
                        decoration: const InputDecoration(
                          labelText: "Expense title",
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Amount",
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField(
                        initialValue: payer,
                        items: widget.members
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => payer = v!),
                        decoration: const InputDecoration(labelText: "Paid by"),
                      ),
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
                        "Udeleženci",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...widget.members.map((member) {
                        final selected = selectedMembers.contains(member);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(member),
                          value: selected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedMembers.add(member);
                              } else {
                                selectedMembers.remove(member);
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
                        "Način delitve",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      RadioListTile(
                        title: const Text("Enakovredno"),
                        value: SplitMethod.equal,
                        groupValue: splitMethod,
                        onChanged: (value) =>
                            setState(() => splitMethod = value!),
                      ),
                      RadioListTile(
                        title: const Text("Po odstotkih"),
                        value: SplitMethod.percentage,
                        groupValue: splitMethod,
                        onChanged: (value) =>
                            setState(() => splitMethod = value!),
                      ),
                      RadioListTile(
                        title: const Text("Po zneskih"),
                        value: SplitMethod.amount,
                        groupValue: splitMethod,
                        onChanged: (value) =>
                            setState(() => splitMethod = value!),
                      ),
                      if (splitMethod != SplitMethod.equal) ...[
                        const SizedBox(height: 8),
                        ...selectedMembers.map((member) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TextField(
                              controller: splitCtrls[member],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: splitMethod == SplitMethod.percentage
                                    ? "$member (%)"
                                    : "$member (amount)",
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
                  onPressed: isSaving ? null : _save,
                  child: Text(isSaving ? "Saving..." : "Save Expense"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
