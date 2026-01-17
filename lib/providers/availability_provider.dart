import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PartialAvailabilityWindow {
  final int startMinutes; // minutes since midnight local time
  final int endMinutes; // minutes since midnight local time
  final String reason;

  const PartialAvailabilityWindow({
    required this.startMinutes,
    required this.endMinutes,
    required this.reason,
  });

  Map<String, dynamic> toMap() => {
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'reason': reason,
      };

  static PartialAvailabilityWindow? fromMap(dynamic v) {
    if (v is! Map) return null;
    final start = v['startMinutes'];
    final end = v['endMinutes'];
    final reason = v['reason'];
    if (start is! int || end is! int) return null;
    return PartialAvailabilityWindow(
      startMinutes: start,
      endMinutes: end,
      reason: reason is String ? reason : 'Partial availability',
    );
  }
}

class AvailabilityProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<String> _unavailableDates = []; // YYYY-MM-DD
  Map<String, String> _unavailableReasonsByDate = {}; // YYYY-MM-DD -> reason
  Map<String, PartialAvailabilityWindow> _partialAvailabilityByDate = {}; // YYYY-MM-DD -> window
  List<String> _scheduledJobDates = []; // YYYY-MM-DD

  String? _lastSyncedAvailableDatesFingerprint;

  List<String> get unavailableDates => _unavailableDates;
  Map<String, String> get unavailableReasonsByDate => _unavailableReasonsByDate;
  Map<String, PartialAvailabilityWindow> get partialAvailabilityByDate => _partialAvailabilityByDate;
  List<String> get scheduledJobDates => _scheduledJobDates;

  AvailabilityProvider() {
    _listen();
  }

  void _listen() {
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        _unavailableDates = [];
        _partialAvailabilityByDate = {};
        _scheduledJobDates = [];
        notifyListeners();
        return;
      }

      _firestore.collection('users').doc(user.uid).snapshots().listen((doc) {
        if (!doc.exists) return;
        final data = doc.data();
        if (data == null) return;

        // Backwards-compat: previously used 'excludedDates'
        final excluded = data['excludedDates'];
        _unavailableDates = List<String>.from(excluded is List ? excluded : const []);

        final reasons = data['unavailableReasonsByDate'];
        final reasonsParsed = <String, String>{};
        if (reasons is Map) {
          for (final entry in reasons.entries) {
            final k = entry.key;
            final v = entry.value;
            if (k is String && v is String) reasonsParsed[k] = v;
          }
        }
        _unavailableReasonsByDate = reasonsParsed;

        final scheduled = data['scheduledJobDates'];
        _scheduledJobDates = List<String>.from(scheduled is List ? scheduled : const []);

        final partial = data['partialAvailabilityByDate'];
        final parsed = <String, PartialAvailabilityWindow>{};
        if (partial is Map) {
          for (final entry in partial.entries) {
            final k = entry.key;
            if (k is! String) continue;
            final w = PartialAvailabilityWindow.fromMap(entry.value);
            if (w != null) parsed[k] = w;
          }
        }
        _partialAvailabilityByDate = parsed;

        // Keep a continuously-updated list of available workdays in Firestore for backend use.
        // This matches the "keywords by day" concept without credits.
        _maybeSyncAvailableDates(user.uid);

        notifyListeners();
      });
    });
  }

  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static bool isWeekend(DateTime day) {
    return day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  }

  // School year cutoff is Aug 1 (all districts).
  // When within 1 month of Aug 1, include next school year too.
  static DateTime _schoolYearCutoffFor(DateTime nowLocal) {
    final thisYearCutoff = DateTime(nowLocal.year, 8, 1);
    if (nowLocal.isBefore(thisYearCutoff)) return thisYearCutoff;
    return DateTime(nowLocal.year + 1, 8, 1);
  }

  static bool _isWithinOneMonth(DateTime a, DateTime b) {
    return a.isAfter(b.subtract(const Duration(days: 31)));
  }

  List<String> computeRelevantWorkdaysForKeywords() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = _schoolYearCutoffFor(today);
    final includeNext = _isWithinOneMonth(today, cutoff);
    final end = includeNext ? DateTime(cutoff.year + 1, 8, 1) : cutoff;

    final out = <String>[];
    for (DateTime d = today; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      if (isWeekend(d)) continue;
      final ds = formatDate(d);
      // Exclude full unavailable days and booked-job days (until canceled)
      if (_unavailableDates.contains(ds)) continue;
      if (_scheduledJobDates.contains(ds)) continue;
      out.add(ds);
    }
    return out;
  }

  Future<void> _maybeSyncAvailableDates(String uid) async {
    final dates = computeRelevantWorkdaysForKeywords();
    final fingerprint = dates.isEmpty ? '0' : '${dates.length}:${dates.first}:${dates.last}';
    if (_lastSyncedAvailableDatesFingerprint == fingerprint) return;
    _lastSyncedAvailableDatesFingerprint = fingerprint;
    try {
      await _firestore.collection('users').doc(uid).update({
        'availableDates': dates,
      });
    } catch (_) {
      // Don't crash UI on rules/network issues; this is an optimization for backend use.
    }
  }

  Future<void> updateScheduledJobDates(List<String> jobDates) async {
    _scheduledJobDates = jobDates;
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'scheduledJobDates': jobDates,
      });
    }
    notifyListeners();
  }

  Future<void> markUnavailable(String dateStr) async {
    await markUnavailableWithReason(dateStr, reason: 'Unavailable');
  }

  Future<void> markUnavailableWithReason(String dateStr, {required String reason}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_unavailableDates.contains(dateStr)) return;
    _unavailableDates = [..._unavailableDates, dateStr]..sort();
    _unavailableReasonsByDate = {
      ..._unavailableReasonsByDate,
      dateStr: reason,
    };
    // Full unavailable overrides partial availability for that date.
    _partialAvailabilityByDate.remove(dateStr);
    notifyListeners();
    await _firestore.collection('users').doc(user.uid).update({
      'excludedDates': FieldValue.arrayUnion([dateStr]),
      'unavailableReasonsByDate.$dateStr': reason,
      'partialAvailabilityByDate.$dateStr': FieldValue.delete(),
    });
  }

  Future<void> removeUnavailable(String dateStr) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (!_unavailableDates.contains(dateStr)) return;
    _unavailableDates = _unavailableDates.where((d) => d != dateStr).toList();
    _unavailableReasonsByDate = Map<String, String>.from(_unavailableReasonsByDate)..remove(dateStr);
    notifyListeners();
    await _firestore.collection('users').doc(user.uid).update({
      'excludedDates': FieldValue.arrayRemove([dateStr]),
      'unavailableReasonsByDate.$dateStr': FieldValue.delete(),
    });
  }

  Future<void> setPartialAvailability({
    required String dateStr,
    required int startMinutes,
    required int endMinutes,
    required String reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (startMinutes < 0 || endMinutes > 24 * 60 || startMinutes >= endMinutes) return;

    // Partial availability implies NOT fully unavailable.
    _unavailableDates = _unavailableDates.where((d) => d != dateStr).toList();
    _partialAvailabilityByDate = {
      ..._partialAvailabilityByDate,
      dateStr: PartialAvailabilityWindow(
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        reason: reason,
      ),
    };
    notifyListeners();

    await _firestore.collection('users').doc(user.uid).update({
      'excludedDates': FieldValue.arrayRemove([dateStr]),
      'partialAvailabilityByDate.$dateStr': _partialAvailabilityByDate[dateStr]!.toMap(),
    });
  }

  Future<void> clearPartialAvailability(String dateStr) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (!_partialAvailabilityByDate.containsKey(dateStr)) return;
    _partialAvailabilityByDate = Map<String, PartialAvailabilityWindow>.from(_partialAvailabilityByDate)
      ..remove(dateStr);
    notifyListeners();
    await _firestore.collection('users').doc(user.uid).update({
      'partialAvailabilityByDate.$dateStr': FieldValue.delete(),
    });
  }
}

