import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class TimetableEntry {
  const TimetableEntry({
    required this.day,
    required this.subject,
    required this.faculty,
    required this.room,
    required this.startTime,
    required this.endTime,
  });

  final String day;
  final String subject;
  final String faculty;
  final String room;
  final String startTime;
  final String endTime;

  factory TimetableEntry.fromMap(Map<dynamic, dynamic> data) {
    return TimetableEntry(
      day: data['day']?.toString() ?? '',
      subject: data['subject']?.toString() ?? '',
      faculty: data['faculty']?.toString() ?? '',
      room: data['room']?.toString() ?? '',
      startTime: data['startTime']?.toString() ?? '',
      endTime: data['endTime']?.toString() ?? '',
    );
  }
}

class RoomAvailability {
  const RoomAvailability({
    required this.occupied,
    this.currentClass,
    this.nextFreeAt,
    this.suggestedRoom,
  });

  final bool occupied;
  final TimetableEntry? currentClass;
  final String? nextFreeAt;
  final String? suggestedRoom;
}

class TimetableService {
  final DatabaseReference dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://indoor-navigation-app-cfb2f-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  static const List<String> weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> knownRooms = [
    'E1-101',
    'E1-102',
    'E1-103',
    'E1-104',
    'E1-105',
    'E1-106',
    'E1-107',
    'E1-108',
    'E1-109',
    'Seminar Hall',
    'HOD Office',
    'Lobby',
  ];

  Stream<List<TimetableEntry>> watchEntries() {
    return dbRef.child('timetable').onValue.map(
          (event) => parseEntries(event.snapshot.value),
        );
  }

  Future<List<TimetableEntry>> fetchEntries() async {
    final snapshot = await dbRef.child('timetable').get();
    return parseEntries(snapshot.value);
  }

  List<TimetableEntry> parseEntries(Object? value) {
    if (value == null) return [];

    final entries = <TimetableEntry>[];

    if (value is List) {
      for (final item in value) {
        if (item is Map) {
          entries.add(TimetableEntry.fromMap(item));
        }
      }
    } else if (value is Map) {
      for (final item in value.values) {
        if (item is Map) {
          entries.add(TimetableEntry.fromMap(item));
        }
      }
    }

    entries.sort((a, b) {
      final dayCompare =
          weekDays.indexOf(a.day).compareTo(weekDays.indexOf(b.day));
      if (dayCompare != 0) return dayCompare;
      return parseTimeToMinutes(a.startTime).compareTo(
        parseTimeToMinutes(b.startTime),
      );
    });

    return entries;
  }

  static String todayName([DateTime? dateTime]) {
    final now = dateTime ?? DateTime.now();
    return weekDays[now.weekday - 1];
  }

  static int currentMinutes([DateTime? dateTime]) {
    final now = dateTime ?? DateTime.now();
    return now.hour * 60 + now.minute;
  }

  static int parseTimeToMinutes(String time) {
    final cleaned = time.trim().toUpperCase();
    final hasPm = cleaned.contains('PM');
    final hasAm = cleaned.contains('AM');
    final numeric = cleaned.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = numeric.split(':');

    if (parts.length < 2) return -1;

    var hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    if (hasPm && hour < 12) hour += 12;
    if (hasAm && hour == 12) hour = 0;

    return hour * 60 + minute;
  }

  static bool isEntryRunningNow(
    TimetableEntry entry, {
    DateTime? now,
  }) {
    final checkTime = now ?? DateTime.now();

    if (entry.day != todayName(checkTime)) return false;

    final current = currentMinutes(checkTime);
    final start = parseTimeToMinutes(entry.startTime);
    final end = parseTimeToMinutes(entry.endTime);

    return start >= 0 && end >= 0 && current >= start && current < end;
  }

  RoomAvailability availabilityForRoom(
    String room,
    List<TimetableEntry> entries, {
    DateTime? now,
  }) {
    final normalizedRoom = room.trim().toLowerCase();
    final checkTime = now ?? DateTime.now();
    TimetableEntry? runningClass;

    for (final entry in entries) {
      if (entry.room.trim().toLowerCase() == normalizedRoom &&
          isEntryRunningNow(entry, now: checkTime)) {
        runningClass = entry;
        break;
      }
    }

    final suggestion = runningClass == null
        ? null
        : firstAvailableRoom(
            entries,
            excludedRoom: room,
            now: checkTime,
          );

    return RoomAvailability(
      occupied: runningClass != null,
      currentClass: runningClass,
      nextFreeAt: runningClass?.endTime,
      suggestedRoom: suggestion,
    );
  }

  String? firstAvailableRoom(
    List<TimetableEntry> entries, {
    String? excludedRoom,
    DateTime? now,
  }) {
    final excluded = excludedRoom?.trim().toLowerCase();

    for (final room in knownRooms) {
      if (room.trim().toLowerCase() == excluded) continue;
      final status = availabilityForRoomWithoutSuggestion(
        room,
        entries,
        now: now,
      );
      if (!status.occupied) return room;
    }

    return null;
  }

  RoomAvailability availabilityForRoomWithoutSuggestion(
    String room,
    List<TimetableEntry> entries, {
    DateTime? now,
  }) {
    final normalizedRoom = room.trim().toLowerCase();
    final checkTime = now ?? DateTime.now();

    for (final entry in entries) {
      if (entry.room.trim().toLowerCase() == normalizedRoom &&
          isEntryRunningNow(entry, now: checkTime)) {
        return RoomAvailability(
          occupied: true,
          currentClass: entry,
          nextFreeAt: entry.endTime,
        );
      }
    }

    return const RoomAvailability(occupied: false);
  }
}
