import 'dart:async';

import 'package:flutter/material.dart';

import '../services/timetable_service.dart';
import 'qr_scanner_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final TimetableService _timetableService = TimetableService();
  Timer? _clockTimer;

  String? _currentLocation = 'Lobby';
  String? _destination = 'E1-101';
  bool _routeToSuggestedRoom = true;

  static const List<String> _locations = [
    'Main Gate',
    'Lobby',
    'HOD Office',
    'Seminar Hall',
    'E1-101',
    'E1-102',
    'E1-103',
    'E1-104',
    'E1-105',
    'E1-106',
    'E1-107',
    'E1-108',
    'E1-109',
  ];

  static const Map<String, Offset> _mapNodes = {
    'Main Gate': Offset(0.10, 0.88),
    'Lobby': Offset(0.22, 0.68),
    'HOD Office': Offset(0.78, 0.20),
    'Seminar Hall': Offset(0.78, 0.80),
    'E1-101': Offset(0.18, 0.28),
    'E1-102': Offset(0.34, 0.28),
    'E1-103': Offset(0.50, 0.28),
    'E1-104': Offset(0.66, 0.28),
    'E1-105': Offset(0.82, 0.28),
    'E1-106': Offset(0.18, 0.58),
    'E1-107': Offset(0.34, 0.58),
    'E1-108': Offset(0.50, 0.58),
    'E1-109': Offset(0.66, 0.58),
  };

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

  Future<void> scanCurrentLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const QRScannerScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _currentLocation = _matchLocation(result.toString());
      });
    }
  }

  String _matchLocation(String value) {
    final normalized = value.trim().toLowerCase();

    return _locations.firstWhere(
      (location) => location.toLowerCase() == normalized,
      orElse: () => value.trim(),
    );
  }

  String _routeTarget(RoomAvailability availability) {
    if (_routeToSuggestedRoom &&
        availability.occupied &&
        availability.suggestedRoom != null) {
      return availability.suggestedRoom!;
    }

    return _destination ?? '';
  }

  List<Offset> _buildRoute(String from, String to) {
    final start = _mapNodes[from];
    final end = _mapNodes[to];

    if (start == null || end == null) return [];

    const corridorY = 0.46;

    return [
      start,
      Offset(start.dx, corridorY),
      const Offset(0.50, corridorY),
      Offset(end.dx, corridorY),
      end,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Navigation'),
      ),
      body: StreamBuilder<List<TimetableEntry>>(
        stream: _timetableService.watchEntries(),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          final destination = _destination ?? '';
          final currentLocation = _currentLocation ?? '';
          final availability =
              _timetableService.availabilityForRoom(destination, entries);
          final routeTarget = _routeTarget(availability);
          final pathPoints = _buildRoute(currentLocation, routeTarget);

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/floor_map.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: PathPainter(pathPoints),
                        ),
                      ),
                      if (_mapNodes[currentLocation] != null)
                        LocationMarker(
                          point: _mapNodes[currentLocation]!,
                          label: 'You',
                          color: Colors.red,
                        ),
                      if (_mapNodes[routeTarget] != null)
                        LocationMarker(
                          point: _mapNodes[routeTarget]!,
                          label: routeTarget,
                          color: availability.occupied &&
                                  routeTarget != destination
                              ? Colors.green
                              : Colors.blue,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _locationPicker(
                              label: 'Current location',
                              value: _currentLocation,
                              icon: Icons.my_location,
                              onChanged: (value) {
                                setState(() => _currentLocation = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Scan current location QR',
                            onPressed: scanCurrentLocation,
                            icon: const Icon(Icons.qr_code_scanner),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _locationPicker(
                        label: 'Destination room',
                        value: _destination,
                        icon: Icons.place,
                        onChanged: (value) {
                          setState(() => _destination = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _StatusPanel(
                        destination: destination,
                        routeTarget: routeTarget,
                        availability: availability,
                        pathAvailable: pathPoints.isNotEmpty,
                        onUseDestination: () {
                          setState(() => _routeToSuggestedRoom = false);
                        },
                        onUseSuggestion: availability.suggestedRoom == null
                            ? null
                            : () {
                                setState(() => _routeToSuggestedRoom = true);
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _locationPicker({
    required String label,
    required String? value,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: _locations.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      items: _locations.map((location) {
        return DropdownMenuItem<String>(
          value: location,
          child: Text(location),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.destination,
    required this.routeTarget,
    required this.availability,
    required this.pathAvailable,
    required this.onUseDestination,
    required this.onUseSuggestion,
  });

  final String destination;
  final String routeTarget;
  final RoomAvailability availability;
  final bool pathAvailable;
  final VoidCallback onUseDestination;
  final VoidCallback? onUseSuggestion;

  @override
  Widget build(BuildContext context) {
    final statusColor = availability.occupied ? Colors.orange : Colors.green;
    final title = availability.occupied
        ? '$destination is occupied'
        : '$destination is free now';
    final faculty = availability.currentClass?.faculty;
    final facultyText = faculty == null || faculty.isEmpty
        ? ''
        : ' with $faculty';
    final waitText = availability.nextFreeAt == null
        ? '.'
        : '. Wait until ${availability.nextFreeAt}.';

    final detail = availability.occupied
        ? '${availability.currentClass?.subject ?? 'Class'} is running'
            '$facultyText$waitText'
        : 'Route is ready from your current location.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.10),
        border: Border.all(color: statusColor.withOpacity(0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                availability.occupied ? Icons.warning_amber : Icons.check,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(detail),
          if (availability.occupied && availability.suggestedRoom != null) ...[
            const SizedBox(height: 8),
            Text(
              'Suggested free room: ${availability.suggestedRoom}. '
              'Showing route to $routeTarget.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onUseDestination,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Wait'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onUseSuggestion,
                    icon: const Icon(Icons.alt_route),
                    label: const Text('Use room'),
                  ),
                ),
              ],
            ),
          ],
          if (!pathAvailable) ...[
            const SizedBox(height: 8),
            const Text(
              'No map path is available for this location yet.',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class LocationMarker extends StatelessWidget {
  const LocationMarker({
    super.key,
    required this.point,
    required this.label,
    required this.color,
  });

  final Offset point;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(point.dx * 2 - 1, point.dy * 2 - 1),
      child: Transform.translate(
        offset: const Offset(0, -22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  PathPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final scaledPoints = points
        .map(
          (point) => Offset(
            point.dx * size.width,
            point.dy * size.height,
          ),
        )
        .toList();

    final shadowPaint = Paint()
      ..color = Colors.white.withOpacity(0.95)
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final routePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(scaledPoints.first.dx, scaledPoints.first.dy);

    for (int i = 1; i < scaledPoints.length; i++) {
      path.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
    }

    canvas
      ..drawPath(path, shadowPaint)
      ..drawPath(path, routePaint);

    for (final point in scaledPoints) {
      canvas.drawCircle(point, 4, routePaint);
    }
  }

  @override
  bool shouldRepaint(PathPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
