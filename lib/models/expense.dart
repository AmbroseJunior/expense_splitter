import 'user.dart';
import 'local_expense.dart';

class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final AppUser paidBy;
  final List<AppUser> sharedWith;
  final Map<String, double>? _shares;
  final SplitMethod? _splitMethod;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.paidBy,
    required this.sharedWith,
    Map<String, double>? shares,
    SplitMethod? splitMethod,
  })  : _shares = shares,
        _splitMethod = splitMethod;

  Map<String, double> get shares => _shares ?? const {};
  SplitMethod get splitMethod => _splitMethod ?? SplitMethod.equal;
}

