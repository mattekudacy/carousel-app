import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import 'location_tracking_service.dart';
import 'direction_inference_service.dart';
import 'station_provider.dart';

/// Types of edge cases / warnings
enum EdgeCaseType {
  gpsLost,
  gpsWeakSignal,
  lowSpeed,
  stationary,
  wrongDirection,
  offRoute,
  noStationsNearby,
}

/// Severity level for edge case warnings
enum WarningSeverity {
  info,     // Just informational
  warning,  // User should be aware
  critical, // Requires attention
}

/// Represents an active edge case warning
class EdgeCaseWarning {
  final EdgeCaseType type;
  final WarningSeverity severity;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isDismissible;

  const EdgeCaseWarning({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isDismissible = true,
  });

  @override
  String toString() => 'EdgeCaseWarning($type: $message)';
}

/// State for edge case monitoring
class EdgeCaseState {
  final List<EdgeCaseWarning> activeWarnings;
  final DateTime? lastGpsUpdate;
  final Duration? gpsSilenceDuration;
  final double? lastKnownSpeed;
  final bool isOffRoute;
  final bool isWrongDirection;
  final int consecutiveSlowUpdates;

  const EdgeCaseState({
    this.activeWarnings = const [],
    this.lastGpsUpdate,
    this.gpsSilenceDuration,
    this.lastKnownSpeed,
    this.isOffRoute = false,
    this.isWrongDirection = false,
    this.consecutiveSlowUpdates = 0,
  });

  EdgeCaseState copyWith({
    List<EdgeCaseWarning>? activeWarnings,
    DateTime? lastGpsUpdate,
    Duration? gpsSilenceDuration,
    double? lastKnownSpeed,
    bool? isOffRoute,
    bool? isWrongDirection,
    int? consecutiveSlowUpdates,
  }) {
    return EdgeCaseState(
      activeWarnings: activeWarnings ?? this.activeWarnings,
      lastGpsUpdate: lastGpsUpdate ?? this.lastGpsUpdate,
      gpsSilenceDuration: gpsSilenceDuration ?? this.gpsSilenceDuration,
      lastKnownSpeed: lastKnownSpeed ?? this.lastKnownSpeed,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      isWrongDirection: isWrongDirection ?? this.isWrongDirection,
      consecutiveSlowUpdates: consecutiveSlowUpdates ?? this.consecutiveSlowUpdates,
    );
  }

  /// Check if there are any critical warnings
  bool get hasCriticalWarning => 
      activeWarnings.any((w) => w.severity == WarningSeverity.critical);

  /// Check if there are any warnings at all
  bool get hasWarnings => activeWarnings.isNotEmpty;

  /// Get the most severe warning
  EdgeCaseWarning? get mostSevereWarning {
    if (activeWarnings.isEmpty) return null;
    return activeWarnings.reduce((a, b) {
      if (a.severity == WarningSeverity.critical) return a;
      if (b.severity == WarningSeverity.critical) return b;
      if (a.severity == WarningSeverity.warning) return a;
      if (b.severity == WarningSeverity.warning) return b;
      return a;
    });
  }
}

/// Service for monitoring and handling edge cases
class EdgeCaseHandler extends StateNotifier<EdgeCaseState> {
  final Ref _ref;
  Timer? _gpsMonitorTimer;
  DateTime? _lastLocationTime;

  // Configuration thresholds
  static const Duration gpsLostThreshold = Duration(seconds: 30);
  static const Duration gpsWeakThreshold = Duration(seconds: 15);
  static const double lowSpeedThreshold = 2.0; // km/h
  static const double stationaryThreshold = 0.5; // km/h
  static const double offRouteDistanceThreshold = 500.0; // meters
  static const int slowUpdatesBeforeWarning = 5;

  EdgeCaseHandler(this._ref) : super(const EdgeCaseState()) {
    _startGpsMonitor();
  }

