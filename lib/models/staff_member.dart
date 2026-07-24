import 'package:flutter/material.dart';

enum StaffStatus {
  onShift,
  offShift;

  String get label {
    switch (this) {
      case StaffStatus.onShift:
        return 'On Shift';
      case StaffStatus.offShift:
        return 'Off Shift';
    }
  }

  Color get color {
    switch (this) {
      case StaffStatus.onShift:
        return Colors.green;
      case StaffStatus.offShift:
        return Colors.grey;
    }
  }

  factory StaffStatus.fromString(String value) {
    return StaffStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StaffStatus.offShift,
    );
  }
}

enum StaffRole {
  cleaner,
  receptionist,
  manager;

  String get label {
    switch (this) {
      case StaffRole.cleaner:
        return 'Cleaner';
      case StaffRole.receptionist:
        return 'Receptionist';
      case StaffRole.manager:
        return 'Manager';
    }
  }

  factory StaffRole.fromString(String value) {
    return StaffRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StaffRole.cleaner,
    );
  }
}

class StaffMember {
  final String id;
  final String? userId;
  final String name;
  final String? accountName;
  final StaffRole role;
  final String? phone;
  final bool isActive;
  final bool onShift;
  final int assignedRooms;

  StaffMember({
    required this.id,
    this.userId,
    required this.name,
    this.accountName,
    required this.role,
    this.phone,
    this.isActive = true,
    this.onShift = true,
    this.assignedRooms = 0,
  });

  StaffStatus get status => onShift && isActive ? StaffStatus.onShift : StaffStatus.offShift;

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String? ?? '',
      accountName: json['account_name'] as String?,
      role: StaffRole.fromString(json['role'] as String? ?? 'cleaner'),
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      onShift: json['on_shift'] as bool? ?? true,
      assignedRooms: json['assigned_rooms'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'account_name': accountName,
      'role': role.name,
      'phone': phone,
      'is_active': isActive,
    };
  }
}
