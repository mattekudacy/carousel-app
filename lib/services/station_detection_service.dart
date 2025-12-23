import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import '../data/station_repository.dart';
import 'location_tracking_service.dart';
import 'station_provider.dart';

/// Represents the user's position relative to stations
enum StationProximity {
  atStation,      // Within station radius
  betweenStations, // Between two stations
  beforeRoute,    // Before the first station
  afterRoute,     // After the last station (past destination)
  unknown,        // Cannot determine
}

/// Result of station detection
class StationDetectionResult {
  final StationProximity proximity;
  final Station? currentStation;      // Station user is at (if atStation)
  final Station? previousStation;     // Last passed station
  final Station? nextStation;         // Next upcoming station
  final double? distanceToNext;       // Distance to next station in meters
  final double? distanceToCurrent;    // Distance to current/nearest station
  final int stationsToDestination;    // Number of stations until destination
  final Station? destination;         // The destination station

  const StationDetectionResult({
    required this.proximity,
    this.currentStation,
    this.previousStation,
    this.nextStation,
    this.distanceToNext,
    this.distanceToCurrent,
    this.stationsToDestination = -1,
    this.destination,
  });

  bool get isAtStation => proximity == StationProximity.atStation;
  bool get hasReachedDestination => 
      isAtStation && currentStation?.id == destination?.id;

  @override
  String toString() {
    return 'StationDetectionResult(proximity: $proximity, '
        'current: ${currentStation?.name}, '
        'next: ${nextStation?.name}, '
        'stationsToDestination: $stationsToDestination)';
  }
}

/// Service for detecting the nearest station based on GPS location
class StationDetectionService {
  final StationRepository _repository;
  
  // Station detection radius in meters
  static const double stationRadius = 100.0;

  StationDetectionService(this._repository);

  /// Detect the current station or segment based on location and direction
  Future<StationDetectionResult> detectStation({
    required double latitude,
    required double longitude,
    required RouteDirection direction,
    required Station destination,
  }) async {
    final stations = await _repository.getStationsByDirection(direction);
    
    if (stations.isEmpty) {
      return const StationDetectionResult(
        proximity: StationProximity.unknown,
      );
    }

    // Calculate distance to all stations
    final stationDistances = <Station, double>{};
    for (final station in stations) {
      final distance = Station.calculateDistance(
        latitude, longitude,
        station.lat, station.lng,
      );
      stationDistances[station] = distance;
    }

    // Find the nearest station
    Station? nearestStation;
    double nearestDistance = double.infinity;
    
    for (final entry in stationDistances.entries) {
      if (entry.value < nearestDistance) {
        nearestDistance = entry.value;
        nearestStation = entry.key;
      }
    }

    if (nearestStation == null) {
      return const StationDetectionResult(
        proximity: StationProximity.unknown,
      );
    }

    // Check if user is at a station (within radius)
    if (nearestDistance <= stationRadius) {
      final stationsToDestination = _calculateStationsToDestination(
        nearestStation, destination, direction, stations,
      );

      // Find next station after current
      final currentIndex = stations.indexOf(nearestStation);
      final nextStation = currentIndex < stations.length - 1
          ? stations[currentIndex + 1]
          : null;

      return StationDetectionResult(
        proximity: StationProximity.atStation,
        currentStation: nearestStation,
        previousStation: currentIndex > 0 ? stations[currentIndex - 1] : null,
        nextStation: nextStation,
        distanceToCurrent: nearestDistance,
        distanceToNext: nextStation != null 
            ? stationDistances[nextStation] 
            : null,
        stationsToDestination: stationsToDestination,
        destination: destination,
      );
    }

    // User is between stations - find the segment
    return _findSegment(
      latitude: latitude,
      longitude: longitude,
      stations: stations,
      stationDistances: stationDistances,
      direction: direction,
      destination: destination,
    );
  }

