import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/timetable_service.dart';
import '../services/voice_navigation_service.dart';
import 'qr_scanner_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final TimetableService _timetableService = TimetableService();
  final VoiceNavigationService _voiceService = VoiceNavigationService();
  Timer? _clockTimer;

  String? _currentLocation = 'Lobby';
  String? _destination = 'E1-101';
  String? _lastSpokenRoute;
  bool _routeToSuggestedRoom = true;
  bool _voiceEnabled = true;

  static const List<String> _locations = [
    'Main Gate',
    'Lobby',
    'Stairs',
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
    'Stairs': Offset(0.50, 0.46),
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
    _voiceService.stop();
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
        _lastSpokenRoute = null;
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

  NavigationRoute _buildRoute(String from, String to) {
    final start = _mapNodes[from];
    final end = _mapNodes[to];

    if (start == null || end == null) {
      return const NavigationRoute(points: [], instructions: []);
    }

    const corridorY = 0.46;
    final stairs = _mapNodes['Stairs']!;
    final points = <Offset>[
      start,
      Offset(start.dx, corridorY),
      if (from != 'Stairs' && to != 'Stairs') stairs,
      Offset(end.dx, corridorY),
      end,
    ].where(_isUsefulPoint).toList();

    final instructions = <NavigationInstruction>[];

    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      if (previous == current) continue;

      final reachesStairs =
          current == stairs && from != 'Stairs' && to != 'Stairs';

      instructions.add(
        NavigationInstruction(
          text: _instructionText(
            previous,
            current,
            i == points.length - 1,
            reachesStairs,
          ),
          point: current,
        ),
      );

      if (reachesStairs) {
        instructions.add(
          NavigationInstruction(
            text: 'Take stairs, then continue',
            point: current,
          ),
        );
      }
    }

    instructions.add(
      NavigationInstruction(
        text: 'You have arrived at $to',
        point: end,
      ),
    );

    return NavigationRoute(points: points, instructions: instructions);
  }

  bool _isUsefulPoint(Offset point) {
    return point.dx.isFinite && point.dy.isFinite;
  }

  String _instructionText(
    Offset from,
    Offset to,
    bool finalLeg,
    bool reachesStairs,
  ) {
    final meters = _estimateMeters(from, to);
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;

    if (reachesStairs) {
      return '$meters m straight to stairs';
    }

    if (finalLeg) {
      return '$meters m straight to destination';
    }

    if (dx.abs() > dy.abs()) {
      return dx > 0 ? '$meters m right' : '$meters m left';
    }

    return '$meters m straight';
  }

  int _estimateMeters(Offset from, Offset to) {
    final distance = math.sqrt(
      math.pow(to.dx - from.dx, 2) + math.pow(to.dy - from.dy, 2),
    );

    return (math.max(10, distance * 180) / 5).round() * 5;
  }

  void _speakRouteIfNeeded({
    required String currentLocation,
    required String routeTarget,
    required RoomAvailability availability,
    required List<NavigationInstruction> instructions,
  }) {
    if (!_voiceEnabled || instructions.isEmpty) return;

    final signature = [
      currentLocation,
      routeTarget,
      availability.occupied,
      availability.nextFreeAt,
      instructions.map((instruction) => instruction.text).join('|'),
    ].join('::');

    if (_lastSpokenRoute == signature) return;
    _lastSpokenRoute = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_voiceEnabled) return;
      _voiceService.speak(_voiceMessage(routeTarget, availability, instructions));
    });
  }

  String _voiceMessage(
    String routeTarget,
    RoomAvailability availability,
    List<NavigationInstruction> instructions,
  ) {
    final conflictMessage = availability.occupied
        ? 'Destination is occupied. '
            '${availability.nextFreeAt == null ? '' : 'Wait until ${availability.nextFreeAt}, or '}'
            'navigate to suggested room $routeTarget. '
        : '';

    return '$conflictMessage${instructions.map((step) => step.text).join('. ')}';
  }

  void _showWrittenDirections(List<NavigationInstruction> instructions) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            itemCount: instructions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text(instructions[index].text),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Navigation'),
        actions: [
          IconButton(
            tooltip: _voiceEnabled ? 'Voice on' : 'Voice off',
            onPressed: () {
              setState(() {
                _voiceEnabled = !_voiceEnabled;
                _lastSpokenRoute = null;
              });
              if (!_voiceEnabled) _voiceService.stop();
            },
            icon: Icon(_voiceEnabled ? Icons.volume_up : Icons.volume_off),
          ),
        ],
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
          final route = _buildRoute(currentLocation, routeTarget);

          _speakRouteIfNeeded(
            currentLocation: currentLocation,
            routeTarget: routeTarget,
            availability: availability,
            instructions: route.instructions,
          );

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
                          painter: PathPainter(route.points),
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
                      if (_mapNodes['Stairs'] != null &&
                          currentLocation != 'Stairs' &&
                          routeTarget != 'Stairs')
                        LocationMarker(
                          point: _mapNodes['Stairs']!,
                          label: 'Stairs',
                          color: Colors.deepOrange,
                        ),
                      RouteInstructionPopups(
                        instructions: route.instructions,
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
                                setState(() {
                                  _currentLocation = value;
                                  _lastSpokenRoute = null;
                                });
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
                          setState(() {
                            _destination = value;
                            _routeToSuggestedRoom = true;
                            _lastSpokenRoute = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _StatusPanel(
                        destination: destination,
                        routeTarget: routeTarget,
                        availability: availability,
                        pathAvailable: route.points.isNotEmpty,
                        voiceEnabled: _voiceEnabled,
                        onUseDestination: () {
                          setState(() {
                            _routeToSuggestedRoom = false;
                            _lastSpokenRoute = null;
                          });
                        },
                        onUseSuggestion: availability.suggestedRoom == null
                            ? null
                            : () {
                                setState(() {
                                  _routeToSuggestedRoom = true;
                                  _lastSpokenRoute = null;
                                });
                              },
                        onShowSteps: route.instructions.isEmpty
                            ? null
                            : () => _showWrittenDirections(route.instructions),
                        onRepeatVoice: route.instructions.isEmpty
                            ? null
                            : () => _voiceService.speak(
                                  _voiceMessage(
                                    routeTarget,
                                    availability,
                                    route.instructions,
                                  ),
                                ),
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
      value: _locations.contains(value) ? value : null,
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
    required this.voiceEnabled,
    required this.onUseDestination,
    required this.onUseSuggestion,
    required this.onShowSteps,
    required this.onRepeatVoice,
  });

  final String destination;
  final String routeTarget;
  final RoomAvailability availability;
  final bool pathAvailable;
  final bool voiceEnabled;
  final VoidCallback onUseDestination;
  final VoidCallback? onUseSuggestion;
  final VoidCallback? onShowSteps;
  final VoidCallback? onRepeatVoice;

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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShowSteps,
                  icon: const Icon(Icons.format_list_numbered),
                  label: const Text('Steps'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: voiceEnabled ? onRepeatVoice : null,
                  icon: const Icon(Icons.record_voice_over),
                  label: const Text('Speak'),
                ),
              ),
            ],
          ),
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

class RouteInstructionPopups extends StatelessWidget {
  const RouteInstructionPopups({
    super.key,
    required this.instructions,
  });

  final List<NavigationInstruction> instructions;

  @override
  Widget build(BuildContext context) {
    if (instructions.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: instructions.take(4).map((instruction) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              border: Border.all(color: Colors.blue.withOpacity(0.35)),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForInstruction(instruction.text),
                    size: 18,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    instruction.text,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _iconForInstruction(String text) {
    if (text.contains('left')) return Icons.turn_left;
    if (text.contains('right')) return Icons.turn_right;
    if (text.contains('stairs')) return Icons.stairs;
    if (text.contains('arrived')) return Icons.flag;
    return Icons.straight;
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

class NavigationRoute {
  const NavigationRoute({
    required this.points,
    required this.instructions,
  });

  final List<Offset> points;
  final List<NavigationInstruction> instructions;
}

class NavigationInstruction {
  const NavigationInstruction({
    required this.text,
    required this.point,
  });

  final String text;
  final Offset point;
}
