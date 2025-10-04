import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:aracfilo/app_router/app_routes.dart';
import 'package:aracfilo/auth/auth_service.dart';
import 'package:aracfilo/common/widgets/inputs.dart';
import 'package:flutter/foundation.dart';

enum _UserRole { driver, owner }

const Color _kPrimary = Color(0xFF1E88E5);
const Color _kTextPrimary = Color(0xFF1F2937);
const Color _kTextSecondary = Color(0xFF6B7280);
const Color _kBg = Color(0xFFF7F9FC);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _isLoading = false;
  _UserRole _role = _UserRole.driver;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (kDebugMode) debugPrint('[Login] email login start role=$_role');
    setState(() => _isLoading = true);
    try {
      final expected = _role == _UserRole.driver ? 'driver' : 'owner';
      final result = await AuthService.signInWithEmailRoleChecked(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final actualRole = result.role;
      if (actualRole.isEmpty) {
        // İlk kez atanmadıysa seçilen rolü ata
        await AuthService.ensureUserRole(result.cred.user!.uid, expected);
      } else if (actualRole != expected) {
        // Yanlış rolde giriş denemesi
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu hesap farklı rol için kayıtlı. Lütfen doğru rolü seçin.')),
        );
        return;
      }
      if (!mounted) return;
      final route = expected == 'driver' ? AppRoutes.driverHome : AppRoutes.ownerHome;
      if (kDebugMode) debugPrint('[Login] navigate -> $route');
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
    } catch (e) {
      if (kDebugMode) debugPrint('[Login] error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Giriş başarısız: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 8),
                _buildRoleSelector(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
                    child: const Text('Şifremi Unuttum'),
                  ),
                ),
                const SizedBox(height: 8),
                _buildPrimaryButton(),
                const SizedBox(height: 16),
                _buildDividerWithText('veya'),
                const SizedBox(height: 16),
                _buildGoogleButton(),
                const SizedBox(height: 16),
                _buildRegisterLine(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.local_taxi, size: 72, color: _kPrimary),
        ),
        const SizedBox(height: 20),
        const Text(
          'Hoş Geldiniz',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _kTextPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'FleetFlow hesabınıza giriş yapın',
          style: TextStyle(fontSize: 14, color: _kTextSecondary),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return AppTextField(
      label: 'E-posta',
      hint: 'ornek@email.com',
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      prefixIcon: Icons.email_outlined,
      validator: (v) {
        if (v == null || v.isEmpty) return 'E-posta adresi gerekli';
        final ok = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v);
        return ok ? null : 'Geçerli bir e-posta adresi girin';
      },
    );
  }

  Widget _buildPasswordField() {
    return AppTextField(
      label: 'Şifre',
      hint: 'Şifrenizi girin',
      controller: _passwordController,
      obscureText: _obscure,
      prefixIcon: Icons.lock_outline,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Şifre gerekli';
        if (v.length < 8) return 'Şifre en az 8 karakter olmalı';
        return null;
      },
      suffix: IconButton(
        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }

  Widget _buildRoleSelector() {
    final isDriver = _role == _UserRole.driver;
    return Center(
      child: ToggleButtons(
        isSelected: [isDriver, !isDriver],
        onPressed: (index) {
          setState(() => _role = index == 0 ? _UserRole.driver : _UserRole.owner);
        },
        borderRadius: BorderRadius.circular(10),
        constraints: const BoxConstraints(minHeight: 36, minWidth: 120),
        color: _kTextSecondary,
        selectedColor: Colors.white,
        fillColor: _kPrimary,
        borderColor: Colors.grey.shade300,
        selectedBorderColor: _kPrimary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Sürücü'),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Filo Sahibi'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      child: PrimaryButton(
        onPressed: _isLoading ? null : _onLogin,
        text: 'E-posta ile Giriş Yap',
        isLoading: _isLoading,
      ),
    );
  }

  Widget _buildDividerWithText(String text) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: const TextStyle(color: _kTextSecondary)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: () async {
        try {
          if (kDebugMode) debugPrint('[Login] google login start role=$_role');
          final cred = await AuthService.signInWithGoogle();
          if (!mounted) return;
          if (cred != null) {
            final expected = _role == _UserRole.driver ? 'driver' : 'owner';
            final uid = cred.user!.uid;
            // Firestore'daki mevcut rolü oku
            final currentRole = await AuthService.getUserRole(uid);

            if (currentRole == null || currentRole.isEmpty) {
              // İlk giriş: seçili rolü onaylat
              final confirmed = await _confirmRoleDialog(expected);
              if (confirmed != true) {
                await FirebaseAuth.instance.signOut();
                return;
              }
              await AuthService.ensureUserRole(uid, expected);
            } else if (currentRole != expected) {
              // Rol uyuşmazsa engelle ve çıkış yap
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                if (kDebugMode) debugPrint('[Login] google role mismatch: expected=$expected current=$currentRole');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bu hesap farklı bir rol için kayıtlı. Lütfen doğru rolü seçin.')),
                );
              }
              return;
            }

            final route = expected == 'driver' ? AppRoutes.driverHome : AppRoutes.ownerHome;
            if (mounted) {
              if (kDebugMode) debugPrint('[Login] google navigate -> $route');
              Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[Login] google error: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google ile giriş başarısız: $e')),
          );
        }
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.grey.shade300),
        backgroundColor: Colors.white,
        foregroundColor: _kTextPrimary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/google-icon.svg',
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 10),
          const Text('Google ile Giriş Yap'),
        ],
      ),
    );
  }

  Future<bool?> _confirmRoleDialog(String expectedRole) async {
    final roleText = expectedRole == 'driver' ? 'Sürücü' : 'Filo Sahibi';
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rolü Onayla'),
          content: Text('Bu hesap için rolünüz "$roleText" olarak kaydedilecek. Onaylıyor musunuz?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Onayla')),
          ],
        );
      },
    );
  }

  Widget _buildRegisterLine() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Hesabınız yok mu? ', style: TextStyle(color: _kTextSecondary)),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushNamed(AppRoutes.register);
          },
          child: const Text('Kayıt Ol'),
        ),
      ],
    );
  }
}

// G özel ikon kodları kaldırıldı