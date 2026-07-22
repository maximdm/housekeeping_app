import 'package:flutter_test/flutter_test.dart';
import 'package:house_keeping_app/models/room.dart';
import 'package:house_keeping_app/models/room_type.dart';
import 'package:house_keeping_app/models/floor.dart';
import 'package:house_keeping_app/models/staff_member.dart';

void main() {
  group('RoomStatus', () {
    test('fromString returns correct status', () {
      expect(RoomStatus.fromString('dirty'), RoomStatus.dirty);
      expect(RoomStatus.fromString('in_progress'), RoomStatus.inProgress);
      expect(RoomStatus.fromString('clean'), RoomStatus.clean);
    });

    test('fromString defaults to dirty for unknown value', () {
      expect(RoomStatus.fromString('unknown'), RoomStatus.dirty);
    });

    test('label returns correct display text', () {
      expect(RoomStatus.dirty.label, 'Dirty');
      expect(RoomStatus.inProgress.label, 'In Progress');
      expect(RoomStatus.clean.label, 'Clean');
    });

    test('dbValue returns correct database string', () {
      expect(RoomStatus.dirty.dbValue, 'dirty');
      expect(RoomStatus.inProgress.dbValue, 'in_progress');
      expect(RoomStatus.clean.dbValue, 'clean');
    });
  });

  group('StaffRole', () {
    test('fromString returns correct role', () {
      expect(StaffRole.fromString('cleaner'), StaffRole.cleaner);
      expect(StaffRole.fromString('receptionist'), StaffRole.receptionist);
    });

    test('label returns correct display text', () {
      expect(StaffRole.cleaner.label, 'Cleaner');
      expect(StaffRole.receptionist.label, 'Receptionist');
    });
  });

  group('Room', () {
    test('fromJson creates room correctly', () {
      final json = {
        'id': '1',
        'number': '101',
        'room_type_id': 'rt-1',
        'floor_id': 'f-1',
        'status': 'dirty',
        'room_type': {'name': 'Standard'},
        'floor': {'name': 'Ground Floor', 'number': '1'},
      };
      final room = Room.fromJson(json);
      expect(room.id, '1');
      expect(room.number, '101');
      expect(room.roomTypeId, 'rt-1');
      expect(room.floorId, 'f-1');
      expect(room.status, RoomStatus.dirty);
      expect(room.roomTypeName, 'Standard');
      expect(room.floorName, 'Ground Floor');
      expect(room.floorNumber, '1');
    });

    test('toJson returns correct map', () {
      final room = Room(
        id: '1',
        number: '101',
        roomTypeId: 'rt-1',
        floorId: 'f-1',
        status: RoomStatus.clean,
      );
      final json = room.toJson();
      expect(json['id'], '1');
      expect(json['number'], '101');
      expect(json['room_type_id'], 'rt-1');
      expect(json['floor_id'], 'f-1');
      expect(json['status'], 'clean');
    });
  });

  group('RoomType', () {
    test('fromJson creates room type correctly', () {
      final json = {'id': '1', 'name': 'Suite', 'description': 'Premium suite'};
      final rt = RoomType.fromJson(json);
      expect(rt.id, '1');
      expect(rt.name, 'Suite');
      expect(rt.description, 'Premium suite');
    });
  });

  group('Floor', () {
    test('fromJson creates floor correctly', () {
      final json = {'id': '1', 'number': '2', 'name': 'First Floor'};
      final floor = Floor.fromJson(json);
      expect(floor.id, '1');
      expect(floor.number, '2');
      expect(floor.name, 'First Floor');
      expect(floor.displayName, 'First Floor');
    });

    test('displayName falls back to Floor N when name is null', () {
      final floor = Floor(id: '1', number: '3');
      expect(floor.displayName, 'Floor 3');
    });
  });

  group('StaffMember', () {
    test('fromJson creates staff member correctly', () {
      final json = {
        'id': '1',
        'user_id': 'u-1',
        'name': 'Mike T.',
        'role': 'cleaner',
        'phone': '+1234567890',
        'is_active': true,
        'assigned_rooms': 3,
      };
      final staff = StaffMember.fromJson(json);
      expect(staff.id, '1');
      expect(staff.userId, 'u-1');
      expect(staff.name, 'Mike T.');
      expect(staff.role, StaffRole.cleaner);
      expect(staff.phone, '+1234567890');
      expect(staff.isActive, true);
      expect(staff.status, StaffStatus.onShift);
      expect(staff.assignedRooms, 3);
    });

    test('toJson returns correct map', () {
      final staff = StaffMember(
        id: '1',
        userId: 'u-1',
        name: 'Mike T.',
        role: StaffRole.receptionist,
        phone: '+1234567890',
        isActive: true,
      );
      final json = staff.toJson();
      expect(json['id'], '1');
      expect(json['user_id'], 'u-1');
      expect(json['name'], 'Mike T.');
      expect(json['role'], 'receptionist');
      expect(json['phone'], '+1234567890');
      expect(json['is_active'], true);
    });

    test('status derives from isActive', () {
      final active = StaffMember(id: '1', name: 'A', role: StaffRole.cleaner, isActive: true);
      final inactive = StaffMember(id: '2', name: 'B', role: StaffRole.cleaner, isActive: false);
      expect(active.status, StaffStatus.onShift);
      expect(inactive.status, StaffStatus.offShift);
    });
  });
}
