import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/school.dart';

class SchoolService {
  static const String _jsonPath = 'assets/alpine_school_district_schools_ls_of_dicts.json';
  List<School>? _schools;

  Future<List<School>> loadSchools() async {
    if (_schools != null) return _schools!;

    try {
      String jsonString;
      
      // Try loading from assets first
      try {
        jsonString = await rootBundle.loadString(_jsonPath);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error loading schools JSON from assets: $e');
        }
        rethrow;
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      
      _schools = jsonList
          .map((json) => School.fromJson(json))
          .where((school) => school.city.toLowerCase() != 'other')
          .toList();

      return _schools!;
    } catch (e) {
      print('Error loading schools: $e');
      return [];
    }
  }

  Future<void> geocodeSchools() async {
    if (_schools == null) await loadSchools();

    for (var school in _schools!) {
      if (school.latitude == null || school.longitude == null) {
        try {
          final address = school.fullAddress;
          final locations = await locationFromAddress(address);
          if (locations.isNotEmpty) {
            final location = locations.first;
            final index = _schools!.indexOf(school);
            _schools![index] = school.copyWith(
              latitude: location.latitude,
              longitude: location.longitude,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error geocoding ${school.name}: $e');
          }
        }
      }
    }
  }

  Future<void> calculateDistancesAndTimes(
    double userLat,
    double userLng,
  ) async {
    if (_schools == null) await loadSchools();

    // Calculate straight-line distance first
    for (var i = 0; i < _schools!.length; i++) {
      final school = _schools![i];
      if (school.latitude != null && school.longitude != null) {
        final distanceMeters = Geolocator.distanceBetween(
          userLat,
          userLng,
          school.latitude!,
          school.longitude!,
        );
        final distanceMiles = distanceMeters * 0.000621371;

        _schools![i] = school.copyWith(distanceMiles: distanceMiles);
      }
    }

    // Calculate travel time using Google Distance Matrix API
    // Note: You'll need to add your API key and handle rate limiting
    // For now, we'll estimate based on distance (assuming 30 mph average)
    for (var i = 0; i < _schools!.length; i++) {
      final school = _schools![i];
      if (school.distanceMiles != null) {
        final estimatedMinutes = (school.distanceMiles! / 30.0 * 60).round();
        _schools![i] = school.copyWith(
          travelTime: estimatedMinutes > 60
              ? '${(estimatedMinutes / 60).toStringAsFixed(1)} hrs'
              : '$estimatedMinutes min',
        );
      }
    }
  }

  List<School> getSchoolsWithinRadius(
    double centerLat,
    double centerLng,
    double radiusMiles,
  ) {
    if (_schools == null) return [];

    return _schools!.where((school) {
      if (school.latitude == null || school.longitude == null) return false;
      if (school.distanceMiles == null) {
        final distanceMeters = Geolocator.distanceBetween(
          centerLat,
          centerLng,
          school.latitude!,
          school.longitude!,
        );
        final distanceMiles = distanceMeters * 0.000621371;
        return distanceMiles <= radiusMiles;
      }
      return school.distanceMiles! <= radiusMiles;
    }).toList();
  }

  List<School> get schools => _schools ?? [];
}
