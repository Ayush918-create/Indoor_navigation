// lib/screens/timetable_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final DatabaseReference dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://indoor-navigation-app-cfb2f-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref();

  List<Map<String, dynamic>> timetableList = [];

  @override
  void initState() {
    super.initState();
    loadTimetable();
  }

  Future<void> loadTimetable() async {
    final snapshot = await dbRef.child("timetable").get();

    if (snapshot.exists) {
      Map data = snapshot.value as Map;

      List<Map<String, dynamic>> temp = [];

      data.forEach((key, value) {
        temp.add({
          "subject": key.toString(),
          "faculty": value["faculty"] ?? "",
          "room": value["room"] ?? "",
          "time": value["time"] ?? "",
        });
      });

      setState(() {
        timetableList = temp;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Time Table"),
      ),
      body: ListView.builder(
        itemCount: timetableList.length,
        itemBuilder: (context, index) {
          final item = timetableList[index];

          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: const Icon(
                Icons.schedule,
                color: Colors.blue,
              ),
              title: Text(item["subject"]),
              subtitle: Text(
                "${item["faculty"]}\nRoom: ${item["room"]}\nTime: ${item["time"]}",
              ),
            ),
          );
        },
      ),
    );
  }
}