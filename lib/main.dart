import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/filters_provider.dart';
import 'providers/credits_provider.dart';
import 'providers/notifications_provider.dart';
import 'services/push_notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/job/job_webview_screen.dart';
import 'widgets/global_terms_gate.dart';

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

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FiltersProvider()),
        ChangeNotifierProvider(create: (_) => CreditsProvider()),
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
            home: const AuthWrapper(),
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


