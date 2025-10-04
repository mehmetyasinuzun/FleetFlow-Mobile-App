import 'package:flutter/material.dart';
import 'package:aracfilo/app_router/app_routes.dart';
import 'package:aracfilo/common/app_bars.dart';
import 'package:aracfilo/common/widgets/inputs.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Ekran stili: mevcut login/register ile uyumlu, yalın Flutter UI
const Color _kPrimary = Color(0xFF1E88E5);
const Color _kTextPrimary = Color(0xFF1F2937);
const Color _kTextSecondary = Color(0xFF6B7280);
const Color _kBg = Color(0xFFF7F9FC);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _emailSent = true;
      });
    } on FirebaseAuthException catch (e) {
      String msg = 'Bir hata oluştu. Lütfen tekrar deneyin.';
      switch (e.code) {
        case 'invalid-email':
          msg = 'Geçersiz e-posta adresi.';
          break;
        case 'user-not-found':
          msg = 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
          break;
        case 'missing-email':
          msg = 'E-posta adresi eksik.';
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beklenmeyen bir hata oluştu.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: const PrimaryAppBar(title: 'Şifre Sıfırlama'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _emailSent ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          // Icon
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_reset, size: 64, color: _kPrimary),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Şifrenizi mi Unuttunuz?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _kTextPrimary),
          ),
          const SizedBox(height: 12),
          const Text(
            'E-posta adresinizi girin, size şifre sıfırlama bağlantısı gönderelim.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _kTextSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),

          // Email field
          AppTextField(
            label: 'E-posta',
            hint: 'kayitli@email.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: (v) {
              if (v == null || v.isEmpty) return 'E-posta adresi gerekli';
              final ok = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v);
              return ok ? null : 'Geçerli bir e-posta adresi girin';
            },
          ),

          const SizedBox(height: 28),
          PrimaryButton(onPressed: _isLoading ? null : _sendReset, text: 'Sıfırlama Bağlantısı Gönder', isLoading: _isLoading),

          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Şifrenizi hatırladınız mı? ', style: TextStyle(color: _kTextSecondary)),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Giriş Yap'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read, size: 50, color: Colors.green),
        ),
        const SizedBox(height: 24),
        const Text(
          'E-posta Gönderildi!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _kTextPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          '${_emailController.text} adresine şifre sıfırlama bağlantısı gönderildi. E-posta kutunuzu kontrol edin.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: _kTextSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),
  PrimaryButton(onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false), text: 'Giriş Ekranına Dön'),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _emailSent = false),
          child: const Text('Tekrar Gönder'),
        ),
      ],
    );
  }
}
