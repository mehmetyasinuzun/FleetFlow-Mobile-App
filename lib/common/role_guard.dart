import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:aracfilo/app_router/app_routes.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// RoleGuard: Belirli bir rol gerektiren sayfaları korur.
/// requiredRole: 'driver' | 'owner'
class RoleGuard extends StatefulWidget {
  const RoleGuard({super.key, required this.requiredRole, required this.child});

  final String requiredRole;
  final Widget child;

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<String?>? _roleFuture;
  int _retry = 0; // future invalidation için tutuluyor

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    final user = _auth.currentUser;
    if (user != null) {
      if (kDebugMode) debugPrint('[RoleGuard] prepare uid=${user.uid}');
      final docRef = _db.collection('users').doc(user.uid);
      // Stream + timeout ile daha sağlam okuma
      _roleFuture = docRef
          .snapshots()
          .map((d) => (d.data()?['role'] as String?))
          .first
          .timeout(const Duration(seconds: 8), onTimeout: () {
        if (kDebugMode) debugPrint('[RoleGuard] role fetch TIMEOUT');
        throw TimeoutException('Rol bilgisi zaman aşımına uğradı');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (kDebugMode) debugPrint('[RoleGuard] authState waiting');
          return const _GuardLoading();
        }
        if (user == null) {
          if (kDebugMode) debugPrint('[RoleGuard] user=null -> go login');
          // Oturum yok → login'e yönlendir
          return _UnauthorizedScaffold(
            message: 'Oturum bulunamadı. Lütfen giriş yapın.',
            actionText: 'Giriş Yap',
            onAction: () => Navigator.of(context)
                .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false),
          );
        }

        // Kullanıcı var → rolü kontrol et
        _roleFuture ??= (() {
          final docRef = _db.collection('users').doc(user.uid);
          return docRef
              .snapshots()
              .map((d) => (d.data()?['role'] as String?))
              .first
              .timeout(const Duration(seconds: 8), onTimeout: () {
            if (kDebugMode) debugPrint('[RoleGuard] role fetch TIMEOUT (builder)');
            throw TimeoutException('Rol bilgisi zaman aşımına uğradı');
          });
        })();

        return FutureBuilder<String?>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              if (kDebugMode) debugPrint('[RoleGuard] role waiting');
              return const _GuardLoading();
            }
            if (roleSnap.hasError) {
              final err = roleSnap.error;
              if (kDebugMode) debugPrint('[RoleGuard] role error: $err');
              return _UnauthorizedScaffold(
                message: 'Rol bilgisi okunamadı (deneme #$_retry). Hata: $err',
                actionText: 'Tekrar Dene',
                onAction: () {
                  setState(() {
                    _retry++;
                    _roleFuture = null;
                    _prepare();
                  });
                },
              );
            }
            final role = roleSnap.data;
            if (kDebugMode) debugPrint('[RoleGuard] have role=$role need=${widget.requiredRole}');
            if (role == null || role.isEmpty) {
              // Rol atanmadı → giriş sayfasına yönlendir (veya rol seçim ekranı ileride)
              return _UnauthorizedScaffold(
                message: 'Hesabınız için rol atanmadı. Lütfen giriş ekranından rolünüzle giriş yapın.',
                actionText: 'Giriş Ekranına Dön',
                onAction: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false),
              );
            }

            if (role != widget.requiredRole) {
              if (kDebugMode) debugPrint('[RoleGuard] role mismatch: $role');
              // Yetkisiz erişim
              final correctRoute = role == 'driver' ? AppRoutes.driverHome : AppRoutes.ownerHome;
              return _UnauthorizedScaffold(
                message: 'Bu sayfaya erişim izniniz yok. (Gerekli rol: ${widget.requiredRole})',
                actionText: 'Doğru Ana Ekrana Git',
                onAction: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(correctRoute, (r) => false),
                extra: TextButton(
                  onPressed: () async {
                    await _auth.signOut();
                    if (context.mounted) {
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
                    }
                  },
                  child: const Text('Çıkış Yap'),
                ),
              );
            }

            // Rol uygun → sayfayı göster
            return widget.child;
          },
        );
      },
    );
  }
}

class _GuardLoading extends StatelessWidget {
  const _GuardLoading();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _UnauthorizedScaffold extends StatelessWidget {
  const _UnauthorizedScaffold({
    required this.message,
    required this.actionText,
    required this.onAction,
    this.extra,
  });

    final String message;
    final String actionText;
    final VoidCallback onAction;
    final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionText)),
              if (extra != null) ...[
                const SizedBox(height: 8),
                extra!,
              ]
            ],
          ),
        ),
      ),
    );
  }
}
