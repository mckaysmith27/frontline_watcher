import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_role_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationTapped =>
      _notificationTapController.stream;

  String? _currentToken;
  bool _isInitialized = false;
  String? _lastSavedToken;

  String? get currentToken => _currentToken;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Check if user has access to schedule feature (requires 'sub' role for job notifications)
    final roleService = UserRoleService();
    final hasScheduleAccess = await roleService.hasFeatureAccess('schedule');
    
    if (!hasScheduleAccess) {
      // User doesn't have access to job notifications, skip permission request
      print('[PushNotificationService] User does not have schedule access, skipping notification permissions');
      return;
    }
    
    // Request permissions only if user has access to the feature
    await _requestPermissions().timeout(const Duration(seconds: 6));

    // Initialize local notifications for foreground
    await _initializeLocalNotifications().timeout(const Duration(seconds: 6));

    // Get FCM token
    await _getToken().timeout(const Duration(seconds: 8));

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app is launched from terminated state
    final initialMessage = await _messaging.getInitialMessage().timeout(const Duration(seconds: 4));
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
    
    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('Notification permission status: ${settings.authorizationStatus}');
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle local notification tap
        if (details.payload != null) {
          try {
            final data = Map<String, dynamic>.from(
              Map<String, String>.fromEntries(
                details.payload!.split(',').map((e) {
                  final parts = e.split(':');
                  return MapEntry(parts[0], parts.length > 1 ? parts[1] : '');
                }),
              ),
            );
            _notificationTapController.add(data);
          } catch (e) {
            print('Error parsing notification payload: $e');
          }
        }
      },
    );
  }

  Future<void> _getToken() async {
    try {
      _currentToken = await _messaging.getToken();
      print('FCM Token: $_currentToken');
      await _saveTokenToFirestore(_currentToken);
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  Future<void> _onTokenRefresh(String newToken) async {
    print('FCM Token refreshed: $newToken');
    _currentToken = newToken;
    await _saveTokenToFirestore(newToken);
  }

  Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;
    if (_lastSavedToken == token) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
      _lastSavedToken = token;
      print('FCM token saved to Firestore');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message received: ${message.messageId}');
    
    // Show local notification for foreground messages
    final notification = message.notification;
    
    if (notification != null) {
      _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'job_notifications',
            'Job Notifications',
            channelDescription: 'Notifications for new job opportunities',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: _buildPayload(message.data),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.messageId}');
    _notificationTapController.add(message.data);
  }

  String _buildPayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  void dispose() {
    _notificationTapController.close();
  }
}

