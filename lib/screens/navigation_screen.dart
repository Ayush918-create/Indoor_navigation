// lib/screens/navigation_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final TextEditingController roomController =
      TextEditingController();

  final DatabaseReference dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://indoor-navigation-app-cfb2f-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref();

  List<Offset> pathPoints = [];
  String pathText = "";

  bool roomConflict = false;
  String suggestedRoom = "";

  Future<void> startNavigation() async {
    String room = roomController.text.trim();

    if (room.isEmpty) {
      setState(() {
        pathText = "Enter Room Number";
      });
      return;
    }

    final snapshot =
        await dbRef.child("navigation_map/$room").get();

    if (!snapshot.exists) {
      setState(() {
        pathText = "Room Not Found";
      });
      return;
    }

    Map data = Map<String, dynamic>.from(
      snapshot.value as Map,
    );

    List points = data["waypoints"] ?? [];

    List<Offset> temp = [];

    for (var p in points) {
      temp.add(
        Offset(
          (p["x"] as num).toDouble(),
          (p["y"] as num).toDouble(),
        ),
      );
    }

    setState(() {
      pathPoints = temp;
      pathText = data["path"].toString();
    });
  }

  Future<void> checkRoomConflict() async {
    String room = roomController.text.trim();

    if (room.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter Room Number"),
        ),
      );
      return;
    }

    final snapshot =
        await dbRef.child("room_status").child(room).get();

    if (!snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Room Not Found"),
        ),
      );
      return;
    }

    bool occupied =
        snapshot.child("occupied").value as bool? ?? false;

    if (occupied) {
      final allRooms =
          await dbRef.child("room_status").get();

      String freeRoom = "No Free Room";

      for (var roomData in allRooms.children) {
        bool isOccupied =
            roomData.child("occupied").value as bool? ??
                false;

        if (!isOccupied) {
          freeRoom = roomData.key ?? "";
          break;
        }
      }

      setState(() {
        roomConflict = true;
        suggestedRoom = freeRoom;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Room Conflict"),
          content: Text(
            "Room $room is occupied.\nSuggested Room: $freeRoom",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        roomConflict = false;
        suggestedRoom = room;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Room $room is available"),
        ),
      );
    }
  }

  @override
  void dispose() {
    roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Navigation"),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Image.asset(
                  "assets/images/floor_map.png",
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
                CustomPaint(
                  size: Size.infinite,
                  painter: PathPainter(pathPoints),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: roomController,
              decoration: const InputDecoration(
                labelText: "Enter Room (E1-101)",
                border: OutlineInputBorder(),
              ),
            ),
          ),

          ElevatedButton(
            onPressed: startNavigation,
            child: const Text("Start Navigation"),
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: checkRoomConflict,
            child: const Text("Check Room Conflict"),
          ),

          const SizedBox(height: 10),

          Text(
            pathText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          if (roomConflict)
            Text(
              "Suggested Room: $suggestedRoom",
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  final List<Offset> points;

  PathPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final path = Path();

    path.moveTo(
      points.first.dx,
      points.first.dy,
    );

    for (int i = 1; i < points.length; i++) {
      path.lineTo(
        points[i].dx,
        points[i].dy,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}