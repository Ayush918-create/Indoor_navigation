import 'package:flutter/material.dart';

import 'faculty_screen.dart';
import 'navigation_screen.dart';
import 'profile_screen.dart';
import 'timetable_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Indoor Navigation'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _menuCard(
              context,
              'Navigation',
              Icons.map,
              Colors.blue,
              const NavigationScreen(),
            ),
            _menuCard(
              context,
              'Faculty Search',
              Icons.person_search,
              Colors.green,
              const FacultyScreen(),
            ),
            _menuCard(
              context,
              'Time Table',
              Icons.schedule,
              Colors.orange,
              const TimetableScreen(),
            ),
            _menuCard(
              context,
              'Profile',
              Icons.person,
              Colors.purple,
              const ProfileScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget screen,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => screen,
          ),
        );
      },
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 60,
              color: color,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
