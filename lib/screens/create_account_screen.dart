import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/user_provider.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  int _selectedRoleIndex = 0; // 0: Household, 1: Collector
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _statusMessage = '';
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  final List<Map<String, dynamic>> _roles = [
    {
      'title': 'Household / Resident',
      'subtitle': 'Request waste pickups',
      'icon': Icons.home,
    },
    {
      'title': 'Collector / Driver',
      'subtitle': 'Pick up scheduled waste',
      'icon': Icons.local_shipping,
    },
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _setStatus(String message) {
    if (mounted) {
      setState(() => _statusMessage = message);
    }
  }

  /// Creates the user profile in Supabase with retry logic.
  Future<bool> _createProfileWithRetry(String userId, {int maxAttempts = 5}) async {
    final phone = '+254${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _setStatus('Creating profile (attempt $attempt/$maxAttempts)...');
        
        final supabase = Supabase.instance.client;
        
        // First check if profile already exists
        final existing = await supabase
            .from('profiles')
            .select('id')
            .eq('id', userId)
            .maybeSingle();

        if (existing != null) {
          // Profile exists — update it with the latest info
          _setStatus('Updating profile info...');
          await supabase.from('profiles').update({
            'full_name': _nameController.text.trim(),
            'role': _selectedRoleIndex == 0 ? 'resident' : 'collector',
            'phone': phone,
            'email': _emailController.text.trim(),
          }).eq('id', userId);
          return true;
        }

        // Create the profile with ALL user information
        await supabase.from('profiles').insert({
          'id': userId,
          'full_name': _nameController.text.trim(),
          'role': _selectedRoleIndex == 0 ? 'resident' : 'collector',
          'phone': phone,
          'email': _emailController.text.trim(),
          'eco_points': 500,
          'co2_saved': 0,
        });

        _setStatus('Profile created successfully!');
        return true;
      } catch (e) {
        debugPrint('Profile creation attempt $attempt/$maxAttempts failed: $e');
        
        if (attempt < maxAttempts) {
          final delay = Duration(milliseconds: (800 * attempt).clamp(800, 5000));
          _setStatus('Retrying profile setup in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      }
    }
    return false;
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating your account...';
    });
    
    try {
      final supabase = Supabase.instance.client;
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      // Step 1: Auth signup with retry
      AuthResponse? response;
      Exception? authError;
      
      for (int attempt = 1; attempt <= 5; attempt++) {
        try {
          _setStatus('Creating account (attempt $attempt/5)...');
          response = await supabase.auth.signUp(
            email: email,
            password: password,
            data: {
              'full_name': _nameController.text.trim(),
              'phone': '+254${_phoneController.text.replaceAll(RegExp(r'\D'), '')}',
            },
          );
          
          if (response.user != null) {
            _setStatus('Account created!');
            break;
          }
        } on AuthException catch (e) {
          final msg = e.message.toLowerCase();
          // Don't retry for definitive auth errors
          if (msg.contains('already registered') ||
              msg.contains('already been registered') ||
              msg.contains('duplicate') ||
              msg.contains('user already exists') ||
              msg.contains('rate') ||
              msg.contains('limit') ||
              msg.contains('exceeded') ||
              msg.contains('invalid') ||
              msg.contains('weak password')) {
            rethrow;
          }
          authError = e;
          debugPrint('Auth attempt $attempt failed: ${e.message}');
          
          if (attempt < 5) {
            final delay = Duration(milliseconds: (800 * attempt).clamp(800, 5000));
            _setStatus('Retrying in ${delay.inSeconds}s...');
            await Future.delayed(delay);
          }
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('already registered') ||
              msg.contains('duplicate') ||
              msg.contains('rate') ||
              msg.contains('limit')) {
            rethrow;
          }
          
          authError = e is Exception ? e : Exception(e.toString());
          debugPrint('Auth attempt $attempt failed: $e');
          
          if (attempt < 5) {
            final delay = Duration(milliseconds: (800 * attempt).clamp(800, 5000));
            _setStatus('Retrying in ${delay.inSeconds}s...');
            await Future.delayed(delay);
          }
        }
      }

      if (response?.user == null) {
        throw authError ?? Exception('Signup failed after 5 attempts. Please check your internet connection.');
      }

      // Step 2: Auto sign-in if needed (some Supabase configs require confirmation)
      if (response!.session == null) {
        _setStatus('Signing you in...');
        try {
          await supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } catch (e) {
          debugPrint('Auto sign-in failed (email confirmation may be required): $e');
          // Continue anyway — profile creation will use the user ID we already have
        }
      }

      // Step 3: Create profile with retry
      final profileCreated = await _createProfileWithRetry(response.user!.id);
      
      if (!profileCreated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created but profile setup failed. Please try logging in — your profile will be set up automatically.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }

      if (!mounted) return;

      // Step 4: Load user data
      _setStatus('Loading your data...');
      await context.read<UserProvider>().loadUserData();

      if (!mounted) return;
      
      // Step 5: Show Success Dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.stars, color: AppColors.primary, size: 60),
              SizedBox(height: 16),
              Text('Welcome!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Congratulations! You\'ve successfully created your account and earned a 500 Eco-Points bonus to start your journey. 🌍',
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Let\'s Go!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      final route = _selectedRoleIndex == 1 ? '/collector-dashboard' : '/home';
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text(
                'Join Nairobi\'s waste\nmanagement\ncommunity.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Both email and phone number are required to create your account.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // ─── Full Name ─────────────────────────────────────
              _buildLabel('Full Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  hint: 'e.g. Muthoni Njeri',
                  prefixIcon: Icons.person_outline,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter your full name';
                  if (value.trim().length < 2) return 'Name too short';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ─── Email Address (MANDATORY) ──────────────────────
              _buildLabel('Email Address'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  hint: 'name@example.com',
                  prefixIcon: Icons.email_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Email is required';
                  final trimmed = value.trim();
                  if (!trimmed.contains('@') || !trimmed.contains('.')) {
                    return 'Enter a valid email address';
                  }
                  if (trimmed.length < 5) return 'Email is too short';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ─── Phone Number (MANDATORY) ───────────────────────
              _buildLabel('Phone Number'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      '+254',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        hint: '7XX XXX XXX',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Phone number is required';
                        final digits = value.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 9) return 'Enter a valid phone number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ─── Password ──────────────────────────────────────
              _buildLabel('Password'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _inputDecoration(
                  hint: 'Min 6 characters',
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
                  if (value == null || value.isEmpty) return 'Enter a password';
                  if (value.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // ─── Role Selection ────────────────────────────────
              const Text(
                'I am a:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              ...List.generate(_roles.length, (index) {
                final role = _roles[index];
                final isSelected = _selectedRoleIndex == index;
                
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedRoleIndex = index);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            role['icon'],
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role['title'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                role['subtitle'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),

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

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
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
                      : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text(
                      'Log in',
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: AppColors.textPrimary,
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
