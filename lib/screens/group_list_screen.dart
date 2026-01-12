import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/expense_store.dart';
import '../models/user.dart';
import 'group_details_screen.dart';

class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  void _showCreateGroupDialog(BuildContext context) {
    final store = context.read<ExpenseStore>();
    final nameCtrl = TextEditingController();
    final Set<String> selectedIds = {};

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Create Group"),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Group name"),
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
                        if (v == true) {
                          selectedIds.add(u.id);
                        } else {
                          selectedIds.remove(u.id);
                        }
                        (context as Element).markNeedsBuild();
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                // če ni izbral nobenega, vzemi vse
                final members = selectedIds.isEmpty
                    ? store.users
                    : store.users.where((u) => selectedIds.contains(u.id)).toList();

                store.addGroup(name: name, members: members);
                Navigator.pop(context);
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();

    return Scaffold(
      appBar: AppBar(title: const Text("Your Groups")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupDialog(context),
        child: const Icon(Icons.add),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: store.groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, index) {
          final g = store.groups[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0097A7).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group, color: Color(0xFF006A6A)),
              ),
              title: Text(
                g.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text("Members: ${g.members.map((m) => m.name).join(", ")}"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupDetailsScreen(groupId: g.id),
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
