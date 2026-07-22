import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/staff_schedule.dart';

class ScheduleService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  List<StaffSchedule> _schedules = [];
  List<StaffSchedule> get schedules => _schedules;

  Future<void> loadMonth(String staffId, DateTime month) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);

      final data = await _client
          .from('staff_schedules')
          .select()
          .eq('staff_id', staffId)
          .gte('date', start.toIso8601String().substring(0, 10))
          .lte('date', end.toIso8601String().substring(0, 10))
          .order('date');

      _schedules = (data as List)
          .map((json) => StaffSchedule.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    }
  }

  Future<void> toggleDay(String staffId, DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final existing = _schedules.where(
      (s) => s.staffId == staffId &&
          s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day,
    );

    try {
      if (existing.isNotEmpty) {
        final schedule = existing.first;
        final newIsOnShift = !schedule.isOnShift;
        await _client
            .from('staff_schedules')
            .update({'is_on_shift': newIsOnShift})
            .eq('id', schedule.id);
      } else {
        await _client.from('staff_schedules').insert({
          'staff_id': staffId,
          'date': dateStr,
          'is_on_shift': true,
        });
      }
      await loadMonth(staffId, date);
    } catch (e) {
      debugPrint('Error toggling schedule day: $e');
    }
  }

  bool isOnShift(DateTime date) {
    return _schedules.any(
      (s) =>
          s.isOnShift &&
          s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day,
    );
  }

  bool hasSchedule(DateTime date) {
    return _schedules.any(
      (s) =>
          s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day,
    );
  }

  void clear() {
    _schedules = [];
  }
}
