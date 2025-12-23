import 'dart:collection';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import '../data/station_repository.dart';
import 'location_tracking_service.dart';
import 'station_provider.dart';

/// Result of direction inference
class DirectionInferenceResult {
  final RouteDirection? inferredDirection;
  final double confidence; // 0.0 to 1.0
  final double bearing; // Degrees from north (0-360)
  final String reasoning;
  final bool shouldOverride;

  const DirectionInferenceResult({
    this.inferredDirection,
    this.confidence = 0.0,
    this.bearing = 0.0,
    this.reasoning = '',
    this.shouldOverride = false,
  });

  bool get isConfident => confidence >= 0.7;
  bool get isHighConfidence => confidence >= 0.85;

  @override
  String toString() {
    return 'DirectionInference(direction: $inferredDirection, '
        'confidence: ${(confidence * 100).toStringAsFixed(0)}%, '
        'bearing: ${bearing.toStringAsFixed(0)}°)';
  }
}

/// Service for inferring travel direction from GPS movement
class DirectionInferenceService {
  final StationRepository _repository;
  
  // Configuration
  static const int _minSamplesRequired = 3;
  static const int _maxSampleHistory = 10;
  static const double _minDistanceForInference = 50.0; // meters
  static const double _overrideThreshold = 0.85;

  // Location history for inference
  final Queue<LocationUpdate> _locationHistory = Queue<LocationUpdate>();

  DirectionInferenceService(this._repository);

  /// Add a new location sample
  void addLocationSample(LocationUpdate location) {
    _locationHistory.addLast(location);
    while (_locationHistory.length > _maxSampleHistory) {
      _locationHistory.removeFirst();
    }
  }

  /// Clear location history
  void clearHistory() {
    _locationHistory.clear();
  }

  /// Infer direction based on accumulated GPS samples
  Future<DirectionInferenceResult> inferDirection() async {
    if (_locationHistory.length < _minSamplesRequired) {
      return DirectionInferenceResult(
        reasoning: 'Need more samples (${_locationHistory.length}/$_minSamplesRequired)',
      );
    }

    // Get first and last points
    final firstPoint = _locationHistory.first;
    final lastPoint = _locationHistory.last;

    // Calculate total distance traveled
    final totalDistance = Station.calculateDistance(
      firstPoint.latitude, firstPoint.longitude,
      lastPoint.latitude, lastPoint.longitude,
    );

    if (totalDistance < _minDistanceForInference) {
      return DirectionInferenceResult(
        reasoning: 'Not enough movement (${totalDistance.toStringAsFixed(0)}m < ${_minDistanceForInference}m)',
      );
    }

    // Calculate bearing (direction of movement)
    final bearing = _calculateBearing(
      firstPoint.latitude, firstPoint.longitude,
      lastPoint.latitude, lastPoint.longitude,
    );

    // Get route bearing from stations
    final stations = await _repository.loadStations();
    if (stations.isEmpty) {
      return DirectionInferenceResult(
        bearing: bearing,
        reasoning: 'No stations available',
      );
    }

    // Calculate the general route bearing (from first to last station in northbound order)
    final northboundStations = List<Station>.from(stations)
      ..sort((a, b) => a.northboundOrder.compareTo(b.northboundOrder));
    
    final routeStart = northboundStations.first;
    final routeEnd = northboundStations.last;
    
    final northboundBearing = _calculateBearing(
      routeStart.lat, routeStart.lng,
      routeEnd.lat, routeEnd.lng,
    );
    
    final southboundBearing = (northboundBearing + 180) % 360;

    // Compare user's bearing to route bearings
    final northboundDiff = _bearingDifference(bearing, northboundBearing);
    final southboundDiff = _bearingDifference(bearing, southboundBearing);

    // Determine direction and confidence
    RouteDirection inferredDirection;
    double confidence;
    String reasoning;

    if (northboundDiff < southboundDiff) {
      inferredDirection = RouteDirection.northbound;
      confidence = _calculateConfidence(northboundDiff);
      reasoning = 'Moving ${bearing.toStringAsFixed(0)}° (route north: ${northboundBearing.toStringAsFixed(0)}°, diff: ${northboundDiff.toStringAsFixed(0)}°)';
    } else {
      inferredDirection = RouteDirection.southbound;
      confidence = _calculateConfidence(southboundDiff);
      reasoning = 'Moving ${bearing.toStringAsFixed(0)}° (route south: ${southboundBearing.toStringAsFixed(0)}°, diff: ${southboundDiff.toStringAsFixed(0)}°)';
    }

    // Additional confidence boost if moving along route consistently
    confidence = _adjustConfidenceByConsistency(confidence);

    return DirectionInferenceResult(
      inferredDirection: inferredDirection,
      confidence: confidence,
      bearing: bearing,
      reasoning: reasoning,
      shouldOverride: confidence >= _overrideThreshold,
    );
  }

