import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/push_notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  User? _user;
  bool _isLoading = true;
  StreamSubscription<User?>? _authSub;
  String? _lastPushInitUid;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
  }

  static const _alphaNum = 'abcdefghijklmnopqrstuvwxyz0123456789';

  String _randomAlnum(int len) {
    final r = Random.secure();
    final buf = StringBuffer();
    for (int i = 0; i < len; i++) {
      buf.write(_alphaNum[r.nextInt(_alphaNum.length)]);
    }
    return buf.toString();
  }

  bool _distinctShortnameAndNickname(String shortname, String nickname) {
    final sn = shortname.trim().toLowerCase();
    final nn = nickname.trim().toLowerCase();
    if (sn.isEmpty || nn.isEmpty) return true;

    final digitsSn = RegExp(r'\d').allMatches(sn).map((m) => m.group(0)!).toSet();
    final digitsNn = RegExp(r'\d').allMatches(nn).map((m) => m.group(0)!).toSet();
    if (digitsSn.intersection(digitsNn).isNotEmpty) return false;

    String lettersOnly(String x) => x.replaceAll(RegExp(r'[^a-z]'), '');
    final a = lettersOnly(sn);
    final b = lettersOnly(nn);
    if (a.length >= 3 && b.length >= 3) {
      final subs = <String>{};
      for (int i = 0; i <= a.length - 3; i++) {
        subs.add(a.substring(i, i + 3));
      }
      for (int i = 0; i <= b.length - 3; i++) {
        if (subs.contains(b.substring(i, i + 3))) return false;
      }
    }
    return true;
  }

  Future<void> _init() async {
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;

      // IMPORTANT: notify immediately so app doesn't hang on startup.
      notifyListeners();

      // Best-effort push init in background; never block app startup.
      if (user != null) {
        final uid = user.uid;
        if (_lastPushInitUid == uid) return;
        _lastPushInitUid = uid;

        // Best-effort: ensure defaults exist (nickname + shortname).
        unawaited(_ensureNicknameAndShortname(uid, email: user.email));

        final pushService = PushNotificationService();
        // Fire-and-forget with timeout to avoid deadlocks on emulators/devices.
        unawaited(
          pushService
              .initialize()
              .timeout(const Duration(seconds: 8))
              .catchError((e) => print('[AuthProvider] Push init failed: $e')),
        );
      } else {
        _lastPushInitUid = null;
      }
    }, onError: (e) {
      // If auth stream errors, don't keep spinner forever.
      print('[AuthProvider] authStateChanges error: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
    required String userRole, // 'teacher', 'sub', or 'administration'
  }) async {
    try {
      print('[AuthProvider] Starting signup for email: $email');
      
      // Validate inputs
      if (email.isEmpty) {
        return 'Email cannot be empty';
      }
      if (password.isEmpty) {
        return 'Password cannot be empty';
      }
      if (username.isEmpty) {
        return 'Username cannot be empty';
      }

      print('[AuthProvider] Creating user with Firebase Auth...');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('[AuthProvider] User created successfully. UID: ${credential.user?.uid}');

      if (credential.user != null) {
        try {
          print('[AuthProvider] Saving user data to Firestore...');
          
          // Generate default shortname + nickname (random 6–8 chars, distinct)
          final pair = await _generateDefaultNicknameAndShortname();
          final defaultShortname = pair.shortname;
          final defaultNickname = pair.nickname;
          
          await _firestore.collection('users').doc(credential.user!.uid).set({
            'username': username,
            'email': email,
            'nickname': defaultNickname,
            'shortname': defaultShortname,
            'userRoles': [userRole], // Array of roles, starting with selected role
            'createdAt': FieldValue.serverTimestamp(),
            'premiumClassesUnlocked': false,
            'premiumWorkdaysUnlocked': false,
            // Subscription model (timestamp-based)
            'subscriptionActive': false,
            'subscriptionStartsAt': null,
            'subscriptionEndsAt': null,
            'subscriptionAutoRenewing': false,
            // Availability model
            'excludedDates': <String>[],
            'partialAvailabilityByDate': <String, dynamic>{},
            'scheduledJobDates': <String>[],
          });
          print('[AuthProvider] User data saved to Firestore successfully with shortname: $defaultShortname');
        } catch (firestoreError) {
          print('[AuthProvider] Firestore error: $firestoreError');
          print('[AuthProvider] Firestore error type: ${firestoreError.runtimeType}');
          
          // Check if it's a permission error
          if (firestoreError.toString().contains('permission') || 
              firestoreError.toString().contains('PERMISSION_DENIED')) {
            print('[AuthProvider] ERROR: Firestore permission denied. User created but data not saved.');
            print('[AuthProvider] Fix: Enable Firestore Database in Firebase Console and check security rules.');
            // Return error so user knows something went wrong
            return 'Account created but failed to save user data. Please check Firestore is enabled in Firebase Console.';
          }
          
          // User was created but Firestore failed - still return success
          // but log the error for debugging
          print('[AuthProvider] WARNING: User created but Firestore write failed: $firestoreError');
        }
      }

      return null;
    } on FirebaseAuthException catch (e) {
      print('[AuthProvider] FirebaseAuthException during signup:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Email: ${e.email}');
      print('  Credential: ${e.credential}');
      
      // Provide detailed error messages
      switch (e.code) {
        case 'weak-password':
          return 'The password provided is too weak. Please use a stronger password.';
        case 'email-already-in-use':
          return 'An account already exists with this email. Please sign in instead.';
        case 'invalid-email':
          return 'The email address is invalid. Please check and try again.';
        case 'operation-not-allowed':
          return 'Email/Password authentication is not enabled in Firebase Console.\n\nTo fix this:\n1. Go to https://console.firebase.google.com/\n2. Select your project (sub67-d4648)\n3. Click "Authentication" → "Sign-in method"\n4. Click "Email/Password"\n5. Enable it and click "Save"';
        case 'configuration-not-found':
          return 'Firebase Auth configuration not found for web.\n\nThis usually means:\n1. Email/Password is not enabled (see above)\n2. Or Firebase Auth is not properly configured\n\nTo fix:\n1. Go to https://console.firebase.google.com/\n2. Select project: sub67-d4648\n3. Go to Authentication → Sign-in method\n4. Enable Email/Password\n5. Make sure your web app is registered in Project Settings';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        default:
          return 'Signup failed: ${e.message ?? e.code}. Please try again or contact support if the issue persists.';
      }
    } catch (e, stackTrace) {
      print('[AuthProvider] Unexpected error during signup:');
      print('  Error: $e');
      print('  Type: ${e.runtimeType}');
      print('  Stack trace: $stackTrace');
      return 'An unexpected error occurred: ${e.toString()}. Please try again or contact support.';
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('[AuthProvider] Starting signin for email: $email');
      
      // Validate inputs
      if (email.isEmpty) {
        return 'Email cannot be empty';
      }
      if (password.isEmpty) {
        return 'Password cannot be empty';
      }

      print('[AuthProvider] Attempting to sign in with Firebase Auth...');
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('[AuthProvider] Sign in successful');
      return null;
    } on FirebaseAuthException catch (e) {
      print('[AuthProvider] FirebaseAuthException during signin:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Email: ${e.email}');
      print('  Credential: ${e.credential}');
      
      // Handle specific Firebase auth errors with helpful messages
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email. Click \'Create New Account\' to sign up!';
        case 'wrong-password':
          return 'Incorrect password. Please try again or use \'Forgot Password\' to reset it.';
        case 'invalid-credential':
          return 'Invalid email or password. Please check your credentials and try again.';
        case 'invalid-email':
          return 'The email address is invalid. Please check and try again.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many failed login attempts. Please try again later or reset your password.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        case 'operation-not-allowed':
          return 'Email/Password authentication is not enabled in Firebase Console.\n\nTo fix this:\n1. Go to https://console.firebase.google.com/\n2. Select your project (sub67-d4648)\n3. Click "Authentication" → "Sign-in method"\n4. Click "Email/Password"\n5. Enable it and click "Save"';
        case 'configuration-not-found':
          return 'Firebase Auth configuration not found for web.\n\nThis usually means:\n1. Email/Password is not enabled (see above)\n2. Or Firebase Auth is not properly configured\n\nTo fix:\n1. Go to https://console.firebase.google.com/\n2. Select project: sub67-d4648\n3. Go to Authentication → Sign-in method\n4. Enable Email/Password\n5. Make sure your web app is registered in Project Settings';
        default:
          return 'Login failed: ${e.message ?? e.code}. Please try again or contact support if the issue persists.';
      }
    } catch (e, stackTrace) {
      print('[AuthProvider] Unexpected error during signin:');
      print('  Error: $e');
      print('  Type: ${e.runtimeType}');
      print('  Stack trace: $stackTrace');
      return 'An unexpected error occurred: ${e.toString()}. Please try again or contact support.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _secureStorage.deleteAll();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> saveEssCredentials({
    required String username,
    required String password,
  }) async {
    if (_user == null) return;

    await _secureStorage.write(
      key: 'ess_username_${_user!.uid}',
      value: username,
    );
    await _secureStorage.write(
      key: 'ess_password_${_user!.uid}',
      value: password,
    );
  }

  Future<Map<String, String?>> getEssCredentials() async {
    if (_user == null) return {};

    return {
      'username': await _secureStorage.read(
        key: 'ess_username_${_user!.uid}',
      ),
      'password': await _secureStorage.read(
        key: 'ess_password_${_user!.uid}',
      ),
    };
  }

  Future<({String nickname, String shortname})> _generateDefaultNicknameAndShortname() async {
    for (int attempt = 0; attempt < 60; attempt++) {
      final lenNick = 6 + Random.secure().nextInt(3); // 6–8
      final lenShort = 6 + Random.secure().nextInt(3); // 6–8
      final nickname = _randomAlnum(lenNick);
      final shortname = _randomAlnum(lenShort);
      if (nickname == shortname) continue;
      if (!_distinctShortnameAndNickname(shortname, nickname)) continue;
      if (!RegExp(r'\d').hasMatch(shortname)) continue; // keep shortname a bit stronger
      if (!await _checkShortnameAvailable(shortname)) continue;
      return (nickname: nickname, shortname: shortname);
    }
    // Fallback
    String sn;
    do {
      sn = _randomAlnum(8);
    } while (!RegExp(r'\d').hasMatch(sn) || !await _checkShortnameAvailable(sn));
    String nn;
    do {
      nn = _randomAlnum(8);
    } while (nn == sn || !_distinctShortnameAndNickname(sn, nn));
    return (nickname: nn, shortname: sn);
  }

  Future<void> _ensureNicknameAndShortname(String uid, {String? email}) async {
    try {
      final ref = _firestore.collection('users').doc(uid);
      final snap = await ref.get();
      final data = snap.data() ?? {};

      final existingShort = (data['shortname'] is String) ? (data['shortname'] as String).trim().toLowerCase() : '';
      final existingNick = (data['nickname'] is String) ? (data['nickname'] as String).trim() : '';

      // Never auto-change an existing shortname (it powers business card links).
      String shortname = existingShort;
      if (shortname.isEmpty) {
        String candidate;
        do {
          candidate = _randomAlnum(8);
        } while (!RegExp(r'\d').hasMatch(candidate) || !await _checkShortnameAvailable(candidate));
        shortname = candidate;
      }

      String nickname = existingNick;
      final needsNick = nickname.isEmpty || !_distinctShortnameAndNickname(shortname, nickname);
      if (needsNick) {
        String candidate;
        do {
          candidate = _randomAlnum(8);
        } while (candidate == shortname || !_distinctShortnameAndNickname(shortname, candidate));
        nickname = candidate;
      }

      final updates = <String, dynamic>{};
      if (existingShort.isEmpty) updates['shortname'] = shortname;
      if (existingNick.isEmpty || needsNick) updates['nickname'] = nickname;
      if (email != null && (data['email'] is! String || (data['email'] as String).trim().isEmpty)) {
        updates['email'] = email;
      }

      if (updates.isNotEmpty) {
        await ref.set(updates, SetOptions(merge: true));
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AuthProvider] ensure nickname/shortname failed: $e');
      }
    }
  }

  /// Check if a shortname is available (case-insensitive)
  Future<bool> _checkShortnameAvailable(String shortname) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('shortname', isEqualTo: shortname.toLowerCase())
          .limit(1)
          .get();
      return snapshot.docs.isEmpty;
    } catch (e) {
      print('Error checking shortname availability: $e');
      // If check fails, assume it's available to avoid blocking signup
      return true;
    }
  }
}

