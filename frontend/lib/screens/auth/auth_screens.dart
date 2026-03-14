// ── login_screen.dart ─────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../core/theme.dart';
import '../../providers/all_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).login(_emailCtrl.text.trim(), _passCtrl.text);
      if (mounted) context.go('/dashboard');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data['detail'] ?? 'Login failed');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sidebarBg,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.inventory, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text('CoreInventory', style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 16,
                )),
              ]),
              const SizedBox(height: 32),
              Text('Welcome back', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 6),
              Text('Sign in to your account', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 28),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/auth/otp-reset'),
                  child: const Text('Forgot password?', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/auth/signup'),
                  child: const Text("Don't have an account? Sign up", style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── signup_screen.dart ────────────────────────────────────────────────────────
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signup() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signup(_nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
      if (mounted) context.go('/auth/login');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data['detail'] ?? 'Signup failed');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sidebarBg,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create account', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
              const SizedBox(height: 14),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 14),
              TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signup,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/auth/login'),
                  child: const Text('Already have an account? Sign in', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── otp_reset_screen.dart ─────────────────────────────────────────────────────
class OtpResetScreen extends ConsumerStatefulWidget {
  const OtpResetScreen({super.key});
  @override
  ConsumerState<OtpResetScreen> createState() => _OtpResetScreenState();
}

class _OtpResetScreenState extends ConsumerState<OtpResetScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _requestOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).requestOtp(_emailCtrl.text.trim());
      setState(() { _otpSent = true; _success = 'OTP sent to your email'; });
    } on DioException catch (e) {
      setState(() => _error = e.response?.data['detail'] ?? 'Failed to send OTP');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).verifyOtp(_emailCtrl.text.trim(), _otpCtrl.text.trim(), _passCtrl.text);
      if (mounted) context.go('/auth/login');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data['detail'] ?? 'Verification failed');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sidebarBg,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reset Password', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                const SizedBox(height: 12),
              ],
              if (_success != null) ...[
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(_success!, style: const TextStyle(color: AppTheme.success, fontSize: 13))),
                const SizedBox(height: 12),
              ],
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), enabled: !_otpSent),
              if (_otpSent) ...[
                const SizedBox(height: 14),
                TextField(controller: _otpCtrl, decoration: const InputDecoration(labelText: 'OTP Code'), keyboardType: TextInputType.number),
                const SizedBox(height: 14),
                TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New Password')),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_otpSent ? _verifyOtp : _requestOtp),
                  child: Text(_otpSent ? 'Reset Password' : 'Send OTP'),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: TextButton(onPressed: () => context.go('/auth/login'), child: const Text('Back to Sign In'))),
            ],
          ),
        ),
      ),
    );
  }
}
