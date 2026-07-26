import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shift.dart';
import 'database_helper.dart';

class ShiftService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  List<Shift> _shifts = [];
  List<Shift> get shifts => _shifts;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  Future<void> loadShifts() async {
    try {
      final data = await _client.from('shifts').select().order('start_time');
      _shifts = (data as List).map((j) => Shift.fromJson(j)).toList();
      _isOffline = false;
      await _cacheShifts(_shifts);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading shifts, using cache: $e');
      _isOffline = true;
      await _loadCachedShifts();
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
      final assignments = (data as List)
          .map((j) => StaffShiftAssignment.fromJson(j))
          .toList();
      await _cacheShiftAssignments(dateStr, assignments);
      return assignments;
    } catch (e) {
      debugPrint('Error loading shift assignments, using cache: $e');
      return await _loadCachedShiftAssignments(date);
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

  Future<int> deletePastShiftAssignments() async {
    try {
      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final countResp = await _client
          .from('staff_shifts')
          .select('id')
          .lt('assignment_date', todayStr);
      final count = countResp.length;
      if (count > 0) {
        await _client
            .from('staff_shifts')
            .delete()
            .lt('assignment_date', todayStr);
      }
      return count;
    } catch (e) {
      debugPrint('Error deleting past shifts: $e');
      return 0;
    }
  }

  void clear() {
    _shifts.clear();
    notifyListeners();
  }

  // --- Offline Cache Methods ---

  Future<void> _cacheShifts(List<Shift> shiftsList) async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      await db.delete('shifts_cache');
      for (final shift in shiftsList) {
        await db.insert('shifts_cache', {
          'id': shift.id,
          'name': shift.name,
          'start_time': shift.timeRange.split(' – ')[0],
          'end_time': shift.timeRange.split(' – ')[1],
          'color': shift.color,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      debugPrint('Error caching shifts: $e');
    }
  }

  Future<void> _loadCachedShifts() async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      final rows = await db.query('shifts_cache', orderBy: 'start_time');
      _shifts = rows.map((row) => Shift(
        id: row['id'] as String,
        name: row['name'] as String,
        startTime: _parseTime(row['start_time'] as String),
        endTime: _parseTime(row['end_time'] as String),
        color: row['color'] as String?,
      )).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached shifts: $e');
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _cacheShiftAssignments(String dateStr, List<StaffShiftAssignment> assignments) async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      await db.delete('staff_shifts_cache', where: 'assignment_date = ?', whereArgs: [dateStr]);
      for (final assignment in assignments) {
        await db.insert('staff_shifts_cache', {
          'id': assignment.id,
          'staff_id': assignment.staffId,
          'shift_id': assignment.shiftId,
          'assignment_date': dateStr,
          'staff_name': assignment.staffName,
          'shift_name': assignment.shiftName,
          'shift_start_time': assignment.shiftStartTime != null
              ? '${assignment.shiftStartTime!.hour.toString().padLeft(2, '0')}:${assignment.shiftStartTime!.minute.toString().padLeft(2, '0')}'
              : null,
          'shift_end_time': assignment.shiftEndTime != null
              ? '${assignment.shiftEndTime!.hour.toString().padLeft(2, '0')}:${assignment.shiftEndTime!.minute.toString().padLeft(2, '0')}'
              : null,
          'shift_color': assignment.shiftColor,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      debugPrint('Error caching shift assignments: $e');
    }
  }

  Future<List<StaffShiftAssignment>> _loadCachedShiftAssignments(DateTime date) async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return [];
      final dateStr = date.toIso8601String().substring(0, 10);
      final rows = await db.query(
        'staff_shifts_cache',
        where: 'assignment_date = ?',
        whereArgs: [dateStr],
      );
      return rows.map((row) => StaffShiftAssignment(
        id: row['id'] as String,
        staffId: row['staff_id'] as String,
        shiftId: row['shift_id'] as String,
        assignmentDate: DateTime.parse(row['assignment_date'] as String).toLocal(),
        staffName: row['staff_name'] as String?,
        shiftName: row['shift_name'] as String?,
        shiftStartTime: row['shift_start_time'] != null ? _parseTime(row['shift_start_time'] as String) : null,
        shiftEndTime: row['shift_end_time'] != null ? _parseTime(row['shift_end_time'] as String) : null,
        shiftColor: row['shift_color'] as String?,
      )).toList();
    } catch (e) {
      debugPrint('Error loading cached shift assignments: $e');
      return [];
    }
  }
}
