import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_state.dart';
import '../../shared/widgets/app_button.dart';

/// The one login screen for every role (Super Admin, academy admin,
/// coach, student, parent) - go_router's redirect sends people to the
/// right place after this succeeds, see app_router.dart. Kept
/// deliberately plain: one logo, two fields, one button, so a manager
/// who's never used an app like this before isn't guessing what to do.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberCredentials = true;
  bool _hasCachedCredentials = false;
  String? _error;
  bool _loading = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _loadCachedCredentials();
  }

  Future<void> _loadCachedCredentials() async {
    try {
      final creds = await context.read<AuthState>().getSavedCredentials();
      final email = creds['email'] as String? ?? '';
      final password = creds['password'] as String? ?? '';
      final remember = creds['remember'] as bool? ?? true;

      if (mounted) {
        setState(() {
          if (email.isNotEmpty) _emailController.text = email;
          if (password.isNotEmpty) _passwordController.text = password;
          _rememberCredentials = remember;
          _hasCachedCredentials = email.isNotEmpty && password.isNotEmpty;
          _initializing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthState>().login(
            email,
            password,
            rememberCredentials: _rememberCredentials,
          );
      // go_router's redirect sends the user to the right screen
      // automatically once AuthState updates - nothing to do here.
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '').replaceAll('Login failed: ', '').trim();
      if (msg.contains('Account is not accessible') || msg.contains('suspended')) {
        setState(() => _error = 'Account is not accessible, contact owner');
      } else {
        setState(() => _error = msg.isNotEmpty ? msg : "Invalid email or password. Please check your credentials.");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearDeviceCache() async {
    await context.read<AuthState>().clearSavedCredentials();
    setState(() {
      _emailController.clear();
      _passwordController.clear();
      _hasCachedCredentials = false;
      _error = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved credentials cleared from this device.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header
                  Hero(
                    tag: 'app_logo',
                    child: Image.asset('assets/images/logo.png', height: 110),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'AcD-Man',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Color(0xFF1E2142),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Academy Management Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Saved Credentials Indicator
                  if (_hasCachedCredentials && !_initializing) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phonelink_lock_rounded, color: Color(0xFF2E7D32), size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Device credentials ready for fast login',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _clearDeviceCache,
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF2E7D32)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Email Field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'admin@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      suffixIcon: _emailController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _emailController.clear()),
                            )
                          : null,
                    ),
                    onChanged: (_) {
                      if (_hasCachedCredentials) setState(() => _hasCachedCredentials = false);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    onSubmitted: (_) => _loading ? null : _submit(),
                    onChanged: (_) {
                      if (_hasCachedCredentials) setState(() => _hasCachedCredentials = false);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Remember Me / Device Cache Checkbox
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _rememberCredentials,
                          activeColor: const Color(0xFF1E2142),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) => setState(() => _rememberCredentials = val ?? true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _rememberCredentials = !_rememberCredentials),
                          child: Text(
                            'Remember credentials on this device',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Error Display
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Login CTA Button
                  AppButton(
                    label: _loading ? 'Logging in...' : 'Login',
                    onPressed: _loading ? null : _submit,
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Protected session • Auto-logout on close & inactivity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

