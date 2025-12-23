import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Enum representing the current location permission status
enum LocationPermissionStatus {
  granted,
  deniedOnce,
  deniedForever,
  serviceDisabled,
  unknown,
}

/// Service for handling location permissions and GPS access
class LocationService {
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current permission status
  Future<LocationPermissionStatus> checkPermissionStatus() async {
    // First check if location services are enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    // Check permission status
    final permission = await Geolocator.checkPermission();
    return _mapPermissionToStatus(permission);
  }

  /// Request location permissions (foreground first, then background)
  Future<LocationPermissionStatus> requestPermissions() async {
    // Check if location services are enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Try to open location settings
      await Geolocator.openLocationSettings();
      return LocationPermissionStatus.serviceDisabled;
    }

    // Check current permission
    LocationPermission permission = await Geolocator.checkPermission();

    // Request permission if not granted
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionStatus.deniedOnce;
      }
    }

    // Check if permanently denied
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }

    // If we have whileInUse, we should also request always (background)
    if (permission == LocationPermission.whileInUse) {
      // On Android, we need to request background location separately
      // This will show the "Allow all the time" option
      // Note: This may require the user to go to settings on some devices
      return LocationPermissionStatus.granted;
    }

    if (permission == LocationPermission.always) {
      return LocationPermissionStatus.granted;
    }

    return LocationPermissionStatus.unknown;
  }

  /// Open app settings for manual permission grant
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    final status = await checkPermissionStatus();
    if (status != LocationPermissionStatus.granted) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // meters
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get position stream for continuous tracking
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  LocationPermissionStatus _mapPermissionToStatus(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.denied:
        return LocationPermissionStatus.deniedOnce;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.unknown;
    }
  }
}

/// Provider for the location service
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Provider for current permission status
final locationPermissionStatusProvider = FutureProvider<LocationPermissionStatus>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.checkPermissionStatus();
});

/// Provider for current position (one-time fetch)
final currentPositionProvider = FutureProvider<Position?>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.getCurrentPosition();
});

/// State notifier for managing location permission requests
class LocationPermissionNotifier extends StateNotifier<LocationPermissionStatus> {
  final LocationService _locationService;

  LocationPermissionNotifier(this._locationService) : super(LocationPermissionStatus.unknown) {
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    state = await _locationService.checkPermissionStatus();
  }

  Future<void> requestPermissions() async {
    state = await _locationService.requestPermissions();
  }

  Future<void> refreshStatus() async {
    state = await _locationService.checkPermissionStatus();
  }

  Future<void> openSettings() async {
    if (state == LocationPermissionStatus.deniedForever) {
      await _locationService.openAppSettings();
    } else if (state == LocationPermissionStatus.serviceDisabled) {
      await _locationService.openLocationSettings();
    }
  }
}

/// Provider for location permission state management
final locationPermissionNotifierProvider =
    StateNotifierProvider<LocationPermissionNotifier, LocationPermissionStatus>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return LocationPermissionNotifier(locationService);
});
