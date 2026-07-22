import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _authService = AuthService();

  List<Map<String, String>> _staffList = [];
  Map<String, String>? _selectedStaff;
  bool _loading = false;
  bool _loadingStaff = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _authService.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    final staff = await _authService.fetchStaffForLogin();
    if (mounted) {
      setState(() {
        _staffList = staff;
        _loadingStaff = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStaff == null) {
      setState(() => _error = 'Please select your name');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _selectedStaff!['login_email'] ?? '';
      if (email.isEmpty) {
        setState(() {
          _error = 'This account is not set up for login. Contact your administrator.';
          _loading = false;
        });
        return;
      }

      await _authService.signIn(email, _passwordController.text.trim());

      if (!mounted) return;

      // Navigate based on role
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Login failed. Please try again.';
          _loading = false;
        });
        return;
      }

      final data = await Supabase.instance.client
          .from('staff')
          .select('role')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _error = 'No staff account found. Contact your administrator.';
          _loading = false;
        });
        return;
      }

      final role = data['role'] as String;
      if (role == 'receptionist') {
        Routefly.navigate('/admin/overview');
      } else {
        Routefly.navigate('/staff/home/staff_dashboard');
      }
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Login failed. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.cleaning_services_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Housekeeping App',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Staff name dropdown
                  if (_loadingStaff)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<Map<String, String>>(
                      initialValue: _selectedStaff,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      items: _staffList.map((staff) {
                        return DropdownMenuItem(
                          value: staff,
                          child: Text(staff['account_name']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStaff = value;
                          _error = null;
                        });
                      },
                      validator: (value) {
                        if (value == null) return 'Please select your name';
                        return null;
                      },
                    ),

                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _login(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign In'),
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
