import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/school.dart';

class SchoolService {
  static const String _jsonPath = 'assets/alpine_school_district_schools_ls_of_dicts.json';
  List<School>? _schools;

  static const _metersToMiles = 0.000621371;

  String _formatTravelTime(int minutes) {
    if (minutes >= 60) {
      return '${(minutes / 60).toStringAsFixed(1)} hrs';
    }
    return '$minutes min';
  }

  /// Uses OSRM (OpenStreetMap routing) to get *road* distance/time.
  ///
  /// Returns a list of results aligned to `destinations` order, or null on failure.
  Future<List<({double distanceMiles, int durationMinutes})>?> _fetchOsrmTable({
    required double originLat,
    required double originLng,
    required List<({double lat, double lng})> destinations,
  }) async {
    if (destinations.isEmpty) return const [];

    // OSRM uses lon,lat order.
    final coordParts = <String>['$originLng,$originLat'];
    for (final d in destinations) {
      coordParts.add('${d.lng},${d.lat}');
    }
    final coords = coordParts.join(';');

    final destIdxs = List.generate(destinations.length, (i) => '${i + 1}').join(';');
    final uri = Uri.https(
      'router.project-osrm.org',
      '/table/v1/driving/$coords',
      {
        'sources': '0',
        'destinations': destIdxs,
        'annotations': 'duration,distance',
      },
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;

    final decoded = json.decode(res.body);
    if (decoded is! Map) return null;
    if (decoded['code'] != 'Ok') return null;

    final durations = decoded['durations'];
    final distances = decoded['distances'];
    if (durations is! List || distances is! List) return null;
    if (durations.isEmpty || distances.isEmpty) return null;

    final rowDur = durations.first;
    final rowDist = distances.first;
    if (rowDur is! List || rowDist is! List) return null;

    final out = <({double distanceMiles, int durationMinutes})>[];
    for (int i = 0; i < destinations.length; i++) {
      final dSec = (i < rowDur.length) ? rowDur[i] : null;
      final dMeters = (i < rowDist.length) ? rowDist[i] : null;
      if (dSec is! num || dMeters is! num) {
        // If OSRM couldn't route, it may return nulls.
        out.add((distanceMiles: 0, durationMinutes: 0));
        continue;
      }

      // OSRM does not include live traffic and can be optimistic, especially for short trips
      // (lights, turns, congestion). Apply a small conservative multiplier so the time-slider
      // behaves closer to real-world "minutes to drive".
      final miles = dMeters.toDouble() * _metersToMiles;
      final rawMinutes = dSec.toDouble() / 60.0;
      final factor = miles < 5
          ? 1.45
          : (miles < 15 ? 1.30 : (miles < 30 ? 1.20 : 1.12));
      final adjustedMinutes = (rawMinutes * factor).ceil().clamp(1, 24 * 60);

      out.add((
        distanceMiles: miles,
        durationMinutes: adjustedMinutes,
      ));
    }
    return out;
  }

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
        final distanceMiles = distanceMeters * _metersToMiles;

        _schools![i] = school.copyWith(distanceMiles: distanceMiles);
      }
    }

    // Prefer road distance/time (OSRM). If it fails (network/CORS/etc), fall back to an estimate.
    try {
      final idxs = <int>[];
      final dests = <({double lat, double lng})>[];
      for (int i = 0; i < _schools!.length; i++) {
        final s = _schools![i];
        if (s.latitude != null && s.longitude != null) {
          idxs.add(i);
          dests.add((lat: s.latitude!, lng: s.longitude!));
        }
      }

      const chunkSize = 50;
      for (int start = 0; start < dests.length; start += chunkSize) {
        final end = (start + chunkSize) > dests.length ? dests.length : (start + chunkSize);
        final chunk = dests.sublist(start, end);
        final chunkIdxs = idxs.sublist(start, end);

        final results = await _fetchOsrmTable(
          originLat: userLat,
          originLng: userLng,
          destinations: chunk,
        );

        if (results == null || results.length != chunk.length) {
          throw StateError('OSRM table failed');
        }

        for (int j = 0; j < chunkIdxs.length; j++) {
          final i = chunkIdxs[j];
          final school = _schools![i];
          final r = results[j];
          // 0/0 indicates an unroutable destination; keep whatever we had as fallback.
          if (r.durationMinutes <= 0 || r.distanceMiles <= 0) {
            continue;
          }
          _schools![i] = school.copyWith(
            driveDistanceMiles: r.distanceMiles,
            driveTimeMinutes: r.durationMinutes,
            travelTime: _formatTravelTime(r.durationMinutes),
          );
        }
      }

      // For any school missing a route time, fall back to a conservative estimate.
      for (int i = 0; i < _schools!.length; i++) {
        final school = _schools![i];
        if (school.driveTimeMinutes != null && school.driveTimeMinutes! > 0) continue;
        final miles = school.driveDistanceMiles ?? school.distanceMiles;
        if (miles == null) continue;
        // Conservative estimate: inflate straight-line distance by 1.25 and assume 25mph average.
        final estimatedMinutes = ((miles * 1.25) / 25.0 * 60).round();
        _schools![i] = school.copyWith(
          driveDistanceMiles: miles,
          driveTimeMinutes: estimatedMinutes,
          travelTime: _formatTravelTime(estimatedMinutes),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OSRM routing failed, using fallback estimates: $e');
      }
      for (var i = 0; i < _schools!.length; i++) {
        final school = _schools![i];
        final miles = school.distanceMiles;
        if (miles == null) continue;
        final estimatedMinutes = ((miles * 1.25) / 25.0 * 60).round();
        _schools![i] = school.copyWith(
          driveDistanceMiles: miles,
          driveTimeMinutes: estimatedMinutes,
          travelTime: _formatTravelTime(estimatedMinutes),
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
