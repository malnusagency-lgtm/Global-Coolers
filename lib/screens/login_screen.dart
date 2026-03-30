import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _statusMessage = '';
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setStatus(String message) {
    if (mounted) {
      setState(() => _statusMessage = message);
    }
  }

  /// Ensures a profile exists for the given user. If not, creates one.
  Future<void> _ensureProfileExists(String userId, String email) async {
    try {
      final supabase = Supabase.instance.client;
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        _setStatus('Setting up your profile...');
        await supabase.from('profiles').insert({
          'id': userId,
          'full_name': email.split('@').first,
          'role': 'resident',
          'email': email,
          'eco_points': 500,
          'co2_saved': 0,
        });
      }
    } catch (e) {
      debugPrint('Profile check/create failed: $e');
      // Non-fatal — the app can still function
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Logging in...';
    });
    
    try {
      final supabase = Supabase.instance.client;
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      // Login with retry (up to 5 attempts for network resilience)
      AuthResponse? response;
      Exception? lastError;

      for (int attempt = 1; attempt <= 5; attempt++) {
        try {
          _setStatus('Logging in (attempt $attempt/5)...');
          response = await supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
          if (response.user != null) {
            _setStatus('Logged in!');
            break;
          }
        } on AuthException catch (e) {
          final msg = e.message.toLowerCase();
          // Don't retry for definitive errors
          if (msg.contains('invalid') ||
              msg.contains('credentials') ||
              msg.contains('not found') ||
              msg.contains('rate') ||
              msg.contains('limit') ||
              msg.contains('exceeded') ||
              msg.contains('email not confirmed')) {
            rethrow;
          }
          lastError = e;
          debugPrint('Login attempt $attempt failed: ${e.message}');
          
          if (attempt < 5) {
            final delay = Duration(milliseconds: (800 * attempt).clamp(800, 5000));
            _setStatus('Retrying in ${delay.inSeconds}s...');
            await Future.delayed(delay);
          }
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('invalid') || msg.contains('rate') || msg.contains('limit')) {
            rethrow;
          }
          lastError = e is Exception ? e : Exception(e.toString());
          debugPrint('Login attempt $attempt failed: $e');
          
          if (attempt < 5) {
            final delay = Duration(milliseconds: (800 * attempt).clamp(800, 5000));
            _setStatus('Retrying in ${delay.inSeconds}s...');
            await Future.delayed(delay);
          }
        }
      }

      if (response?.user == null) {
        throw lastError ?? Exception('Login failed after 5 attempts. Check your internet connection.');
      }

      if (!mounted) return;

      // Ensure profile exists (handles edge case from failed signup)
      await _ensureProfileExists(response!.user!.id, email);

      if (!mounted) return;

      // Load user data
      _setStatus('Loading your data...');
      await context.read<UserProvider>().loadUserData();

      if (!mounted) return;
      
      // Navigate based on role
      final userProvider = context.read<UserProvider>();
      final route = userProvider.role == AppRole.collector 
          ? '/collector-dashboard' 
          : '/home';
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Icon(Icons.eco, size: 48, color: AppColors.primary),
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Log in with your email and password to continue.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Email Address ────────────────────────────────
                const Text(
                  'Email Address',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(
                    hint: 'name@example.com',
                    prefixIcon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter your email';
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ─── Password ─────────────────────────────────────
                const Text(
                  'Password',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(
                    hint: 'Enter your password',
                    prefixIcon: Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter your password';
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Status message during loading
                if (_statusMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        if (_isLoading) ...[
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Don\'t have an account? ',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/create-account');
                      },
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }
}
