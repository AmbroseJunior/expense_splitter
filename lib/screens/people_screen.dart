import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/expense_store.dart';
import '../models/user.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  Future<void> _showAddPersonDialog(BuildContext context) async {
    final store = context.read<ExpenseStore>();
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add person"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await store.addUser(ctrl.text);
    }
  }

  Future<void> _showRenameDialog(BuildContext context, AppUser user) async {
    final store = context.read<ExpenseStore>();
    final ctrl = TextEditingController(text: user.name);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename person"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await store.renameUser(user.id, ctrl.text);
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppUser user) async {
    final store = context.read<ExpenseStore>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete person?"),
        content: Text("Delete '${user.name}' from the app?"),
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
      final success = await store.deleteUser(user.id);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cannot delete: this person paid at least one expense."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("People"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPersonDialog(context),
        child: const Icon(Icons.person_add),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: store.users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final u = store.users[i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0097A7).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Color(0xFF006A6A)),
              ),
              title: Text(
                u.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') _showRenameDialog(context, u);
                  if (v == 'delete') _confirmDelete(context, u);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text("Rename")),
                  PopupMenuItem(value: 'delete', child: Text("Delete")),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

