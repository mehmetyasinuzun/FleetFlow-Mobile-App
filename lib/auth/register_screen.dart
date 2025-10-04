import 'package:flutter/material.dart';
import 'package:aracfilo/common/app_bars.dart';
import 'package:aracfilo/app_router/app_routes.dart';
import 'package:aracfilo/auth/auth_service.dart';
import 'package:aracfilo/common/widgets/inputs.dart';

// Register ekranı (yalın, sadece Flutter UI)
const Color _kPrimary = Color(0xFF1E88E5);
const Color _kTextPrimary = Color(0xFF1F2937);
const Color _kTextSecondary = Color(0xFF6B7280);
const Color _kBg = Color(0xFFF7F9FC);

enum _UserRole { driver, owner }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _UserRole _role = _UserRole.driver;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final role = _role == _UserRole.driver ? 'driver' : 'owner';
      await AuthService.registerWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: role,
      );
      if (!mounted) return;
      final route = role == 'driver' ? AppRoutes.driverHome : AppRoutes.ownerHome;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt başarısız: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: const PrimaryAppBar(title: 'Kayıt Ol'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Yeni Hesap Oluştur',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'FleetFlow ailesine katılın',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: _kTextSecondary),
                ),
                const SizedBox(height: 24),

                AppTextField(
                  label: 'Ad Soyad',
                  hint: 'Adınızı ve soyadınızı girin',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline,
                  validator: (v) => (v == null || v.isEmpty) ? 'Ad soyad zorunludur' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'E-posta',
                  hint: 'ornek@email.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'E-posta zorunludur';
                    final ok = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v);
                    return ok ? null : 'Geçerli bir e-posta adresi girin';
                  },
                ),
                const SizedBox(height: 14),
                _buildRoleSegmented(),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Şifre',
                  hint: 'En az 8 karakter',
                  controller: _passwordController,
                  obscureText: _obscure1,
                  prefixIcon: Icons.lock_outline,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Şifre zorunludur';
                    if (v.length < 8) return 'Şifre en az 8 karakter olmalıdır';
                    return null;
                  },
                  suffix: IconButton(
                    icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Şifre Tekrar',
                  hint: 'Şifrenizi tekrar girin',
                  controller: _confirmPasswordController,
                  obscureText: _obscure2,
                  prefixIcon: Icons.lock_outline,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Şifre tekrarı zorunludur';
                    if (v != _passwordController.text) return 'Şifreler eşleşmiyor';
                    return null;
                  },
                  suffix: IconButton(
                    icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  onPressed: _isLoading ? null : _onRegister,
                  text: 'Kayıt Ol',
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                _buildLoginLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSegmented() {
    final isDriver = _role == _UserRole.driver;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Hesap Türü', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        Center(
          child: ToggleButtons(
            isSelected: [isDriver, !isDriver],
            onPressed: (index) => setState(() => _role = index == 0 ? _UserRole.driver : _UserRole.owner),
            borderRadius: BorderRadius.circular(10),
            constraints: const BoxConstraints(minHeight: 36, minWidth: 120),
            color: _kTextSecondary,
            selectedColor: Colors.white,
            fillColor: _kPrimary,
            borderColor: Colors.grey.shade300,
            selectedBorderColor: _kPrimary,
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Sürücü')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Filo Sahibi')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Zaten hesabınız var mı? ', style: TextStyle(color: _kTextSecondary)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Giriş Yap'),
        ),
      ],
    );
  }
}