import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'school_service.dart';

/// Best-effort warmup for the Filters/Map experience.
///
/// - Preloads school data + geocoding in the background
/// - Optionally prompts for location (with an in-app explanation)
/// - If permission is granted, precomputes distances/times early
/// - If user declines/denies, falls back to a default (Lehi) without nagging
class MapWarmupService {
  static final MapWarmupService _instance = MapWarmupService._internal();
  factory MapWarmupService() => _instance;
  MapWarmupService._internal();

  static const _prefsPromptShownKey = 'map_location_prompt_shown';
  static const _prefsOptOutKey = 'map_location_opt_out';

  // Default fallback when location is unavailable/declined.
  // (Approximate Lehi, UT)
  static const double _fallbackLat = 40.3916;
  static const double _fallbackLng = -111.8508;

  final SchoolService _schoolService = SchoolService();

  Future<void> prewarmSchools() async {
    // Load schools immediately; geocode in background (may take a bit).
    await _schoolService.loadSchools();
    unawaited(_schoolService.geocodeSchools());
  }

  Future<void> prewarmDistances({required double lat, required double lng}) async {
    await _schoolService.calculateDistancesAndTimes(lat, lng);
  }

  Future<Position?> tryGetCurrentPositionIfPermitted() async {
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> prewarmWithoutPrompt() async {
    // This is safe to call even on app start; no OS prompts.
    await prewarmSchools();
    final pos = await tryGetCurrentPositionIfPermitted();
    if (pos != null) {
      unawaited(prewarmDistances(lat: pos.latitude, lng: pos.longitude));
    } else {
      unawaited(prewarmDistances(lat: _fallbackLat, lng: _fallbackLng));
    }
  }

  Future<void> maybePromptForLocation(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final optedOut = prefs.getBool(_prefsOptOutKey) ?? false;
    final shown = prefs.getBool(_prefsPromptShownKey) ?? false;
    if (optedOut || shown) return;

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
      await prefs.setBool(_prefsPromptShownKey, true);
      return;
    }
    if (perm == LocationPermission.deniedForever) {
      // Don't nag. The map will use the default fallback.
      await prefs.setBool(_prefsPromptShownKey, true);
      return;
    }

    if (!context.mounted) return;

    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable location?'),
          content: const Text(
            'Enable location to automatically set your starting point for school distance filtering.\n\n'
            'If you decline, we’ll use a default location (Lehi, Utah) and you can still type your address anytime.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Use Lehi'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    await prefs.setBool(_prefsPromptShownKey, true);

    // If user dismissed the dialog, treat it as "not now" (no opt-out, but no prompt spam).
    if (choice != true) {
      // User wants fallback. Mark opt-out so we don't re-prompt.
      await prefs.setBool(_prefsOptOutKey, true);
      unawaited(prewarmDistances(lat: _fallbackLat, lng: _fallbackLng));
      return;
    }

    // Request OS permission only after explicit in-app consent.
    final requested = await Geolocator.requestPermission();
    if (requested == LocationPermission.always || requested == LocationPermission.whileInUse) {
      final pos = await tryGetCurrentPositionIfPermitted();
      if (pos != null) {
        unawaited(prewarmDistances(lat: pos.latitude, lng: pos.longitude));
        return;
      }
    }

    // Denied (or failed). Fall back and don't keep prompting.
    await prefs.setBool(_prefsOptOutKey, true);
    unawaited(prewarmDistances(lat: _fallbackLat, lng: _fallbackLng));
  }
}

