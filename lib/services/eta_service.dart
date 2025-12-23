import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import 'location_tracking_service.dart';
import 'station_progression_service.dart';
import 'station_provider.dart';
import 'direction_inference_service.dart';

/// ETA calculation result
class ETAResult {
  final double distanceToNextStation; // meters
  final double distanceToDestination; // meters
  final Duration? etaToNextStation;
  final Duration? etaToDestination;
  final double currentSpeed; // m/s
  final double averageSpeed; // m/s
  final Station? nextStation;
  final Station? destination;
  final bool isStationary;
  final String status;

  const ETAResult({
    this.distanceToNextStation = 0,
    this.distanceToDestination = 0,
    this.etaToNextStation,
    this.etaToDestination,
    this.currentSpeed = 0,
    this.averageSpeed = 0,
    this.nextStation,
    this.destination,
    this.isStationary = true,
    this.status = 'Calculating...',
  });

  /// Format distance for display
  String get distanceToNextFormatted => _formatDistance(distanceToNextStation);
  String get distanceToDestFormatted => _formatDistance(distanceToDestination);

  /// Format ETA for display
  String get etaToNextFormatted => _formatETA(etaToNextStation);
  String get etaToDestFormatted => _formatETA(etaToDestination);

  /// Speed in km/h
  double get currentSpeedKmh => currentSpeed * 3.6;
  double get averageSpeedKmh => averageSpeed * 3.6;

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  String _formatETA(Duration? duration) {
    if (duration == null) return '--';
    
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 1) {
      return '< 1 min';
    } else if (totalMinutes < 60) {
      return '$totalMinutes min';
    } else {
      final hours = duration.inHours;
      final mins = totalMinutes % 60;
      if (mins == 0) {
        return '$hours hr';
      }
      return '$hours hr $mins min';
    }
  }

  /// Estimated arrival time
  DateTime? get arrivalTimeToNext {
    if (etaToNextStation == null) return null;
    return DateTime.now().add(etaToNextStation!);
  }

  DateTime? get arrivalTimeToDest {
    if (etaToDestination == null) return null;
    return DateTime.now().add(etaToDestination!);
  }

  @override
  String toString() {
    return 'ETAResult(next: $distanceToNextFormatted in $etaToNextFormatted, '
           'dest: $distanceToDestFormatted in $etaToDestFormatted)';
  }
}

/// Service for calculating ETA
class ETAService {
  // Configuration
  static const double _minSpeedThreshold = 0.5; // m/s (~1.8 km/h) - walking speed
  static const int _speedHistorySize = 10;
  static const double _routeSpeedFactor = 1.2; // Account for stops/slowdowns

  // Speed history for better averaging
  final List<double> _speedHistory = [];
  double _rollingAverageSpeed = 0;

  ETAService();

  /// Add speed sample to history
  void addSpeedSample(double speed) {
    if (speed >= 0) {
      _speedHistory.add(speed);
      while (_speedHistory.length > _speedHistorySize) {
        _speedHistory.removeAt(0);
      }
      _calculateRollingAverage();
    }
  }

  void _calculateRollingAverage() {
    if (_speedHistory.isEmpty) {
      _rollingAverageSpeed = 0;
      return;
    }

    // Use weighted average - recent samples have more weight
    double weightedSum = 0;
    double weightTotal = 0;
    int weight = 1;

    for (final speed in _speedHistory) {
      weightedSum += speed * weight;
      weightTotal += weight;
      weight++;
    }

    _rollingAverageSpeed = weightedSum / weightTotal;
  }

  /// Clear speed history
  void clearHistory() {
    _speedHistory.clear();
    _rollingAverageSpeed = 0;
  }

