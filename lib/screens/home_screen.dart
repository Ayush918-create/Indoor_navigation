import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import 'admin_management_screens.dart';
import 'faculty_screen.dart';
import 'login_screen.dart';
import 'navigation_screen.dart';
import 'profile_screen.dart';
import 'room_screens.dart';
import 'timetable_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final permissions = PermissionService(user);
    final items = _dashboardItems(permissions);

    return Scaffold(
      appBar: AppBar(
        title: Text('${user.role.label} Dashboard'),
        centerTitle: true,
      ),
      drawer: _RoleDrawer(user: user, items: items),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 720 ? 3 : 2;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => item.screen),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 48, color: item.color),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<_DashboardItem> _dashboardItems(PermissionService permissions) {
    final items = <_DashboardItem>[
      _DashboardItem(
        title: 'Indoor Navigation',
        icon: Icons.map,
        color: Colors.blue,
        screen: const NavigationScreen(),
      ),
      _DashboardItem(
        title: 'Faculty Search',
        icon: Icons.person_search,
        color: Colors.green,
        screen: const FacultyScreen(),
      ),
      _DashboardItem(
        title: 'Faculty Timetable',
        icon: Icons.badge,
        color: Colors.teal,
        screen: const FacultyScreen(),
      ),
      _DashboardItem(
        title: 'Student Timetable',
        icon: Icons.schedule,
        color: Colors.orange,
        screen: const TimetableScreen(),
      ),
      _DashboardItem(
        title: 'Room Conflicts',
        icon: Icons.report_problem,
        color: Colors.deepOrange,
        screen: RoomConflictScreen(user: user),
      ),
      _DashboardItem(
        title: 'Profile',
        icon: Icons.person,
        color: Colors.purple,
        screen: ProfileScreen(user: user),
      ),
    ];

    if (permissions.canViewRoomStatus) {
      items.addAll([
        _DashboardItem(
          title: 'Room Status',
          icon: Icons.meeting_room,
          color: Colors.indigo,
          screen: RoomStatusScreen(user: user),
        ),
        _DashboardItem(
          title: 'Temporary Room Allocation',
          icon: Icons.event_available,
          color: Colors.brown,
          screen: RoomAllocationScreen(user: user),
        ),
        _DashboardItem(
          title: 'Student Profiles',
          icon: Icons.groups,
          color: Colors.cyan,
          screen: StudentProfilesScreen(user: user),
        ),
      ]);
    }

    if (permissions.canManageStudents) {
      items.addAll([
        _DashboardItem(
          title: 'Student Management',
          icon: Icons.manage_accounts,
          color: Colors.red,
          screen: StudentManagementScreen(user: user),
        ),
        _DashboardItem(
          title: 'Faculty Management',
          icon: Icons.supervisor_account,
          color: Colors.blueGrey,
          screen: FacultyManagementScreen(user: user),
        ),
        _DashboardItem(
          title: 'Room Management',
          icon: Icons.apartment,
          color: Colors.deepPurple,
          screen: RoomManagementScreen(user: user),
        ),
        _DashboardItem(
          title: 'Timetable Management',
          icon: Icons.edit_calendar,
          color: Colors.pink,
          screen: TimetableManagementScreen(user: user),
        ),
        _DashboardItem(
          title: 'Conflict Management',
          icon: Icons.rule,
          color: Colors.black87,
          screen: ConflictManagementScreen(user: user),
        ),
      ]);
    }

    return items;
  }
}

class _RoleDrawer extends StatelessWidget {
  const _RoleDrawer({
    required this.user,
    required this.items,
  });

  final AppUser user;
  final List<_DashboardItem> items;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user.name),
              accountEmail: Text(user.email),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              otherAccountsPictures: [
                Chip(label: Text(user.role.label)),
              ],
            ),
            Expanded(
              child: ListView(
                children: items.map((item) {
                  return ListTile(
                    leading: Icon(item.icon, color: item.color),
                    title: Text(item.title),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => item.screen),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await AuthService().signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardItem {
  const _DashboardItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.screen,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget screen;
}
