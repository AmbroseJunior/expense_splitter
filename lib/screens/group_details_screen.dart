import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/expense_store.dart';
import '../logic/settlement.dart';
import '../models/user.dart';
import '../widgets/expense_tile.dart';
import 'add_expense_screen.dart';
import 'people_screen.dart';

class GroupDetailsScreen extends StatelessWidget {
  final String groupId;
  const GroupDetailsScreen({super.key, required this.groupId});

  void _showEditGroupDialog(BuildContext context) {
    final store = context.read<ExpenseStore>();
    final group = store.getGroupById(groupId);
    if (group == null) return;

    final nameCtrl = TextEditingController(text: group.name);
    final selectedIds = group.members.map((m) => m.id).toSet();

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text("Edit Group"),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration:
                            const InputDecoration(labelText: "Group name"),
                      ),
                      const SizedBox(height: 16),
                      const Text("Members:"),
                      const SizedBox(height: 8),
                      ...store.users.map((u) {
                        final checked = selectedIds.contains(u.id);
                        return CheckboxListTile(
                          dense: true,
                          value: checked,
                          title: Text(u.name),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                selectedIds.add(u.id);
                              } else {
                                selectedIds.remove(u.id);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () {
                    final newName = nameCtrl.text.trim();
                    if (newName.isEmpty) return;

                    final members = store.users
                        .where((u) => selectedIds.contains(u.id))
                        .toList();

                    if (members.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Select at least 1 member")),
                      );
                      return;
                    }

                    store.updateGroup(
                        groupId: groupId, name: newName, members: members);
                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteGroup(BuildContext context) async {
    final store = context.read<ExpenseStore>();
    final group = store.getGroupById(groupId);
    if (group == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete group?"),
        content: Text("Delete '${group.name}' and all its expenses?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok == true) {
      store.deleteGroup(groupId);
      Navigator.pop(context);
    }
  }

  void _showManageUsersDialog(BuildContext context) {
    final store = context.read<ExpenseStore>();
    final newUserCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text("Manage Users"),
              content: SizedBox(
                width: 460,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: newUserCtrl,
                      decoration: const InputDecoration(
                        labelText: "New user name",
                        hintText: "e.g. Matej",
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          store.addUser(newUserCtrl.text);
                          newUserCtrl.clear();
                          setState(() {});
                        },
                        child: const Text("Add user"),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: store.users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final u = store.users[i];
                          return ListTile(
                            title: Text(u.name),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'rename') {
                                  _showRenameUserDialog(context, u);
                                } else if (v == 'delete') {
                                  final ok = store.deleteUser(u.id);
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "Cannot delete: user paid at least one expense."),
                                      ),
                                    );
                                  } else {
                                    setState(() {});
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'rename', child: Text("Rename")),
                                PopupMenuItem(
                                    value: 'delete', child: Text("Delete")),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRenameUserDialog(BuildContext context, AppUser user) {
    final store = context.read<ExpenseStore>();
    final ctrl = TextEditingController(text: user.name);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename user"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              store.renameUser(user.id, ctrl.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteExpense(
    BuildContext context, {
    required String expenseId,
    required String title,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete expense?"),
        content: Text("Delete '$title'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok == true) {
      context.read<ExpenseStore>().deleteExpenseFromGroup(
            groupId: groupId,
            expenseId: expenseId,
          );
    }
  }

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
    final net = calculateNet(group.members, expenses);
    final settlements = minimize(group.members, net);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit_group') _showEditGroupDialog(context);
              if (v == 'delete_group') _confirmDeleteGroup(context);
              if (v == 'manage_users') _showManageUsersDialog(context);
              if (v == 'people') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PeopleScreen()),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit_group', child: Text("Edit group")),
              PopupMenuItem(value: 'manage_users', child: Text("Manage users")),
              PopupMenuItem(value: 'people', child: Text("People")),
              PopupMenuItem(value: 'delete_group', child: Text("Delete group")),
            ],
          ),
        ],
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
                child: GestureDetector(
                  onLongPress: () => _confirmDeleteExpense(
                    context,
                    expenseId: e.id,
                    title: e.title,
                  ),
                  child: ExpenseTile(
                    title: e.title,
                    amount: e.amount,
                    payer: e.paidBy.name,
                  ),
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
    );
  }
}
