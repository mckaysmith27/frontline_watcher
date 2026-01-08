import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration
/// 
/// IMPORTANT: Replace these values with your actual Firebase project configuration
/// You can find these values in Firebase Console → Project Settings → Your apps → Web app
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // TODO: Replace with your Firebase Web configuration
  // Get these values from Firebase Console → Project Settings → Your apps → Web app
  const firebaseConfig = {
    apiKey: "AIzaSyC979_5krvVbto3Lj_0MlAnLqoWxPGKc1U",
    authDomain: "sub67-d4648.firebaseapp.com",
    projectId: "sub67-d4648",
    storageBucket: "sub67-d4648.firebasestorage.app",
    messagingSenderId: "734452992066",
    appId: "1:734452992066:web:529bd344cbbbfd3adb05db",
    measurementId: "G-HZ49M6D6RC"
  };

  // Android configuration from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD39Pj3E_jtITY0wrIU46IMCYgvETQPmaA',
    appId: '1:734452992066:android:cb67eeae5f833347db05db',
    messagingSenderId: '734452992066',
    projectId: 'sub67-d4648',
    storageBucket: 'sub67-d4648.firebasestorage.app',
  );

  // iOS configuration from GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBVkATaBpxWqiCjKMOdUDaR5yOBcN7MtEM',
    appId: '1:734452992066:ios:6d18f34860b089c7db05db',
    messagingSenderId: '734452992066',
    projectId: 'sub67-d4648',
    storageBucket: 'sub67-d4648.firebasestorage.app',
    iosBundleId: 'com.sub67.app',
  );

  // TODO: Add macOS configuration when needed
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.sub67',
  );
}



