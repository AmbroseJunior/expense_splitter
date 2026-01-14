import 'user.dart';

class Group {
  final String id;
  final String name;
  final List<AppUser> members;

  Group({required this.id, required this.name, required this.members});

  factory Group.fromFirestore(String id, Map<String, dynamic> data) {
    final memberNames = (data['memberNames'] as Map<String, dynamic>? ?? {});
    final memberIds = (data['memberIds'] as List<dynamic>? ?? []);

    final members = memberIds.map((mid) {
      final name = memberNames[mid] ?? 'Member';
      return AppUser(id: mid.toString(), name: name.toString());
    }).toList();

    return Group(
      id: id,
      name: (data['name'] ?? 'Group').toString(),
      members: members,
    );
  }
}
