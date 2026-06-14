import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/timetable_service.dart';
import '../services/voice_navigation_service.dart';
import 'qr_scanner_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    this.initialDestination,
    this.initialCurrentLocation,
  });

  final String? initialDestination;
  final String? initialCurrentLocation;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final TimetableService _timetableService = TimetableService();
  final VoiceNavigationService _voiceService = VoiceNavigationService();
  Timer? _clockTimer;
  DateTime? _navigationStartedAt;
  String? _activeRouteSignature;
  String? _activeRouteTarget;

  late String? _currentLocation;
  late String? _destination;
  String? _lastSpokenRoute;
  bool _routeToSuggestedRoom = true;
  bool _voiceEnabled = true;
  bool _isNavigating = false;

  static final Map<String, _MapNode> _nodes = _buildCollegeNodes();
  static final List<String> _locations = _buildSearchLocations(_nodes);
  static final Map<String, Map<String, double>> _graph =
      _buildCollegeGraph(_nodes);

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialCurrentLocation == null
        ? null
        : _matchLocation(widget.initialCurrentLocation!);
    _destination = widget.initialDestination == null
        ? null
        : _matchLocation(widget.initialDestination!);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _voiceService.stop();
    super.dispose();
  }

  void _resetNavigationProgress() {
    _navigationStartedAt = null;
    _activeRouteSignature = null;
    _activeRouteTarget = null;
    _isNavigating = false;
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
        _resetNavigationProgress();
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
        availability.suggestedRoom != null &&
        _nodes.containsKey(availability.suggestedRoom)) {
      return availability.suggestedRoom!;
    }

    return _destination ?? '';
  }

  NavigationRoute _buildRoute(String from, String to) {
    final routeNames = _shortestRoute(from, to);

    if (routeNames.isEmpty) {
      return const NavigationRoute(
        points: [],
        instructions: [],
        totalMeters: 0,
      );
    }

    final points = routeNames.map((name) => _nodes[name]!.point).toList();
    final instructions = <NavigationInstruction>[];
    var totalMeters = 0;
    var pendingMeters = 0;
    var instructionStartName = routeNames.first;

    for (var i = 1; i < routeNames.length; i++) {
      final fromName = routeNames[i - 1];
      final toName = routeNames[i];
      final meters = _edgeMeters(fromName, toName).round();
      totalMeters += meters;
      pendingMeters += meters;

      if (_nodes[toName]?.routeOnly == true && !_isStairMove(fromName, toName)) {
        continue;
      }

      final visibleMeters = pendingMeters;
      instructions.add(
        NavigationInstruction(
          text: _instructionText(
            fromName: instructionStartName,
            toName: toName,
            meters: visibleMeters,
            finalLeg: i == routeNames.length - 1,
          ),
          point: _nodes[toName]!.point,
        ),
      );
      pendingMeters = 0;
      instructionStartName = toName;
    }

    instructions.add(
      NavigationInstruction(
        text: 'You have arrived at ${_displayName(to)}',
        point: _nodes[to]!.point,
      ),
    );

    return NavigationRoute(
      points: points,
      instructions: instructions,
      totalMeters: totalMeters,
    );
  }

  List<String> _shortestRoute(String from, String to) {
    if (!_nodes.containsKey(from) || !_nodes.containsKey(to)) return [];
    if (from == to) return [from];

    final distances = <String, double>{
      for (final node in _nodes.keys) node: double.infinity,
    };
    final previous = <String, String?>{};
    final unvisited = _nodes.keys.toSet();

    distances[from] = 0;

    while (unvisited.isNotEmpty) {
      final current = unvisited.reduce(
        (a, b) => distances[a]! <= distances[b]! ? a : b,
      );

      if (distances[current] == double.infinity || current == to) break;
      unvisited.remove(current);

      for (final entry in (_graph[current] ?? const <String, double>{}).entries) {
        final neighbor = entry.key;
        if (!unvisited.contains(neighbor)) continue;

        final nextDistance = distances[current]! + entry.value;
        if (nextDistance < distances[neighbor]!) {
          distances[neighbor] = nextDistance;
          previous[neighbor] = current;
        }
      }
    }

    final route = <String>[];
    String? cursor = to;

    while (cursor != null) {
      route.insert(0, cursor);
      if (cursor == from) break;
      cursor = previous[cursor];
    }

    return route.isNotEmpty && route.first == from ? route : [];
  }

  String _instructionText({
    required String fromName,
    required String toName,
    required int meters,
    required bool finalLeg,
  }) {
    final from = _nodes[fromName]!;
    final to = _nodes[toName]!;

    if (_isStairMove(fromName, toName)) {
      final targetFloor = _floorLabel(to.floor);
      final action = to.floor > from.floor ? 'Go up stairs' : 'Go down stairs';
      return '$action $meters m to $targetFloor';
    }

    final dx = to.point.dx - from.point.dx;
    final dy = to.point.dy - from.point.dy;
    final direction = dx.abs() >= dy.abs()
        ? (dx >= 0 ? 'right' : 'left')
        : (dy >= 0 ? 'straight' : 'straight');

    if (finalLeg) {
      return '$meters m $direction to ${_displayName(toName)}';
    }

    return '$meters m $direction toward ${_displayName(toName)}';
  }

  bool _isStairMove(String fromName, String toName) {
    final from = _nodes[fromName];
    final to = _nodes[toName];

    return from != null &&
        to != null &&
        from.stairGroup != null &&
        from.stairGroup == to.stairGroup &&
        from.floor != to.floor;
  }

  double _edgeMeters(String from, String to) {
    return _graph[from]?[to] ??
        _pointDistance(_nodes[from]!.point, _nodes[to]!.point) * 180;
  }

  int _routeSeconds(int meters) {
    return math.max(10, (meters / 1.2).round());
  }

  String _routeSignature(String currentLocation, String routeTarget) {
    return '$currentLocation::$routeTarget';
  }

  double _routeProgress(String signature, int totalSeconds) {
    if (!_isNavigating ||
        _activeRouteSignature != signature ||
        _navigationStartedAt == null) {
      return 0;
    }

    final elapsed = DateTime.now().difference(_navigationStartedAt!).inSeconds;
    final progress = elapsed / math.max(1, totalSeconds);

    if (progress >= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _isNavigating = false;
          _currentLocation = _activeRouteTarget ?? _destination;
          _activeRouteTarget = null;
        });
      });
    }

    return progress.clamp(0, 1).toDouble();
  }

  Offset? _pointAtProgress(List<Offset> points, double progress) {
    if (points.isEmpty) return null;
    if (points.length == 1 || progress <= 0) return points.first;
    if (progress >= 1) return points.last;

    final totalDistance = _polylineDistance(points);
    final targetDistance = totalDistance * progress;
    var traveled = 0.0;

    for (var i = 1; i < points.length; i++) {
      final segmentDistance = _pointDistance(points[i - 1], points[i]);
      if (traveled + segmentDistance >= targetDistance) {
        final localProgress =
            (targetDistance - traveled) / math.max(segmentDistance, 0.0001);
        return Offset.lerp(points[i - 1], points[i], localProgress) ?? points[i];
      }

      traveled += segmentDistance;
    }

    return points.last;
  }

  double _polylineDistance(List<Offset> points) {
    var distance = 0.0;

    for (var i = 1; i < points.length; i++) {
      distance += _pointDistance(points[i - 1], points[i]);
    }

    return distance;
  }

  double _pointDistance(Offset from, Offset to) {
    return math.sqrt(
      math.pow(to.dx - from.dx, 2) + math.pow(to.dy - from.dy, 2),
    );
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
            separatorBuilder: (_, _) => const Divider(height: 1),
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
        title: const Text('College Block Navigation'),
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
          final routeSignature = _routeSignature(currentLocation, routeTarget);
          final totalMeters = route.totalMeters;
          final totalSeconds = _routeSeconds(totalMeters);
          final progress = _routeProgress(routeSignature, totalSeconds);
          final remainingMeters = (totalMeters * (1 - progress))
              .round()
              .clamp(0, totalMeters)
              .toInt();
          final remainingSeconds = (totalSeconds * (1 - progress))
              .round()
              .clamp(0, totalSeconds)
              .toInt();
          final movingPoint =
              _pointAtProgress(route.points, progress) ?? _nodes[currentLocation]?.point;

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
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/floor_map.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: PathPainter(route.points),
                          ),
                        ),
                        if (movingPoint != null)
                          LocationMarker(
                            point: movingPoint,
                            label: 'You',
                            color: Colors.red,
                          ),
                        if (_nodes[routeTarget] != null)
                          LocationMarker(
                            point: _nodes[routeTarget]!.point,
                            label: _displayName(routeTarget),
                            color: availability.occupied &&
                                    routeTarget != destination
                                ? Colors.green
                                : Colors.blue,
                          ),
                        RouteInstructionPopups(
                          instructions: route.instructions,
                        ),
                      ],
                    ),
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
                                  _resetNavigationProgress();
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
                            _resetNavigationProgress();
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
                        isNavigating: _isNavigating &&
                            _activeRouteSignature == routeSignature,
                        totalMeters: totalMeters,
                        remainingMeters: remainingMeters,
                        remainingSeconds: remainingSeconds,
                        onStartNavigation: route.points.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _isNavigating = true;
                                  _navigationStartedAt = DateTime.now();
                                  _activeRouteSignature = routeSignature;
                                  _activeRouteTarget = routeTarget;
                                  _lastSpokenRoute = null;
                                });
                              },
                        onStopNavigation: () {
                          setState(_resetNavigationProgress);
                        },
                        onUseDestination: () {
                          setState(() {
                            _routeToSuggestedRoom = false;
                            _resetNavigationProgress();
                            _lastSpokenRoute = null;
                          });
                        },
                        onUseSuggestion: availability.suggestedRoom == null
                            ? null
                            : () {
                                setState(() {
                                  _routeToSuggestedRoom = true;
                                  _resetNavigationProgress();
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
          child: Text(_displayName(location)),
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
    required this.isNavigating,
    required this.totalMeters,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.onStartNavigation,
    required this.onStopNavigation,
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
  final bool isNavigating;
  final int totalMeters;
  final int remainingMeters;
  final int remainingSeconds;
  final VoidCallback? onStartNavigation;
  final VoidCallback onStopNavigation;
  final VoidCallback onUseDestination;
  final VoidCallback? onUseSuggestion;
  final VoidCallback? onShowSteps;
  final VoidCallback? onRepeatVoice;

  @override
  Widget build(BuildContext context) {
    final statusColor = availability.occupied ? Colors.orange : Colors.green;
    final title = destination.isEmpty
        ? 'Select a destination'
        : availability.occupied
            ? '$destination is occupied'
            : '$destination is free now';
    final faculty = availability.currentClass?.faculty;
    final facultyText =
        faculty == null || faculty.isEmpty ? '' : ' with $faculty';
    final waitText = availability.nextFreeAt == null
        ? '.'
        : '. Wait until ${availability.nextFreeAt}.';

    final detail = destination.isEmpty
        ? 'Choose your current location and destination to start navigation.'
        : availability.occupied
            ? '${availability.currentClass?.subject ?? 'Class'} is running'
                '$facultyText$waitText'
            : 'Route is ready from your current location.';
    final etaText = remainingSeconds >= 60
        ? '${(remainingSeconds / 60).ceil()} min'
        : '$remainingSeconds sec';

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
          if (pathAvailable) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Route',
                    value: '$totalMeters m',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Remaining',
                    value: '$remainingMeters m',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'ETA',
                    value: etaText,
                  ),
                ),
              ],
            ),
          ],
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
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isNavigating ? onStopNavigation : onStartNavigation,
              icon: Icon(isNavigating ? Icons.stop : Icons.navigation),
              label:
                  Text(isNavigating ? 'Stop Navigation' : 'Start Navigation'),
            ),
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
    final visibleInstructions = _visibleInstructions();

    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: visibleInstructions.map((instruction) {
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

  List<NavigationInstruction> _visibleInstructions() {
    if (instructions.length <= 4) return instructions;

    final selected = <NavigationInstruction>[];

    void add(NavigationInstruction instruction) {
      if (!selected.contains(instruction) && selected.length < 4) {
        selected.add(instruction);
      }
    }

    add(instructions.first);

    for (final instruction in instructions) {
      final text = instruction.text.toLowerCase();
      if (text.contains('stairs')) add(instruction);
    }

    if (instructions.length > 1) {
      add(instructions[instructions.length - 2]);
    }

    add(instructions.last);

    for (final instruction in instructions) {
      add(instruction);
    }

    return selected;
  }

  IconData _iconForInstruction(String text) {
    if (text.contains('left')) return Icons.turn_left;
    if (text.contains('right')) return Icons.turn_right;
    if (text.contains('stairs')) return Icons.stairs;
    if (text.contains('arrived')) return Icons.flag;
    return Icons.straight;
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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

    for (var i = 1; i < scaledPoints.length; i++) {
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
    required this.totalMeters,
  });

  final List<Offset> points;
  final List<NavigationInstruction> instructions;
  final int totalMeters;
}

class NavigationInstruction {
  const NavigationInstruction({
    required this.text,
    required this.point,
  });

  final String text;
  final Offset point;
}

class _MapNode {
  const _MapNode({
    required this.name,
    required this.point,
    required this.floor,
    this.routeOnly = false,
    this.stairGroup,
  });

  final String name;
  final Offset point;
  final int floor;
  final bool routeOnly;
  final String? stairGroup;
}

Map<String, _MapNode> _buildCollegeNodes() {
  final nodes = <String, _MapNode>{};
  const floorCorridorY = {
    0: 0.193,
    1: 0.458,
    2: 0.678,
    3: 0.887,
  };
  const floorTopY = {
    0: 0.135,
    1: 0.402,
    2: 0.633,
    3: 0.846,
  };
  const floorBottomY = {
    0: 0.252,
    1: 0.505,
    2: 0.725,
    3: 0.934,
  };
  const sideTopY = {
    0: 0.174,
    1: 0.440,
    2: 0.662,
    3: 0.872,
  };
  const sideBottomY = {
    0: 0.247,
    1: 0.506,
    2: 0.728,
    3: 0.933,
  };
  const blockX = {
    'E1': [0.198, 0.244, 0.291, 0.337],
    'E2': [0.444, 0.494, 0.544, 0.594],
    'E3': [0.694, 0.742, 0.790, 0.837],
  };
  const sideX = {
    'E1': [0.108, 0.151],
    'E3': [0.872, 0.920],
  };
  const stairX = {
    'left': 0.058,
    'e1e2': 0.390,
    'e2e3': 0.639,
    'right': 0.951,
  };

  void add(
    String name,
    Offset point,
    int floor, {
    bool routeOnly = false,
    String? stairGroup,
  }) {
    nodes[name] = _MapNode(
      name: name,
      point: point,
      floor: floor,
      routeOnly: routeOnly,
      stairGroup: stairGroup,
    );
  }

  add('Main Gate', const Offset(0.036, 0.193), 0);
  add('E1 Block Entrance', const Offset(0.071, 0.193), 0, routeOnly: true);
  add('Lobby', const Offset(0.083, 0.193), 0);

  for (final floor in [0, 1, 2, 3]) {
    final corridorY = floorCorridorY[floor]!;
    final topY = floorTopY[floor]!;
    final bottomY = floorBottomY[floor]!;
    final topSide = sideTopY[floor]!;
    final bottomSide = sideBottomY[floor]!;

    for (final stair in stairX.entries) {
      add(
        'F$floor-${stair.key}-stairs',
        Offset(stair.value, corridorY),
        floor,
        routeOnly: true,
        stairGroup: stair.key,
      );
    }

    for (final block in ['E1', 'E2', 'E3']) {
      final xs = blockX[block]!;
      for (var i = 0; i < xs.length; i++) {
        add(
          'F$floor-$block-C${i + 1}',
          Offset(xs[i], corridorY),
          floor,
          routeOnly: true,
        );
      }
    }

    add('F$floor-E1-side-corridor', Offset(0.132, corridorY), floor,
        routeOnly: true);
    add('F$floor-E3-side-corridor', Offset(0.897, corridorY), floor,
        routeOnly: true);

    for (final block in ['E1', 'E2', 'E3']) {
      final floorPrefix = floor == 0 ? '' : '$floor';
      final xs = blockX[block]!;

      for (var room = 1; room <= 8; room++) {
        final roomSuffix = '$floorPrefix${room.toString().padLeft(2, '0')}';
        final name = '$block-$roomSuffix';
        final column = (room - 1) % 4;
        final y = room <= 4 ? topY : bottomY;

        add(name, Offset(xs[column], y), floor);
      }
    }

    for (final block in ['E1', 'E3']) {
      final floorPrefix = floor == 0 ? '' : '$floor';
      final xs = sideX[block]!;
      final sideRooms = {
        9: Offset(xs[0], topSide),
        10: Offset(xs[1], topSide),
        11: Offset(xs[0], bottomSide),
        12: Offset(xs[1], bottomSide),
      };

      for (final entry in sideRooms.entries) {
        final roomSuffix =
            '$floorPrefix${entry.key.toString().padLeft(2, '0')}';
        add('$block-$roomSuffix', entry.value, floor);
      }
    }
  }

  add('Seminar Hall', const Offset(0.446, 0.136), 0);
  add('Auditorium', const Offset(0.544, 0.136), 0);
  add('HOD Office', const Offset(0.909, 0.846), 3);

  return nodes;
}

List<String> _buildSearchLocations(Map<String, _MapNode> nodes) {
  final locations = nodes.values
      .where((node) => !node.routeOnly || node.stairGroup != null)
      .map((node) => node.name)
      .toList()
    ..sort(_locationSort);

  return locations;
}

Map<String, Map<String, double>> _buildCollegeGraph(Map<String, _MapNode> nodes) {
  final graph = <String, Map<String, double>>{};

  void connect(String a, String b, double meters) {
    graph.putIfAbsent(a, () => {})[b] = meters;
    graph.putIfAbsent(b, () => {})[a] = meters;
  }

  connect('Main Gate', 'E1 Block Entrance', 5);
  connect('E1 Block Entrance', 'Lobby', 5);
  connect('Lobby', 'F0-left-stairs', 5);

  for (final floor in [0, 1, 2, 3]) {
    connect('F$floor-left-stairs', 'F$floor-E1-side-corridor', 5);
    connect('F$floor-E1-side-corridor', 'F$floor-E1-C1', 15);
    connect('F$floor-E1-C1', 'F$floor-E1-C2', 15);
    connect('F$floor-E1-C2', 'F$floor-E1-C3', 15);
    connect('F$floor-E1-C3', 'F$floor-E1-C4', 15);
    connect('F$floor-E1-C4', 'F$floor-e1e2-stairs', 15);

    connect('F$floor-e1e2-stairs', 'F$floor-E2-C1', 15);
    connect('F$floor-E2-C1', 'F$floor-E2-C2', 15);
    connect('F$floor-E2-C2', 'F$floor-E2-C3', 15);
    connect('F$floor-E2-C3', 'F$floor-E2-C4', 15);
    connect('F$floor-E2-C4', 'F$floor-e2e3-stairs', 15);

    connect('F$floor-e2e3-stairs', 'F$floor-E3-C1', 15);
    connect('F$floor-E3-C1', 'F$floor-E3-C2', 15);
    connect('F$floor-E3-C2', 'F$floor-E3-C3', 15);
    connect('F$floor-E3-C3', 'F$floor-E3-C4', 15);
    connect('F$floor-E3-C4', 'F$floor-E3-side-corridor', 15);
    connect('F$floor-E3-side-corridor', 'F$floor-right-stairs', 5);

    for (final block in ['E1', 'E2', 'E3']) {
      final floorPrefix = floor == 0 ? '' : '$floor';
      for (var room = 1; room <= 8; room++) {
        final suffix = '$floorPrefix${room.toString().padLeft(2, '0')}';
        final roomName = '$block-$suffix';
        final corridor = 'F$floor-$block-C${((room - 1) % 4) + 1}';
        if (nodes.containsKey(roomName)) connect(roomName, corridor, 5);
      }
    }

    for (final block in ['E1', 'E3']) {
      final floorPrefix = floor == 0 ? '' : '$floor';
      final corridor =
          block == 'E1' ? 'F$floor-E1-side-corridor' : 'F$floor-E3-side-corridor';
      for (final room in [9, 10, 11, 12]) {
        final suffix = '$floorPrefix${room.toString().padLeft(2, '0')}';
        final roomName = '$block-$suffix';
        if (nodes.containsKey(roomName)) connect(roomName, corridor, 5);
      }
    }
  }

  connect('Seminar Hall', 'F0-E2-C1', 5);
  connect('Seminar Hall', 'F0-E2-C2', 5);
  connect('Auditorium', 'F0-E2-C3', 5);
  connect('Auditorium', 'F0-E2-C4', 5);
  connect('HOD Office', 'E3-310', 2);

  for (final stair in ['left', 'e1e2', 'e2e3', 'right']) {
    connect('F0-$stair-stairs', 'F1-$stair-stairs', 5);
    connect('F1-$stair-stairs', 'F2-$stair-stairs', 5);
    connect('F2-$stair-stairs', 'F3-$stair-stairs', 5);
  }

  return graph;
}

String _displayName(String name) {
  if (!name.startsWith('F')) return name;
  final parts = name.split('-');
  if (parts.length < 2) return name;

  if (name.contains('stairs')) {
    final floor = int.tryParse(parts.first.substring(1)) ?? 0;
    final stairLabel = _stairLabel(parts[1]);
    return '${_floorLabel(floor)} $stairLabel stairs';
  }

  return '${_floorLabel(int.tryParse(parts.first.substring(1)) ?? 0)} corridor';
}

String _stairLabel(String stairGroup) {
  switch (stairGroup) {
    case 'left':
      return 'left';
    case 'e1e2':
      return 'E1-E2';
    case 'e2e3':
      return 'E2-E3';
    case 'right':
      return 'right';
    default:
      return stairGroup;
  }
}

String _floorLabel(int floor) {
  switch (floor) {
    case 0:
      return 'ground floor';
    case 1:
      return 'first floor';
    case 2:
      return 'second floor';
    case 3:
      return 'third floor';
    default:
      return 'floor $floor';
  }
}

int _locationSort(String a, String b) {
  final priority = {
    'Main Gate': 0,
    'E1 Block Entrance': 1,
    'Lobby': 2,
    'Seminar Hall': 3,
    'Auditorium': 4,
    'HOD Office': 5,
  };

  final aPriority = priority[a] ?? 20;
  final bPriority = priority[b] ?? 20;
  if (aPriority != bPriority) return aPriority.compareTo(bPriority);

  return a.compareTo(b);
}
