import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/staff_member.dart';
import 'activity_service.dart';
import 'database_helper.dart';

class StaffService extends ChangeNotifier {
  static const int maxAccounts = 35;

  final SupabaseClient _client = Supabase.instance.client;

  List<StaffMember> _staff = [];
  List<StaffMember> get staff => _staff;

  int get staffCount => _staff.length;
  bool get canAddMore => staffCount < maxAccounts;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  Future<void> loadStaff() async {
    try {
      final data = await _client.from('staff').select('''
        id, user_id, name, account_name, role, phone, is_active, on_shift
      ''').order('name');

      _staff = (data as List).map((json) => StaffMember.fromJson(json)).toList();
      _isOffline = false;
      await _cacheStaff(_staff);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading staff, using cache: $e');
      _isOffline = true;
      await _loadCachedStaff();
    }
  }

  Future<StaffMember> addStaff({
    required String name,
    required String accountName,
    required StaffRole role,
    String? phone,
  }) async {
    if (!canAddMore) {
      throw Exception('Staff limit of $maxAccounts reached');
    }

    final data = await _client
        .from('staff')
        .insert({
          'name': name,
          'account_name': accountName,
          'role': role.name,
          'phone': phone,
          'is_active': true,
        })
        .select()
        .single();

    final member = StaffMember.fromJson(data);
    _staff.add(member);
    notifyListeners();

    await ActivityService().log(
      action: 'staff_created',
      details: {'staff_id': member.id, 'name': name, 'role': role.name},
    );

    return member;
  }

  Future<bool> updateStaff(String id, {
    String? name,
    String? accountName,
    StaffRole? role,
    String? phone,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (accountName != null) updates['account_name'] = accountName;
      if (role != null) updates['role'] = role.name;
      if (phone != null) updates['phone'] = phone;

      if (updates.isEmpty) return false;

      await _client.from('staff').update(updates).eq('id', id);
      await loadStaff();

      await ActivityService().log(
        action: 'staff_updated',
        details: {'staff_id': id, ...updates},
      );

      return true;
    } catch (e) {
      debugPrint('Error updating staff: $e');
      return false;
    }
  }

  Future<bool> deactivateStaff(String id) async {
    try {
      await _client
          .from('staff')
          .update({'is_active': false})
          .eq('id', id);

      final index = _staff.indexWhere((s) => s.id == id);
      if (index != -1) {
        _staff[index] = StaffMember(
          id: _staff[index].id,
          userId: _staff[index].userId,
          name: _staff[index].name,
          accountName: _staff[index].accountName,
          role: _staff[index].role,
          phone: _staff[index].phone,
          isActive: false,
          assignedRooms: _staff[index].assignedRooms,
        );
        notifyListeners();
      }

      await ActivityService().log(
        action: 'staff_deactivated',
        details: {'staff_id': id},
      );

      return true;
    } catch (e) {
      debugPrint('Error deactivating staff: $e');
      return false;
    }
  }

  Future<bool> activateStaff(String id) async {
    try {
      await _client
          .from('staff')
          .update({'is_active': true})
          .eq('id', id);

      final index = _staff.indexWhere((s) => s.id == id);
      if (index != -1) {
        _staff[index] = StaffMember(
          id: _staff[index].id,
          userId: _staff[index].userId,
          name: _staff[index].name,
          accountName: _staff[index].accountName,
          role: _staff[index].role,
          phone: _staff[index].phone,
          isActive: true,
          assignedRooms: _staff[index].assignedRooms,
        );
        notifyListeners();
      }

      await ActivityService().log(
        action: 'staff_activated',
        details: {'staff_id': id},
      );

      return true;
    } catch (e) {
      debugPrint('Error activating staff: $e');
      return false;
    }
  }

  Future<bool> deleteStaff(String id) async {
    if (id.isEmpty) {
      debugPrint('deleteStaff called with empty id');
      return false;
    }
    try {
      var member = getStaffById(id);
      var userId = member?.userId;
      final staffName = member?.name;

      if (userId == null) {
        try {
          final row = await _client
              .from('staff')
              .select('user_id, name')
              .eq('id', id)
              .maybeSingle();
          userId = row?['user_id'] as String?;
          if (staffName == null && row != null) {
            // eslint-disable-next-line
          }
        } catch (_) {}
      }

      await _client.from('staff').delete().eq('id', id);

      final verify = await _client
          .from('staff')
          .select('id')
          .eq('id', id)
          .maybeSingle();
      if (verify != null) {
        debugPrint('Staff delete failed - row still exists (RLS?)');
        return false;
      }

      if (userId != null && userId.isNotEmpty) {
        try {
          await _client.rpc('delete_staff_auth', params: {
            'p_user_id': userId,
          });
        } catch (e) {
          debugPrint('Warning: auth user cleanup failed: $e');
        }
      }

      _staff.removeWhere((s) => s.id == id);
      notifyListeners();

      await ActivityService().log(
        action: 'staff_deleted',
        details: {'staff_id': id, 'name': staffName},
      );

      return true;
    } catch (e) {
      debugPrint('Error deleting staff: $e');
      return false;
    }
  }

  StaffMember? getStaffById(String id) {
    try {
      return _staff.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // --- Offline Cache Methods ---

  Future<void> _cacheStaff(List<StaffMember> staffList) async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      await db.delete('staff_cache');
      for (final member in staffList) {
        await db.insert('staff_cache', {
          'id': member.id,
          'user_id': member.userId,
          'name': member.name,
          'account_name': member.accountName,
          'role': member.role.name,
          'phone': member.phone,
          'is_active': member.isActive ? 1 : 0,
          'on_shift': member.onShift ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      debugPrint('Error caching staff: $e');
    }
  }

  Future<void> _loadCachedStaff() async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      final rows = await db.query('staff_cache', orderBy: 'name');
      _staff = rows.map((row) => StaffMember(
        id: row['id'] as String,
        userId: row['user_id'] as String?,
        name: row['name'] as String,
        accountName: row['account_name'] as String?,
        role: StaffRole.fromString(row['role'] as String),
        phone: row['phone'] as String?,
        isActive: (row['is_active'] as int) == 1,
        onShift: (row['on_shift'] as int) == 1,
      )).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached staff: $e');
    }
  }

  Future<bool> toggleOnShift(String id) async {
    try {
      final member = getStaffById(id);
      if (member == null) return false;
      final newOnShift = !member.onShift;
      await _client.from('staff').update({'on_shift': newOnShift}).eq('id', id);

      final index = _staff.indexWhere((s) => s.id == id);
      if (index != -1) {
        _staff[index] = StaffMember(
          id: member.id,
          userId: member.userId,
          name: member.name,
          accountName: member.accountName,
          role: member.role,
          phone: member.phone,
          isActive: member.isActive,
          onShift: newOnShift,
          assignedRooms: member.assignedRooms,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error toggling on_shift: $e');
      return false;
    }
  }
}
