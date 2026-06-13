import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  late AppUser user;
  late TextEditingController emailController;
  late TextEditingController mobileController;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    emailController = TextEditingController(text: user.email);
    mobileController = TextEditingController(text: user.mobile);
  }

  @override
  void dispose() {
    emailController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    setState(() => saving = true);

    await _authService.updateProfile(user, {
      'email': emailController.text.trim(),
      'mobile': mobileController.text.trim(),
    });

    setState(() {
      saving = false;
      user = user.copyWith(
        email: emailController.text.trim(),
        mobile: mobileController.text.trim(),
      );
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissions = PermissionService(user);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 54,
              backgroundImage:
                  user.profileImage.isEmpty ? null : NetworkImage(user.profileImage),
              child: user.profileImage.isEmpty
                  ? const Icon(Icons.person, size: 54)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Chip(
              avatar: const Icon(Icons.verified_user, size: 18),
              label: Text(user.role.label),
            ),
            const SizedBox(height: 20),
            _lockedTile('Name', user.name, Icons.person),
            _lockedTile('Roll Number', user.rollNumber, Icons.numbers),
            _lockedTile('Department', user.department, Icons.school),
            _lockedTile('Semester', user.semester, Icons.calendar_month),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              enabled: permissions.canEditProfileField('email'),
              decoration: const InputDecoration(
                labelText: 'Email ID',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mobileController,
              enabled: permissions.canEditProfileField('mobile'),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : saveProfile,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Contact Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockedTile(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value.isEmpty ? 'Not set' : value),
        trailing: const Icon(Icons.lock),
      ),
    );
  }
}
