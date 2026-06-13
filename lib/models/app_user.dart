enum UserRole {
  student,
  faculty,
  admin,
}

extension UserRoleX on UserRole {
  String get value {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.faculty:
        return 'faculty';
      case UserRole.admin:
        return 'admin';
    }
  }

  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.faculty:
        return 'Faculty';
      case UserRole.admin:
        return 'Admin';
    }
  }

  static UserRole fromValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'faculty':
        return UserRole.faculty;
      case 'admin':
        return UserRole.admin;
      case 'student':
      default:
        return UserRole.student;
    }
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.mobile = '',
    this.department = '',
    this.profileImage = '',
    this.rollNumber = '',
    this.semester = '',
    this.active = true,
    this.createdAt = '',
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String mobile;
  final String department;
  final String profileImage;
  final String rollNumber;
  final String semester;
  final bool active;
  final String createdAt;

  bool get isStudent => role == UserRole.student;
  bool get isFaculty => role == UserRole.faculty;
  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromMap(Map<dynamic, dynamic> data) {
    return AppUser(
      uid: data['uid']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      role: UserRoleX.fromValue(data['role']?.toString()),
      mobile: data['mobile']?.toString() ?? '',
      department: data['department']?.toString() ?? '',
      profileImage: data['profileImage']?.toString() ?? '',
      rollNumber: data['rollNumber']?.toString() ?? '',
      semester: data['semester']?.toString() ?? '',
      active: data['active'] as bool? ?? true,
      createdAt: data['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.value,
      'mobile': mobile,
      'department': department,
      'profileImage': profileImage,
      'rollNumber': rollNumber,
      'semester': semester,
      'active': active,
      'createdAt': createdAt,
    };
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    UserRole? role,
    String? mobile,
    String? department,
    String? profileImage,
    String? rollNumber,
    String? semester,
    bool? active,
    String? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      mobile: mobile ?? this.mobile,
      department: department ?? this.department,
      profileImage: profileImage ?? this.profileImage,
      rollNumber: rollNumber ?? this.rollNumber,
      semester: semester ?? this.semester,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
