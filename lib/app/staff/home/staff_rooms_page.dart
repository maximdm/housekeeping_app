import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';

import '../../../models/room.dart';
import '../../../services/assignment_service.dart';
import '../../../services/room_service.dart';
import '../../../layouts/staff_layout.dart';

class StaffRoomsPage extends StatefulWidget {
  const StaffRoomsPage({super.key});

  @override
  State<StaffRoomsPage> createState() => _StaffRoomsPageState();
}

class _StaffRoomsPageState extends State<StaffRoomsPage>
    with SingleTickerProviderStateMixin {
  final RoomService _roomService = RoomService();
  final AssignmentService _assignmentService = AssignmentService();

  String? _filterFloorId;
  String? _filterRoomTypeId;
  String? _staffId;
  List<String> _assignedFloorIds = [];
  List<Room> _allRooms = [];
  bool _loading = true;
  final List<Timer> _pendingTimers = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final staffData = await Supabase.instance.client
          .from('staff')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (staffData == null) return;

      _staffId = staffData['id'] as String;

      final floorData = await Supabase.instance.client
          .from('floor_assignments')
          .select('floor_id')
          .eq('staff_id', _staffId!)
          .eq('assignment_date',
              DateTime.now().toIso8601String().substring(0, 10));

      _assignedFloorIds = (floorData as List)
          .map((f) => f['floor_id'] as String)
          .toList();

      final roomsData = await Supabase.instance.client.from('rooms').select('''
            id, number, status, room_type_id, floor_id, description,
            room_type:room_types(name),
            floor:floors(name, number)
          ''');

      _allRooms = (roomsData as List)
          .map((json) => Room.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading staff rooms: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  bool _canToggle(Room room) => _assignedFloorIds.contains(room.floorId);

  List<Room> get _filteredAssignedRooms {
    final filtered = _allRooms.where((room) {
      if (!_assignedFloorIds.contains(room.floorId)) return false;
      if (_filterFloorId != null && room.floorId != _filterFloorId) return false;
      if (_filterRoomTypeId != null && room.roomTypeId != _filterRoomTypeId) {
        return false;
      }
      return true;
    }).toList();
    filtered.sort(Room.compareByStatus);
    return filtered;
  }

  List<Room> get _filteredDirtyRooms {
    return _filteredAssignedRooms
        .where((r) =>
            r.status == RoomStatus.dirty || r.status == RoomStatus.inProgress)
        .toList();
  }

  List<String> get _availableFloorIds {
    return _allRooms.map((r) => r.floorId).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return StaffLayout(
      currentTabIndex: 2,
      title: localizations.tr('rooms'),
      child: Column(
        children: [
          _buildFilters(),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(text: localizations.tr('needsCleaning')),
              Tab(text: localizations.tr('allRooms')),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRoomList(_filteredDirtyRooms,
                          emptyText: localizations.tr('needsCleaning'),
                          showFloor: true),
                      _buildRoomList(_allRooms,
                          emptyText: localizations.tr('noItems'),
                          showFloor: true),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList(List<Room> rooms,
      {required String emptyText, bool showFloor = false}) {
    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.meeting_room_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(emptyText,
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: rooms.length,
      itemBuilder: (context, index) =>
          _buildRoomCard(rooms[index]),
    );
  }

  Widget _buildFilters() {
    final availableFloors = _roomService.floors
        .where((f) => _availableFloorIds.contains(f.id))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<String>(
              initialValue: _filterFloorId,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Floor',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...availableFloors.map((f) => DropdownMenuItem(
                      value: f.id,
                      child: Text(f.displayName),
                    )),
              ],
              onChanged: (v) => setState(() => _filterFloorId = v),
            ),
          ),
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<String>(
              initialValue: _filterRoomTypeId,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Room Type',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ..._roomService.roomTypes.map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(t.name),
                    )),
              ],
              onChanged: (v) => setState(() => _filterRoomTypeId = v),
            ),
          ),
          if (_filterFloorId != null || _filterRoomTypeId != null)
            TextButton.icon(
              onPressed: () => setState(() {
                _filterFloorId = null;
                _filterRoomTypeId = null;
              }),
              icon: const Icon(Icons.clear, size: 16),
              label: Text(localizations.tr('clear')),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Room room) {
    final canToggle = _canToggle(room);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.number,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _filterRoomTypeId = room.roomTypeId;
                          });
                        },
                        child: _buildInfoChip(Icons.category_outlined,
                            room.roomTypeName ?? '-'),
                      ),
                      _buildInfoChip(
                          Icons.layers_outlined, room.floorName ?? '-'),
                    ],
                  ),
                  if (room.description != null &&
                      room.description!.isNotEmpty) ...[

                    const SizedBox(height: 6),
                    Text(
                      room.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            canToggle
                ? GestureDetector(
                    onTap: () async {
                      final oldStatus = room.status;
                      final next = RoomStatus.values[
                          (RoomStatus.values.indexOf(room.status) + 1) %
                              RoomStatus.values.length];
                      setState(() => room.status = next);
                      final success = await _assignmentService.updateRoomStatus(
                          room.id, next);
                      if (!success && mounted) {
                        setState(() => room.status = oldStatus);
                      }
                      if (mounted) {
                        Timer? undoTimer;
                        showTimedSnackBar(SnackBar(
                          content: Text(
                              '${localizations.tr('room')} ${room.number} → ${next.label}'),
                          backgroundColor: next.color,
                          duration: const Duration(seconds: 4),
                          action: SnackBarAction(
                            label: localizations.tr('undo'),
                            textColor: Colors.white,
                            onPressed: () {
                              undoTimer?.cancel();
                              setState(() => room.status = oldStatus);
                              _assignmentService.updateRoomStatus(
                                  room.id, oldStatus);
                            },
                          ),
                        ));
                        undoTimer = Timer(const Duration(seconds: 4), () {
                          _loadData();
                        });
                        _pendingTimers.add(undoTimer);
                      }
                    },
                    child: Chip(
                      label: Text(room.status.label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                      backgroundColor: room.status.color,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                : Chip(
                    label: Text(room.status.label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11)),
                    backgroundColor: room.status.color,
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
