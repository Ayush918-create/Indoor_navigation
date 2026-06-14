import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import '../services/timetable_service.dart';

class RoomStatusScreen extends StatelessWidget {
  const RoomStatusScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final timetableService = TimetableService();

    return Scaffold(
      appBar: AppBar(title: const Text('Room Status')),
      body: StreamBuilder<List<TimetableEntry>>(
        stream: timetableService.watchEntries(),
        builder: (context, snapshot) {
          return StreamBuilder<DatabaseEvent>(
            stream: AuthService().dbRef.child('rooms').onValue,
            builder: (context, roomSnapshot) {
              final entries = snapshot.data ?? [];
              final roomStatus = _parseRoomStatus(
                roomSnapshot.data?.snapshot.value,
              );
              final occupied = <String>{};

              for (final room in TimetableService.knownRooms) {
                final status =
                    timetableService.availabilityForRoomWithoutSuggestion(
                  room,
                  entries,
                );
                if (status.occupied || roomStatus[room] == true) {
                  occupied.add(room);
                }
              }

              final free = TimetableService.knownRooms
                  .where((room) => !occupied.contains(room))
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (PermissionService(user).canAllocateRooms)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_available),
                        title: const Text('Allocate Free Room'),
                        subtitle: const Text('Select a free room and time'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showAllocationSheet(
                          context: context,
                          user: user,
                          freeRooms: free,
                        ),
                      ),
                    ),
                  _RoomGroup(
                    title: 'All Rooms',
                    rooms: TimetableService.knownRooms,
                  ),
                  _RoomGroup(title: 'Occupied Rooms', rooms: occupied.toList()),
                  _RoomGroup(title: 'Free Rooms', rooms: free),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showAllocationSheet({
    required BuildContext context,
    required AppUser user,
    required List<String> freeRooms,
  }) {
    final authService = AuthService();
    String? selectedRoom;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    String formatTime(TimeOfDay time) {
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Allocate Free Room',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRoom,
                      decoration: const InputDecoration(
                        labelText: 'Free Room',
                        border: OutlineInputBorder(),
                      ),
                      items: freeRooms.map((room) {
                        return DropdownMenuItem(
                          value: room,
                          child: Text(room),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setSheetState(() => selectedRoom = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final value = await showTimePicker(
                                context: context,
                                initialTime: startTime ?? TimeOfDay.now(),
                              );
                              if (value != null) {
                                setSheetState(() => startTime = value);
                              }
                            },
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              startTime == null
                                  ? 'Start'
                                  : TimetableService.formatTime12Hour(
                                      formatTime(startTime!),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final value = await showTimePicker(
                                context: context,
                                initialTime: endTime ?? TimeOfDay.now(),
                              );
                              if (value != null) {
                                setSheetState(() => endTime = value);
                              }
                            },
                            icon: const Icon(Icons.timer_off),
                            label: Text(
                              endTime == null
                                  ? 'End'
                                  : TimetableService.formatTime12Hour(
                                      formatTime(endTime!),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selectedRoom == null ||
                                startTime == null ||
                                endTime == null
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final allocationId =
                                    '${user.uid}_${selectedRoom}_${now.millisecondsSinceEpoch}';
                                await authService.dbRef
                                    .child('room_allocations/$allocationId')
                                    .set({
                                  'id': allocationId,
                                  'room': selectedRoom,
                                  'facultyUid': user.uid,
                                  'facultyName': user.name,
                                  'day': TimetableService.todayName(),
                                  'date': DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                  ).toIso8601String(),
                                  'startTime': formatTime(startTime!),
                                  'endTime': formatTime(endTime!),
                                  'createdAt': now.toIso8601String(),
                                  'active': true,
                                });
                                await authService.dbRef
                                    .child('rooms/$selectedRoom')
                                    .update({
                                  'room': selectedRoom,
                                  'occupied': true,
                                  'allocatedBy': user.uid,
                                  'allocationId': allocationId,
                                });
                                if (context.mounted) Navigator.pop(context);
                              },
                        icon: const Icon(Icons.event_available),
                        label: const Text('Allocate'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class RoomAllocationScreen extends StatefulWidget {
  const RoomAllocationScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  State<RoomAllocationScreen> createState() => _RoomAllocationScreenState();
}

class _RoomAllocationScreenState extends State<RoomAllocationScreen> {
  final AuthService _authService = AuthService();
  final TimetableService _timetableService = TimetableService();
  String? selectedRoom;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _cleanupExpiredAllocations();
  }

  Future<void> _cleanupExpiredAllocations() async {
    final snapshot = await _authService.dbRef.child('room_allocations').get();
    final allocations = _parseCollection(snapshot.value);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    for (final allocation in allocations) {
      final id = allocation['id']?.toString() ?? '';
      final room = allocation['room']?.toString() ?? '';
      final dateText = allocation['date']?.toString() ?? '';
      final date = DateTime.tryParse(dateText);

      if (id.isEmpty || room.isEmpty || date == null) continue;

      final allocationDay = DateTime(date.year, date.month, date.day);
      if (allocationDay.isBefore(todayOnly)) {
        await _authService.dbRef.child('room_allocations/$id').remove();
        await _authService.dbRef.child('rooms/$room').update({
          'occupied': false,
          'allocatedBy': null,
          'allocationId': null,
        });
      }
    }
  }

  Future<void> allocateRoom(List<String> freeRooms) async {
    if (!PermissionService(widget.user).canAllocateRooms) return;
    if (selectedRoom == null || startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select room, start time and end time')),
      );
      return;
    }

    if (!freeRooms.contains(selectedRoom)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only free rooms can be allocated')),
      );
      return;
    }

    setState(() => saving = true);

    final now = DateTime.now();
    final allocationId =
        '${widget.user.uid}_${selectedRoom}_${now.millisecondsSinceEpoch}';

    await _authService.dbRef.child('room_allocations/$allocationId').set({
      'id': allocationId,
      'room': selectedRoom,
      'facultyUid': widget.user.uid,
      'facultyName': widget.user.name,
      'day': TimetableService.todayName(),
      'date': DateTime(now.year, now.month, now.day).toIso8601String(),
      'startTime': _formatTime(startTime!),
      'endTime': _formatTime(endTime!),
      'createdAt': now.toIso8601String(),
      'active': true,
    });

    await _authService.dbRef.child('rooms/$selectedRoom').update({
      'room': selectedRoom,
      'occupied': true,
      'allocatedBy': widget.user.uid,
      'allocationId': allocationId,
    });

    setState(() => saving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$selectedRoom allocated')),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStartTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );
    if (value != null) setState(() => startTime = value);
  }

  Future<void> _pickEndTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: endTime ?? TimeOfDay.now(),
    );
    if (value != null) setState(() => endTime = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Allocate Free Room')),
      body: StreamBuilder<List<TimetableEntry>>(
        stream: _timetableService.watchEntries(),
        builder: (context, snapshot) {
          return StreamBuilder<DatabaseEvent>(
            stream: _authService.dbRef.child('rooms').onValue,
            builder: (context, roomSnapshot) {
              final entries = snapshot.data ?? [];
              final roomStatus = _parseRoomStatus(
                roomSnapshot.data?.snapshot.value,
              );
              final freeRooms = TimetableService.knownRooms.where((room) {
                final timetableOccupied = _timetableService
                    .availabilityForRoomWithoutSuggestion(room, entries)
                    .occupied;
                return !timetableOccupied && roomStatus[room] != true;
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    value: freeRooms.contains(selectedRoom) ? selectedRoom : null,
                    decoration: const InputDecoration(
                      labelText: 'Free Room',
                      border: OutlineInputBorder(),
                    ),
                    items: freeRooms.map((room) {
                      return DropdownMenuItem(
                        value: room,
                        child: Text(room),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedRoom = value),
                  ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        startTime == null
                            ? 'Start Time'
                            : _formatTime(startTime!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEndTime,
                      icon: const Icon(Icons.timer_off),
                      label: Text(
                        endTime == null ? 'End Time' : _formatTime(endTime!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: saving ? null : () => allocateRoom(freeRooms),
                icon: const Icon(Icons.event_available),
                label: const Text('Allocate Room'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Current Allocations',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<DatabaseEvent>(
                stream: _authService.dbRef.child('room_allocations').onValue,
                builder: (context, allocationSnapshot) {
                  final allocations =
                      _parseCollection(allocationSnapshot.data?.snapshot.value);

                  return Column(
                    children: allocations.map((allocation) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.meeting_room),
                          title: Text(allocation['room']?.toString() ?? ''),
                          subtitle: Text(
                            '${allocation['facultyName']} | '
                            '${TimetableService.formatTime12Hour(allocation['startTime']?.toString() ?? '')}'
                            ' - ${TimetableService.formatTime12Hour(allocation['endTime']?.toString() ?? '')}',
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class RoomConflictScreen extends StatelessWidget {
  const RoomConflictScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(title: const Text('Room Conflicts')),
      body: StreamBuilder<DatabaseEvent>(
        stream: authService.dbRef.child('conflicts').onValue,
        builder: (context, snapshot) {
          final conflicts = _parseCollection(snapshot.data?.snapshot.value);

          if (conflicts.isEmpty) {
            return const Center(child: Text('No conflicts found'));
          }

          return ListView.builder(
            itemCount: conflicts.length,
            itemBuilder: (context, index) {
              final conflict = conflicts[index];

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: const Icon(Icons.report_problem),
                  title: Text(conflict['room']?.toString() ?? 'Room Conflict'),
                  subtitle: Text(conflict['message']?.toString() ?? ''),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StudentProfilesScreen extends StatelessWidget {
  const StudentProfilesScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return _UserListScreen(
      title: 'Student Profiles',
      user: user,
      roleFilter: UserRole.student,
      editable: false,
    );
  }
}

class _RoomGroup extends StatelessWidget {
  const _RoomGroup({
    required this.title,
    required this.rooms,
  });

  final String title;
  final List<String> rooms;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text('$title (${rooms.length})'),
        children: rooms.isEmpty
            ? [
                const ListTile(title: Text('No rooms')),
              ]
            : rooms.map((room) => ListTile(title: Text(room))).toList(),
      ),
    );
  }
}

class _UserListScreen extends StatefulWidget {
  const _UserListScreen({
    required this.title,
    required this.user,
    required this.roleFilter,
    required this.editable,
  });

  final String title;
  final AppUser user;
  final UserRole roleFilter;
  final bool editable;

  @override
  State<_UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<_UserListScreen> {
  final AuthService _authService = AuthService();
  String query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                hintText: 'Search by name, email, department',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _authService.watchUsers(),
              builder: (context, snapshot) {
                final users = _parseCollection(snapshot.data?.snapshot.value)
                    .map(AppUser.fromMap)
                    .where((item) => item.role == widget.roleFilter)
                    .where((item) {
                  final search = query.toLowerCase();
                  return item.name.toLowerCase().contains(search) ||
                      item.email.toLowerCase().contains(search) ||
                      item.department.toLowerCase().contains(search);
                }).toList();

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final item = users[index];

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.email}\n${item.department} ${item.semester}',
                        ),
                        trailing: widget.editable
                            ? Switch(
                                value: item.active,
                                onChanged: (value) {
                                  _authService.setAccountActive(
                                    user: item,
                                    active: value,
                                  );
                                },
                              )
                            : const Icon(Icons.visibility),
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

List<Map<dynamic, dynamic>> _parseCollection(Object? value) {
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

Map<String, bool> _parseRoomStatus(Object? value) {
  final status = <String, bool>{};

  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.value is Map) {
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        status[entry.key.toString()] = data['occupied'] == true;
      }
    }
  }

  return status;
}
