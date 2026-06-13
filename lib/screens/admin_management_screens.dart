import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import '../services/timetable_service.dart';

class StudentManagementScreen extends StatelessWidget {
  const StudentManagementScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return _ManagementGuard(
      user: user,
      allowed: PermissionService(user).canManageStudents,
      child: _UserManagementScreen(
        title: 'Student Management',
        role: UserRole.student,
      ),
    );
  }
}

class FacultyManagementScreen extends StatelessWidget {
  const FacultyManagementScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return _ManagementGuard(
      user: user,
      allowed: PermissionService(user).canManageFaculty,
      child: _UserManagementScreen(
        title: 'Faculty Management',
        role: UserRole.faculty,
      ),
    );
  }
}

class RoomManagementScreen extends StatelessWidget {
  const RoomManagementScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return _ManagementGuard(
      user: user,
      allowed: PermissionService(user).canManageRooms,
      child: Scaffold(
        appBar: AppBar(title: const Text('Room Management')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showRoomDialog(context, authService),
          icon: const Icon(Icons.add),
          label: const Text('Room'),
        ),
        body: StreamBuilder<DatabaseEvent>(
          stream: authService.dbRef.child('rooms').onValue,
          builder: (context, snapshot) {
            final rooms = _parseCollection(snapshot.data?.snapshot.value);

            if (rooms.isEmpty) {
              return const Center(child: Text('No rooms created'));
            }

            return ListView.builder(
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                final roomNo = room['room']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.meeting_room),
                    title: Text(roomNo),
                    subtitle: Text(
                      room['occupied'] == true ? 'Occupied' : 'Free',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Deallocate',
                          onPressed: () {
                            authService.dbRef.child('rooms/$roomNo').update({
                              'occupied': false,
                              'allocatedBy': null,
                              'allocationId': null,
                            });
                          },
                          icon: const Icon(Icons.lock_open),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () {
                            authService.dbRef.child('rooms/$roomNo').remove();
                          },
                          icon: const Icon(Icons.delete),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showRoomDialog(BuildContext context, AuthService authService) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Room'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Room Number'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final room = controller.text.trim();
                if (room.isNotEmpty) {
                  authService.dbRef.child('rooms/$room').set({
                    'room': room,
                    'occupied': false,
                    'createdAt': DateTime.now().toIso8601String(),
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}

class TimetableManagementScreen extends StatelessWidget {
  const TimetableManagementScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return _ManagementGuard(
      user: user,
      allowed: PermissionService(user).canManageTimetables,
      child: Scaffold(
        appBar: AppBar(title: const Text('Timetable Management')),
        body: StreamBuilder<DatabaseEvent>(
          stream: authService.dbRef.child('timetable').onValue,
          builder: (context, snapshot) {
            final entries = TimetableService().parseEntries(
              snapshot.data?.snapshot.value,
            );

            if (entries.isEmpty) {
              return const Center(child: Text('No timetable entries'));
            }

            return ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(entry.subject),
                    subtitle: Text(
                      '${entry.day} | ${entry.startTime} - ${entry.endTime}\n'
                      '${entry.faculty} | ${entry.room}',
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () {},
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ConflictManagementScreen extends StatelessWidget {
  const ConflictManagementScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return _ManagementGuard(
      user: user,
      allowed: PermissionService(user).canResolveConflicts,
      child: Scaffold(
        appBar: AppBar(title: const Text('Conflict Management')),
        body: StreamBuilder<DatabaseEvent>(
          stream: authService.dbRef.child('conflicts').onValue,
          builder: (context, snapshot) {
            final conflicts = _parseCollection(snapshot.data?.snapshot.value);

            if (conflicts.isEmpty) {
              return const Center(child: Text('No conflicts found'));
            }

            return ListView.builder(
              itemCount: conflicts.length,
              itemBuilder: (context, index) {
                final conflict = conflicts[index];
                final id = conflict['id']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.rule),
                    title: Text(conflict['room']?.toString() ?? 'Conflict'),
                    subtitle: Text(conflict['message']?.toString() ?? ''),
                    trailing: FilledButton(
                      onPressed: id.isEmpty
                          ? null
                          : () {
                              authService.dbRef.child('conflicts/$id').update({
                                'resolved': true,
                                'resolvedAt': DateTime.now().toIso8601String(),
                              });
                            },
                      child: const Text('Resolve'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _UserManagementScreen extends StatelessWidget {
  _UserManagementScreen({
    required this.title,
    required this.role,
  });

  final String title;
  final UserRole role;
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<DatabaseEvent>(
        stream: _authService.watchUsers(),
        builder: (context, snapshot) {
          final users = _parseCollection(snapshot.data?.snapshot.value)
              .map(AppUser.fromMap)
              .where((item) => item.role == role)
              .toList();

          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.profileImage.isEmpty
                        ? null
                        : NetworkImage(user.profileImage),
                    child: user.profileImage.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user.name),
                  subtitle: Text(
                    '${user.email}\n${user.department} ${user.semester}',
                  ),
                  trailing: Switch(
                    value: user.active,
                    onChanged: (value) {
                      _authService.setAccountActive(
                        user: user,
                        active: value,
                      );
                    },
                  ),
                  onTap: () => _showEditUserDialog(context, user),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, AppUser user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final mobileController = TextEditingController(text: user.mobile);
    final departmentController = TextEditingController(text: user.department);
    final semesterController = TextEditingController(text: user.semester);
    final imageController = TextEditingController(text: user.profileImage);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit ${user.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameController, 'Name'),
                _dialogField(emailController, 'Email'),
                _dialogField(mobileController, 'Mobile'),
                _dialogField(departmentController, 'Department'),
                _dialogField(semesterController, 'Semester'),
                _dialogField(imageController, 'Profile Image URL'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _authService.updateProfile(user, {
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'mobile': mobileController.text.trim(),
                  'department': departmentController.text.trim(),
                  'semester': semesterController.text.trim(),
                  'profileImage': imageController.text.trim(),
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _ManagementGuard extends StatelessWidget {
  const _ManagementGuard({
    required this.user,
    required this.allowed,
    required this.child,
  });

  final AppUser user;
  final bool allowed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (allowed) return child;

    return Scaffold(
      appBar: AppBar(title: const Text('Access Denied')),
      body: const Center(
        child: Text('You are not allowed to access this screen.'),
      ),
    );
  }
}

List<Map<dynamic, dynamic>> _parseCollection(Object? value) {
  final items = <Map<dynamic, dynamic>>[];

  if (value is List) {
    for (final item in value) {
      if (item is Map) items.add(item);
    }
  } else if (value is Map) {
    for (final item in value.values) {
      if (item is Map) items.add(item);
    }
  }

  return items;
}
