import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/floor.dart';
import '../models/room.dart';
import '../models/room_type.dart';
import 'database_helper.dart';
import 'activity_service.dart';

class RoomService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  List<Room> _rooms = [];
  List<Room> get rooms => _rooms;

  List<RoomType> _roomTypes = [];
  List<RoomType> get roomTypes => _roomTypes;

  List<Floor> _floors = [];
  List<Floor> get floors => _floors;

  RealtimeChannel? _roomsChannel;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  Future<void> loadAll() async {
    await Future.wait([
      loadRooms(),
      loadRoomTypes(),
      loadFloors(),
    ]);
  }

  Future<void> loadRooms() async {
    try {
      final data = await _client.from('rooms').select('''
        id, number, room_type_id, floor_id, status, description, created_at, updated_at,
        room_type:room_types(name),
        floor:floors(name, number)
      ''').order('number');

      _rooms = (data as List).map((json) => Room.fromJson(json)).toList();
      _rooms.sort(Room.compare);
      _isOffline = false;
      await _cacheRooms(_rooms);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading rooms from Supabase, using cache: $e');
      _isOffline = true;
      await _loadCachedRooms();
    }
  }

  Future<void> loadRoomTypes() async {
    try {
      final data = await _client.from('room_types').select().order('name');
      _roomTypes = (data as List).map((json) => RoomType.fromJson(json)).toList();
      await _cacheRoomTypes(_roomTypes);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading room types, using cache: $e');
      await _loadCachedRoomTypes();
    }
  }

  Future<void> loadFloors() async {
    try {
      final data = await _client.from('floors').select().order('number');
      _floors = (data as List).map((json) => Floor.fromJson(json)).toList();
      await _cacheFloors(_floors);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading floors, using cache: $e');
      await _loadCachedFloors();
    }
  }

  Future<Room?> createRoom({
    required String number,
    required String roomTypeId,
    required String floorId,
    String? description,
  }) async {
    try {
      final data = await _client
          .from('rooms')
          .insert({
            'number': number,
            'room_type_id': roomTypeId,
            'floor_id': floorId,
            'description': description,
            'status': 'dirty',
          })
          .select('''
            id, number, room_type_id, floor_id, status, description, created_at, updated_at,
            room_type:room_types(name),
            floor:floors(name, number)
          ''')
          .single();

      final room = Room.fromJson(data);
      _rooms.add(room);
      await _cacheRooms(_rooms);
      notifyListeners();

      await ActivityService().log(
        action: 'room_created',
        details: {'room_id': room.id, 'room_number': number},
      );

      return room;
    } catch (e) {
      debugPrint('Error creating room: $e');
      return null;
    }
  }

  Future<bool> updateRoom(String id, {
    String? number,
    String? roomTypeId,
    String? floorId,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (number != null) updates['number'] = number;
      if (roomTypeId != null) updates['room_type_id'] = roomTypeId;
      if (floorId != null) updates['floor_id'] = floorId;
      if (description != null) updates['description'] = description;

      if (updates.isEmpty) return false;

      await _client.from('rooms').update(updates).eq('id', id);
      await loadRooms();

      await ActivityService().log(
        action: 'room_updated',
        details: {'room_id': id, ...updates},
      );

      return true;
    } catch (e) {
      debugPrint('Error updating room: $e');
      return false;
    }
  }

  Future<bool> updateRoomStatus(String id, RoomStatus status) async {
    try {
      await _client.from('rooms').update({'status': status.dbValue}).eq('id', id);
      final index = _rooms.indexWhere((r) => r.id == id);
      if (index != -1) {
        _rooms[index].status = status;
        await _cacheRooms(_rooms);
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error updating room status: $e');
      return false;
    }
  }

  Future<bool> deleteRoom(String id) async {
    try {
      final room = _rooms.firstWhere((r) => r.id == id);

      await _client.from('rooms').delete().eq('id', id);
      _rooms.removeWhere((r) => r.id == id);
      await _cacheRooms(_rooms);
      notifyListeners();

      await ActivityService().log(
        action: 'room_deleted',
        details: {'room_id': id, 'room_number': room.number},
      );

      return true;
    } catch (e) {
      debugPrint('Error deleting room: $e');
      return false;
    }
  }

  void subscribeToChanges() {
    _roomsChannel = _client
        .channel('rooms-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rooms',
          callback: (_) => loadRooms(),
        )
        .subscribe();
  }

  void unsubscribeFromChanges() {
    if (_roomsChannel != null) {
      _client.removeChannel(_roomsChannel!);
      _roomsChannel = null;
    }
  }

  // --- Room Type CRUD ---

  Future<RoomType?> createRoomType({required String name, String? description}) async {
    try {
      final data = await _client
          .from('room_types')
          .insert({'name': name, 'description': description})
          .select()
          .single();

      final roomType = RoomType.fromJson(data);
      _roomTypes.add(roomType);
      await _cacheRoomTypes(_roomTypes);
      notifyListeners();

      await ActivityService().log(
        action: 'room_type_created',
        details: {'name': name},
      );

      return roomType;
    } catch (e) {
      debugPrint('Error creating room type: $e');
      return null;
    }
  }

  Future<bool> updateRoomType(String id, {String? name, String? description}) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;

      if (updates.isEmpty) return false;

      await _client.from('room_types').update(updates).eq('id', id);
      await loadRoomTypes();

      await ActivityService().log(
        action: 'room_type_updated',
        details: {'room_type_id': id, ...updates},
      );

      return true;
    } catch (e) {
      debugPrint('Error updating room type: $e');
      return false;
    }
  }

  Future<bool> deleteRoomType(String id) async {
    try {
      final roomType = _roomTypes.firstWhere((rt) => rt.id == id);

      await _client.from('room_types').delete().eq('id', id);
      _roomTypes.removeWhere((rt) => rt.id == id);
      await _cacheRoomTypes(_roomTypes);
      notifyListeners();

      await ActivityService().log(
        action: 'room_type_deleted',
        details: {'room_type_id': id, 'name': roomType.name},
      );

      return true;
    } catch (e) {
      debugPrint('Error deleting room type: $e');
      return false;
    }
  }

  // --- Floor CRUD ---

  Future<Floor?> createFloor({required String number, String? name}) async {
    try {
      final data = await _client
          .from('floors')
          .insert({'number': number, 'name': name})
          .select()
          .single();

      final floor = Floor.fromJson(data);
      _floors.add(floor);
      await _cacheFloors(_floors);
      notifyListeners();

      await ActivityService().log(
        action: 'floor_created',
        details: {'floor_number': number, 'name': name},
      );

      return floor;
    } catch (e) {
      debugPrint('Error creating floor: $e');
      return null;
    }
  }

  Future<bool> updateFloor(String id, {String? number, String? name}) async {
    try {
      final updates = <String, dynamic>{};
      if (number != null) updates['number'] = number;
      if (name != null) updates['name'] = name;

      if (updates.isEmpty) return false;

      await _client.from('floors').update(updates).eq('id', id);
      await loadFloors();

      await ActivityService().log(
        action: 'floor_updated',
        details: {'floor_id': id, ...updates},
      );

      return true;
    } catch (e) {
      debugPrint('Error updating floor: $e');
      return false;
    }
  }

  Future<bool> deleteFloor(String id) async {
    try {
      final floor = _floors.firstWhere((f) => f.id == id);

      await _client.from('floors').delete().eq('id', id);
      _floors.removeWhere((f) => f.id == id);
      await _cacheFloors(_floors);
      notifyListeners();

      await ActivityService().log(
        action: 'floor_deleted',
        details: {'floor_id': id, 'number': floor.number},
      );

      return true;
    } catch (e) {
      debugPrint('Error deleting floor: $e');
      return false;
    }
  }

  // --- Filtering ---

  List<Room> filterRooms({String? floorId, RoomStatus? status, String? roomTypeId}) {
    return _rooms.where((room) {
      if (floorId != null && room.floorId != floorId) return false;
      if (status != null && room.status != status) return false;
      if (roomTypeId != null && room.roomTypeId != roomTypeId) return false;
      return true;
    }).toList();
  }

  // --- Offline Cache Methods ---

  Future<void> _cacheRooms(List<Room> rooms) async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      await db.delete('rooms_cache');
      for (final room in rooms) {
        await db.insert('rooms_cache', {
          'id': room.id,
          'number': room.number,
          'room_type_id': room.roomTypeId,
          'floor_id': room.floorId,
          'status': room.status.dbValue,
          'description': room.description,
          'room_type_name': room.roomTypeName,
          'floor_name': room.floorName,
          'floor_number': room.floorNumber,
        });
      }
    } catch (e) {
      debugPrint('Error caching rooms: $e');
    }
  }

  Future<void> _loadCachedRooms() async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      final rows = await db.query('rooms_cache', orderBy: 'number');
      _rooms = rows.map((row) => Room(
        id: row['id'] as String,
        number: row['number'] as String,
        roomTypeId: row['room_type_id'] as String,
        floorId: row['floor_id'] as String,
        status: RoomStatus.fromString(row['status'] as String),
        description: row['description'] as String?,
        roomTypeName: row['room_type_name'] as String?,
        floorName: row['floor_name'] as String?,
        floorNumber: row['floor_number'] as String?,
      )).toList();
      _rooms.sort(Room.compare);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached rooms: $e');
    }
  }

  Future<void> _cacheRoomTypes(List<RoomType> types) async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      await db.delete('room_types_cache');
      for (final type in types) {
        await db.insert('room_types_cache', type.toJson());
      }
    } catch (e) {
      debugPrint('Error caching room types: $e');
    }
  }

  Future<void> _loadCachedRoomTypes() async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      final rows = await db.query('room_types_cache', orderBy: 'name');
      _roomTypes = rows.map((row) => RoomType.fromJson(row)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached room types: $e');
    }
  }

  Future<void> _cacheFloors(List<Floor> floors) async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      await db.delete('floors_cache');
      for (final floor in floors) {
        await db.insert('floors_cache', floor.toJson());
      }
    } catch (e) {
      debugPrint('Error caching floors: $e');
    }
  }

  Future<void> _loadCachedFloors() async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      final rows = await db.query('floors_cache', orderBy: 'number');
      _floors = rows.map((row) => Floor.fromJson(row)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached floors: $e');
    }
  }

  @override
  void dispose() {
    unsubscribeFromChanges();
    super.dispose();
  }
}
