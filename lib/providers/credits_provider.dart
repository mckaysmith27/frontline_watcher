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
  
  /// Check if subscription is active (has credits OR has future committed dates)
  bool get hasActiveSubscription {
    // Has credits available
    if (_credits > 0) return true;
    
    // Has committed dates that are today or in the future
    if (_committedDates.isNotEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      for (final dateStr in _committedDates) {
        final dateParts = dateStr.split('-');
        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );
        // If any committed date is today or in the future, subscription is active
        if (date.isAtSameMomentAs(today) || date.isAfter(today)) {
          return true;
        }
      }
    }
    
    return false;
  }

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
        
        // Auto-disable notifications if user has no credits AND no green days
        final isLocked = _credits == 0 && _committedDates.isEmpty;
        if (isLocked && data['notifyEnabled'] == true) {
          await _firestore.collection('users').doc(user.uid).update({
            'notifyEnabled': false,
          });
          print('[CreditsProvider] Auto-disabled notifications: no credits and no green days');
        }
        
        // Update subscriptionActive field in Firestore
        final subscriptionActive = hasActiveSubscription;
        if (data['subscriptionActive'] != subscriptionActive) {
          await _firestore.collection('users').doc(user.uid).update({
            'subscriptionActive': subscriptionActive,
          });
        }
        
        notifyListeners();
      }
    } catch (e, stackTrace) {
      print('Error loading credits: $e');
      print('Stack trace: $stackTrace');
      // Don't crash - just log the error and keep current state
    }
  }

  /// Get the next workday (Monday-Friday) from a given date
  DateTime _getNextWorkday(DateTime fromDate) {
    DateTime nextDay = fromDate.add(const Duration(days: 1));
    // Skip weekends
    while (nextDay.weekday == DateTime.saturday || nextDay.weekday == DateTime.sunday) {
      nextDay = nextDay.add(const Duration(days: 1));
    }
    return nextDay;
  }

  /// Format DateTime to YYYY-MM-DD string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if a date is today
  bool _isToday(String dateStr) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateParts = dateStr.split('-');
    final date = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    return date.isAtSameMomentAs(today);
  }

  Future<void> addCredits(int amount, {String? promoCode}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Calculate dates to commit: starting from tomorrow, next X workdays (where X = amount)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final datesToCommit = <String>[];
      
      // Add today as freebie if it's a workday and not already committed/excluded/has job
      final todayStr = _formatDate(today);
      final isTodayWorkday = today.weekday != DateTime.saturday && today.weekday != DateTime.sunday;
      
      if (isTodayWorkday && 
          !_committedDates.contains(todayStr) && 
          !_excludedDates.contains(todayStr) &&
          !_scheduledJobDates.contains(todayStr)) {
        datesToCommit.add(todayStr);
      }
      
      // Start from tomorrow (not today)
      DateTime currentDay = _getNextWorkday(today);
      
      // Add next X workdays (where X = amount)
      for (int i = 0; i < amount; i++) {
        final dateStr = _formatDate(currentDay);
        // Skip if already committed, excluded, or has a job
        if (!_committedDates.contains(dateStr) && 
            !_excludedDates.contains(dateStr) &&
            !_scheduledJobDates.contains(dateStr)) {
          datesToCommit.add(dateStr);
        } else {
          // If this day is already committed/excluded/has job, find the next available workday
          DateTime nextAvailable = _getNextWorkday(currentDay);
          while (_committedDates.contains(_formatDate(nextAvailable)) || 
                 _excludedDates.contains(_formatDate(nextAvailable)) ||
                 _scheduledJobDates.contains(_formatDate(nextAvailable))) {
            nextAvailable = _getNextWorkday(nextAvailable);
          }
          datesToCommit.add(_formatDate(nextAvailable));
          currentDay = nextAvailable;
        }
        // Move to next workday for next iteration
        currentDay = _getNextWorkday(currentDay);
      }

      // Update local state first
      _credits += amount;
      _committedDates.addAll(datesToCommit);
      // Remove duplicates and sort
      _committedDates = _committedDates.toSet().toList()..sort();
      notifyListeners();

      // Create purchase action record
      final purchaseAction = <String, dynamic>{
        'timestamp': FieldValue.serverTimestamp(),
        'promotion': promoCode,
        'credits': amount,
      };

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'credits': FieldValue.increment(amount),
        'committedDates': FieldValue.arrayUnion(datesToCommit),
        'purchaseActions': FieldValue.arrayUnion([purchaseAction]),
        'subscriptionActive': true, // Adding credits makes subscription active
      });
      
      // Auto-apply global filters to newly committed dates
      // Only apply to dates that are notification days (not unavailable, not has job)
      for (var dateStr in datesToCommit) {
        // Check if date is still a notification day and not unavailable/has job
        if (_committedDates.contains(dateStr) &&
            !_excludedDates.contains(dateStr) &&
            !_scheduledJobDates.contains(dateStr)) {
          // Trigger auto-apply via notifyListeners - FiltersProvider will handle it
          // We'll use a callback mechanism or the FiltersProvider will listen to committedDates changes
        }
      }
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
      final subscriptionActive = _credits > 1 || (_credits == 1 && !_committedDates.contains(date));
      await _firestore.collection('users').doc(user.uid).update({
        'committedDates': FieldValue.arrayUnion([date]),
        'credits': FieldValue.increment(-1),
        'subscriptionActive': subscriptionActive,
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

    // Cannot uncommit today
    if (_isToday(date)) {
      throw Exception('Cannot uncommit today');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Find the next available workday to automatically commit the credit to
      final dateParts = date.split('-');
      final uncommittedDate = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );
      
      DateTime nextWorkday = _getNextWorkday(uncommittedDate);
      String nextWorkdayStr = _formatDate(nextWorkday);
      
      // Keep finding next workday until we find one that's not already committed or excluded
      while (_committedDates.contains(nextWorkdayStr) || 
             _excludedDates.contains(nextWorkdayStr)) {
        nextWorkday = _getNextWorkday(nextWorkday);
        nextWorkdayStr = _formatDate(nextWorkday);
      }

      // Update local state first - remove old date, add new date (credit stays committed, just moves)
      _committedDates.remove(date);
      _committedDates.add(nextWorkdayStr);
      _committedDates.sort();
      notifyListeners(); // Update UI immediately

      // Update Firestore - remove old date, add new date
      final subscriptionActive = hasActiveSubscription;
      await _firestore.collection('users').doc(user.uid).update({
        'committedDates': FieldValue.arrayRemove([date]),
        'committedDates': FieldValue.arrayUnion([nextWorkdayStr]),
        'subscriptionActive': subscriptionActive,
      });
      
      // Check if we need to disable notifications after uncommitting date
      final isLocked = _credits == 0 && _committedDates.isEmpty;
      if (isLocked) {
        await _firestore.collection('users').doc(user.uid).update({
          'notifyEnabled': false,
        });
        print('[CreditsProvider] Auto-disabled notifications: no credits and no green days after uncommitting');
      }
    } catch (e) {
      // Rollback local state on error
      _committedDates.add(date);
      _committedDates.sort();
      notifyListeners();
      print('Error uncommitting date: $e');
      rethrow;
    }
  }

  Future<void> excludeDate(String date) async {
    if (_excludedDates.contains(date)) return;

    final user = _auth.currentUser;
    if (user == null) return;

    // If this date has a committed credit, move it to the next available workday
    if (_committedDates.contains(date)) {
      await _moveCreditToNextAvailable(date);
    }

    _excludedDates.add(date);
    final subscriptionActive = hasActiveSubscription;
    await _firestore.collection('users').doc(user.uid).update({
      'excludedDates': FieldValue.arrayUnion([date]),
      'subscriptionActive': subscriptionActive,
    });
    notifyListeners();
  }
  
  /// Move a credit from one date to the next available workday (not excluded, not has job)
  Future<void> _moveCreditToNextAvailable(String fromDate) async {
    final dateParts = fromDate.split('-');
    final fromDateTime = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    
    DateTime nextWorkday = _getNextWorkday(fromDateTime);
    String nextWorkdayStr = _formatDate(nextWorkday);
    
    // Find next available workday (not excluded, not has job, not already committed)
    while (_excludedDates.contains(nextWorkdayStr) || 
           _scheduledJobDates.contains(nextWorkdayStr) ||
           _committedDates.contains(nextWorkdayStr)) {
      nextWorkday = _getNextWorkday(nextWorkday);
      nextWorkdayStr = _formatDate(nextWorkday);
    }
    
    // Move the credit
    _committedDates.remove(fromDate);
    _committedDates.add(nextWorkdayStr);
    _committedDates.sort();
    
    final user = _auth.currentUser;
    if (user != null) {
      final subscriptionActive = hasActiveSubscription;
      await _firestore.collection('users').doc(user.uid).update({
        'committedDates': FieldValue.arrayRemove([fromDate]),
        'committedDates': FieldValue.arrayUnion([nextWorkdayStr]),
        'subscriptionActive': subscriptionActive,
      });
    }
  }
  
  /// Handle canceling a job - if the day would be within sequential range, move credit from furthest day
  Future<void> handleJobCanceled(String dateStr) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // Check if this date would be within the sequential credit range
    if (_committedDates.isEmpty) return;
    
    // Get all committed dates sorted
    final sortedCommitted = List<String>.from(_committedDates)..sort();
    final furthestDate = sortedCommitted.last;
    
    // Parse dates
    final dateParts = dateStr.split('-');
    final canceledDate = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    
    final furthestParts = furthestDate.split('-');
    final furthestDateTime = DateTime(
      int.parse(furthestParts[0]),
      int.parse(furthestParts[1]),
      int.parse(furthestParts[2]),
    );
    
    // If canceled date is before or equal to furthest date, move credit
    if (canceledDate.isBefore(furthestDateTime) || canceledDate.isAtSameMomentAs(furthestDateTime)) {
      // Check if canceled date is not excluded and not already committed
      if (!_excludedDates.contains(dateStr) && !_committedDates.contains(dateStr)) {
        // Remove credit from furthest date, add to canceled date
        _committedDates.remove(furthestDate);
        _committedDates.add(dateStr);
        _committedDates.sort();
        
        final subscriptionActive = hasActiveSubscription;
        await _firestore.collection('users').doc(user.uid).update({
          'committedDates': FieldValue.arrayRemove([furthestDate]),
          'committedDates': FieldValue.arrayUnion([dateStr]),
          'subscriptionActive': subscriptionActive,
        });
        notifyListeners();
      }
    }
  }
  
  /// Handle removing unavailable status - same logic as canceling job
  Future<void> handleUnavailableRemoved(String dateStr) async {
    await handleJobCanceled(dateStr);
  }

  Future<void> removeExcludedDate(String date) async {
    if (!_excludedDates.contains(date)) return;

    final user = _auth.currentUser;
    if (user == null) return;

    // Handle sequential credit management when removing unavailable status
    await handleUnavailableRemoved(date);

    _excludedDates.remove(date);
    final subscriptionActive = hasActiveSubscription;
    await _firestore.collection('users').doc(user.uid).update({
      'excludedDates': FieldValue.arrayRemove([date]),
      'subscriptionActive': subscriptionActive,
    });
    notifyListeners();
  }

  Future<void> useCredit() async {
    if (_credits <= 0) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _credits -= 1;
    final subscriptionActive = hasActiveSubscription;
    await _firestore.collection('users').doc(user.uid).update({
      'credits': FieldValue.increment(-1),
      'subscriptionActive': subscriptionActive,
    });
    
    // Check if we need to disable notifications after using credit
    final isLocked = _credits == 0 && _committedDates.isEmpty;
    if (isLocked) {
      await _firestore.collection('users').doc(user.uid).update({
        'notifyEnabled': false,
      });
      print('[CreditsProvider] Auto-disabled notifications: credits exhausted and no green days');
    }
    
    notifyListeners();
  }
  
  /// Check if features are locked (inverse of hasActiveSubscription)
  bool get isLocked => !hasActiveSubscription;
  
  /// Update scheduled job dates (called when jobs are loaded)
  Future<void> updateScheduledJobDates(List<String> jobDates) async {
    _scheduledJobDates = jobDates;
    notifyListeners();
  }
}


