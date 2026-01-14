import 'user.dart';

class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final AppUser paidBy;
  final List<AppUser> sharedWith;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.paidBy,
    required this.sharedWith,
  });
}
