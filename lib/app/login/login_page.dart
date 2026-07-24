import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';
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
  bool _keepLoggedIn = true;
  String? _error;

  bool get _isCleaner => _selectedStaff?['role'] == 'cleaner';

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
      setState(() => _error = localizations.tr('pleaseSelectName'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final role = _selectedStaff!['role'] ?? '';

      if (role == 'cleaner') {
        await _authService.signInCleaner(
          _selectedStaff!['account_name']!,
          _selectedStaff!['name']!,
          _selectedStaff!['id']!,
        );
      } else {
        final email = _selectedStaff!['login_email'] ?? '';
        if (email.isEmpty) {
          setState(() {
            _error = localizations.tr('accountNotSetUp');
            _loading = false;
          });
          return;
        }
        await _authService.signIn(email, _passwordController.text.trim());
      }

      if (!mounted) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = localizations.tr('loginFailed');
          _loading = false;
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('keepLoggedIn_${user.id}', _keepLoggedIn);

      final data = await Supabase.instance.client
          .from('staff')
          .select('role')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _error = localizations.tr('noStaffAccount');
          _loading = false;
        });
        return;
      }

      final roleFromDb = data['role'] as String;
      if (roleFromDb == 'receptionist' || roleFromDb == 'manager') {
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
        _error = localizations.tr('loginFailed');
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
                  // Language selector
                  _buildLanguageSelector(),
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/icons/icon_hk_log_in.png',
                    width: 120,
                    height: 120,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.tr('appTitle'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.tr('signInToContinue'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  if (_loadingStaff)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<Map<String, String>>(
                      initialValue: _selectedStaff,
                      decoration: InputDecoration(
                        labelText: localizations.tr('yourName'),
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
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
                        if (value == null) return localizations.tr('pleaseSelectName');
                        return null;
                      },
                    ),

                  const SizedBox(height: 16),

                  if (!_isCleaner)
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: localizations.tr('password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return localizations.tr('pleaseEnterPassword');
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

                  Row(
                    children: [
                      Checkbox(
                        value: _keepLoggedIn,
                        onChanged: (v) => setState(() => _keepLoggedIn = v ?? true),
                      ),
                      Text(localizations.tr('keepLoggedIn')),
                    ],
                  ),
                  const SizedBox(height: 8),

                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(localizations.tr('signIn')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return ListenableBuilder(
      listenable: localizations,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFlagButton(
              emoji: '\u{1F1EC}\u{1F1E7}', // GB flag
              language: AppLanguage.en,
              label: 'EN',
            ),
            const SizedBox(width: 12),
            _buildFlagButton(
              emoji: '\u{1F1F7}\u{1F1F4}', // RO flag
              language: AppLanguage.ro,
              label: 'RO',
            ),
          ],
        );
      },
    );
  }

  Widget _buildFlagButton({
    required String emoji,
    required AppLanguage language,
    required String label,
  }) {
    final isSelected = localizations.language == language;
    return GestureDetector(
      onTap: () => localizations.setLanguage(language),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
