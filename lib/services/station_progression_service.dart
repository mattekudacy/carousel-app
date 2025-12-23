import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import '../data/station_repository.dart';
import 'location_tracking_service.dart';
import 'station_provider.dart';
import 'direction_inference_service.dart';

/// Status of a station in the journey
enum StationStatus {
  upcoming,    // Station is ahead
  approaching, // Within approach radius (e.g., 300m)
  atStation,   // Within station radius (e.g., 100m)
  passed,      // Station has been passed
  skipped,     // Station was skipped (GPS drift)
}

/// Record of a station visit/pass
class StationPassRecord {
  final Station station;
  final StationStatus status;
  final DateTime? enteredAt;
  final DateTime? exitedAt;
  final double? minDistance; // Closest distance achieved

  const StationPassRecord({
    required this.station,
    required this.status,
    this.enteredAt,
    this.exitedAt,
    this.minDistance,
  });

  StationPassRecord copyWith({
    Station? station,
    StationStatus? status,
    DateTime? enteredAt,
    DateTime? exitedAt,
    double? minDistance,
  }) {
    return StationPassRecord(
      station: station ?? this.station,
      status: status ?? this.status,
      enteredAt: enteredAt ?? this.enteredAt,
      exitedAt: exitedAt ?? this.exitedAt,
      minDistance: minDistance ?? this.minDistance,
    );
  }

  bool get wasVisited => status == StationStatus.passed || status == StationStatus.atStation;

  @override
  String toString() => 'StationPassRecord(${station.name}, $status)';
}

/// State of the station progression tracking
class StationProgressionState {
  final List<StationPassRecord> stationRecords;
  final Station? currentStation;
  final Station? nextStation;
  final Station? destination;
  final int passedCount;
  final int remainingCount;
  final bool hasArrived;

  const StationProgressionState({
    this.stationRecords = const [],
    this.currentStation,
    this.nextStation,
    this.destination,
    this.passedCount = 0,
    this.remainingCount = 0,
    this.hasArrived = false,
  });

  StationProgressionState copyWith({
    List<StationPassRecord>? stationRecords,
    Station? currentStation,
    Station? nextStation,
    Station? destination,
    int? passedCount,
    int? remainingCount,
    bool? hasArrived,
  }) {
    return StationProgressionState(
      stationRecords: stationRecords ?? this.stationRecords,
      currentStation: currentStation ?? this.currentStation,
      nextStation: nextStation ?? this.nextStation,
      destination: destination ?? this.destination,
      passedCount: passedCount ?? this.passedCount,
      remainingCount: remainingCount ?? this.remainingCount,
      hasArrived: hasArrived ?? this.hasArrived,
    );
  }

  /// Get stations by status
  List<StationPassRecord> getByStatus(StationStatus status) {
    return stationRecords.where((r) => r.status == status).toList();
  }

  /// Get passed stations in order
  List<Station> get passedStations {
    return stationRecords
        .where((r) => r.status == StationStatus.passed)
        .map((r) => r.station)
        .toList();
  }
}

/// Service for tracking station progression
class StationProgressionService {
  final StationRepository _repository;

  // Configuration
  static const double stationRadius = 100.0; // meters - at station
  static const double approachRadius = 300.0; // meters - approaching
  static const double exitRadius = 150.0; // meters - buffer to prevent flapping
  static const int maxMissedStations = 2; // Max stations that can be skipped

  StationProgressionService(this._repository);

  /// Initialize progression state for a journey
  Future<StationProgressionState> initializeJourney({
    required RouteDirection direction,
    required Station destination,
  }) async {
    final stations = await _repository.getStationsByDirection(direction);
    final destIndex = stations.indexWhere((s) => s.id == destination.id);

    if (destIndex == -1) {
      return const StationProgressionState();
    }

    // Create records for stations up to and including destination
    final journeyStations = stations.sublist(0, destIndex + 1);
    final records = journeyStations.map((station) {
      return StationPassRecord(
        station: station,
        status: station.id == destination.id 
            ? StationStatus.upcoming 
            : StationStatus.upcoming,
      );
    }).toList();

    return StationProgressionState(
      stationRecords: records,
      nextStation: records.isNotEmpty ? records.first.station : null,
      destination: destination,
      passedCount: 0,
      remainingCount: records.length,
      hasArrived: false,
    );
  }

