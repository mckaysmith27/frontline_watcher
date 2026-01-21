import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'firebase_options.dart';
import 'config/app_config.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/filters_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/availability_provider.dart';
import 'providers/notifications_provider.dart';
import 'services/push_notification_service.dart';
import 'services/frontline_webview_warmup.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/job/job_webview_screen.dart';
import 'widgets/global_terms_gate.dart';
import 'screens/booking/teacher_landing_screen.dart';

// Background message handler must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('[Main] Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('[Main] Firebase initialized successfully');
    
    // Set background message handler before runApp
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e, stackTrace) {
    print('[Main] ERROR: Firebase initialization failed!');
    print('  Error: $e');
    print('  Type: ${e.runtimeType}');
    print('  Stack trace: $stackTrace');
    // Still run the app - it will show errors when trying to use Firebase
    print('[Main] Continuing app startup despite Firebase error...');
  }

  // Stripe PaymentSheet (card entry + saved payment method).
  // If the publishable key is empty, checkout will show an error.
  if (AppConfig.stripePublishableKey.trim().isNotEmpty) {
    Stripe.publishableKey = AppConfig.stripePublishableKey.trim();
    Stripe.merchantIdentifier = 'merchant.com.sub67.app';
    await Stripe.instance.applySettings();
  }

  runApp(const Sub67App());
}

class Sub67App extends StatefulWidget {
  const Sub67App({super.key});

  @override
  State<Sub67App> createState() => _Sub67AppState();
}

class _Sub67AppState extends State<Sub67App> {
  final PushNotificationService _pushService = PushNotificationService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final FrontlineWebViewWarmup _frontlineWarmup = FrontlineWebViewWarmup();

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
    // Best-effort: warm the WebView engine/domain early for faster "tap notification → accept".
    unawaited(_frontlineWarmup.prewarm());
  }

  void _setupPushNotifications() {
    // Listen for notification taps
    _pushService.onNotificationTapped.listen((data) {
      final jobUrl = data['jobUrl'] as String?;
      if (jobUrl != null && _navigatorKey.currentContext != null) {
        Navigator.of(_navigatorKey.currentContext!).push(
          MaterialPageRoute(
            builder: (_) => JobWebViewScreen(jobUrl: jobUrl),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialPublicShortname = _getPublicShortnameFromUrl();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FiltersProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => AvailabilityProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Sub67',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
                brightness: Brightness.light,
              ),
              textTheme: GoogleFonts.interTextTheme(),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
                brightness: Brightness.dark,
              ),
              textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            ),
            themeMode: themeProvider.themeMode,
            home: initialPublicShortname != null
                ? TeacherLandingScreen(shortname: initialPublicShortname)
                : const AuthWrapper(),
            routes: {
              '/job': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
                final jobUrl = args?['jobUrl'] as String? ?? '';
                return JobWebViewScreen(jobUrl: jobUrl);
              },
            },
          );
        },
      ),
    );
  }

  String? _getPublicShortnameFromUrl() {
    // Support public booking links: sub67.com/<shortname>
    // Only relevant for web; on mobile this will typically be "/".
    final segments = Uri.base.pathSegments.where((s) => s.trim().isNotEmpty).toList();
    if (segments.length == 1) {
      final shortname = segments.first.toLowerCase();
      // avoid routing collisions with known top-level paths
      const reserved = {'job'};
      if (reserved.contains(shortname)) return null;
      return shortname;
    }
    return null;
  }

  @override
  void dispose() {
    _pushService.dispose();
    super.dispose();
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (authProvider.user == null) {
          return const LoginScreen();
        }

        return GlobalTermsGate(
          child: const MainNavigation(),
        );
      },
    );
  }
}


