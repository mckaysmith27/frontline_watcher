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

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      _isLoading = false;
      
      // Initialize push notifications when user signs in
      if (user != null) {
        final pushService = PushNotificationService();
        await pushService.initialize();
        // Save token if it exists
        if (pushService.currentToken != null) {
          await _saveFcmToken(pushService.currentToken!);
        }
      }
      
      notifyListeners();
    });
  }

  Future<void> _saveFcmToken(String token) async {
    if (_user == null) return;
    
    try {
      await _firestore.collection('users').doc(_user!.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
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
          await _firestore.collection('users').doc(credential.user!.uid).set({
            'username': username,
            'email': email,
            'nickname': username,
            'shortname': null, // Will be set later via business card screen
            'credits': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'premiumClassesUnlocked': false,
            'premiumWorkdaysUnlocked': false,
          });
          print('[AuthProvider] User data saved to Firestore successfully');
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
}