  /// Update progression based on current location
  StationProgressionState updateProgression({
    required StationProgressionState currentState,
    required double latitude,
    required double longitude,
    required RouteDirection direction,
  }) {
    if (currentState.stationRecords.isEmpty || currentState.hasArrived) {
      return currentState;
    }

    final records = List<StationPassRecord>.from(currentState.stationRecords);
    Station? currentStation;
    Station? nextStation;
    int passedCount = 0;
    bool hasArrived = false;

    // Calculate distances to all stations
    final distances = <String, double>{};
    for (final record in records) {
      distances[record.station.id] = Station.calculateDistance(
        latitude, longitude,
        record.station.lat, record.station.lng,
      );
    }

    // Find current position in route
    int? currentIndex;
    for (int i = 0; i < records.length; i++) {
      final distance = distances[records[i].station.id]!;
      if (distance <= stationRadius) {
        currentIndex = i;
        currentStation = records[i].station;
        break;
      }
    }

    // Process each station
    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      final distance = distances[record.station.id]!;
      final isDestination = record.station.id == currentState.destination?.id;

      // Determine new status
      StationStatus newStatus = record.status;
      DateTime? enteredAt = record.enteredAt;
      DateTime? exitedAt = record.exitedAt;
      double? minDistance = record.minDistance;

      // Update minimum distance
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
      }

      if (currentIndex != null && i < currentIndex) {
        // Station is behind current position - mark as passed
        if (record.status != StationStatus.passed && 
            record.status != StationStatus.skipped) {
          // Check if we actually visited it (got close enough)
          if (record.minDistance != null && record.minDistance! <= exitRadius) {
            newStatus = StationStatus.passed;
            exitedAt ??= DateTime.now();
          } else {
            // Skipped due to GPS drift or express route
            newStatus = StationStatus.skipped;
          }
        }
      } else if (distance <= stationRadius) {
        // At station
        newStatus = StationStatus.atStation;
        enteredAt ??= DateTime.now();

        if (isDestination) {
          hasArrived = true;
        }
      } else if (distance <= approachRadius) {
        // Approaching station
        if (record.status == StationStatus.upcoming) {
          newStatus = StationStatus.approaching;
        } else if (record.status == StationStatus.atStation) {
          // Just left station
          newStatus = StationStatus.passed;
          exitedAt = DateTime.now();
        }
      } else {
        // Far from station
        if (record.status == StationStatus.atStation ||
            record.status == StationStatus.approaching) {
          // Check if we've moved past (based on route order)
          if (_hasPassedStation(records, i, latitude, longitude, direction)) {
            newStatus = StationStatus.passed;
            exitedAt ??= DateTime.now();
          }
        }
      }

      // Update record if changed
      if (newStatus != record.status ||
          enteredAt != record.enteredAt ||
          exitedAt != record.exitedAt ||
          minDistance != record.minDistance) {
        records[i] = record.copyWith(
          status: newStatus,
          enteredAt: enteredAt,
          exitedAt: exitedAt,
          minDistance: minDistance,
        );
      }

      // Count passed stations
      if (newStatus == StationStatus.passed || newStatus == StationStatus.skipped) {
        passedCount++;
      }
    }

    // Find next upcoming station
    nextStation = null;
    for (final record in records) {
      if (record.status == StationStatus.upcoming ||
          record.status == StationStatus.approaching) {
        nextStation = record.station;
        break;
      }
    }

    // Handle skipped stations due to GPS drift
    _handleSkippedStations(records, currentIndex, direction);

    return currentState.copyWith(
      stationRecords: records,
      currentStation: currentStation,
      nextStation: nextStation,
      passedCount: passedCount,
      remainingCount: records.length - passedCount,
      hasArrived: hasArrived,
    );
  }

  /// Check if user has passed a station based on route progression
  bool _hasPassedStation(
    List<StationPassRecord> records,
    int stationIndex,
    double latitude,
    double longitude,
    RouteDirection direction,
  ) {
    // Check if any station after this one is closer or at station
    for (int i = stationIndex + 1; i < records.length; i++) {
      final nextRecord = records[i];
      final nextDistance = Station.calculateDistance(
        latitude, longitude,
        nextRecord.station.lat, nextRecord.station.lng,
      );

      // If we're closer to a later station, we've passed the earlier one
      if (nextDistance <= approachRadius) {
        return true;
      }
    }

    return false;
  }

  /// Handle skipped stations - mark them appropriately
  void _handleSkippedStations(
    List<StationPassRecord> records,
    int? currentIndex,
    RouteDirection direction,
  ) {
    if (currentIndex == null) return;

    // Check for gaps in passed stations
    int lastPassedIndex = -1;
    for (int i = 0; i < currentIndex; i++) {
      final record = records[i];
      if (record.status == StationStatus.passed) {
        // Check for gap
        if (lastPassedIndex >= 0) {
          final gap = i - lastPassedIndex - 1;
          if (gap > 0 && gap <= maxMissedStations) {
            // Mark intermediate stations as skipped
            for (int j = lastPassedIndex + 1; j < i; j++) {
              if (records[j].status != StationStatus.passed) {
                records[j] = records[j].copyWith(status: StationStatus.skipped);
              }
            }
          }
        }
        lastPassedIndex = i;
      }
    }

    // Also mark stations before current as passed/skipped
    for (int i = 0; i < currentIndex; i++) {
      final record = records[i];
      if (record.status == StationStatus.upcoming ||
          record.status == StationStatus.approaching) {
        // Determine if passed or skipped based on minimum distance
        if (record.minDistance != null && record.minDistance! <= exitRadius) {
          records[i] = record.copyWith(
            status: StationStatus.passed,
            exitedAt: DateTime.now(),
          );
        } else {
          records[i] = record.copyWith(status: StationStatus.skipped);
        }
      }
    }
  }
}

