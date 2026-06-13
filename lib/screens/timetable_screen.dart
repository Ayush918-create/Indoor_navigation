import 'dart:async';

import 'package:flutter/material.dart';

import '../services/timetable_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Timetable'),
      ),
      body: StreamBuilder<List<TimetableEntry>>(
        stream: _timetableService.watchEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return const Center(
              child: Text('No Timetable Found'),
            );
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
                initiallyExpanded:
                    entry.key == TimetableService.todayName(),
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
                    color: isCurrentClass
                        ? Colors.green.shade100
                        : Colors.white,
                    child: ListTile(
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
                        'Time: ${item.startTime} - ${item.endTime}',
                      ),
                      trailing: isCurrentClass
                          ? const Chip(
                              label: Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Colors.green,
                            )
                          : null,
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
