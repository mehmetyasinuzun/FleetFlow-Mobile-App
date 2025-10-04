import 'package:flutter/material.dart';

import 'package:aracfilo/auth/splash_screen.dart';
import 'package:aracfilo/auth/login_screen.dart';
import 'package:aracfilo/auth/register_screen.dart';
import 'package:aracfilo/auth/forgot_password_screen.dart';
import 'package:aracfilo/driver/driver_ana_ekran.dart';
import 'package:aracfilo/driver/tum_gecmis_turlarim_ekran.dart';
import 'package:aracfilo/driver/map/driver_map_screen.dart';
import 'package:aracfilo/driver/arac_talep.dart';
import 'package:aracfilo/owner/owner_ana_ekran.dart';
import 'package:aracfilo/common/role_guard.dart';
import 'package:aracfilo/common/firebase_debug_screen.dart';

import 'app_routes.dart';
import 'package:aracfilo/common/not_found_page.dart';
import 'package:flutter/foundation.dart';

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (kDebugMode) {
      debugPrint('[AppRouter] onGenerateRoute -> ${settings.name}');
    }
    switch (settings.name) {
      case AppRoutes.splash:
        return _material(const SplashScreen(), settings);
      case AppRoutes.login:
        return _material(const LoginScreen(), settings);
      case AppRoutes.register:
        return _material(const RegisterScreen(), settings);
      case AppRoutes.forgotPassword:
        return _material(const ForgotPasswordScreen(), settings);
      case AppRoutes.driverHome:
        return _material(
          const RoleGuard(requiredRole: 'driver', child: DriverAnaEkran()),
          settings,
        );
      case AppRoutes.ownerHome:
        return _material(
          const RoleGuard(requiredRole: 'owner', child: OwnerAnaEkran()),
          settings,
        );
      case AppRoutes.driverTours:
        return _material(
          const RoleGuard(requiredRole: 'driver', child: TumGecmisTurlarimEkran()),
          settings,
        );
      case AppRoutes.mapScreen:
        return _material(
          const RoleGuard(requiredRole: 'driver', child: MapScreen()),
          settings,
        );
      case AppRoutes.vehicleRequest:
        return _material(
          const RoleGuard(requiredRole: 'driver', child: AracTalepScreen()),
          settings,
        );
      case AppRoutes.firebaseDebug:
        return _material(
          const FirebaseDebugScreen(),
          settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const NotFoundPage(),
          settings: const RouteSettings(name: '404'),
        );
    }
  }

  static MaterialPageRoute _material(Widget child, RouteSettings settings) =>
      MaterialPageRoute(builder: (_) => child, settings: settings);
}

// NotFoundPage ortak bileşen olarak lib/common/not_found_page.dart içine taşındı.
