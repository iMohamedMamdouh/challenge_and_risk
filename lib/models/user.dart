import 'package:firebase_database/firebase_database.dart';

enum UserRole { user, moderator, admin }

class AppUser {
  final String id;
  final String username;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isActive;
  final String? passwordHash;
  final String? profilePicture;
  DateTime? lastLoginAt;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.lastLogin,
    this.isActive = true,
    this.passwordHash,
    this.profilePicture,
    this.lastLoginAt,
  });

  // إنشاء من DatabaseSnapshot
  factory AppUser.fromSnapshot(DataSnapshot snapshot) {
    final value = snapshot.value;
    if (value == null || value is! Map<Object?, Object?>) {
      throw Exception('بيانات المستخدم تالفة أو فارغة');
    }
    final data = Map<String, dynamic>.from(value);
    return AppUser.fromMap(data, snapshot.key!);
  }

  // إنشاء من Map
  factory AppUser.fromMap(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == data['role'],
        orElse: () => UserRole.user,
      ),
      createdAt:
          data['createdAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
              : DateTime.now(),
      lastLogin:
          data['lastLogin'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['lastLogin'] as int)
              : DateTime.now(),
      isActive: data['isActive'] ?? true,
      passwordHash: data['passwordHash'],
      profilePicture: data['profilePicture'],
      lastLoginAt:
          data['lastLoginAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['lastLoginAt'] as int)
              : null,
    );
  }

  // تحويل إلى Map
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'role': role.toString().split('.').last,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLogin': lastLogin.millisecondsSinceEpoch,
      'isActive': isActive,
      'passwordHash': passwordHash,
      'profilePicture': profilePicture,
      'lastLoginAt': lastLoginAt?.millisecondsSinceEpoch,
    };
  }

  // التحقق من الصلاحيات
  bool canManageQuestions() {
    return role == UserRole.admin || role == UserRole.moderator;
  }

  bool canManageUsers() {
    return role == UserRole.admin;
  }

  bool canDeleteQuestions() {
    return role == UserRole.admin;
  }

  // الحصول على اسم الدور بالعربية
  String get roleDisplayName {
    switch (role) {
      case UserRole.admin:
        return 'مشرف عام';
      case UserRole.moderator:
        return 'مشرف';
      case UserRole.user:
        return 'مستخدم';
    }
  }

  // إنشاء نسخة جديدة مع تعديل بعض الخصائص
  AppUser copyWith({
    String? id,
    String? username,
    String? email,
    UserRole? role,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
    String? passwordHash,
    String? profilePicture,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
      passwordHash: passwordHash ?? this.passwordHash,
      profilePicture: profilePicture ?? this.profilePicture,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
