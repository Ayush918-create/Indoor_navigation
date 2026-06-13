import 'timetable_service.dart';

class ConflictService {
  final TimetableService _timetableService = TimetableService();

  Future<Map<String, dynamic>> checkConflict({
    required String room,
  }) async {
    final entries = await _timetableService.fetchEntries();
    final availability = _timetableService.availabilityForRoom(room, entries);

    return {
      'conflict': availability.occupied,
      'suggestedRoom': availability.suggestedRoom ?? 'No Free Room',
      'nextFreeAt': availability.nextFreeAt,
      'subject': availability.currentClass?.subject,
      'faculty': availability.currentClass?.faculty,
    };
  }
}
