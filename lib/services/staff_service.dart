import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/staff_member.dart';
import 'activity_service.dart';

class StaffService extends ChangeNotifier {
  static const int maxAccounts = 35;

  final SupabaseClient _client = Supabase.instance.client;

  List<StaffMember> _staff = [];
  List<StaffMember> get staff => _staff;

  int get staffCount => _staff.length;
  bool get canAddMore => staffCount < maxAccounts;

  Future<void> loadStaff() async {
    try {
      final data = await _client.from('staff').select('''
        id, user_id, name, account_name, role, phone, is_active, on_shift
      ''').order('name');

      _staff = (data as List).map((json) => StaffMember.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading staff: $e');
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
    try {
      // Try local list first, fall back to DB query
      var member = getStaffById(id);
      var userId = member?.userId;
      final staffName = member?.name;

      if (userId == null) {
        // Staff was already removed from local list (optimistic UI) — query DB
        try {
          final row = await _client
              .from('staff')
              .select('user_id, name')
              .eq('id', id)
              .maybeSingle();
          userId = row?['user_id'] as String?;
        } catch (_) {}
      }

      final response = await _client.from('staff').delete().eq('id', id).select();
      if (response.isEmpty) {
        debugPrint('Delete returned no rows - RLS may be blocking');
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
