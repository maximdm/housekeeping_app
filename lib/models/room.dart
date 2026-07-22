import 'package:flutter/material.dart';

enum RoomStatus {
  dirty,
  inProgress,
  clean;

  String get label {
    switch (this) {
      case RoomStatus.dirty:
        return 'Dirty';
      case RoomStatus.inProgress:
        return 'In Progress';
      case RoomStatus.clean:
        return 'Clean';
    }
  }

  Color get color {
    switch (this) {
      case RoomStatus.dirty:
        return Colors.orange;
      case RoomStatus.inProgress:
        return Colors.blue;
      case RoomStatus.clean:
        return Colors.green;
    }
  }

  String get dbValue {
    switch (this) {
      case RoomStatus.dirty:
        return 'dirty';
      case RoomStatus.inProgress:
        return 'in_progress';
      case RoomStatus.clean:
        return 'clean';
    }
  }

  factory RoomStatus.fromString(String value) {
    switch (value) {
      case 'dirty':
        return RoomStatus.dirty;
      case 'in_progress':
        return RoomStatus.inProgress;
      case 'clean':
        return RoomStatus.clean;
      default:
        return RoomStatus.dirty;
    }
  }
}

class Room {
  final String id;
  final String number;
  final String roomTypeId;
  final String floorId;
  RoomStatus status;
  final String? description;

  final String? roomTypeName;
  final String? floorName;
  final String? floorNumber;

  Room({
    required this.id,
    required this.number,
    required this.roomTypeId,
    required this.floorId,
    required this.status,
    this.description,
    this.roomTypeName,
    this.floorName,
    this.floorNumber,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      number: json['number'] as String,
      roomTypeId: json['room_type_id'] as String,
      floorId: json['floor_id'] as String,
      status: RoomStatus.fromString(json['status'] as String? ?? 'dirty'),
      description: json['description'] as String?,
      roomTypeName: json['room_type'] != null
          ? (json['room_type'] as Map<String, dynamic>)['name'] as String?
          : json['roomTypeName'] as String?,
      floorName: json['floor'] != null
          ? (json['floor'] as Map<String, dynamic>)['name'] as String?
          : json['floorName'] as String?,
      floorNumber: json['floor'] != null
          ? (json['floor'] as Map<String, dynamic>)['number']?.toString()
          : json['floorNumber'] as String?,
    );
  }

  int get _sortKey {
    final n = int.tryParse(floorNumber ?? '0') ?? 0;
    final r = int.tryParse(number) ?? 0;
    return n * 1000 + r;
  }

  static int compare(Room a, Room b) => a._sortKey.compareTo(b._sortKey);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'room_type_id': roomTypeId,
      'floor_id': floorId,
      'status': status.dbValue,
      'description': description,
    };
  }
}
