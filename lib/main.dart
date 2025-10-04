import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase/firebase_options.dart' as fb;
import 'package:aracfilo/app_router/app_router.dart';
import 'package:aracfilo/app_router/app_routes.dart';
import 'package:aracfilo/common/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: fb.DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FleetFlow',
      theme: ThemeData(
        useMaterial3: true,
        // App'ın birincil rengi (ColorScheme.primary) sabitlenmedi.
        // Bileşenler (AppBar, Button, Link) kendi içinde AppColors.primary kullanıyor.
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
