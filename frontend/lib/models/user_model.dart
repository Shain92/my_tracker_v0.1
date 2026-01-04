/// Модель отдела
class DepartmentModel {
  final int id;
  final String name;
  final String? description;
  final String color;

  DepartmentModel({
    required this.id,
    required this.name,
    this.description,
    this.color = '#000000',
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      color: json['color'] ?? '#000000',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
    };
  }
}

/// Модель пользователя
class UserModel {
  final int id;
  final String username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final bool isSuperuser;
  final bool isActive;
  final String? dateJoined;
  final DepartmentModel? department;

  UserModel({
    required this.id,
    required this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.isSuperuser = false,
    this.isActive = true,
    this.dateJoined,
    this.department,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DepartmentModel? department;
    if (json['department'] != null) {
      department = DepartmentModel.fromJson(json['department']);
    }
    
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      isSuperuser: json['is_superuser'] ?? false,
      isActive: json['is_active'] ?? true,
      dateJoined: json['date_joined'],
      department: department,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'is_superuser': isSuperuser,
      'is_active': isActive,
      'date_joined': dateJoined,
      'department': department?.toJson(),
    };
  }
}

