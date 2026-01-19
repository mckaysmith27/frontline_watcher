class School {
  final String name;
  final String street;
  final String city;
  final String state;
  final String zip;
  final String schoolType;
  final double? latitude;
  final double? longitude;
  /// Straight-line distance (haversine via `Geolocator.distanceBetween`) in miles.
  final double? distanceMiles;

  /// Road distance in miles (if available). Falls back to `distanceMiles`.
  final double? driveDistanceMiles;

  /// Road travel time in minutes (if available).
  final int? driveTimeMinutes;

  /// Display string (derived from `driveTimeMinutes` when available).
  final String? travelTime;

  School({
    required this.name,
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    required this.schoolType,
    this.latitude,
    this.longitude,
    this.distanceMiles,
    this.driveDistanceMiles,
    this.driveTimeMinutes,
    this.travelTime,
  });

  String get fullAddress => '$street, $city, $state $zip';

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      name: json['name'] ?? '',
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zip: json['zip'] ?? '',
      schoolType: json['type'] ?? 'other',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'street': street,
      'city': city,
      'state': state,
      'zip': zip,
      'type': schoolType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (distanceMiles != null) 'distanceMiles': distanceMiles,
      if (driveDistanceMiles != null) 'driveDistanceMiles': driveDistanceMiles,
      if (driveTimeMinutes != null) 'driveTimeMinutes': driveTimeMinutes,
      if (travelTime != null) 'travelTime': travelTime,
    };
  }

  School copyWith({
    String? name,
    String? street,
    String? city,
    String? state,
    String? zip,
    String? schoolType,
    double? latitude,
    double? longitude,
    double? distanceMiles,
    double? driveDistanceMiles,
    int? driveTimeMinutes,
    String? travelTime,
  }) {
    return School(
      name: name ?? this.name,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zip: zip ?? this.zip,
      schoolType: schoolType ?? this.schoolType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      driveDistanceMiles: driveDistanceMiles ?? this.driveDistanceMiles,
      driveTimeMinutes: driveTimeMinutes ?? this.driveTimeMinutes,
      travelTime: travelTime ?? this.travelTime,
    );
  }
}
