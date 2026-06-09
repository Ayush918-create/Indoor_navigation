// lib/screens/faculty_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class FacultyScreen extends StatefulWidget {
  const FacultyScreen({super.key});

  @override
  State<FacultyScreen> createState() => _FacultyScreenState();
}

class _FacultyScreenState extends State<FacultyScreen> {
  final DatabaseReference dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://indoor-navigation-app-cfb2f-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref();

  List<Map<String, dynamic>> facultyList = [];
  List<Map<String, dynamic>> filteredList = [];

  @override
  void initState() {
    super.initState();
    loadFaculty();
  }

  Future<void> loadFaculty() async {
    final snapshot = await dbRef.child("faculty").get();

    if (snapshot.exists) {
      Map data = snapshot.value as Map;

      List<Map<String, dynamic>> temp = [];

      data.forEach((key, value) {
        temp.add({
          "name": value["name"],
          "room": value["room"],
          "available": value["available"] ?? true,
        });
      });

      setState(() {
        facultyList = temp;
        filteredList = temp;
      });
    }
  }

  void searchFaculty(String value) {
    setState(() {
      filteredList = facultyList
          .where(
            (faculty) => faculty["name"]
                .toString()
                .toLowerCase()
                .contains(value.toLowerCase()),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Faculty Search"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: searchFaculty,
              decoration: const InputDecoration(
                labelText: "Search Faculty",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final faculty = filteredList[index];

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(faculty["name"]),
                    subtitle: Text("Room: ${faculty["room"]}"),
                    trailing: faculty["available"]
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          )
                        : const Icon(
                            Icons.cancel,
                            color: Colors.red,
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}