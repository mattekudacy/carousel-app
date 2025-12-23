import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'station_progression_service.dart';
import 'eta_service.dart';
import 'edge_case_handler.dart';

/// Represents a location update with smoothed speed
class LocationUpdate {
  final double latitude;
  final double longitude;
  final double rawSpeed; // meters per second
  final double smoothedSpeed; // meters per second (rolling average)
  final double accuracy;
  final DateTime timestamp;

  const LocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.rawSpeed,
    required this.smoothedSpeed,
    required this.accuracy,
    required this.timestamp,
  });

  /// Speed in km/h
  double get speedKmh => smoothedSpeed * 3.6;

  /// Raw speed in km/h
  double get rawSpeedKmh => rawSpeed * 3.6;

  @override
  String toString() {
    return 'LocationUpdate(lat: $latitude, lng: $longitude, speed: ${speedKmh.toStringAsFixed(1)} km/h)';
  }
}

/// Service for continuous GPS tracking with smoothed speed
class LocationTrackingService {
  // Configuration
  static const int _speedSampleSize = 5; // Number of samples for rolling average
  static const Duration _locationInterval = Duration(seconds: 3);
  static const double _distanceFilter = 5.0; // meters

  // State
  final Queue<double> _speedSamples = Queue<double>();
  StreamSubscription<Position>? _positionSubscription;
  final _locationController = StreamController<LocationUpdate>.broadcast();
  
  Position? _lastPosition;
  bool _isTracking = false;

  /// Stream of location updates
  Stream<LocationUpdate> get locationStream => _locationController.stream;

  /// Whether tracking is currently active
  bool get isTracking => _isTracking;

  /// Start tracking location
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    // Check permissions first
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    _isTracking = true;
    _speedSamples.clear();

    // Configure location settings for Android
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _distanceFilter.toInt(),
      intervalDuration: _locationInterval,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'Tracking your location for station alerts',
        notificationTitle: 'EDSA Carousel Tracker',
        enableWakeLock: true,
      ),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _handlePositionUpdate,
      onError: (error) {
        // Handle location stream errors silently
        debugPrint('Location stream error: $error');
      },
    );

    // Get initial position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _handlePositionUpdate(position);
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }

    return true;
  }

  /// Stop tracking location
  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _speedSamples.clear();
    _lastPosition = null;
  }

  /// Handle incoming position updates
  void _handlePositionUpdate(Position position) {
    double rawSpeed = position.speed;

    // If speed is negative or invalid, calculate from distance/time
    if (rawSpeed < 0 && _lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      final timeDiff = position.timestamp.difference(_lastPosition!.timestamp);
      if (timeDiff.inMilliseconds > 0) {
        rawSpeed = distance / (timeDiff.inMilliseconds / 1000);
      } else {
        rawSpeed = 0;
      }
    }

    // Ensure non-negative speed
    rawSpeed = rawSpeed.clamp(0, double.infinity);

    // Add to rolling average
    _speedSamples.addLast(rawSpeed);
    while (_speedSamples.length > _speedSampleSize) {
      _speedSamples.removeFirst();
    }

    // Calculate smoothed speed
    final smoothedSpeed = _calculateSmoothedSpeed();

    // Create location update
    final update = LocationUpdate(
      latitude: position.latitude,
      longitude: position.longitude,
      rawSpeed: rawSpeed,
      smoothedSpeed: smoothedSpeed,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
    );

    // Emit update
    _locationController.add(update);

    // Store for next calculation
    _lastPosition = position;
  }

  /// Calculate rolling average of speed
  double _calculateSmoothedSpeed() {
    if (_speedSamples.isEmpty) return 0;

    // Use weighted average - more recent samples have higher weight
    double weightedSum = 0;
    double weightTotal = 0;
    int weight = 1;

    for (final speed in _speedSamples) {
      weightedSum += speed * weight;
      weightTotal += weight;
      weight++;
    }

    return weightedSum / weightTotal;
  }

  /// Get the last known location update
  LocationUpdate? get lastLocation {
    if (_lastPosition == null) return null;

    return LocationUpdate(
      latitude: _lastPosition!.latitude,
      longitude: _lastPosition!.longitude,
      rawSpeed: _lastPosition!.speed.clamp(0, double.infinity),
      smoothedSpeed: _calculateSmoothedSpeed(),
      accuracy: _lastPosition!.accuracy,
      timestamp: _lastPosition!.timestamp,
    );
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _locationController.close();
  }
}

/// Provider for the location tracking service
final locationTrackingServiceProvider = Provider<LocationTrackingService>((ref) {
  final service = LocationTrackingService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for tracking state
final isTrackingProvider = StateProvider<bool>((ref) => false);

/// Provider for the live location stream
final locationStreamProvider = StreamProvider<LocationUpdate>((ref) {
  final trackingService = ref.watch(locationTrackingServiceProvider);
  return trackingService.locationStream;
});

/// Provider for the latest location update
final latestLocationProvider = StateProvider<LocationUpdate?>((ref) => null);

/// State notifier for managing location tracking
class LocationTrackingNotifier extends StateNotifier<LocationTrackingState> {
  final LocationTrackingService _trackingService;
  final Ref _ref;
  StreamSubscription<LocationUpdate>? _subscription;

  LocationTrackingNotifier(this._trackingService, this._ref)
      : super(const LocationTrackingState());

  Future<bool> startTracking() async {
    if (state.isTracking) return true;

    final started = await _trackingService.startTracking();
    if (!started) {
      state = state.copyWith(
        error: 'Failed to start tracking. Check permissions.',
      );
      return false;
    }

    _subscription = _trackingService.locationStream.listen(
      (update) {
        state = state.copyWith(
          isTracking: true,
          lastUpdate: update,
          error: null,
        );
        
        // Feed location update to direction inference
        _ref.read(directionInferenceCallbackProvider)?.call(update);
        
        // Feed location update to station progression
        _ref.read(progressionUpdateCallbackProvider)?.call(update);
        
        // Feed location update to ETA computation
        _ref.read(etaUpdateCallbackProvider)?.call(update);
        
        // Feed location update to edge case handler
        _ref.read(edgeCaseUpdateCallbackProvider)?.call(update);
      },
      onError: (error) {
        state = state.copyWith(error: error.toString());
      },
    );

    state = state.copyWith(isTracking: true, error: null);
    return true;
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _trackingService.stopTracking();
    state = state.copyWith(isTracking: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// State class for location tracking
class LocationTrackingState {
  final bool isTracking;
  final LocationUpdate? lastUpdate;
  final String? error;

  const LocationTrackingState({
    this.isTracking = false,
    this.lastUpdate,
    this.error,
  });

  LocationTrackingState copyWith({
    bool? isTracking,
    LocationUpdate? lastUpdate,
    String? error,
  }) {
    return LocationTrackingState(
      isTracking: isTracking ?? this.isTracking,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      error: error,
    );
  }
}

/// Provider for location tracking state management
final locationTrackingNotifierProvider =
    StateNotifierProvider<LocationTrackingNotifier, LocationTrackingState>((ref) {
  final trackingService = ref.watch(locationTrackingServiceProvider);
  return LocationTrackingNotifier(trackingService, ref);
});

/// Callback provider for direction inference integration
/// This allows the direction inference service to receive location updates
final directionInferenceCallbackProvider = StateProvider<void Function(LocationUpdate)?>(
  (ref) => null,
);
