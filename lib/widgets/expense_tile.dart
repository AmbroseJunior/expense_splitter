import 'package:flutter/material.dart';

class ExpenseTile extends StatelessWidget {
  final String title;
  final double amount;
  final String payer;

  const ExpenseTile({
    super.key,
    required this.title,
    required this.amount,
    required this.payer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF006A6A).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_long, color: Color(0xFF006A6A)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        subtitle: Text("Paid by $payer"),
        trailing: Text(
          "${amount.toStringAsFixed(2)}€",
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF006A6A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
