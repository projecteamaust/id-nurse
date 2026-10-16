/// The signed-in staff member. Shape: `user` in POST /auth/login and GET /me (docs/api.md).
class User {
  final int id;
  final String employeeId;
  final String name;
  final String role; // "nurse" or "supervisor"
  final String ward;

  const User({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.role,
    required this.ward,
  });

  bool get isSupervisor => role == 'supervisor';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        employeeId: json['employee_id'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        ward: json['ward'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        'name': name,
        'role': role,
        'ward': ward,
      };
}
