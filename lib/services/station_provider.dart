import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/station_repository.dart';
import '../models/station.dart';

/// Provider for the station repository
final stationRepositoryProvider = Provider<StationRepository>((ref) {
  return StationRepository();
});

/// Provider for all stations
final stationsProvider = FutureProvider<List<Station>>((ref) async {
  final repository = ref.watch(stationRepositoryProvider);
  return repository.loadStations();
});

/// Provider for stations filtered and sorted by selected direction
final stationsByDirectionProvider = FutureProvider<List<Station>>((ref) async {
  final repository = ref.watch(stationRepositoryProvider);
  final direction = ref.watch(selectedDirectionProvider);
  
  if (direction == null) return [];
  
  return repository.getStationsByDirection(direction);
});

/// Provider for the selected travel direction
final selectedDirectionProvider = StateProvider<RouteDirection?>((ref) => null);

/// Provider for the selected destination station
final selectedDestinationProvider = StateProvider<Station?>((ref) => null);

/// Provider for the current/boarding station (optional, for future use)
final currentStationProvider = StateProvider<Station?>((ref) => null);

/// Provider for the alert threshold (stations before destination to trigger alert)
/// Default: 2 stations, Range: 1-5
final alertThresholdProvider = StateProvider<int>((ref) => 2);

/// Constants for alert threshold validation
const int minAlertThreshold = 1;
const int maxAlertThreshold = 5;
const int defaultAlertThreshold = 2;
