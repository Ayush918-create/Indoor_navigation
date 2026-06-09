// lib/services/upload_data.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

Future<void> uploadInitialData() async {
  final FirebaseDatabase database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://indoor-navigation-app-cfb2f-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  await database.ref().set({
    "navigation_map": {
      "E1-101": {
        "path": "Gate → E1 →  Stairs → 1st floor → Room 101",
        "waypoints": [
          {"x": 20, "y": 50},
          {"x": 100, "y": 150},
          {"x": 200, "y": 250},
        ],
      },
      "E1-102": {
        "path": "Gate → E1 → Stairs → 1st floor → Room 102",
        "waypoints": [
          {"x": 20, "y": 50},
          {"x": 150, "y": 150},
          {"x": 250, "y": 250},
        ],
      },
    },

    "faculty": {
      "F1": {"name": "Dr Sharma", "room": "E1-101", "available": true},
      "F2": {"name": "Dr Paulraj", "room": "E1-102", "available": false},
      "F3": {"name": "Dr. Pandey", "room": "E1-105", "available": false},
      "F4": {"name": "Dr. Kumar", "room": "E1-205", "available": true},

    },

    "timetable": {
      "Operating System": {"faculty": "Dr Sharma", "room": "E1-101", "time": "10:00 AM"},
      "Java": {
        "faculty": "Dr. Paulraj",
        "room": "E1-102",
        "time": "11:00 AM",
      },
      "Maths": {
        "faculty": "Dr. Pandey",
        "room": "E1-105",
        "time": "11:00 AM",
      },
      "TOC": {
        "faculty": "Dr. Kumar",
        "room": "E1-205",
        "time": "11:00 AM",
      },
    },

    "room_status": {
      "E1-101": {"occupied": true},
      "E1-102": {"occupied": false},
      "E1-103": {"occupied": false},
      "E1-104": {"occupied": true},
      "E1-105": {"occupied": true},
      "E1-205": {"occupied": true},
      "E1-204": {"occupied": false},
    },

    "users": {
      "101": {"userNo": "101", "name": "Lucky Gupta", "password": "1234"},
      "102": {"userNo": "102", "name": "Bhavya", "password": "5678"},
      "103": {"userNo": "103", "name": "Admin", "password": "admin123"},
    },
  });

  print("Firebase Data Uploaded Successfully");
}