  void _startGpsMonitor() {
    _gpsMonitorTimer?.cancel();
    _gpsMonitorTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkGpsStatus();
    });
  }

  /// Process a new location update
  void processLocationUpdate(LocationUpdate location) {
    _lastLocationTime = DateTime.now();
    final warnings = <EdgeCaseWarning>[];

    // Clear GPS-related warnings since we got an update
    _removeWarningType(EdgeCaseType.gpsLost);
    _removeWarningType(EdgeCaseType.gpsWeakSignal);

    // Check speed
    final speedKmh = location.speedKmh;
    int slowUpdates = state.consecutiveSlowUpdates;

    if (speedKmh < stationaryThreshold) {
      slowUpdates++;
      if (slowUpdates >= slowUpdatesBeforeWarning) {
        warnings.add(EdgeCaseWarning(
          type: EdgeCaseType.stationary,
          severity: WarningSeverity.info,
          title: 'Vehicle Stationary',
          message: 'You appear to be stopped. ETA updates paused.',
          timestamp: DateTime.now(),
        ));
      }
    } else if (speedKmh < lowSpeedThreshold) {
      slowUpdates++;
      if (slowUpdates >= slowUpdatesBeforeWarning) {
        warnings.add(EdgeCaseWarning(
          type: EdgeCaseType.lowSpeed,
          severity: WarningSeverity.info,
          title: 'Heavy Traffic',
          message: 'Moving slowly (${speedKmh.toStringAsFixed(1)} km/h). ETA may be longer.',
          timestamp: DateTime.now(),
        ));
      }
    } else {
      slowUpdates = 0;
      _removeWarningType(EdgeCaseType.stationary);
      _removeWarningType(EdgeCaseType.lowSpeed);
    }

    // Update state
    state = state.copyWith(
      lastGpsUpdate: DateTime.now(),
      gpsSilenceDuration: Duration.zero,
      lastKnownSpeed: speedKmh,
      consecutiveSlowUpdates: slowUpdates,
      activeWarnings: _mergeWarnings(state.activeWarnings, warnings),
    );
  }

  /// Check direction against expected
  void checkDirection(DirectionInferenceResult inference) {
    final selectedDirection = _ref.read(selectedDirectionProvider);
    final effectiveDirection = _ref.read(effectiveDirectionProvider);
    final currentDirection = effectiveDirection ?? selectedDirection;

    if (currentDirection == null || inference.inferredDirection == null) {
      return;
    }

    // If moving in wrong direction with high confidence
    if (inference.inferredDirection != currentDirection && inference.isConfident) {
      if (!state.isWrongDirection) {
        final warning = EdgeCaseWarning(
          type: EdgeCaseType.wrongDirection,
          severity: WarningSeverity.warning,
          title: 'Wrong Direction?',
          message: 'You appear to be heading ${inference.inferredDirection?.displayName ?? "unknown"}. '
              'Expected: ${currentDirection.displayName}.',
          timestamp: DateTime.now(),
        );
        _addWarning(warning);
        state = state.copyWith(isWrongDirection: true);
      }
    } else if (inference.inferredDirection == currentDirection) {
      _removeWarningType(EdgeCaseType.wrongDirection);
      state = state.copyWith(isWrongDirection: false);
    }
  }

  /// Check if user is off route
  void checkOffRoute(double latitude, double longitude, List<Station> stations) {
    if (stations.isEmpty) return;

    // Find minimum distance to any station
    double minDistance = double.infinity;
    for (final station in stations) {
      final distance = Station.calculateDistance(
        latitude, longitude,
        station.lat, station.lng,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    if (minDistance > offRouteDistanceThreshold) {
      if (!state.isOffRoute) {
        final warning = EdgeCaseWarning(
          type: EdgeCaseType.offRoute,
          severity: WarningSeverity.warning,
          title: 'Off Route',
          message: 'You are ${(minDistance / 1000).toStringAsFixed(1)} km from the nearest station.',
          timestamp: DateTime.now(),
        );
        _addWarning(warning);
        state = state.copyWith(isOffRoute: true);
      }
    } else {
      _removeWarningType(EdgeCaseType.offRoute);
      state = state.copyWith(isOffRoute: false);
    }
  }

  /// Check GPS status based on time since last update
  void _checkGpsStatus() {
    if (_lastLocationTime == null) return;

    final silence = DateTime.now().difference(_lastLocationTime!);

    if (silence > gpsLostThreshold) {
      _removeWarningType(EdgeCaseType.gpsWeakSignal);
      if (!_hasWarningType(EdgeCaseType.gpsLost)) {
        final warning = EdgeCaseWarning(
          type: EdgeCaseType.gpsLost,
          severity: WarningSeverity.critical,
          title: 'GPS Signal Lost',
          message: 'No location updates for ${silence.inSeconds}s. Check GPS settings.',
          timestamp: DateTime.now(),
          isDismissible: false,
        );
        _addWarning(warning);
      }
      state = state.copyWith(gpsSilenceDuration: silence);
    } else if (silence > gpsWeakThreshold) {
      if (!_hasWarningType(EdgeCaseType.gpsWeakSignal)) {
        final warning = EdgeCaseWarning(
          type: EdgeCaseType.gpsWeakSignal,
          severity: WarningSeverity.warning,
          title: 'Weak GPS Signal',
          message: 'Location updates are delayed. Move to an open area.',
          timestamp: DateTime.now(),
        );
        _addWarning(warning);
      }
      state = state.copyWith(gpsSilenceDuration: silence);
    }
  }

  /// Add a warning to the active list
  void _addWarning(EdgeCaseWarning warning) {
    final warnings = List<EdgeCaseWarning>.from(state.activeWarnings);
    // Remove existing warning of same type
    warnings.removeWhere((w) => w.type == warning.type);
    warnings.add(warning);
    state = state.copyWith(activeWarnings: warnings);
  }

  /// Remove warnings of a specific type
  void _removeWarningType(EdgeCaseType type) {
    final warnings = List<EdgeCaseWarning>.from(state.activeWarnings);
    warnings.removeWhere((w) => w.type == type);
    if (warnings.length != state.activeWarnings.length) {
      state = state.copyWith(activeWarnings: warnings);
    }
  }

  /// Check if a warning type already exists
  bool _hasWarningType(EdgeCaseType type) {
    return state.activeWarnings.any((w) => w.type == type);
  }

  /// Merge new warnings with existing, avoiding duplicates
  List<EdgeCaseWarning> _mergeWarnings(
    List<EdgeCaseWarning> existing,
    List<EdgeCaseWarning> newWarnings,
  ) {
    final result = List<EdgeCaseWarning>.from(existing);
    for (final warning in newWarnings) {
      result.removeWhere((w) => w.type == warning.type);
      result.add(warning);
    }
    return result;
  }

  /// Dismiss a specific warning
  void dismissWarning(EdgeCaseType type) {
    final warnings = List<EdgeCaseWarning>.from(state.activeWarnings);
    final warning = warnings.firstWhere(
      (w) => w.type == type,
      orElse: () => throw StateError('Warning not found'),
    );
    if (warning.isDismissible) {
      warnings.removeWhere((w) => w.type == type);
      state = state.copyWith(activeWarnings: warnings);
    }
  }

  /// Clear all warnings
  void clearAllWarnings() {
    state = state.copyWith(activeWarnings: []);
  }

  /// Reset handler state
  void reset() {
    _lastLocationTime = null;
    state = const EdgeCaseState();
  }

  @override
  void dispose() {
    _gpsMonitorTimer?.cancel();
    super.dispose();
  }
}

// ============ PROVIDERS ============

/// Provider for edge case handler
final edgeCaseHandlerProvider = StateNotifierProvider<EdgeCaseHandler, EdgeCaseState>((ref) {
  return EdgeCaseHandler(ref);
});

/// Provider for active warnings
final activeWarningsProvider = Provider<List<EdgeCaseWarning>>((ref) {
  return ref.watch(edgeCaseHandlerProvider).activeWarnings;
});

/// Provider for checking if there are critical warnings
final hasCriticalWarningProvider = Provider<bool>((ref) {
  return ref.watch(edgeCaseHandlerProvider).hasCriticalWarning;
});

/// Provider for the most severe warning
final mostSevereWarningProvider = Provider<EdgeCaseWarning?>((ref) {
  return ref.watch(edgeCaseHandlerProvider).mostSevereWarning;
});

/// Provider for GPS status message
final gpsStatusMessageProvider = Provider<String?>((ref) {
  final state = ref.watch(edgeCaseHandlerProvider);
  
  if (state.gpsSilenceDuration != null && 
      state.gpsSilenceDuration! > EdgeCaseHandler.gpsWeakThreshold) {
    return 'GPS signal weak - ${state.gpsSilenceDuration!.inSeconds}s since last update';
  }
  return null;
});

/// Provider for speed status message
final speedStatusMessageProvider = Provider<String?>((ref) {
  final state = ref.watch(edgeCaseHandlerProvider);
  
  if (state.lastKnownSpeed != null) {
    if (state.lastKnownSpeed! < EdgeCaseHandler.stationaryThreshold) {
      return 'Vehicle stopped';
    } else if (state.lastKnownSpeed! < EdgeCaseHandler.lowSpeedThreshold) {
      return 'Heavy traffic (${state.lastKnownSpeed!.toStringAsFixed(1)} km/h)';
    }
  }
  return null;
});

/// Callback provider for edge case monitoring from location updates
final edgeCaseUpdateCallbackProvider = StateProvider<void Function(LocationUpdate)?>(
  (ref) => null,
);
