import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TimeWindow {
  final String id;
  TimeOfDay startTime;
  TimeOfDay endTime;

  TimeWindow({
    required this.id,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
    };
  }

  factory TimeWindow.fromMap(Map<String, dynamic> map) {
    return TimeWindow(
      id: map['id'] ?? '',
      startTime: TimeOfDay(
        hour: map['startHour'] ?? 8,
        minute: map['startMinute'] ?? 0,
      ),
      endTime: TimeOfDay(
        hour: map['endHour'] ?? 17,
        minute: map['endMinute'] ?? 0,
      ),
    );
  }
}

class NotificationsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _notificationsEnabled = true; // Default to true
  bool _fastNotificationsEnabled = false;
  bool _fastJobAcceptEnabled = false;
  bool _applyFilterEnabled = false;
  bool _setTimesEnabled = false;
  bool _termsAccepted = false;
  List<TimeWindow> _timeWindows = [];

  bool get notificationsEnabled => _notificationsEnabled;
  bool get fastNotificationsEnabled => _fastNotificationsEnabled;
  bool get fastJobAcceptEnabled => _fastJobAcceptEnabled;
  bool get applyFilterEnabled => _applyFilterEnabled;
  bool get setTimesEnabled => _setTimesEnabled;
  bool get termsAccepted => _termsAccepted;
  List<TimeWindow> get timeWindows => _timeWindows;

  NotificationsProvider() {
    _loadFromFirebase();
  }

  Future<void> _loadFromFirebase() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _refreshData();
      }
    });

    await _refreshData();
  }

  Future<void> _refreshData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _notificationsEnabled = data['notifyEnabled'] ?? true; // Default to true
        _fastNotificationsEnabled = data['fastNotificationsEnabled'] ?? false;
        _fastJobAcceptEnabled = data['fastJobAcceptEnabled'] ?? false;
        _applyFilterEnabled = data['applyFilterEnabled'] ?? false;
        _setTimesEnabled = data['setTimesEnabled'] ?? false;
        _termsAccepted = data['notificationsTermsAccepted'] ?? false;
        
        // Load time windows
        final timeWindowsData = data['notificationTimeWindows'] as List<dynamic>? ?? [];
        _timeWindows = timeWindowsData
            .map((tw) => TimeWindow.fromMap(Map<String, dynamic>.from(tw)))
            .toList();
        
        notifyListeners();
      } else {
        // New user - default notifications to enabled
        _notificationsEnabled = true;
        await _firestore.collection('users').doc(user.uid).update({
          'notifyEnabled': true,
        });
        notifyListeners();
      }
    } catch (e) {
      print('Error loading notification settings: $e');
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _notificationsEnabled = enabled;
    await _firestore.collection('users').doc(user.uid).update({
      'notifyEnabled': enabled,
    });
    notifyListeners();
  }

  Future<void> setFastNotificationsEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _fastNotificationsEnabled = enabled;
    await _firestore.collection('users').doc(user.uid).update({
      'fastNotificationsEnabled': enabled,
    });
    notifyListeners();
  }

  Future<void> setFastJobAcceptEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _fastJobAcceptEnabled = enabled;
    await _firestore.collection('users').doc(user.uid).update({
      'fastJobAcceptEnabled': enabled,
    });
    notifyListeners();
  }

  Future<void> setApplyFilterEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _applyFilterEnabled = enabled;
    await _firestore.collection('users').doc(user.uid).update({
      'applyFilterEnabled': enabled,
    });
    notifyListeners();
  }

  Future<void> setSetTimesEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _setTimesEnabled = enabled;
    await _firestore.collection('users').doc(user.uid).update({
      'setTimesEnabled': enabled,
    });
    notifyListeners();
  }

  Future<void> acceptTerms() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _termsAccepted = true;
    await _firestore.collection('users').doc(user.uid).update({
      'notificationsTermsAccepted': true,
    });
    notifyListeners();
  }

  Future<void> addTimeWindow(TimeWindow timeWindow) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _timeWindows.add(timeWindow);
    await _saveTimeWindows();
    notifyListeners();
  }

  Future<void> updateTimeWindow(String id, TimeWindow updatedWindow) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final index = _timeWindows.indexWhere((tw) => tw.id == id);
    if (index != -1) {
      _timeWindows[index] = updatedWindow;
      await _saveTimeWindows();
      notifyListeners();
    }
  }

  Future<void> removeTimeWindow(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _timeWindows.removeWhere((tw) => tw.id == id);
    await _saveTimeWindows();
    notifyListeners();
  }

  Future<void> _saveTimeWindows() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'notificationTimeWindows': _timeWindows.map((tw) => tw.toMap()).toList(),
    });
  }

  /// Check if current time is within any of the user's time windows
  bool isWithinTimeWindow() {
    if (!_setTimesEnabled || _timeWindows.isEmpty) {
      return true; // If time windows are disabled or empty, allow all times
    }

    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);

    for (final window in _timeWindows) {
      if (_isTimeInRange(currentTime, window.startTime, window.endTime)) {
        return true;
      }
    }

    return false;
  }

  bool _isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // Normal case: start < end (e.g., 8:00 AM to 5:00 PM)
      return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
    } else {
      // Wraps around midnight (e.g., 10:00 PM to 2:00 AM)
      return timeMinutes >= startMinutes || timeMinutes <= endMinutes;
    }
  }
}
