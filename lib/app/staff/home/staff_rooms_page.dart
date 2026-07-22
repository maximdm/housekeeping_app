import 'package:flutter/material.dart';

import '../../../models/room.dart';
import '../../../services/room_service.dart';
import '../../../layouts/staff_layout.dart';

class StaffRoomsPage extends StatefulWidget {
  const StaffRoomsPage({super.key});

  @override
  State<StaffRoomsPage> createState() => _StaffRoomsPageState();
}

class _StaffRoomsPageState extends State<StaffRoomsPage> {
  final RoomService _roomService = RoomService();

  String? _filterFloorId;
  RoomStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _roomService.addListener(_onDataChanged);
    _roomService.loadAll();
    _roomService.subscribeToChanges();
  }

  @override
  void dispose() {
    _roomService.removeListener(_onDataChanged);
    _roomService.unsubscribeFromChanges();
    _roomService.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  List<Room> get _filteredRooms => _roomService.filterRooms(
        floorId: _filterFloorId,
        status: _filterStatus,
      );

  @override
  Widget build(BuildContext context) {
    return StaffLayout(
      currentTabIndex: 1,
      title: 'Rooms',
      child: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _roomService.rooms.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _filteredRooms.isEmpty
                    ? _buildEmptyState()
                    : _buildRoomList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.meeting_room_outlined,
              size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No rooms found',
              style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 160,
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
                const DropdownMenuItem(
                    value: null, child: Text('All')),
                ..._roomService.floors.map((f) => DropdownMenuItem(
                      value: f.id,
                      child: Text(f.displayName),
                    )),
              ],
              onChanged: (v) => setState(() => _filterFloorId = v),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<RoomStatus>(
              initialValue: _filterStatus,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All')),
                ...RoomStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label),
                    )),
              ],
              onChanged: (v) => setState(() => _filterStatus = v),
            ),
          ),
          if (_filterFloorId != null || _filterStatus != null)
            TextButton.icon(
              onPressed: () => setState(() {
                _filterFloorId = null;
                _filterStatus = null;
              }),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _filteredRooms.length,
      itemBuilder: (context, index) => _buildRoomCard(_filteredRooms[index]),
    );
  }

  Widget _buildRoomCard(Room room) {
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
                      _buildInfoChip(Icons.category_outlined,
                          room.roomTypeName ?? '-'),
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
            PopupMenuButton<RoomStatus>(
              tooltip: 'Change Status',
              padding: EdgeInsets.zero,
              onSelected: (s) => _roomService.updateRoomStatus(room.id, s),
              itemBuilder: (context) => RoomStatus.values
                  .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              child: Chip(
                label: Text(room.status.label,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 11)),
                backgroundColor: room.status.color,
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
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