  /// Calculate ETA based on current location and progression state
  Future<ETAResult> calculateETA({
    required double latitude,
    required double longitude,
    required double currentSpeed,
    required StationProgressionState progressionState,
    RouteDirection? direction,
  }) async {
    // Add current speed to history
    addSpeedSample(currentSpeed);

    final destination = progressionState.destination;
    if (destination == null) {
      return const ETAResult(status: 'No destination set');
    }

    // Check if arrived
    if (progressionState.hasArrived) {
      return ETAResult(
        destination: destination,
        distanceToDestination: 0,
        status: 'Arrived!',
        isStationary: true,
      );
    }

    // Find next station from progression
    Station? nextStation = progressionState.nextStation;
    
    // Calculate distances
    double distanceToNext = 0;
    double distanceToDest = 0;

    if (nextStation != null) {
      distanceToNext = Station.calculateDistance(
        latitude, longitude,
        nextStation.lat, nextStation.lng,
      );
    }

    // Calculate total distance to destination
    distanceToDest = await _calculateRouteDistance(
      latitude, longitude,
      progressionState,
      direction,
    );

    // Determine effective speed for ETA
    final effectiveSpeed = _getEffectiveSpeed(currentSpeed);
    final isStationary = effectiveSpeed < _minSpeedThreshold;

    // Calculate ETAs
    Duration? etaToNext;
    Duration? etaToDest;

    if (!isStationary && distanceToNext > 0) {
      final secondsToNext = distanceToNext / effectiveSpeed;
      etaToNext = Duration(seconds: secondsToNext.round());
    }

    if (!isStationary && distanceToDest > 0) {
      // Apply route factor for destination ETA (accounts for stops)
      final adjustedSpeed = effectiveSpeed / _routeSpeedFactor;
      final secondsToDest = distanceToDest / adjustedSpeed;
      etaToDest = Duration(seconds: secondsToDest.round());
    }

    // Determine status message
    String status;
    if (isStationary) {
      if (_speedHistory.length < 3) {
        status = 'Gathering speed data...';
      } else {
        status = 'Vehicle stopped';
      }
    } else if (effectiveSpeed < 2.0) {
      status = 'Slow traffic';
    } else if (effectiveSpeed > 15.0) {
      status = 'Good traffic flow';
    } else {
      status = 'Normal traffic';
    }

    return ETAResult(
      distanceToNextStation: distanceToNext,
      distanceToDestination: distanceToDest,
      etaToNextStation: etaToNext,
      etaToDestination: etaToDest,
      currentSpeed: currentSpeed,
      averageSpeed: _rollingAverageSpeed,
      nextStation: nextStation,
      destination: destination,
      isStationary: isStationary,
      status: status,
    );
  }

  /// Calculate route distance through remaining stations
  Future<double> _calculateRouteDistance(
    double latitude,
    double longitude,
    StationProgressionState progressionState,
    RouteDirection? direction,
  ) async {
    // Get upcoming stations from progression
    final upcomingRecords = progressionState.stationRecords.where((r) => 
      r.status == StationStatus.upcoming || 
      r.status == StationStatus.approaching
    ).toList();

    if (upcomingRecords.isEmpty) {
      // Direct distance to destination
      final dest = progressionState.destination;
      if (dest != null) {
        return Station.calculateDistance(
          latitude, longitude,
          dest.lat, dest.lng,
        );
      }
      return 0;
    }

    // Calculate distance to first upcoming station
    double totalDistance = Station.calculateDistance(
      latitude, longitude,
      upcomingRecords.first.station.lat,
      upcomingRecords.first.station.lng,
    );

    // Add distances between remaining stations
    for (int i = 0; i < upcomingRecords.length - 1; i++) {
      final current = upcomingRecords[i].station;
      final next = upcomingRecords[i + 1].station;
      totalDistance += Station.calculateDistance(
        current.lat, current.lng,
        next.lat, next.lng,
      );
    }

    return totalDistance;
  }

  /// Get effective speed for ETA calculation
  double _getEffectiveSpeed(double currentSpeed) {
    // If we have enough history, use rolling average
    if (_speedHistory.length >= 3 && _rollingAverageSpeed > _minSpeedThreshold) {
      // Blend current and average for responsiveness
      return (currentSpeed * 0.3 + _rollingAverageSpeed * 0.7);
    }

    // If current speed is valid, use it
    if (currentSpeed > _minSpeedThreshold) {
      return currentSpeed;
    }

    // If stationary but have historical average, could use default
    // but better to show "calculating" state
    return 0;
  }

  /// Get average speed from history
  double get averageSpeed => _rollingAverageSpeed;
}

// ============ PROVIDERS ============

/// Provider for ETA service
final etaServiceProvider = Provider<ETAService>((ref) {
  return ETAService();
});

/// Provider for current ETA result
final etaResultProvider = StateProvider<ETAResult>((ref) => const ETAResult());

/// Provider that computes ETA from location updates
final etaComputationProvider = Provider<void Function(LocationUpdate)>((ref) {
  final etaService = ref.read(etaServiceProvider);
  
  return (LocationUpdate location) async {
    final progressionState = ref.read(stationProgressionProvider);
    final direction = ref.read(effectiveDirectionProvider) ?? 
                      ref.read(selectedDirectionProvider);

    final result = await etaService.calculateETA(
      latitude: location.latitude,
      longitude: location.longitude,
      currentSpeed: location.smoothedSpeed,
      progressionState: progressionState,
      direction: direction,
    );

    ref.read(etaResultProvider.notifier).state = result;
  };
});

/// Callback provider for ETA updates from location tracking
final etaUpdateCallbackProvider = StateProvider<void Function(LocationUpdate)?>(
  (ref) => null,
);
