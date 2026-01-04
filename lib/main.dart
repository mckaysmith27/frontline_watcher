import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/filters_provider.dart';
import 'providers/credits_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('[Main] Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('[Main] Firebase initialized successfully');
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

class Sub67App extends StatelessWidget {
  const Sub67App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FiltersProvider()),
        ChangeNotifierProvider(create: (_) => CreditsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
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
          );
        },
      ),
    );
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
        
        return const MainNavigation();
      },
    );
  }
}


