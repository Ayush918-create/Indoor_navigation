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
      day: _firstString(data, ['day', 'Day', 'weekday']),
      subject: _firstString(data, ['subject', 'Subject', 'class', 'course']),
      faculty: _firstString(
        data,
        ['faculty', 'Faculty', 'facultyName', 'teacher', 'name'],
      ),
      room: _firstString(
        data,
        ['room', 'Room', 'roomNo', 'roomNumber', 'classRoom'],
      ),
      startTime: _firstString(
        data,
        ['startTime', 'StartTime', 'start', 'from', 'timeFrom'],
      ),
      endTime: _firstString(
        data,
        ['endTime', 'EndTime', 'end', 'to', 'timeTo'],
      ),
    );
  }
}

String _firstString(Map<dynamic, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }

  return '';
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

  static final List<String> knownRooms = _buildKnownRooms();

  Stream<List<TimetableEntry>> watchEntries() {
    return dbRef.child('timetable').onValue.map(
          (event) => parseEntries(event.snapshot.value),
        );
  }

  Stream<List<TimetableEntry>> watchAllEntries() {
    return dbRef.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <TimetableEntry>[];

      final entries = <TimetableEntry>[
        ...parseEntries(value['timetable']),
        ...parseEntries(value['student_timetable']),
        ...parseEntries(value['faculty_timetable']),
      ];

      entries.sort(_compareEntries);
      return entries;
    });
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

    entries.sort(_compareEntries);

    return entries;
  }

  int _compareEntries(TimetableEntry a, TimetableEntry b) {
    final dayCompare =
        weekDays.indexOf(a.day).compareTo(weekDays.indexOf(b.day));
    if (dayCompare != 0) return dayCompare;
    return parseTimeToMinutes(a.startTime).compareTo(
      parseTimeToMinutes(b.startTime),
    );
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

  static String formatTime12Hour(String time) {
    final minutes = parseTimeToMinutes(time);
    if (minutes < 0) return time;

    final hour24 = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
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

List<String> _buildKnownRooms() {
  final rooms = <String>[
    'Seminar Hall',
    'Auditorium',
    'HOD Office',
  ];

  for (final block in ['E1', 'E2', 'E3']) {
    for (final floor in [0, 1, 2, 3]) {
      final floorPrefix = floor == 0 ? '' : '$floor';
      final maxRoom = block == 'E2' ? 8 : 12;

      for (var room = 1; room <= maxRoom; room++) {
        rooms.add('$block-$floorPrefix${room.toString().padLeft(2, '0')}');
      }
    }
  }

  return rooms;
}
