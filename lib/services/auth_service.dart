// lib/services/auth_service.dart

import 'firebase_service.dart';

class AuthService {
  // Create Demo Users
  Future<void> createDemoUsers() async {
    await dbRef.child("users").set({
      "101": {
        "userNo": "101",
        "name": "Lucky Gupta",
        "password": "1234",
      },
      "102": {
        "userNo": "102",
        "name": "Bhavya",
        "password": "5678",
      },
      "103": {
        "userNo": "103",
        "name": "Admin",
        "password": "admin123",
      },
    });
  }

  // Signup
  Future<void> signup({
    required String userNo,
    required String name,
    required String password,
  }) async {
    await dbRef.child("users").child(userNo).set({
      "userNo": userNo,
      "name": name,
      "password": password,
    });
  }

  // Login
  Future<bool> login({
    required String userNo,
    required String password,
  }) async {
    try {
      final snapshot =
          await dbRef.child("users").child(userNo).get();

      if (!snapshot.exists) {
        return false;
      }

      final data =
          Map<String, dynamic>.from(snapshot.value as Map);

      return data["password"] == password;
    } catch (e) {
      print("Login Error: $e");
      return false;
    }
  }

  // Update User
  Future<void> updateUser({
    required String userNo,
    required String newName,
    required String newPassword,
  }) async {
    await dbRef.child("users").child(userNo).update({
      "name": newName,
      "password": newPassword,
    });
  }

  // Delete User
  Future<void> deleteUser(String userNo) async {
    await dbRef.child("users").child(userNo).remove();
  }
}