  /// Infer direction based on proximity to stations
  Future<DirectionInferenceResult> inferDirectionFromStationProximity(
    double latitude,
    double longitude,
  ) async {
    final stations = await _repository.loadStations();
    if (stations.length < 2) {
      return const DirectionInferenceResult(
        reasoning: 'Not enough stations',
      );
    }

    // Find the two nearest stations
    final stationDistances = <Station, double>{};
    for (final station in stations) {
      final distance = Station.calculateDistance(
        latitude, longitude,
        station.lat, station.lng,
      );
      stationDistances[station] = distance;
    }

    final sortedStations = stationDistances.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final nearest1 = sortedStations[0].key;
    final nearest2 = sortedStations[1].key;

    // If we have location history, check which station we're moving toward
    if (_locationHistory.length >= 2) {
      final prevLocation = _locationHistory.elementAt(_locationHistory.length - 2);
      final currLocation = _locationHistory.last;

      final prevDistTo1 = Station.calculateDistance(
        prevLocation.latitude, prevLocation.longitude,
        nearest1.lat, nearest1.lng,
      );
      final currDistTo1 = Station.calculateDistance(
        currLocation.latitude, currLocation.longitude,
        nearest1.lat, nearest1.lng,
      );

      final prevDistTo2 = Station.calculateDistance(
        prevLocation.latitude, prevLocation.longitude,
        nearest2.lat, nearest2.lng,
      );
      final currDistTo2 = Station.calculateDistance(
        currLocation.latitude, currLocation.longitude,
        nearest2.lat, nearest2.lng,
      );

      // Determine which station we're approaching
      Station approachingStation;
      if (currDistTo1 < prevDistTo1 && currDistTo2 > prevDistTo2) {
        approachingStation = nearest1;
      } else if (currDistTo2 < prevDistTo2 && currDistTo1 > prevDistTo1) {
        approachingStation = nearest2;
      } else {
        // Can't determine confidently
        return const DirectionInferenceResult(
          reasoning: 'Movement unclear between stations',
          confidence: 0.3,
        );
      }

      // Determine direction based on station order
      final order1 = nearest1.northboundOrder;
      final order2 = nearest2.northboundOrder;
      final approachingOrder = approachingStation.northboundOrder;

      RouteDirection direction;
      if (approachingOrder > min(order1, order2)) {
        direction = RouteDirection.northbound;
      } else {
        direction = RouteDirection.southbound;
      }

      return DirectionInferenceResult(
        inferredDirection: direction,
        confidence: 0.75,
        reasoning: 'Approaching ${approachingStation.name} (order: $approachingOrder)',
        shouldOverride: false,
      );
    }

    return const DirectionInferenceResult(
      reasoning: 'Need more location history',
    );
  }

  /// Calculate bearing between two points (in degrees, 0-360)
  double _calculateBearing(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    final dLng = _toRadians(lng2 - lng1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final y = sin(dLng) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) - 
              sin(lat1Rad) * cos(lat2Rad) * cos(dLng);

    final bearing = atan2(y, x);
    return (_toDegrees(bearing) + 360) % 360;
  }

