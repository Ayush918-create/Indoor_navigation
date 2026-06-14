import 'dart:async';

import 'package:flutter/material.dart';

import '../services/timetable_service.dart';
import 'navigation_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final TimetableService _timetableService = TimetableService();
  Timer? _clockTimer;

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
    super.dispose();
  }

  void _openNavigation(String room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationScreen(initialDestination: room),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Timetable'),
      ),
      body: StreamBuilder<List<TimetableEntry>>(
        stream: _timetableService.watchEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return const Center(child: Text('No Timetable Found'));
          }

          final groupedData = <String, List<TimetableEntry>>{
            for (final day in TimetableService.weekDays) day: [],
          };

          for (final entry in entries) {
            groupedData.putIfAbsent(entry.day, () => []).add(entry);
          }

          return ListView(
            children: groupedData.entries.map((entry) {
              if (entry.value.isEmpty) return const SizedBox.shrink();

              return ExpansionTile(
                initiallyExpanded: entry.key == TimetableService.todayName(),
                title: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: entry.value.map((item) {
                  final isCurrentClass =
                      TimetableService.isEntryRunningNow(item);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    color: isCurrentClass ? Colors.green.shade100 : Colors.white,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            item.subject,
                            style: TextStyle(
                              fontWeight: isCurrentClass
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            'Faculty: ${item.faculty}\n'
                            'Room: ${item.room}\n'
                            'Time: ${TimetableService.formatTime12Hour(item.startTime)}'
                            ' - ${TimetableService.formatTime12Hour(item.endTime)}',
                          ),
                          trailing: isCurrentClass
                              ? const Chip(
                                  label: Text(
                                    'LIVE',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.green,
                                )
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: item.room.trim().isEmpty
                                  ? null
                                  : () => _openNavigation(item.room),
                              icon: const Icon(Icons.navigation),
                              label: Text('Navigate to ${item.room}'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
