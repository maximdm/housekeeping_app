import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityService {
  static final ActivityService _instance = ActivityService._();
  factory ActivityService() => _instance;
  ActivityService._();

  final SupabaseClient _client = Supabase.instance.client;

  Future<void> log({
    required String action,
    Map<String, dynamic>? details,
  }) async {
    try {
      final user = _client.auth.currentUser;
      String? staffId;
      if (user != null) {
        final staffData = await _client
            .from('staff')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();
        staffId = staffData?['id'] as String?;
      }

      await _client.from('activity_log').insert({
        'staff_id': staffId,
        'action': action,
        'details': details,
      });
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      await _client.from('activity_log').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    } catch (e) {
      debugPrint('Error clearing activity: $e');
    }
  }
}
