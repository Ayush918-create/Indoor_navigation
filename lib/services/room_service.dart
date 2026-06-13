import 'timetable_service.dart';

class RoomService {
  final TimetableService _timetableService = TimetableService();

  Future<bool> isRoomOccupied(
    String room,
    String currentTime,
  ) async {
    final entries = await _timetableService.fetchEntries();
    final minutes = TimetableService.parseTimeToMinutes(currentTime);
    final now = DateTime.now();
    final checkTime = DateTime(
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );

    return _timetableService
        .availabilityForRoomWithoutSuggestion(
          room,
          entries,
          now: checkTime,
        )
        .occupied;
  }
}
