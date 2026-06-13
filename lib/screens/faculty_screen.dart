import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../services/timetable_service.dart';

class FacultyScreen extends StatefulWidget {
  const FacultyScreen({super.key});

  @override
  State<FacultyScreen> createState() => _FacultyScreenState();
}

class _FacultyScreenState extends State<FacultyScreen> {
  final DatabaseReference dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://indoor-navigation-app-cfb2f-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();
  final TimetableService _timetableService = TimetableService();

  List<Map<String, dynamic>> facultyList = [];
  List<Map<String, dynamic>> filteredList = [];

  @override
  void initState() {
    super.initState();
    loadFaculty();
  }

  Future<void> loadFaculty() async {
    try {
      final facultySnapshot = await dbRef.child('faculty').get();
      final entries = await _timetableService.fetchEntries();

      if (!facultySnapshot.exists) return;

      final temp = <Map<String, dynamic>>[];

      for (final item in _parseFirebaseCollection(facultySnapshot.value)) {
        final facultyName = item['name']?.toString() ?? '';
        final cabinRoom = item['room']?.toString() ?? '';

        var available = true;
        var currentRoom = cabinRoom;

        for (final entry in entries) {
          if (entry.faculty.trim().toLowerCase() ==
                  facultyName.trim().toLowerCase() &&
              TimetableService.isEntryRunningNow(entry)) {
            available = false;
            currentRoom = entry.room;
            break;
          }
        }

        temp.add({
          'name': facultyName,
          'room': currentRoom,
          'available': available,
        });
      }

      setState(() {
        facultyList = temp;
        filteredList = temp;
      });
    } catch (e) {
      debugPrint('Faculty Error: $e');
    }
  }

  List<Map<dynamic, dynamic>> _parseFirebaseCollection(Object? value) {
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

  void searchFaculty(String query) {
    setState(() {
      filteredList = facultyList.where((faculty) {
        return faculty['name']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> refreshFaculty() async {
    await loadFaculty();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: searchFaculty,
              decoration: const InputDecoration(
                hintText: 'Search Faculty',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refreshFaculty,
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
                      title: Text(faculty['name']),
                      subtitle: Text(
                        faculty['available']
                            ? 'Cabin: ${faculty["room"]}'
                            : 'Currently Teaching In: ${faculty["room"]}',
                      ),
                      trailing: faculty['available']
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
          ),
        ],
      ),
    );
  }
}
