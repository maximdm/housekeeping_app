import 'dart:async';

import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';

import '../../../main.dart';
import '../../../models/room.dart';
import '../../../services/room_service.dart';
import '../../../layouts/admin_layout.dart';
import 'room_form_page.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  final RoomService _roomService = RoomService();
  final List<Timer> _pendingTimers = [];

  String? _filterFloorId;
  RoomStatus? _filterStatus;
  String? _filterRoomTypeId;

  @override
  void initState() {
    super.initState();
    _roomService.addListener(_onDataChanged);
    _roomService.loadAll();
    _roomService.subscribeToChanges();
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
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
        roomTypeId: _filterRoomTypeId,
      );

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return AdminLayout(
      currentRoute: '/admin/rooms',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rooms'),
          actions: [
            _buildSetupMenu(),
            const SizedBox(width: 4),
            if (!isMobile)
              FilledButton.icon(
                onPressed: () => Routefly.navigate('/admin/rooms/room_form'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Room'),
              ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: isMobile
            ? FloatingActionButton(
                onPressed: () => Routefly.navigate('/admin/rooms/room_form'),
                child: const Icon(Icons.add),
              )
            : null,
        body: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: _roomService.rooms.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredRooms.isEmpty
                      ? _buildEmptyState()
                      : isMobile
                          ? _buildMobileList()
                          : _buildDesktopTable(),
            ),
          ],
        ),
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

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          RoomFormPage.pendingRoom = room;
          Routefly.navigate('/admin/rooms/room_form');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    room.number,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<RoomStatus>(
                    tooltip: 'Change Status',
                    padding: EdgeInsets.zero,
                    onSelected: (s) =>
                        _roomService.updateRoomStatus(room.id, s),
                    itemBuilder: (context) => RoomStatus.values
                        .map((s) =>
                            PopupMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    child: Chip(
                      label: Text(room.status.label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                      backgroundColor: room.status.color,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') {
                        RoomFormPage.pendingRoom = room;
                        Routefly.navigate('/admin/rooms/room_form');
                      } else {
                        _confirmDelete(room);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                const SizedBox(height: 8),
                Text(
                  room.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ],
          ),
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

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DataTable(
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
          columns: const [
            DataColumn(label: Text('Room')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Floor')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: _filteredRooms
              .map((room) => _buildDataRow(room))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSetupMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Manage Setup',
      onSelected: (value) {
        switch (value) {
          case 'room_types':
            _showRoomTypesSheet();
            break;
          case 'floors':
            _showFloorsSheet();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'room_types',
          child: ListTile(
            leading: Icon(Icons.category_outlined),
            title: Text('Manage Room Types'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'floors',
          child: ListTile(
            leading: Icon(Icons.layers_outlined),
            title: Text('Manage Floors'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
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
            width: 170,
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
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              initialValue: _filterRoomTypeId,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All')),
                ..._roomService.roomTypes.map((rt) => DropdownMenuItem(
                      value: rt.id,
                      child: Text(rt.name),
                    )),
              ],
              onChanged: (v) => setState(() => _filterRoomTypeId = v),
            ),
          ),
          if (_filterFloorId != null ||
              _filterStatus != null ||
              _filterRoomTypeId != null)
            TextButton.icon(
              onPressed: () => setState(() {
                _filterFloorId = null;
                _filterStatus = null;
                _filterRoomTypeId = null;
              }),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(Room room) {
    return DataRow(cells: [
      DataCell(Text(room.number,
          style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(Text(room.roomTypeName ?? '-')),
      DataCell(Text(room.floorName ?? '-')),
      DataCell(
        SizedBox(
          width: 200,
          child: Text(
            room.description ?? '-',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
      DataCell(
        PopupMenuButton<RoomStatus>(
          tooltip: 'Change Status',
          onSelected: (newStatus) =>
              _roomService.updateRoomStatus(room.id, newStatus),
          itemBuilder: (context) => RoomStatus.values.map((status) {
            return PopupMenuItem(value: status, child: Text(status.label));
          }).toList(),
          child: Chip(
            label: Text(room.status.label,
                style:
                    const TextStyle(color: Colors.white, fontSize: 12)),
            backgroundColor: room.status.color,
            side: BorderSide.none,
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit Room',
              onPressed: () {
                RoomFormPage.pendingRoom = room;
                Routefly.navigate('/admin/rooms/room_form');
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.error),
              tooltip: 'Delete Room',
              onPressed: () => _confirmDelete(room),
            ),
          ],
        ),
      ),
    ]);
  }

  void _confirmDelete(Room room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text(
            'Are you sure you want to delete room ${room.number}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _roomService.rooms.removeWhere((r) => r.id == room.id);
              });
              if (mounted) {
                Timer? undoTimer;
                showTimedSnackBar(
                  SnackBar(
                    content: Text('Room ${room.number} deleted'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        undoTimer?.cancel();
                        setState(() {
                          _roomService.rooms.add(room);
                          _roomService.rooms.sort(Room.compare);
                        });
                      },
                    ),
                    duration: const Duration(seconds: 5),
                  ),
                );
                undoTimer = Timer(const Duration(seconds: 5), () async {
                  if (!mounted) return;
                  await _roomService.deleteRoom(room.id);
                });
                _pendingTimers.add(undoTimer);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRoomTypesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _RoomTypesSheet(roomService: _roomService),
    );
  }

  void _showFloorsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _FloorsSheet(roomService: _roomService),
    );
  }
}

// --- Room Types Sheet ---

class _RoomTypesSheet extends StatefulWidget {
  final RoomService roomService;

  const _RoomTypesSheet({required this.roomService});

  @override
  State<_RoomTypesSheet> createState() => _RoomTypesSheetState();
}

class _RoomTypesSheetState extends State<_RoomTypesSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final List<Timer> _pendingTimers = [];
  String? _editingId;

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _descController.clear();
    _editingId = null;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (_editingId != null) {
      await widget.roomService.updateRoomType(
        _editingId!,
        name: name,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );
    } else {
      await widget.roomService.createRoomType(
        name: name,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );
    }
    _resetForm();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return DraggableScrollableSheet(
      initialChildSize: isMobile ? 0.8 : 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Room Types',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isMobile)
                Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Type name (e.g. Suite)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        hintText: 'Description (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _save,
                            icon: Icon(
                                _editingId != null
                                    ? Icons.check
                                    : Icons.add,
                                size: 18),
                            label: Text(
                                _editingId != null ? 'Update' : 'Add'),
                          ),
                        ),
                        if (_editingId != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _resetForm,
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Cancel Edit',
                          ),
                        ],
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Type name (e.g. Suite)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          hintText: 'Description (optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: Icon(
                          _editingId != null ? Icons.check : Icons.add,
                          size: 18),
                      label:
                          Text(_editingId != null ? 'Update' : 'Add'),
                    ),
                    if (_editingId != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: _resetForm,
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Cancel Edit',
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.roomService.roomTypes.length,
                  itemBuilder: (context, index) {
                    final type = widget.roomService.roomTypes[index];
                    return ListTile(
                      title: Text(type.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: type.description != null &&
                              type.description!.isNotEmpty
                          ? Text(type.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon:
                                const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit',
                            onPressed: () {
                              setState(() {
                                _editingId = type.id;
                                _nameController.text = type.name;
                                _descController.text =
                                    type.description ?? '';
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .error),
                            tooltip: 'Delete',
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title:
                                      const Text('Delete Room Type'),
                                  content: Text(
                                      'Delete "${type.name}"? Rooms using this type will not be affected.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            Theme.of(context)
                                                .colorScheme
                                                .error,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                widget.roomService.roomTypes
                                    .removeWhere((rt) => rt.id == type.id);
                                setState(() {});
                                if (mounted) {
                                  Timer? undoTimer;
                                  showTimedSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Room type "${type.name}" deleted'),
                                       action: SnackBarAction(
                                        label: 'Undo',
                                        onPressed: () {
                                          undoTimer?.cancel();
                                          widget.roomService.roomTypes
                                              .add(type);
                                          setState(() {});
                                        },
                                      ),
                                      duration:
                                          const Duration(seconds: 5),
                                    ),
                                  );
                                  undoTimer = Timer(
                                      const Duration(seconds: 5),
                                      () async {
                                    if (!mounted) return;
                                    await widget.roomService
                                        .deleteRoomType(type.id);
                                  });
                                  _pendingTimers.add(undoTimer);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- Floors Sheet ---

class _FloorsSheet extends StatefulWidget {
  final RoomService roomService;

  const _FloorsSheet({required this.roomService});

  @override
  State<_FloorsSheet> createState() => _FloorsSheetState();
}

class _FloorsSheetState extends State<_FloorsSheet> {
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final List<Timer> _pendingTimers = [];

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _numberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addFloor() async {
    final numberText = _numberController.text.trim();
    if (numberText.isEmpty) return;

    final exists =
        widget.roomService.floors.any((f) => f.number == numberText);
    if (exists) {
      showTimedSnackBar(
        const SnackBar(content: Text('Floor number already exists')),
      );
      return;
    }

    await widget.roomService.createFloor(
      number: numberText,
      name: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
    );

    _numberController.clear();
    _nameController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return DraggableScrollableSheet(
      initialChildSize: isMobile ? 0.75 : 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Floors',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isMobile)
                Column(
                  children: [
                    TextField(
                      controller: _numberController,
                      decoration: const InputDecoration(
                        hintText: 'Floor # (e.g. 1, B, III)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Name (optional, e.g. Ground Floor)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _addFloor,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Floor'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _numberController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 1, B, III',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText:
                              'Name (optional, e.g. Ground Floor)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _addFloor,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.roomService.floors.length,
                  itemBuilder: (context, index) {
                    final floor = widget.roomService.floors[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(floor.number,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      title: Text(floor.displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .error),
                        tooltip: 'Delete Floor',
                        onPressed: () async {
                          final hasRooms = widget.roomService.rooms
                              .any((r) => r.floorId == floor.id);
                          if (hasRooms) {
                            showTimedSnackBar(
                              SnackBar(
                                content: Text(
                                    'Cannot delete ${floor.displayName} - it has rooms assigned'),
                              ),
                            );
                            return;
                          }
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Floor'),
                              content: Text(
                                  'Delete "${floor.displayName}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context)
                                            .colorScheme
                                            .error,
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            widget.roomService.floors
                                .removeWhere((f) => f.id == floor.id);
                            setState(() {});
                            if (mounted) {
                              Timer? undoTimer;
                              showTimedSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Floor ${floor.displayName} deleted'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () {
                                      undoTimer?.cancel();
                                      widget.roomService.floors
                                          .add(floor);
                                      setState(() {});
                                    },
                                  ),
                                  duration:
                                      const Duration(seconds: 5),
                                ),
                              );
                              undoTimer = Timer(
                                  const Duration(seconds: 5),
                                  () async {
                                if (!mounted) return;
                                await widget.roomService
                                    .deleteFloor(floor.id);
                              });
                              _pendingTimers.add(undoTimer);
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
