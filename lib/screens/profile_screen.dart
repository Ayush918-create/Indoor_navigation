// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),

            const CircleAvatar(
              radius: 60,
              child: Icon(
                Icons.person,
                size: 60,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              "Lucky Gupta",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Text(
              "Student",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                leading: const Icon(Icons.email),
                title: const Text("Email"),
                subtitle: const Text("lucky@example.com"),
              ),
            ),

            Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                leading: const Icon(Icons.school),
                title: const Text("Department"),
                subtitle: const Text("Computer Science"),
              ),
            ),

            Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text("Current Location"),
                subtitle: const Text("Block E1"),
              ),
            ),

            Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text("Recent Navigation"),
                subtitle: const Text("E1-101"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}