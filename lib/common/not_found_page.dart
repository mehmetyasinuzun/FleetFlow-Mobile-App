import 'package:flutter/material.dart';
import 'package:aracfilo/app_router/app_routes.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('Sayfa bulunamadı'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false),
              child: const Text('Ana sayfaya dön'),
            ),
          ],
        ),
      ),
    );
  }
}
