import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/staff_member.dart';
import 'database_helper.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isAuthenticated => currentSession != null;

  StaffMember? _currentStaff;
  StaffMember? get currentStaff => _currentStaff;

  StaffRole? get userRole => _currentStaff?.role;
  bool get isAdmin => userRole == StaffRole.receptionist || userRole == StaffRole.manager;
  bool get isManager => userRole == StaffRole.manager;
  bool get isCleaner => userRole == StaffRole.cleaner;

  StreamSubscription<AuthState>? _authSubscription;

  void init() {
    _authSubscription = _client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _fetchStaffProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        _currentStaff = null;
        notifyListeners();
      }
    });

    if (isAuthenticated) {
      _fetchStaffProfile();
    }
  }

  /// Fetch all active staff names for the login dropdown
  Future<List<Map<String, String>>> fetchStaffForLogin() async {
    try {
      final data = await _client
          .from('staff')
          .select('id, name, account_name, user_id, login_email, role')
          .eq('is_active', true)
          .order('name');

      return (data as List).map((json) => {
        'id': json['id'] as String,
        'name': json['name'] as String,
        'account_name': json['account_name'] as String? ?? '',
        'user_id': json['user_id'] as String? ?? '',
        'login_email': json['login_email'] as String? ?? '',
        'role': json['role'] as String? ?? 'cleaner',
      }).toList();
    } catch (e) {
      debugPrint('Error fetching staff for login: $e');
      return [];
    }
  }

  /// Generate a fake email from staff name and ID
  static String generateEmail(String name, String id) {
    final safeName = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final shortId = id.substring(0, 8);
    return '${safeName}_$shortId@hotel.local';
  }

  /// Sign in a cleaner without a password field (uses a known temp password)
  Future<bool> signInCleaner(String accountName, String name, String id) async {
    // Use the same fallback logic as createStaffAuth to match the email
    final effectiveName = accountName.isNotEmpty ? accountName : name;
    final email = generateEmail(effectiveName, id);
    final tempPassword = 'cleaner_$id';
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: tempPassword,
      );
      if (response.session != null) {
        await _fetchStaffProfile();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      // If "Invalid login credentials", the auth user may not exist yet.
      // Try to create it on the fly.
      if (e.message.contains('Invalid login credentials') ||
          e.message.contains('invalid')) {
        debugPrint('Auth user not found for cleaner $effectiveName, creating on the fly...');
        try {
          await _ensureCleanerAuthUser(effectiveName, id);
          final retry = await _client.auth.signInWithPassword(
            email: email,
            password: tempPassword,
          );
          if (retry.session != null) {
            await _fetchStaffProfile();
            return true;
          }
          return false;
        } catch (e2) {
          debugPrint('Failed to create cleaner auth user: $e2');
          rethrow;
        }
      }
      debugPrint('Cleaner sign in error: ${e.message}');
      rethrow;
    }
  }

  /// Ensure a cleaner has an auth user — creates one if missing.
  Future<void> _ensureCleanerAuthUser(String name, String id) async {
    final email = generateEmail(name, id);
    final tempPassword = 'cleaner_$id';

    final url = const String.fromEnvironment('SUPABASE_URL');
    final anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

    final response = await http.post(
      Uri.parse('$url/auth/v1/signup'),
      headers: {
        'apikey': anonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': tempPassword,
        'data': {},
      }),
    );

    String newUserId;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final result = jsonDecode(response.body);
      newUserId = (result['id'] as String?) ??
          (result['user'] as Map<String, dynamic>?)?['id'] as String? ?? '';
      if (newUserId.isEmpty) {
        throw Exception('Signup succeeded but no user ID returned');
      }
    } else {
      final body = jsonDecode(response.body);
      final errorCode = body['error_code'] as String?;
      if (errorCode == 'user_already_exists') {
        debugPrint('Auth user already exists for $email, looking up existing user...');
        final lookup = await http.get(
          Uri.parse('$url/auth/v1/admin/users?email=$email'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer ${_client.auth.currentSession?.accessToken ?? anonKey}',
          },
        );
        if (lookup.statusCode == 200) {
          final users = jsonDecode(lookup.body);
          final userList = users['users'] as List? ?? [];
          if (userList.isNotEmpty) {
            newUserId = userList[0]['id'] as String;
          } else {
            throw Exception('User already_exists but could not find user for $email');
          }
        } else {
          throw Exception('Failed to look up existing user: ${lookup.body}');
        }
      } else {
        throw Exception('Failed to create auth user: ${body['msg'] ?? response.body}');
      }
    }

    // Auto-confirm — safe to ignore if already confirmed
    try {
      await _client.rpc('auto_confirm_user', params: {
        'p_user_id': newUserId,
      });
    } catch (e) {
      debugPrint('Auto-confirm failed (non-fatal): $e');
    }

    // Link to staff record
    await _client.from('staff').update({
      'user_id': newUserId,
      'login_email': email,
    }).eq('id', id);
  }

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        await _fetchStaffProfile();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      debugPrint('Sign in error: ${e.message}');
      rethrow;
    }
  }

  /// Create a new staff auth user (called by admin)
  /// Uses direct HTTP call to Supabase signup endpoint, then auto-confirms.
  Future<({String email, String tempPassword})> createStaffAuth({
    required String staffId,
    required String name,
    required StaffRole role,
  }) async {
    final email = generateEmail(name, staffId);
    final tempPassword = role == StaffRole.cleaner
        ? 'cleaner_$staffId'
        : 'Temp${DateTime.now().millisecondsSinceEpoch % 10000}!';

    final url = const String.fromEnvironment('SUPABASE_URL');
    final anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

    // Direct HTTP signup — no client session needed
    final response = await http.post(
      Uri.parse('$url/auth/v1/signup'),
      headers: {
        'apikey': anonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': tempPassword,
        'data': {},
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['msg'] ?? 'Signup failed (${response.statusCode})');
    }

    final result = jsonDecode(response.body);
    debugPrint('Signup response: $result');

    // Handle different response shapes from GoTrue
    final newUserId = (result['id'] as String?) ??
        (result['user'] as Map<String, dynamic>?)?['id'] as String?;
    if (newUserId == null) {
      throw Exception('Signup succeeded but no user ID returned: $result');
    }

    // Auto-confirm the user via RPC (admin session) — safe to ignore if already confirmed
    try {
      await _client.rpc('auto_confirm_user', params: {
        'p_user_id': newUserId,
      });
      debugPrint('Auto-confirm succeeded');
    } catch (e) {
      debugPrint('Auto-confirm RPC failed (non-fatal): $e');
    }

    // Link the auth user to the staff record using admin session
    debugPrint('Linking staff $staffId to user $newUserId');
    await _client.from('staff').update({
      'user_id': newUserId,
      'login_email': email,
    }).eq('id', staffId);

    debugPrint('Staff linked successfully');
    return (email: email, tempPassword: tempPassword);
  }

  /// Change the current user's password
  Future<bool> changePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } on AuthException catch (e) {
      debugPrint('Change password error: ${e.message}');
      rethrow;
    }
  }

  /// Admin reset a staff member's password
  Future<({String tempPassword})?> resetStaffPassword(String staffId) async {
    try {
      final staff = await _client
          .from('staff')
          .select('user_id, name')
          .eq('id', staffId)
          .single();

      final userId = staff['user_id'] as String?;
      if (userId == null) return null;

      final tempPassword = 'Reset${DateTime.now().millisecondsSinceEpoch % 10000}!';

      await _client.rpc('reset_staff_password', params: {
        'p_user_id': userId,
        'p_new_password': tempPassword,
      });

      return (tempPassword: tempPassword);
    } catch (e) {
      debugPrint('Error resetting staff password: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    _currentStaff = null;
    notifyListeners();
  }

  Future<void> _fetchStaffProfile() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final data = await _client
          .from('staff')
          .select()
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (data != null) {
        _currentStaff = StaffMember.fromJson(data);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching staff profile, trying cache: $e');
      try {
        final db = await DatabaseHelper.database;
        if (db == null) return;
        final rows = await db.query(
          'staff_cache',
          where: 'user_id = ? AND is_active = 1',
          whereArgs: [user.id],
        );
        if (rows.isNotEmpty) {
          final row = rows.first;
          _currentStaff = StaffMember(
            id: row['id'] as String,
            userId: row['user_id'] as String?,
            name: row['name'] as String,
            accountName: row['account_name'] as String?,
            role: StaffRole.fromString(row['role'] as String),
            phone: row['phone'] as String?,
            isActive: (row['is_active'] as int) == 1,
            onShift: (row['on_shift'] as int) == 1,
          );
          notifyListeners();
        }
      } catch (e2) {
        debugPrint('Error loading staff profile from cache: $e2');
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
