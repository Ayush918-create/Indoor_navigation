import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/app_user.dart';

class AuthResult {
  const AuthResult({
    required this.success,
    this.user,
    this.message = '',
  });

  final bool success;
  final AppUser? user;
  final String message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://indoor-navigation-app-cfb2f-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  User? get firebaseUser => _auth.currentUser;

  Future<AuthResult> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Enter any email and password',
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        return _developmentLogin(email: email, role: role);
      }

      final appUser = await loadCurrentUser(uid);
      if (appUser == null) {
        final createdUser = await createUserProfile(
          uid: uid,
          name: _nameFromEmail(email),
          email: email.trim(),
          role: role,
        );
        return AuthResult(success: true, user: createdUser);
      }

      if (!appUser.active) {
        await _auth.signOut();
        return const AuthResult(
          success: false,
          message: 'This account is deactivated',
        );
      }

      if (appUser.role != role) {
        await _auth.signOut();
        return AuthResult(
          success: false,
          message: 'Please use ${appUser.role.label} login',
        );
      }

      return AuthResult(success: true, user: appUser);
    } on FirebaseAuthException {
      return _developmentLogin(email: email, role: role);
    } catch (e) {
      return _developmentLogin(email: email, role: role);
    }
  }

  Future<AuthResult> _developmentLogin({
    required String email,
    required UserRole role,
  }) async {
    final uid = _developmentUid(email, role);
    final existingUser = await loadCurrentUser(uid);

    if (existingUser != null) {
      final roleUser = existingUser.copyWith(role: role);
      await _dbRef.child('users/$uid').update({'role': role.value});
      await _dbRef.child('${_roleTable(role)}/$uid').update(roleUser.toMap());
      return AuthResult(success: true, user: roleUser);
    }

    final user = await createUserProfile(
      uid: uid,
      name: _nameFromEmail(email),
      email: email.trim(),
      role: role,
      department: role == UserRole.admin ? 'Administration' : '',
    );

    return AuthResult(success: true, user: user);
  }

  String _developmentUid(String email, UserRole role) {
    final safeEmail = email
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return 'dev_${role.value}_${safeEmail.isEmpty ? 'user' : safeEmail}';
  }

  String _nameFromEmail(String email) {
    final prefix = email.trim().split('@').first;
    if (prefix.isEmpty) return 'Demo User';

    return prefix
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  Future<AppUser?> loadCurrentUser([String? uid]) async {
    final userId = uid ?? _auth.currentUser?.uid;
    if (userId == null) return null;

    final snapshot = await _dbRef.child('users/$userId').get();
    if (!snapshot.exists || snapshot.value == null) return null;

    return AppUser.fromMap(Map<dynamic, dynamic>.from(snapshot.value as Map));
  }

  Future<AppUser> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required UserRole role,
    String mobile = '',
    String department = '',
    String rollNumber = '',
    String semester = '',
  }) async {
    final user = AppUser(
      uid: uid,
      name: name,
      email: email,
      role: role,
      mobile: mobile,
      department: department,
      rollNumber: rollNumber,
      semester: semester,
      createdAt: DateTime.now().toIso8601String(),
    );

    await _dbRef.child('users/$uid').set(user.toMap());
    await _dbRef.child('${_roleTable(role)}/$uid').set(user.toMap());

    return user;
  }

  Future<void> signup({
    required String userNo,
    required String name,
    required String password,
  }) async {
    await _dbRef.child('legacy_signups/$userNo').set({
      'userNo': userNo,
      'name': name,
      'passwordSet': password.isNotEmpty,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateProfile(AppUser user, Map<String, dynamic> updates) async {
    final sanitized = Map<String, dynamic>.from(updates)
      ..removeWhere((_, value) => value == null);

    await _dbRef.child('users/${user.uid}').update(sanitized);
    await _dbRef.child('${_roleTable(user.role)}/${user.uid}').update(sanitized);
  }

  Future<void> setAccountActive({
    required AppUser user,
    required bool active,
  }) async {
    await updateProfile(user, {'active': active});
  }

  Stream<DatabaseEvent> watchUsers() {
    return _dbRef.child('users').onValue;
  }

  DatabaseReference get dbRef => _dbRef;

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _roleTable(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'students';
      case UserRole.faculty:
        return 'faculty';
      case UserRole.admin:
        return 'admins';
    }
  }
}