// ============ PROVIDERS ============

/// Provider for station progression service
final stationProgressionServiceProvider = Provider<StationProgressionService>((ref) {
  final repository = ref.watch(stationRepositoryProvider);
  return StationProgressionService(repository);
});

/// State notifier for managing station progression
class StationProgressionNotifier extends StateNotifier<StationProgressionState> {
  final StationProgressionService _service;
  final Ref _ref;
  bool _initialized = false;

  StationProgressionNotifier(this._service, this._ref) 
      : super(const StationProgressionState());

  /// Initialize for a new journey
  Future<void> initializeJourney() async {
    final direction = _ref.read(effectiveDirectionProvider) ?? 
                      _ref.read(selectedDirectionProvider);
    final destination = _ref.read(selectedDestinationProvider);

    if (direction == null || destination == null) {
      debugPrint('Cannot initialize journey: missing direction or destination');
      return;
    }

    state = await _service.initializeJourney(
      direction: direction,
      destination: destination,
    );
    _initialized = true;
  }

  /// Update with new location
  void updateLocation(LocationUpdate location) {
    if (!_initialized) return;

    final direction = _ref.read(effectiveDirectionProvider) ?? 
                      _ref.read(selectedDirectionProvider);
    if (direction == null) return;

    state = _service.updateProgression(
      currentState: state,
      latitude: location.latitude,
      longitude: location.longitude,
      direction: direction,
    );
  }

  /// Reset for new journey
  void reset() {
    _initialized = false;
    state = const StationProgressionState();
  }

  /// Mark a station as manually visited (for testing/correction)
  void markStationPassed(String stationId) {
    final records = List<StationPassRecord>.from(state.stationRecords);
    final index = records.indexWhere((r) => r.station.id == stationId);
    
    if (index >= 0) {
      records[index] = records[index].copyWith(
        status: StationStatus.passed,
        exitedAt: DateTime.now(),
      );

      // Also mark all previous stations as passed
      for (int i = 0; i < index; i++) {
        if (records[i].status != StationStatus.passed) {
          records[i] = records[i].copyWith(
            status: StationStatus.skipped,
          );
        }
      }

      state = state.copyWith(stationRecords: records);
    }
  }
}

/// Provider for station progression state
final stationProgressionProvider = 
    StateNotifierProvider<StationProgressionNotifier, StationProgressionState>((ref) {
  final service = ref.watch(stationProgressionServiceProvider);
  return StationProgressionNotifier(service, ref);
});

/// Provider for stations remaining to destination
final stationsRemainingProvider = Provider<int>((ref) {
  final progression = ref.watch(stationProgressionProvider);
  return progression.remainingCount;
});

/// Provider for passed stations count
final stationsPassedProvider = Provider<int>((ref) {
  final progression = ref.watch(stationProgressionProvider);
  return progression.passedCount;
});

/// Provider to check if arrived at destination
final hasArrivedProvider = Provider<bool>((ref) {
  final progression = ref.watch(stationProgressionProvider);
  return progression.hasArrived;
});

/// Callback provider for progression updates from location tracking
final progressionUpdateCallbackProvider = StateProvider<void Function(LocationUpdate)?>(
  (ref) => null,
);
