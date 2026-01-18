import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SubscriptionProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime? _subscriptionStartsAtUtc;
  DateTime? _subscriptionEndsAtUtc;
  bool _autoRenewing = false;

  DateTime? get subscriptionStartsAtUtc => _subscriptionStartsAtUtc;
  DateTime? get subscriptionEndsAtUtc => _subscriptionEndsAtUtc;
  bool get autoRenewing => _autoRenewing;

  bool get hasActiveSubscription {
    final end = _subscriptionEndsAtUtc;
    if (end == null) return false;
    return DateTime.now().toUtc().isBefore(end);
  }

  SubscriptionProvider() {
    _listen();
  }

  void _listen() {
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        _subscriptionStartsAtUtc = null;
        _subscriptionEndsAtUtc = null;
        _autoRenewing = false;
        notifyListeners();
        return;
      }

      _firestore.collection('users').doc(user.uid).snapshots().listen((doc) {
        if (!doc.exists) return;
        final data = doc.data();
        if (data == null) return;

        final startsTs = data['subscriptionStartsAt'];
        final endsTs = data['subscriptionEndsAt'];

        _subscriptionStartsAtUtc =
            (startsTs is Timestamp) ? startsTs.toDate().toUtc() : null;
        _subscriptionEndsAtUtc =
            (endsTs is Timestamp) ? endsTs.toDate().toUtc() : null;

        final autoRenewingValue = data['subscriptionAutoRenewing'];
        _autoRenewing = autoRenewingValue == true;

        notifyListeners();
      });
    });
  }
}

