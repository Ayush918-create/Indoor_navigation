import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../services/timetable_service.dart';
import 'navigation_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();
  Timer? _clockTimer;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Map<String, FacultyProfile> _parseFacultyProfiles(Object? value) {
    final profiles = <String, FacultyProfile>{};

    Iterable<dynamic> items = const [];
    if (value is List) {
      items = value.whereType<Map>();
    } else if (value is Map) {
      items = value.values.whereType<Map>();
    }

    for (final item in items) {
      final name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;

      profiles[name.toLowerCase()] = FacultyProfile(
        name: name,
        cabinRoom: _firstValue(
          item,
          ['room', 'cabin', 'cabinNumber', 'cabinRoom', 'facultyCabin'],
        ),
      );
    }

    return profiles;
  }

  String _firstValue(Map<dynamic, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  List<FacultySchedule> _buildFacultySchedules(
    Object? facultyValue,
    List<TimetableEntry> entries,
  ) {
    final profiles = _parseFacultyProfiles(facultyValue);

    for (final entry in entries) {
      final faculty = entry.faculty.trim();
      if (faculty.isEmpty) continue;

      profiles.putIfAbsent(
        faculty.toLowerCase(),
        () => FacultyProfile(name: faculty, cabinRoom: ''),
      );
    }

    final schedules = profiles.values.map((profile) {
      final facultyEntries = entries
          .where(
            (entry) =>
                entry.faculty.trim().toLowerCase() ==
                profile.name.trim().toLowerCase(),
          )
          .toList();

      TimetableEntry? runningClass;
      for (final entry in facultyEntries) {
        if (TimetableService.isEntryRunningNow(entry)) {
          runningClass = entry;
          break;
        }
      }

      return FacultySchedule(
        profile: profile,
        entries: facultyEntries,
        runningClass: runningClass,
      );
    }).toList()
      ..sort(
        (a, b) => a.profile.name.toLowerCase().compareTo(
              b.profile.name.toLowerCase(),
            ),
      );

    if (_query.trim().isEmpty) return schedules;

    final query = _query.trim().toLowerCase();
    return schedules.where((schedule) {
      return schedule.profile.name.toLowerCase().contains(query) ||
          schedule.profile.cabinRoom.toLowerCase().contains(query) ||
          schedule.entries.any(
            (entry) =>
                entry.subject.toLowerCase().contains(query) ||
                entry.room.toLowerCase().contains(query),
          );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Timetable'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search faculty, room, or subject',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: dbRef.child('faculty').onValue,
              builder: (context, facultySnapshot) {
                return StreamBuilder<List<TimetableEntry>>(
                  stream: _timetableService.watchAllEntries(),
                  builder: (context, timetableSnapshot) {
                    if (!facultySnapshot.hasData &&
                        !timetableSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final schedules = _buildFacultySchedules(
                      facultySnapshot.data?.snapshot.value,
                      timetableSnapshot.data ?? [],
                    );

                    if (schedules.isEmpty) {
                      return const Center(
                        child: Text('No Faculty Timetable Found'),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => setState(() {}),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: schedules.length,
                        itemBuilder: (context, index) {
                          return FacultyScheduleTile(
                            schedule: schedules[index],
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FacultyScheduleTile extends StatelessWidget {
  const FacultyScheduleTile({
    super.key,
    required this.schedule,
  });

  final FacultySchedule schedule;

  @override
  Widget build(BuildContext context) {
    final runningClass = schedule.runningClass;
    final available = runningClass == null;
    final activeRoom = runningClass?.room ?? schedule.profile.cabinRoom;
    final activeLocationLabel = available ? 'Cabin' : 'Current class room';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: available ? Colors.green : Colors.red,
          child: Icon(
            available ? Icons.check : Icons.close,
            color: Colors.white,
          ),
        ),
        title: Text(
          schedule.profile.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          available
              ? 'Available${activeRoom.isEmpty ? '' : ' | Cabin: $activeRoom'}'
              : 'Teaching ${runningClass.subject} | Room: ${runningClass.room}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (activeRoom.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$activeLocationLabel: $activeRoom',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openNavigation(context, activeRoom),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                  ),
                ],
              ),
            ),
          if (schedule.entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No timetable entries'),
              ),
            )
          else
            ...schedule.entries.map((entry) {
              final isLive = TimetableService.isEntryRunningNow(entry);

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isLive ? Colors.green.shade50 : Colors.grey.shade50,
                  border: Border.all(
                    color: isLive ? Colors.green : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        entry.day,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.subject,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${entry.startTime} - ${entry.endTime}  |  ${entry.room}',
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: entry.room.trim().isEmpty
                                  ? null
                                  : () => _openNavigation(context, entry.room),
                              icon: const Icon(Icons.navigation),
                              label: Text('Navigate to ${entry.room}'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLive)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Chip(
                          label: Text('LIVE'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _openNavigation(BuildContext context, String room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationScreen(initialDestination: room),
      ),
    );
  }
}

class FacultyProfile {
  const FacultyProfile({
    required this.name,
    required this.cabinRoom,
  });

  final String name;
  final String cabinRoom;
}

class FacultySchedule {
  const FacultySchedule({
    required this.profile,
    required this.entries,
    required this.runningClass,
  });

  final FacultyProfile profile;
  final List<TimetableEntry> entries;
  final TimetableEntry? runningClass;
}