  /// Find which segment (between two stations) the user is in
  StationDetectionResult _findSegment({
    required double latitude,
    required double longitude,
    required List<Station> stations,
    required Map<Station, double> stationDistances,
    required RouteDirection direction,
    required Station destination,
  }) {
    // Sort stations by distance
    final sortedByDistance = stationDistances.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Get two nearest stations
    if (sortedByDistance.length < 2) {
      final nearest = sortedByDistance.first.key;
      return StationDetectionResult(
        proximity: StationProximity.unknown,
        currentStation: nearest,
        distanceToCurrent: sortedByDistance.first.value,
        destination: destination,
      );
    }

    final nearest1 = sortedByDistance[0].key;
    final nearest2 = sortedByDistance[1].key;

    // Determine which is previous and which is next based on route order
    final order1 = nearest1.getOrder(direction);
    final order2 = nearest2.getOrder(direction);

    Station previousStation;
    Station nextStation;

    if (order1 < order2) {
      previousStation = nearest1;
      nextStation = nearest2;
    } else {
      previousStation = nearest2;
      nextStation = nearest1;
    }

    // Check if before first station or after last
    final firstStation = stations.first;
    final lastStation = stations.last;

    StationProximity proximity;
    
    if (previousStation.id == firstStation.id && 
        stationDistances[firstStation]! > stationDistances[nextStation]!) {
      // Closer to second station, might be before route
      proximity = StationProximity.betweenStations;
    } else if (nextStation.id == lastStation.id &&
        stationDistances[lastStation]! < stationDistances[previousStation]!) {
      // Past the last station
      proximity = StationProximity.afterRoute;
    } else {
      proximity = StationProximity.betweenStations;
    }

    final stationsToDestination = _calculateStationsToDestination(
      nextStation, destination, direction, stations,
    ) + 1; // +1 because we haven't reached nextStation yet

    return StationDetectionResult(
      proximity: proximity,
      previousStation: previousStation,
      nextStation: nextStation,
      distanceToNext: stationDistances[nextStation],
      distanceToCurrent: stationDistances[nearest1],
      stationsToDestination: stationsToDestination,
      destination: destination,
    );
  }

  /// Calculate how many stations until destination
  int _calculateStationsToDestination(
    Station fromStation,
    Station destination,
    RouteDirection direction,
    List<Station> stations,
  ) {
    final fromOrder = fromStation.getOrder(direction);
    final destOrder = destination.getOrder(direction);

    if (fromOrder >= destOrder) {
      return 0; // Already at or past destination
    }

    return destOrder - fromOrder;
  }

  /// Get all stations with their distances from current location
  Future<List<StationWithDistance>> getStationsWithDistances({
    required double latitude,
    required double longitude,
    required RouteDirection direction,
  }) async {
    final stations = await _repository.getStationsByDirection(direction);
    
    return stations.map((station) {
      final distance = Station.calculateDistance(
        latitude, longitude,
        station.lat, station.lng,
      );
      return StationWithDistance(station: station, distance: distance);
    }).toList();
  }
}

/// Helper class to hold station with distance
class StationWithDistance {
  final Station station;
  final double distance; // meters

  const StationWithDistance({
    required this.station,
    required this.distance,
  });

  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}m';
    }
    return '${(distance / 1000).toStringAsFixed(1)}km';
  }
}

// ============ PROVIDERS ============

/// Provider for station detection service
final stationDetectionServiceProvider = Provider<StationDetectionService>((ref) {
  final repository = ref.watch(stationRepositoryProvider);
  return StationDetectionService(repository);
});

/// Provider for current station detection result
/// Updates whenever location changes
final stationDetectionProvider = Provider<StationDetectionResult?>((ref) {
  final trackingState = ref.watch(locationTrackingNotifierProvider);
  final direction = ref.watch(selectedDirectionProvider);
  final destination = ref.watch(selectedDestinationProvider);
  
  if (!trackingState.isTracking || 
      trackingState.lastUpdate == null ||
      direction == null ||
      destination == null) {
    return null;
  }

  // This is a synchronous provider, so we need to use a FutureProvider or
  // cache the result. For now, return null and use the async version.
  return null;
});

/// Async provider for station detection
final stationDetectionAsyncProvider = FutureProvider<StationDetectionResult?>((ref) async {
  final trackingState = ref.watch(locationTrackingNotifierProvider);
  final direction = ref.watch(selectedDirectionProvider);
  final destination = ref.watch(selectedDestinationProvider);
  final detectionService = ref.watch(stationDetectionServiceProvider);
  
  if (!trackingState.isTracking || 
      trackingState.lastUpdate == null ||
      direction == null ||
      destination == null) {
    return null;
  }

  final location = trackingState.lastUpdate!;
  
  return detectionService.detectStation(
    latitude: location.latitude,
    longitude: location.longitude,
    direction: direction,
    destination: destination,
  );
});

/// Provider for stations with distances from current location
final stationsWithDistancesProvider = FutureProvider<List<StationWithDistance>>((ref) async {
  final trackingState = ref.watch(locationTrackingNotifierProvider);
  final direction = ref.watch(selectedDirectionProvider);
  final detectionService = ref.watch(stationDetectionServiceProvider);
  
  if (!trackingState.isTracking || 
      trackingState.lastUpdate == null ||
      direction == null) {
    return [];
  }

  final location = trackingState.lastUpdate!;
  
  return detectionService.getStationsWithDistances(
    latitude: location.latitude,
    longitude: location.longitude,
    direction: direction,
  );
});
