import 'user.dart';

class Group {
  final String id;
  final String name;
  final List<AppUser> members;

  Group({
    required this.id,
    required this.name,
    required this.members,
  });
}

