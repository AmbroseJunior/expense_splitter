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
        return StatefulBuilder(
          builder: (ctx, setState) {
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
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    // če ni izbral nobenega, vzemi vse
                    final members = selectedIds.isEmpty
                        ? store.users
                        : store.users
                            .where((u) => selectedIds.contains(u.id))
                            .toList();

                    store.addGroup(name: name, members: members);
                    Navigator.pop(context);
                  },
                  child: const Text("Create"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditGroupDialog(BuildContext context, String groupId) {
    final store = context.read<ExpenseStore>();
    final group = store.getGroupById(groupId);
    if (group == null) return;

    final nameCtrl = TextEditingController(text: group.name);
    final Set<String> selectedIds =
        group.members.map((m) => m.id).toSet();

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
                          content: Text("Select at least 1 member"),
                        ),
                      );
                      return;
                    }

                    store.updateGroup(
                      groupId: groupId,
                      name: newName,
                      members: members,
                    );

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

  Future<void> _confirmDeleteGroup(BuildContext context, String groupId) async {
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
    }
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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle:
                  Text("Members: ${g.members.map((m) => m.name).join(", ")}"),

              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'open') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailsScreen(groupId: g.id),
                      ),
                    );
                  } else if (v == 'edit') {
                    _showEditGroupDialog(context, g.id);
                  } else if (v == 'delete') {
                    _confirmDeleteGroup(context, g.id);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text("Open")),
                  PopupMenuItem(value: 'edit', child: Text("Edit")),
                  PopupMenuItem(value: 'delete', child: Text("Delete")),
                ],
              ),

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
