import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/station.dart';

/// Repository for loading and accessing station data
class StationRepository {
  List<Station>? _stations;

  /// Loads stations from the JSON asset file
  Future<List<Station>> loadStations() async {
    if (_stations != null) return _stations!;

    final jsonString = await rootBundle.loadString('assets/stations.json');
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;
    final stationsList = jsonData['stations'] as List;

    _stations = stationsList
        .map((stationJson) => Station.fromJson(stationJson as Map<String, dynamic>))
        .toList();

    return _stations!;
  }

  /// Gets stations sorted by direction order
  Future<List<Station>> getStationsByDirection(RouteDirection direction) async {
    final stations = await loadStations();
    final sorted = List<Station>.from(stations);
    
    sorted.sort((a, b) {
      final orderA = a.getOrder(direction);
      final orderB = b.getOrder(direction);
      return orderA.compareTo(orderB);
    });

    return sorted;
  }

  /// Gets a station by its ID
  Future<Station?> getStationById(String id) async {
    final stations = await loadStations();
    try {
      return stations.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Gets stations that come after the given station in the specified direction
  Future<List<Station>> getStationsAfter(
    Station currentStation,
    RouteDirection direction,
  ) async {
    final stations = await getStationsByDirection(direction);
    final currentOrder = currentStation.getOrder(direction);
    
    return stations.where((s) => s.getOrder(direction) > currentOrder).toList();
  }
}
