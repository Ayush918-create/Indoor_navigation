// lib/screens/home_screen.dart

import 'package:flutter/material.dart';

import '../services/upload_data.dart';
import 'navigation_screen.dart';
import 'faculty_screen.dart';
import 'timetable_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Indoor Navigation"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await uploadInitialData();

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Firebase Data Uploaded Successfully",
                      ),
                    ),
                  );
                },
                child: const Text("Upload Firebase Data"),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _menuCard(
                    context,
                    "Navigation",
                    Icons.map,
                    Colors.blue,
                    const NavigationScreen(),
                  ),
                  _menuCard(
                    context,
                    "Faculty Search",
                    Icons.person_search,
                    Colors.green,
                    const FacultyScreen(),
                  ),
                  _menuCard(
                    context,
                    "Time Table",
                    Icons.schedule,
                    Colors.orange,
                    const TimetableScreen(),
                  ),
                  _menuCard(
                    context,
                    "Profile",
                    Icons.person,
                    Colors.purple,
                    const ProfileScreen(),
                  ),
                ],
              ),
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
          borderRadius: BorderRadius.circular(20),
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