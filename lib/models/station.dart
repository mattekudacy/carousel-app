import 'dart:math';

/// Represents a single EDSA Carousel station
class Station {
  final String id;
  final String name;
  final String fullName;
  final double lat;
  final double lng;
  final int northboundOrder;
  final int southboundOrder;
  final bool isTerminal;
  final List<String> landmarks;

  const Station({
    required this.id,
    required this.name,
    required this.fullName,
    required this.lat,
    required this.lng,
    required this.northboundOrder,
    required this.southboundOrder,
    required this.isTerminal,
    required this.landmarks,
  });

  /// Creates a Station from JSON data
  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      name: json['name'] as String,
      fullName: json['fullName'] as String,
      lat: (json['latitude'] as num).toDouble(),
      lng: (json['longitude'] as num).toDouble(),
      northboundOrder: json['northboundOrder'] as int,
      southboundOrder: json['southboundOrder'] as int,
      isTerminal: json['isTerminal'] as bool,
      landmarks: List<String>.from(json['landmarks'] as List),
    );
  }

  /// Converts Station to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fullName': fullName,
      'latitude': lat,
      'longitude': lng,
      'northboundOrder': northboundOrder,
      'southboundOrder': southboundOrder,
      'isTerminal': isTerminal,
      'landmarks': landmarks,
    };
  }

  /// Gets the order based on direction
  int getOrder(RouteDirection direction) {
    return direction == RouteDirection.northbound
        ? northboundOrder
        : southboundOrder;
  }

  /// Calculates the distance in meters to another station using Haversine formula
  double distanceTo(Station other) {
    return calculateDistance(lat, lng, other.lat, other.lng);
  }

  /// Calculates the distance in meters from given coordinates using Haversine formula
  double distanceFromCoordinates(double latitude, double longitude) {
    return calculateDistance(lat, lng, latitude, longitude);
  }

  /// Haversine formula to calculate distance between two points on Earth
  /// Returns distance in meters
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Station && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Station(id: $id, name: $name, lat: $lat, lng: $lng)';
  }
}

/// Direction of travel along the EDSA Carousel route
enum RouteDirection {
  northbound, // PITX to Monumento (going north)
  southbound, // Monumento to PITX (going south)
}

extension RouteDirectionExtension on RouteDirection {
  String get displayName {
    switch (this) {
      case RouteDirection.northbound:
        return 'Northbound';
      case RouteDirection.southbound:
        return 'Southbound';
    }
  }

  String get description {
    switch (this) {
      case RouteDirection.northbound:
        return 'PITX → Monumento';
      case RouteDirection.southbound:
        return 'Monumento → PITX';
    }
  }
}