  /// Calculate the smallest difference between two bearings
  double _bearingDifference(double bearing1, double bearing2) {
    double diff = (bearing1 - bearing2).abs();
    if (diff > 180) {
      diff = 360 - diff;
    }
    return diff;
  }

  /// Calculate confidence based on bearing difference
  double _calculateConfidence(double bearingDiff) {
    // Perfect alignment = 100% confidence
    // 45° off = 50% confidence
    // 90° off = 0% confidence
    if (bearingDiff >= 90) return 0.0;
    return 1.0 - (bearingDiff / 90);
  }

  /// Adjust confidence based on movement consistency
  double _adjustConfidenceByConsistency(double baseConfidence) {
    if (_locationHistory.length < 3) return baseConfidence;

    // Check if movement has been consistent
    int consistentMoves = 0;
    double? lastBearing;

    final locationList = _locationHistory.toList();
    for (int i = 1; i < locationList.length; i++) {
      final bearing = _calculateBearing(
        locationList[i - 1].latitude, locationList[i - 1].longitude,
        locationList[i].latitude, locationList[i].longitude,
      );

      if (lastBearing != null) {
        final diff = _bearingDifference(bearing, lastBearing);
        if (diff < 45) {
          consistentMoves++;
        }
      }
      lastBearing = bearing;
    }

    final consistencyRatio = consistentMoves / (locationList.length - 2);
    
    // Boost confidence if movement is consistent
    return (baseConfidence + (consistencyRatio * 0.2)).clamp(0.0, 1.0);
  }

  double _toRadians(double degrees) => degrees * pi / 180;
  double _toDegrees(double radians) => radians * 180 / pi;
}

// ============ PROVIDERS ============

/// Provider for direction inference service
final directionInferenceServiceProvider = Provider<DirectionInferenceService>((ref) {
  final repository = ref.watch(stationRepositoryProvider);
  return DirectionInferenceService(repository);
});

/// Provider for inferred direction result
final inferredDirectionProvider = StateProvider<DirectionInferenceResult?>((ref) => null);

/// Provider that manages direction with auto-inference
class DirectionManager extends StateNotifier<RouteDirection?> {
  final DirectionInferenceService _inferenceService;
  final Ref _ref;
  bool _manualOverride = false;

  DirectionManager(this._inferenceService, this._ref) : super(null);

  /// Set direction manually (disables auto-inference override)
  void setDirection(RouteDirection direction) {
    _manualOverride = true;
    state = direction;
  }

  /// Update with new location and potentially infer direction
  Future<void> updateWithLocation(LocationUpdate location) async {
    _inferenceService.addLocationSample(location);

    // Always compute inference for display purposes
    final inference = await _inferenceService.inferDirection();
    _ref.read(inferredDirectionProvider.notifier).state = inference;

    // Only override if user hasn't manually set direction or if very confident
    if (!_manualOverride && inference.shouldOverride && inference.inferredDirection != null) {
      state = inference.inferredDirection;
    }
  }

  /// Allow auto-inference to override again
  void enableAutoInference() {
    _manualOverride = false;
  }

  /// Clear history and reset
  void reset() {
    _inferenceService.clearHistory();
    _manualOverride = false;
    state = null;
  }
}

/// Provider for direction manager
final directionManagerProvider = StateNotifierProvider<DirectionManager, RouteDirection?>((ref) {
  final inferenceService = ref.watch(directionInferenceServiceProvider);
  return DirectionManager(inferenceService, ref);
});

/// Provider that combines manual selection with inference
final effectiveDirectionProvider = Provider<RouteDirection?>((ref) {
  // First check the direction manager (handles inference + manual)
  final managedDirection = ref.watch(directionManagerProvider);
  if (managedDirection != null) return managedDirection;

  // Fall back to manual selection
  return ref.watch(selectedDirectionProvider);
});
