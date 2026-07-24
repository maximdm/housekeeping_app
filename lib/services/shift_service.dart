import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shift.dart';

class ShiftService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  List<Shift> _shifts = [];
  List<Shift> get shifts => _shifts;

  Future<void> loadShifts() async {
    try {
      final data = await _client.from('shifts').select().order('start_time');
      _shifts = (data as List).map((j) => Shift.fromJson(j)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading shifts: $e');
    }
  }

  Future<bool> createShift({
    required String name,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? color,
  }) async {
    try {
      await _client.from('shifts').insert({
        'name': name,
        'start_time':
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'end_time':
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'color': color,
      });
      await loadShifts();
      return true;
    } catch (e) {
      debugPrint('Error creating shift: $e');
      return false;
    }
  }

  Future<bool> updateShift({
    required String id,
    required String name,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? color,
  }) async {
    try {
      await _client.from('shifts').update({
        'name': name,
        'start_time':
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'end_time':
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'color': color,
      }).eq('id', id);
      await loadShifts();
      return true;
    } catch (e) {
      debugPrint('Error updating shift: $e');
      return false;
    }
  }

  Future<bool> deleteShift(String id) async {
    try {
      await _client.from('shifts').delete().eq('id', id);
      await loadShifts();
      return true;
    } catch (e) {
      debugPrint('Error deleting shift: $e');
      return false;
    }
  }

  Future<bool> assignShiftToStaff({
    required String staffId,
    required String shiftId,
    required DateTime date,
  }) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      await _client.from('staff_shifts').upsert({
        'staff_id': staffId,
        'shift_id': shiftId,
        'assignment_date': dateStr,
      }, onConflict: 'staff_id,shift_id,assignment_date');
      return true;
    } catch (e) {
      debugPrint('Error assigning shift: $e');
      return false;
    }
  }

  Future<bool> unassignShiftFromStaff({
    required String staffId,
    required String shiftId,
    required DateTime date,
  }) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      await _client
          .from('staff_shifts')
          .delete()
          .eq('staff_id', staffId)
          .eq('shift_id', shiftId)
          .eq('assignment_date', dateStr);
      return true;
    } catch (e) {
      debugPrint('Error unassigning shift: $e');
      return false;
    }
  }

  Future<List<StaffShiftAssignment>> loadShiftAssignmentsForDate(
      DateTime date) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final data = await _client
          .from('staff_shifts')
          .select('''
            id, staff_id, shift_id, assignment_date,
            staff:staff(name),
            shift:shifts(name, start_time, end_time, color)
          ''')
          .eq('assignment_date', dateStr);
      return (data as List)
          .map((j) => StaffShiftAssignment.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('Error loading shift assignments: $e');
      return [];
    }
  }

  Future<List<StaffShiftAssignment>> loadMyShiftAssignmentsForDate(
      String staffId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final data = await _client
          .from('staff_shifts')
          .select('''
            id, staff_id, shift_id, assignment_date,
            shift:shifts(name, start_time, end_time, color)
          ''')
          .eq('staff_id', staffId)
          .eq('assignment_date', dateStr);
      return (data as List)
          .map((j) => StaffShiftAssignment.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('Error loading my shift assignments: $e');
      return [];
    }
  }

  Future<List<StaffShiftAssignment>> loadMyShiftAssignmentsForMonth(
      String staffId, DateTime month) async {
    try {
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);
      final from = firstDay.toIso8601String().substring(0, 10);
      final to = lastDay.toIso8601String().substring(0, 10);
      final data = await _client
          .from('staff_shifts')
          .select('''
            id, staff_id, shift_id, assignment_date,
            staff:staff(name),
            shift:shifts(name, start_time, end_time, color)
          ''')
          .eq('staff_id', staffId)
          .gte('assignment_date', from)
          .lte('assignment_date', to);
      return (data as List)
          .map((j) => StaffShiftAssignment.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('Error loading my monthly shifts: $e');
      return [];
    }
  }

  void clear() {
    _shifts.clear();
    notifyListeners();
  }
}
