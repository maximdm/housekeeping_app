import 'package:flutter/material.dart';

/// Safely parses a hex color string (e.g. '#FF9800' or 'FF9800') into a [Color].
/// Returns [fallback] if the string is null, empty, or invalid.
Color parseHexColor(String? hex, {Color fallback = Colors.grey}) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.isEmpty) return fallback;
    return Color(int.parse('FF$cleaned', radix: 16));
  } catch (_) {
    return fallback;
  }
}

class Shift {
  final String id;
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? color;

  Shift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.color,
  });

  Color get displayColor => parseHexColor(color);

  String get timeRange {
    return '${_formatTime(startTime)} – ${_formatTime(endTime)}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    final startStr = json['start_time'] as String;
    final endStr = json['end_time'] as String;
    final startParts = startStr.split(':');
    final endParts = endStr.split(':');
    return Shift(
      id: json['id'] as String,
      name: json['name'] as String,
      startTime: TimeOfDay(
          hour: int.parse(startParts[0]), minute: int.parse(startParts[1])),
      endTime: TimeOfDay(
          hour: int.parse(endParts[0]), minute: int.parse(endParts[1])),
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'start_time':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'end_time':
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'color': color,
    };
  }
}

class StaffShiftAssignment {
  final String id;
  final String staffId;
  final String shiftId;
  final DateTime assignmentDate;
  final String? staffName;
  final String? shiftName;
  final TimeOfDay? shiftStartTime;
  final TimeOfDay? shiftEndTime;
  final String? shiftColor;

  StaffShiftAssignment({
    required this.id,
    required this.staffId,
    required this.shiftId,
    required this.assignmentDate,
    this.staffName,
    this.shiftName,
    this.shiftStartTime,
    this.shiftEndTime,
    this.shiftColor,
  });

  factory StaffShiftAssignment.fromJson(Map<String, dynamic> json) {
    final shiftData = json['shift'] as Map<String, dynamic>?;
    final staffData = json['staff'] as Map<String, dynamic>?;

    TimeOfDay? startTime;
    TimeOfDay? endTime;
    if (shiftData != null) {
      final startStr = shiftData['start_time'] as String;
      final endStr = shiftData['end_time'] as String;
      final sp = startStr.split(':');
      final ep = endStr.split(':');
      startTime = TimeOfDay(hour: int.parse(sp[0]), minute: int.parse(sp[1]));
      endTime = TimeOfDay(hour: int.parse(ep[0]), minute: int.parse(ep[1]));
    }

    return StaffShiftAssignment(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      shiftId: json['shift_id'] as String,
      assignmentDate:
          DateTime.parse(json['assignment_date'] as String).toLocal(),
      staffName: staffData?['name'] as String?,
      shiftName: shiftData?['name'] as String?,
      shiftStartTime: startTime,
      shiftEndTime: endTime,
      shiftColor: shiftData?['color'] as String?,
    );
  }
}
