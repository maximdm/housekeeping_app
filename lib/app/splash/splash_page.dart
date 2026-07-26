import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/database_helper.dart';
import '../../widgets/animations.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkAuth();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 1));

    final session = Supabase.instance.client.auth.currentSession;

    if (!mounted) return;

    if (session == null) {
      Routefly.navigate('/login');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Routefly.navigate('/login');
      return;
    }

    try {
      String? role;
      try {
        final data = await Supabase.instance.client
            .from('staff')
            .select('role')
            .eq('user_id', user.id)
            .eq('is_active', true)
            .maybeSingle();
        role = data?['role'] as String?;
      } catch (e) {
        debugPrint('Error loading staff role, trying cache: $e');
        try {
          final db = await DatabaseHelper.database;
          if (db != null) {
            final rows = await db.query(
              'staff_cache',
              where: 'user_id = ? AND is_active = 1',
              whereArgs: [user.id],
            );
            if (rows.isNotEmpty) {
              role = rows.first['role'] as String?;
            }
          }
        } catch (e2) {
          debugPrint('Error loading role from cache: $e2');
        }
      }

      if (!mounted) return;

      if (role == null) {
        await Supabase.instance.client.auth.signOut();
        Routefly.navigate('/login');
        return;
      }

      // Check keepLoggedIn preference
      final prefs = await SharedPreferences.getInstance();
      final keepLoggedIn = prefs.getBool('keepLoggedIn_${user.id}') ?? true;

      if (!keepLoggedIn) {
        await Supabase.instance.client.auth.signOut();
        Routefly.navigate('/login');
        return;
      }

      if (role == 'receptionist' || role == 'manager') {
        Routefly.navigate('/admin/overview');
      } else {
        Routefly.navigate('/staff/home/staff_dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      Routefly.navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleInWidget(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 600),
              beginScale: 0.5,
              child: Image.asset(
                'assets/icons/icon_hk_app.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 24),
            ScaleInWidget(
              delay: const Duration(milliseconds: 400),
              duration: const Duration(milliseconds: 500),
              child: FadeTransition(
                opacity: _pulseAnim,
                child: Text(
                  'Housekeeping',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ScaleInWidget(
              delay: const Duration(milliseconds: 600),
              duration: const Duration(milliseconds: 400),
              child: const CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
