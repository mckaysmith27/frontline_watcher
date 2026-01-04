import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CreditsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _credits = 0;
  List<String> _committedDates = [];
  List<String> _excludedDates = [];
  List<String> _scheduledJobDates = [];

  int get credits => _credits;
  List<String> get committedDates => _committedDates;
  List<String> get excludedDates => _excludedDates;
  List<String> get scheduledJobDates => _scheduledJobDates;

  CreditsProvider() {
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
        // Safely parse credits - handle null or invalid values
        final creditsValue = data['credits'];
        if (creditsValue is int) {
          _credits = creditsValue;
        } else if (creditsValue is num) {
          _credits = creditsValue.toInt();
        } else {
          _credits = 0;
        }
        
        _committedDates = List<String>.from(data['committedDates'] ?? []);
        _excludedDates = List<String>.from(data['excludedDates'] ?? []);
        _scheduledJobDates = List<String>.from(data['scheduledJobDates'] ?? []);
        notifyListeners();
      }
    } catch (e, stackTrace) {
      print('Error loading credits: $e');
      print('Stack trace: $stackTrace');
      // Don't crash - just log the error and keep current state
    }
  }

  Future<void> addCredits(int amount) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Update local state first
      _credits += amount;
      notifyListeners();

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'credits': FieldValue.increment(amount),
      });
    } catch (e) {
      // Rollback local state on error
      _credits -= amount;
      notifyListeners();
      print('Error adding credits: $e');
      rethrow;
    }
  }

  Future<bool> hasUsedPromoCode(String promoCode) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final usedPromoCodes = List<String>.from(data['usedPromoCodes'] ?? []);
      return usedPromoCodes.contains(promoCode.toUpperCase());
    } catch (e) {
      print('Error checking promo code: $e');
      return false;
    }
  }

  Future<void> markPromoCodeAsUsed(String promoCode) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'usedPromoCodes': FieldValue.arrayUnion([promoCode.toUpperCase()]),
      });
    } catch (e) {
      print('Error marking promo code as used: $e');
      rethrow;
    }
  }

  Future<void> commitDate(String date) async {
    if (_committedDates.contains(date)) return;

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Check if user has credits available
    if (_credits <= 0) {
      throw Exception('No credits available to commit');
    }

    try {
      // Update local state first - deduct credit and add date
      _credits -= 1;
      _committedDates.add(date);
      notifyListeners(); // Update UI immediately

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'committedDates': FieldValue.arrayUnion([date]),
        'credits': FieldValue.increment(-1),
      });
    } catch (e) {
      // Rollback local state on error
      _credits += 1;
      _committedDates.remove(date);
      notifyListeners();
      print('Error committing date: $e');
      rethrow;
    }
  }

  Future<void> uncommitDate(String date) async {
    if (!_committedDates.contains(date)) return;

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Update local state first - add credit back and remove date
      _credits += 1;
      _committedDates.remove(date);
      notifyListeners(); // Update UI immediately

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'committedDates': FieldValue.arrayRemove([date]),
        'credits': FieldValue.increment(1),
      });
    } catch (e) {
      // Rollback local state on error
      _credits -= 1;
      _committedDates.add(date);
      notifyListeners();
      print('Error uncommitting date: $e');
      rethrow;
    }
  }

  Future<void> excludeDate(String date) async {
    if (_excludedDates.contains(date)) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _excludedDates.add(date);
    await _firestore.collection('users').doc(user.uid).update({
      'excludedDates': FieldValue.arrayUnion([date]),
    });
    notifyListeners();
  }

  Future<void> removeExcludedDate(String date) async {
    if (!_excludedDates.contains(date)) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _excludedDates.remove(date);
    await _firestore.collection('users').doc(user.uid).update({
      'excludedDates': FieldValue.arrayRemove([date]),
    });
    notifyListeners();
  }

  Future<void> useCredit() async {
    if (_credits <= 0) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _credits -= 1;
    await _firestore.collection('users').doc(user.uid).update({
      'credits': FieldValue.increment(-1),
    });
    notifyListeners();
  }
}


