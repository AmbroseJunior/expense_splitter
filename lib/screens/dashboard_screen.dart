import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../state/expense_store.dart';
import 'group_list_screen.dart';
import 'login_screen.dart';
import 'people_screen.dart';
import 'summary_chart.dart';

class DashboardScreen extends StatefulWidget {
  final bool localOnly;

  const DashboardScreen({super.key, this.localOnly = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _prompted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePromptMigration();
  }

  Future<void> _maybePromptMigration() async {
    if (_prompted) return;
    if (widget.localOnly) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || user.isAnonymous) return;

    final store = context.read<ExpenseStore>();
    final hasLocal = await store.hasLocalData();
    if (!hasLocal || !mounted) return;

    _prompted = true;
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Local data found"),
        content: const Text(
          "You have local (offline) data. What do you want to do with it?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cloud'),
            child: const Text("Use cloud only"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'merge_keep'),
            child: const Text("Merge"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'merge_delete'),
            child: const Text("Merge + delete local"),
          ),
        ],
      ),
    );

    if (action == null) return;
    if (action == 'cloud') {
      await store.clearLocalData();
      return;
    }
    if (action == 'merge_keep') {
      await store.migrateLocalData(
        toOwnerId: user.uid,
        deleteLocalAfter: false,
      );
      return;
    }
    if (action == 'merge_delete') {
      await store.migrateLocalData(
        toOwnerId: user.uid,
        deleteLocalAfter: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    final displayName = user == null
        ? "User"
        : user.isAnonymous
            ? "Guest"
            : (user.displayName ?? "User");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Welcome"),
        actions: widget.localOnly
            ? [
                IconButton(
                  icon: const Icon(Icons.login),
                  tooltip: 'Back to Login',
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await auth.logout();
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                ),
              ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hello $displayName",
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "What would you like to do today?",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            if (user?.isAnonymous == true) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "You are using a guest account. Data may be lost if you log out.",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (widget.localOnly) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Local-only mode: data is saved in SQLite and sync is disabled.",
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text("Sign in to sync"),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            DashboardButton(
              icon: Icons.people,
              label: "Manage People",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PeopleScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            DashboardButton(
              icon: Icons.add_card,
              label: "Add New Expense",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupListScreen()),
                );
              },
            ),
            const SizedBox(height: 40),
            const Text(
              "Summary Overview",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const SummaryChart(),
            ),
            const Spacer(),
            const Center(
              child: Text(
                "Powered By: expense_splitter 2025",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const DashboardButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0097A7).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 32, color: const Color(0xFF006A6A)),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
