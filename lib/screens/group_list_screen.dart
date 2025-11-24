import 'package:flutter/material.dart';
import 'group_details_screen.dart';

class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = ["Roommates", "Trip to Paris", "Project Team"];

    return Scaffold(
      appBar: AppBar(title: const Text("Your Groups")),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // Create new group placeholder
        },
      ),

      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return Card(
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0097A7).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group, color: Color(0xFF006A6A)),
                ),
                title: Text(
                  groups[index],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.black54,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          GroupDetailsScreen(groupName: groups[index]),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
