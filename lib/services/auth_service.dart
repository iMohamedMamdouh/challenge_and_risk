import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  AppUser? _currentUser;
  final StreamController<AppUser?> _userController =
      StreamController<AppUser?>.broadcast();

  AppUser? get currentUser => _currentUser;
  Stream<AppUser?> get userStream => _userController.stream;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isModerator => _currentUser?.role == UserRole.moderator || isAdmin;

  // تشفير كلمة المرور
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // إنشاء المشرف الافتراضي
  Future<void> createDefaultAdmin() async {
    try {
      print('🔍 فحص وجود المشرف الافتراضي...');
      final adminSnapshot = await _database.child('users').child('admin').get();

      if (!adminSnapshot.exists) {
        print('➕ إنشاء المشرف الافتراضي الجديد...');

        final adminPassword = 'admin123';
        final hashedPassword = _hashPassword(adminPassword);

        print('📝 بيانات المشرف:');
        print('   - اسم المستخدم: admin');
        print('   - كلمة المرور: $adminPassword');
        print(
          '   - كلمة المرور المشفرة: ${hashedPassword.substring(0, 10)}...',
        );

        final admin = AppUser(
          id: 'admin',
          username: 'admin',
          email: 'admin@challenge.com',
          role: UserRole.admin,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
          passwordHash: hashedPassword,
        );

        await _database.child('users').child('admin').set(admin.toMap());
        print('✅ تم إنشاء المشرف الافتراضي بنجاح');

        // التحقق من الحفظ
        final verifySnapshot =
            await _database.child('users').child('admin').get();
        if (verifySnapshot.exists) {
          final savedData = verifySnapshot.value;
          if (savedData != null && savedData is Map<Object?, Object?>) {
            final userData = Map<String, dynamic>.from(savedData);
            print('✅ تم التحقق من حفظ البيانات:');
            print('   - اسم المستخدم المحفوظ: ${userData['username']}');
            print(
              '   - كلمة المرور المحفوظة: ${userData['passwordHash']?.substring(0, 10)}...',
            );
            print('   - الدور: ${userData['role']}');
          }
        }
      } else {
        print('ℹ️ المشرف الافتراضي موجود بالفعل');

        // طباعة بيانات المشرف الموجود للتشخيص
        final existingData = adminSnapshot.value;
        if (existingData != null && existingData is Map<Object?, Object?>) {
          final userData = Map<String, dynamic>.from(existingData);
          print('📋 بيانات المشرف الموجود:');
          print('   - اسم المستخدم: ${userData['username']}');
          print(
            '   - كلمة المرور المشفرة: ${userData['passwordHash']?.substring(0, 10)}...',
          );
          print('   - الدور: ${userData['role']}');
          print('   - نشط: ${userData['isActive'] ?? true}');
        }
      }
    } catch (e) {
      print('❌ خطأ في إنشاء المشرف الافتراضي: $e');
    }
  }

  // تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
  Future<bool> loginWithEmail(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final firebaseUser = credential.user!;

        // البحث عن المستخدم في قاعدة البيانات
        final usersSnapshot = await _database.child('users').get();
        AppUser? user;

        if (usersSnapshot.exists) {
          final usersValue = usersSnapshot.value;
          if (usersValue != null && usersValue is Map<Object?, Object?>) {
            final usersData = Map<String, dynamic>.from(usersValue);

            for (String userId in usersData.keys) {
              final userValue = usersData[userId];
              if (userValue != null && userValue is Map<Object?, Object?>) {
                final userData = Map<String, dynamic>.from(userValue);
                if (userData['email'] == email) {
                  user = AppUser.fromMap(userData, userId);
                  break;
                }
              }
            }
          }
        }

        // إنشاء مستخدم جديد إذا لم يكن موجوداً
        if (user == null) {
          final hashedPassword = _hashPassword(password);
          print('🔐 إنشاء مستخدم جديد مع كلمة مرور مشفرة');

          user = AppUser(
            id: firebaseUser.uid,
            username: firebaseUser.displayName ?? email.split('@')[0],
            email: email,
            role: UserRole.user,
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
            profilePicture: firebaseUser.photoURL,
            passwordHash: hashedPassword, // إضافة كلمة المرور المشفرة
          );

          await _database.child('users').child(user.id).set(user.toMap());
          print('✅ تم حفظ المستخدم الجديد مع كلمة المرور المشفرة');
        } else if (user.passwordHash == null || user.passwordHash!.isEmpty) {
          // إضافة passwordHash للمستخدمين القدامى الذين ليس لديهم passwordHash
          final hashedPassword = _hashPassword(password);
          print('🔐 إضافة كلمة مرور مشفرة للمستخدم الموجود: ${user.username}');

          user = user.copyWith(passwordHash: hashedPassword);
          await _database.child('users').child(user.id).update({
            'passwordHash': hashedPassword,
          });
          print('✅ تم حفظ كلمة المرور المشفرة للمستخدم الموجود');
        }

        user.lastLoginAt = DateTime.now();
        await _database.child('users').child(user.id).update({
          'lastLoginAt': user.lastLoginAt!.millisecondsSinceEpoch,
        });

        await _setCurrentUser(user, rememberMe: rememberMe);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول بالبريد الإلكتروني: $e');
      throw Exception(_getAuthErrorMessage(e.toString()));
    }
  }

  // تسجيل الدخول بـ Google
  Future<bool> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        final firebaseUser = userCredential.user!;

        // البحث عن المستخدم أو إنشاؤه
        final usersSnapshot = await _database.child('users').get();
        AppUser? user;

        if (usersSnapshot.exists) {
          final usersValue = usersSnapshot.value;
          if (usersValue != null && usersValue is Map<Object?, Object?>) {
            final usersData = Map<String, dynamic>.from(usersValue);

            for (String userId in usersData.keys) {
              final userValue = usersData[userId];
              if (userValue != null && userValue is Map<Object?, Object?>) {
                final userData = Map<String, dynamic>.from(userValue);
                if (userData['email'] == firebaseUser.email) {
                  user = AppUser.fromMap(userData, userId);
                  break;
                }
              }
            }
          }
        }

        if (user == null) {
          user = AppUser(
            id: firebaseUser.uid,
            username:
                firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
            email: firebaseUser.email!,
            role: UserRole.user,
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
            profilePicture: firebaseUser.photoURL,
          );

          await _database.child('users').child(user.id).set(user.toMap());
        }

        user.lastLoginAt = DateTime.now();
        await _database.child('users').child(user.id).update({
          'lastLoginAt': user.lastLoginAt!.millisecondsSinceEpoch,
        });

        await _setCurrentUser(user, rememberMe: true);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول بـ Google: $e');
      throw Exception(_getAuthErrorMessage(e.toString()));
    }
  }

  // تسجيل الدخول العادي (اسم المستخدم وكلمة المرور)
  Future<bool> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    try {
      print('🔐 محاولة تسجيل الدخول باسم المستخدم: $username');

      final hashedPassword = _hashPassword(password);
      print('🔑 كلمة المرور المشفرة: ${hashedPassword.substring(0, 10)}...');

      final usersSnapshot = await _database.child('users').get();

      if (usersSnapshot.exists) {
        final usersValue = usersSnapshot.value;
        if (usersValue != null && usersValue is Map<Object?, Object?>) {
          final usersData = Map<String, dynamic>.from(usersValue);
          print(
            '👥 تم العثور على ${usersData.keys.length} مستخدم في قاعدة البيانات',
          );

          for (String userId in usersData.keys) {
            final userValue = usersData[userId];
            if (userValue != null && userValue is Map<Object?, Object?>) {
              final userData = Map<String, dynamic>.from(userValue);

              print('🔍 فحص المستخدم: ${userData['username']}');
              print('   - المعرف: $userId');
              print('   - اسم المستخدم: ${userData['username']}');
              print('   - الدور: ${userData['role']}');
              print('   - نشط: ${userData['isActive'] ?? true}');
              print(
                '   - كلمة المرور موجودة: ${userData['passwordHash'] != null}',
              );

              if (userData['passwordHash'] != null) {
                print(
                  '   - كلمة المرور المحفوظة: ${userData['passwordHash'].substring(0, 10)}...',
                );
                print(
                  '   - تطابق كلمة المرور: ${userData['passwordHash'] == hashedPassword}',
                );
              }

              if (userData['username'] == username &&
                  userData['passwordHash'] == hashedPassword &&
                  (userData['isActive'] ?? true)) {
                print('✅ تم العثور على المستخدم المطابق!');

                final user = AppUser.fromMap(userData, userId);
                user.lastLoginAt = DateTime.now();

                await _database.child('users').child(userId).update({
                  'lastLoginAt': user.lastLoginAt!.millisecondsSinceEpoch,
                });

                await _setCurrentUser(user, rememberMe: rememberMe);
                print(
                  '✅ تم تسجيل الدخول بنجاح للمستخدم: ${user.username} (${user.role})',
                );
                return true;
              }
            }
          }
        }
      } else {
        print('❌ لا توجد بيانات مستخدمين في قاعدة البيانات');
      }

      print('❌ لم يتم العثور على مستخدم مطابق');
      print(
        '❌ المطلوب: username=$username, password hash=${hashedPassword.substring(0, 10)}...',
      );
      throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول: $e');
      throw Exception(e.toString());
    }
  }

  // تسجيل مستخدم جديد بالبريد الإلكتروني
  Future<bool> registerWithEmail(
    String email,
    String password,
    String username,
  ) async {
    try {
      print('📝 إنشاء حساب جديد للمستخدم: $username');

      // التحقق من عدم وجود اسم المستخدم مسبقاً
      final usersSnapshot = await _database.child('users').get();
      if (usersSnapshot.exists) {
        final usersValue = usersSnapshot.value;
        if (usersValue != null && usersValue is Map<Object?, Object?>) {
          final usersData = Map<String, dynamic>.from(usersValue);

          for (String userId in usersData.keys) {
            final userValue = usersData[userId];
            if (userValue != null && userValue is Map<Object?, Object?>) {
              final userData = Map<String, dynamic>.from(userValue);
              if (userData['username'] == username) {
                throw Exception('اسم المستخدم موجود بالفعل');
              }
            }
          }
        }
      }

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final firebaseUser = credential.user!;

        // تشفير كلمة المرور لحفظها في قاعدة البيانات
        final hashedPassword = _hashPassword(password);
        print('🔐 تم تشفير كلمة المرور للمستخدم الجديد');

        final user = AppUser(
          id: firebaseUser.uid,
          username: username,
          email: email,
          role: UserRole.user,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
          passwordHash: hashedPassword, // إضافة كلمة المرور المشفرة
        );

        await _database.child('users').child(user.id).set(user.toMap());
        print('✅ تم حفظ بيانات المستخدم الجديد مع كلمة المرور المشفرة');

        // التحقق من الحفظ
        final verifySnapshot =
            await _database.child('users').child(user.id).get();
        if (verifySnapshot.exists) {
          final savedData = verifySnapshot.value;
          if (savedData != null && savedData is Map<Object?, Object?>) {
            final userData = Map<String, dynamic>.from(savedData);
            print('✅ تم التحقق من حفظ البيانات:');
            print('   - اسم المستخدم: ${userData['username']}');
            print('   - البريد الإلكتروني: ${userData['email']}');
            print(
              '   - كلمة المرور محفوظة: ${userData['passwordHash'] != null}',
            );
          }
        }

        await _setCurrentUser(user, rememberMe: true);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ خطأ في إنشاء الحساب: $e');
      throw Exception(_getAuthErrorMessage(e.toString()));
    }
  }

  // تسجيل مستخدم جديد بـ اسم المستخدم وكلمة المرور فقط
  Future<bool> register(
    String username,
    String password, {
    String? email,
  }) async {
    try {
      print('📝 إنشاء حساب جديد للمستخدم: $username');

      if (username.trim().isEmpty) {
        throw Exception('اسم المستخدم مطلوب');
      }

      if (password.length < 6) {
        throw Exception('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      }

      // التحقق من عدم وجود اسم المستخدم مسبقاً
      final usersSnapshot = await _database.child('users').get();
      if (usersSnapshot.exists) {
        final usersValue = usersSnapshot.value;
        if (usersValue != null && usersValue is Map<Object?, Object?>) {
          final usersData = Map<String, dynamic>.from(usersValue);

          for (String userId in usersData.keys) {
            final userValue = usersData[userId];
            if (userValue != null && userValue is Map<Object?, Object?>) {
              final userData = Map<String, dynamic>.from(userValue);
              if (userData['username'] == username) {
                throw Exception('اسم المستخدم موجود بالفعل');
              }
              if (email != null && userData['email'] == email) {
                throw Exception('البريد الإلكتروني مستخدم بالفعل');
              }
            }
          }
        }
      }

      // إنشاء معرف فريد للمستخدم
      final userId =
          'user_${DateTime.now().millisecondsSinceEpoch}_${username.hashCode.abs()}';

      // تشفير كلمة المرور
      final hashedPassword = _hashPassword(password);
      print('🔐 تم تشفير كلمة المرور للمستخدم الجديد');

      final user = AppUser(
        id: userId,
        username: username,
        email: email ?? '$username@local.app',
        role: UserRole.user,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        passwordHash: hashedPassword,
        isActive: true,
      );

      await _database.child('users').child(userId).set(user.toMap());
      print('✅ تم حفظ بيانات المستخدم الجديد');

      // التحقق من الحفظ
      final verifySnapshot = await _database.child('users').child(userId).get();
      if (verifySnapshot.exists) {
        final savedData = verifySnapshot.value;
        if (savedData != null && savedData is Map<Object?, Object?>) {
          final userData = Map<String, dynamic>.from(savedData);
          print('✅ تم التحقق من حفظ البيانات:');
          print('   - المعرف: $userId');
          print('   - اسم المستخدم: ${userData['username']}');
          print('   - البريد الإلكتروني: ${userData['email']}');
          print('   - الدور: ${userData['role']}');
          print('   - نشط: ${userData['isActive']}');
        }
      }

      await _setCurrentUser(user, rememberMe: true);
      print('✅ تم تسجيل دخول المستخدم الجديد');

      return true;
    } catch (e) {
      print('❌ خطأ في إنشاء الحساب: $e');
      throw Exception(e.toString());
    }
  }

  // محاولة تسجيل الدخول التلقائي
  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (userData != null) {
        try {
          final userMap = jsonDecode(userData);
          if (userMap is Map<String, dynamic>) {
            final user = AppUser.fromMap(userMap, userMap['id']);

            _currentUser = user;
            _userController.add(_currentUser);
            return true;
          }
        } catch (e) {
          print('❌ خطأ في تحليل بيانات المستخدم المحفوظة: $e');
          // حذف البيانات التالفة
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('user_data');
        }
      }
      return false;
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول التلقائي: $e');
      return false;
    }
  }

  // تعيين المستخدم الحالي
  Future<void> _setCurrentUser(AppUser user, {bool rememberMe = false}) async {
    _currentUser = user;
    _userController.add(_currentUser);

    if (rememberMe) {
      await _saveUserSession(user);
    }
  }

  // حفظ جلسة المستخدم
  Future<void> _saveUserSession(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(user.toMap()));
    } catch (e) {
      print('❌ خطأ في حفظ جلسة المستخدم: $e');
    }
  }

  // تسجيل الخروج
  Future<void> logout() async {
    try {
      print('🚪 بدء عملية تسجيل الخروج...');

      // تسجيل الخروج من Firebase Auth
      if (_firebaseAuth.currentUser != null) {
        await _firebaseAuth.signOut();
        print('✅ تم تسجيل الخروج من Firebase Auth');
      }

      // تسجيل الخروج من Google
      try {
        await _googleSignIn.signOut();
        print('✅ تم تسجيل الخروج من Google');
      } catch (e) {
        print('⚠️ خطأ في تسجيل الخروج من Google: $e');
        // لا نوقف العملية إذا فشل تسجيل الخروج من Google
      }

      // مسح بيانات الجلسة المحلية
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_data');
        await prefs.remove('remember_me');
        print('✅ تم مسح بيانات الجلسة المحلية');
      } catch (e) {
        print('⚠️ خطأ في مسح البيانات المحلية: $e');
      }

      // مسح المستخدم الحالي
      _currentUser = null;
      _userController.add(null);
      print('✅ تم مسح المستخدم الحالي');

      print('🎉 تم تسجيل الخروج بنجاح');
    } catch (e) {
      print('❌ خطأ في تسجيل الخروج: $e');
      throw Exception('فشل في تسجيل الخروج: $e');
    }
  }

  // الحصول على جميع المستخدمين (للمشرفين فقط)
  Future<List<AppUser>> getUsers() async {
    try {
      final usersSnapshot = await _database.child('users').get();
      final users = <AppUser>[];

      if (usersSnapshot.exists) {
        final usersValue = usersSnapshot.value;
        if (usersValue != null && usersValue is Map<Object?, Object?>) {
          final usersData = Map<String, dynamic>.from(usersValue);

          for (String userId in usersData.keys) {
            final userValue = usersData[userId];
            if (userValue != null && userValue is Map<Object?, Object?>) {
              final userData = Map<String, dynamic>.from(userValue);
              users.add(AppUser.fromMap(userData, userId));
            }
          }
        }
      }

      return users;
    } catch (e) {
      print('❌ خطأ في جلب المستخدمين: $e');
      return [];
    }
  }

  // تحديث دور المستخدم
  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _database.child('users').child(userId).update({
        'role': newRole.toString().split('.').last,
      });
      return true;
    } catch (e) {
      print('❌ خطأ في تحديث دور المستخدم: $e');
      return false;
    }
  }

  // تفعيل/إلغاء تفعيل المستخدم
  Future<bool> toggleUserStatus(String userId) async {
    try {
      final userSnapshot = await _database.child('users').child(userId).get();

      if (userSnapshot.exists) {
        final userValue = userSnapshot.value;
        if (userValue != null && userValue is Map<Object?, Object?>) {
          final userData = Map<String, dynamic>.from(userValue);
          final currentStatus = userData['isActive'] ?? true;

          await _database.child('users').child(userId).update({
            'isActive': !currentStatus,
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ خطأ في تحديث حالة المستخدم: $e');
      return false;
    }
  }

  // حذف المستخدم
  Future<bool> deleteUser(String userId) async {
    try {
      // التحقق من وجود المستخدم أولاً
      final userSnapshot = await _database.child('users').child(userId).get();

      if (!userSnapshot.exists) {
        print('❌ المستخدم غير موجود: $userId');
        return false;
      }

      // منع حذف المستخدم الحالي
      if (_currentUser?.id == userId) {
        print('❌ لا يمكن حذف المستخدم الحالي');
        return false;
      }

      // التحقق من عدد المشرفين إذا كان المستخدم مشرفاً
      final userValue = userSnapshot.value;
      if (userValue != null && userValue is Map<Object?, Object?>) {
        final userData = Map<String, dynamic>.from(userValue);
        if (userData['role'] == 'admin') {
          // عد المشرفين المتبقين
          final usersSnapshot = await _database.child('users').get();
          int adminCount = 0;

          if (usersSnapshot.exists) {
            final usersValue = usersSnapshot.value;
            if (usersValue != null && usersValue is Map<Object?, Object?>) {
              final usersData = Map<String, dynamic>.from(usersValue);

              for (String id in usersData.keys) {
                final user = usersData[id];
                if (user != null && user is Map<Object?, Object?>) {
                  final userMap = Map<String, dynamic>.from(user);
                  if (userMap['role'] == 'admin') {
                    adminCount++;
                  }
                }
              }
            }
          }

          // إذا كان هذا هو المشرف الوحيد، منع الحذف
          if (adminCount <= 1) {
            print('❌ لا يمكن حذف المشرف الوحيد في النظام');
            return false;
          }
        }
      }

      // حذف المستخدم من قاعدة البيانات
      await _database.child('users').child(userId).remove();

      // TODO: يمكن إضافة حذف من Firebase Auth إذا كان ضرورياً
      // لكن هذا يتطلب صلاحيات إدارية إضافية

      print('✅ تم حذف المستخدم بنجاح: $userId');
      return true;
    } catch (e) {
      print('❌ خطأ في حذف المستخدم: $e');
      return false;
    }
  }

  // تغيير كلمة المرور
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      if (_currentUser == null) {
        return {'success': false, 'message': 'يجب تسجيل الدخول أولاً'};
      }

      if (newPassword.length < 6) {
        return {
          'success': false,
          'message': 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل',
        };
      }

      // للمستخدمين الذين لديهم passwordHash (النظام القديم)
      if (_currentUser!.passwordHash != null) {
        final currentHashed = _hashPassword(currentPassword);
        final userSnapshot =
            await _database.child('users').child(_currentUser!.id).get();

        if (userSnapshot.exists) {
          final userValue = userSnapshot.value;
          if (userValue != null && userValue is Map<Object?, Object?>) {
            final userData = Map<String, dynamic>.from(userValue);
            if (userData['passwordHash'] != currentHashed) {
              return {
                'success': false,
                'message': 'كلمة المرور الحالية غير صحيحة',
              };
            }

            // تحديث كلمة المرور
            await _database.child('users').child(_currentUser!.id).update({
              'passwordHash': _hashPassword(newPassword),
            });

            return {'success': true, 'message': 'تم تغيير كلمة المرور بنجاح'};
          }
        }
      } else {
        // للمستخدمين المسجلين بـ Firebase Auth
        final firebaseUser = _firebaseAuth.currentUser;
        if (firebaseUser != null) {
          // إعادة مصادقة المستخدم
          final credential = EmailAuthProvider.credential(
            email: firebaseUser.email!,
            password: currentPassword,
          );

          await firebaseUser.reauthenticateWithCredential(credential);

          // تحديث كلمة المرور
          await firebaseUser.updatePassword(newPassword);

          return {'success': true, 'message': 'تم تغيير كلمة المرور بنجاح'};
        }
      }

      return {'success': false, 'message': 'فشل في تحديث كلمة المرور'};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      print('❌ خطأ في تغيير كلمة المرور: $e');
      return {'success': false, 'message': 'حدث خطأ أثناء تغيير كلمة المرور'};
    }
  }

  // ترجمة رسائل خطأ Firebase
  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'المستخدم غير موجود';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'user-disabled':
        return 'تم تعطيل الحساب';
      case 'too-many-requests':
        return 'تم تجاوز عدد المحاولات المسموح. حاول لاحقاً';
      case 'operation-not-allowed':
        return 'العملية غير مسموحة';
      default:
        return 'حدث خطأ أثناء المصادقة: $errorCode';
    }
  }

  // تنظيف الموارد
  void dispose() {
    _userController.close();
  }

  // دالة اختبار تسجيل الدخول (للتشخيص)
  Future<void> testLogin() async {
    print('🧪 اختبار تسجيل الدخول...');
    try {
      final result = await login('admin', 'admin123');
      print('📊 نتيجة الاختبار: $result');
    } catch (e) {
      print('❌ فشل اختبار تسجيل الدخول: $e');
    }
  }

  // دالة لطباعة جميع المستخدمين (للتشخيص)
  Future<void> debugPrintAllUsers() async {
    try {
      print('🔍 طباعة جميع المستخدمين...');
      final usersSnapshot = await _database.child('users').get();

      if (usersSnapshot.exists) {
        final usersValue = usersSnapshot.value;
        if (usersValue != null && usersValue is Map<Object?, Object?>) {
          final usersData = Map<String, dynamic>.from(usersValue);

          print('👥 عدد المستخدمين: ${usersData.keys.length}');

          for (String userId in usersData.keys) {
            final userValue = usersData[userId];
            if (userValue != null && userValue is Map<Object?, Object?>) {
              final userData = Map<String, dynamic>.from(userValue);
              print('👤 مستخدم $userId:');
              print('   - اسم المستخدم: ${userData['username']}');
              print('   - البريد الإلكتروني: ${userData['email']}');
              print('   - الدور: ${userData['role']}');
              print('   - نشط: ${userData['isActive'] ?? true}');
              print(
                '   - كلمة المرور موجودة: ${userData['passwordHash'] != null}',
              );
            }
          }
        }
      } else {
        print('❌ لا توجد بيانات مستخدمين');
      }
    } catch (e) {
      print('❌ خطأ في طباعة المستخدمين: $e');
    }
  }

  // التحقق من اتصال Firebase Database
  Future<bool> testDatabaseConnection() async {
    try {
      print('🔗 اختبار اتصال Firebase Database...');

      // محاولة كتابة واقراءة بيانات اختبار
      final testRef = _database.child('test');
      final testData = {'timestamp': DateTime.now().millisecondsSinceEpoch};

      await testRef.set(testData);
      print('✅ تم كتابة بيانات الاختبار');

      final snapshot = await testRef.get();
      if (snapshot.exists) {
        print('✅ تم قراءة بيانات الاختبار');
        await testRef.remove(); // حذف بيانات الاختبار
        print('✅ تم حذف بيانات الاختبار');
        return true;
      } else {
        print('❌ فشل في قراءة بيانات الاختبار');
        return false;
      }
    } catch (e) {
      print('❌ خطأ في اختبار اتصال Database: $e');
      return false;
    }
  }

  // الحصول على المستخدم الحالي
  AppUser? getCurrentUser() {
    return _currentUser;
  }

  // تسجيل الخروج (alias for logout)
  Future<void> signOut() async {
    await logout();
  }

  // مسح بيانات المستخدم الحالي
  void _clearCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
      _currentUser = null;
      _userController.add(null);
    } catch (e) {
      print('❌ خطأ في مسح بيانات المستخدم: $e');
    }
  }
}
