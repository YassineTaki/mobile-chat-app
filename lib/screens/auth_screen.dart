// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _obscure = true;

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl     = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authNotifierProvider.notifier);
    bool ok;

    if (_isLogin) {
      ok = await auth.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } else {
      ok = await auth.register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        displayName: _nameCtrl.text.trim(),
      );
    }

    if (ok && mounted) context.go('/contacts');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final error = authState.hasError ? authState.error.toString() : null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Gap(40),

              // Logo
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.2), blurRadius: 30)],
                ),
                child: const Center(child: Text('🔐', style: TextStyle(fontSize: 36))),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const Gap(16),

              const Text('Vault', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.text))
                  .animate().fadeIn(delay: 100.ms),
              const Gap(6),
              Text(
                _isLogin ? 'Sign in to your encrypted account' : 'Create your encrypted identity',
                style: const TextStyle(fontSize: 13, color: AppColors.text2),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 150.ms),

              const Gap(32),

              // Toggle login/register
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _TabBtn(label: 'Sign In',  active: _isLogin,  onTap: () => setState(() => _isLogin = true)),
                    _TabBtn(label: 'Register', active: !_isLogin, onTap: () => setState(() => _isLogin = false)),
                  ],
                ),
              ),
              const Gap(20),

              // Name field (register only)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _isLogin ? const SizedBox.shrink() : Column(
                  children: [
                    _Field(ctrl: _nameCtrl, hint: 'Display name', icon: Icons.person_outline),
                    const Gap(10),
                  ],
                ),
              ),

              _Field(ctrl: _emailCtrl, hint: 'Email address', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
              const Gap(10),
              _Field(
                ctrl: _passwordCtrl,
                hint: 'Password',
                icon: Icons.lock_outline,
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.text3, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),

              // Error
              if (error != null) ...[
                const Gap(12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Text(error, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
                ),
              ],

              const Gap(20),

              // Register key-gen notice
              if (!_isLogin) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Text('🔑', style: TextStyle(fontSize: 16)),
                      Gap(10),
                      Expanded(child: Text(
                        'A RSA-2048 key pair will be generated and your private key stored in your device Keychain.',
                        style: TextStyle(fontSize: 12, color: AppColors.text2, height: 1.4),
                      )),
                    ],
                  ),
                ),
                const Gap(16),
              ],

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF0A1A12),
                    disabledBackgroundColor: AppColors.accent.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A1A12)))
                      : Text(
                          _isLogin ? 'Sign In' : 'Create Account & Generate Keys',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),
              ),

              const Gap(32),

              // Crypto badge row
              Wrap(
                spacing: 8, runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _CryptoBadge('🔑 RSA-2048'),
                  _CryptoBadge('⚡ AES-256-CBC'),
                  _CryptoBadge('🔒 E2E Encrypted'),
                  _CryptoBadge('📱 Keychain'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: active ? const Color(0xFF0A1A12) : AppColors.text2),
        ),
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboard;
  final Widget? suffix;
  const _Field({required this.ctrl, required this.hint, required this.icon, this.obscure = false, this.keyboard = TextInputType.text, this.suffix});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    obscureText: obscure,
    keyboardType: keyboard,
    style: const TextStyle(fontSize: 15, color: AppColors.text),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.text3, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

class _CryptoBadge extends StatelessWidget {
  final String label;
  const _CryptoBadge(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text3, fontFamily: 'DMMono')),
  );
}
