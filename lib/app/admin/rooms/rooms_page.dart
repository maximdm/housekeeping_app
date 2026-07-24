import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';
import '../../../models/room.dart';
import '../../../models/staff_member.dart';
import '../../../services/room_service.dart';
import '../../../services/staff_service.dart';
import '../../../services/assignment_service.dart';
import '../../../widgets/multi_select_calendar.dart';
import '../../../services/notification_service.dart';
import '../../../layouts/admin_layout.dart';
import 'room_form_page.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  final RoomService _roomService = RoomService();
  final StaffService _staffService = StaffService();
  final AssignmentService _assignmentService = AssignmentService();
  bool _isFullAdmin = false;
  bool _showAssignments = false;
  final Set<DateTime> _selectedDates = {};
  final Set<String> _selectedStaffIds = {};
  final Set<String> _selectedFloorIds = {};
  bool _assigning = false;

  String? _filterFloorId;
  RoomStatus? _filterStatus;
  String? _filterRoomTypeId;

  @override
  void initState() {
    super.initState();
    _detectRole();
    _roomService.addListener(_onDataChanged);
    _roomService.loadAll();
    _roomService.subscribeToChanges();
    _staffService.loadStaff();
  }

  Future<void> _detectRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final data = await Supabase.instance.client
        .from('staff')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    if (mounted && data != null) {
      setState(() => _isFullAdmin = data['role'] == 'manager');
    }
  }

  @override
  void dispose() {
    _roomService.removeListener(_onDataChanged);
    _roomService.unsubscribeFromChanges();
    _roomService.dispose();
    _staffService.dispose();
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
      isFullAdmin: _isFullAdmin,
      child: Scaffold(
        appBar: AppBar(
          title: Text(localizations.tr('rooms')),
          actions: [
            if (_isFullAdmin) ...[
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.meeting_room_outlined, size: 20),
                    label: Text(localizations.tr('rooms')),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.assignment_outlined, size: 20),
                    label: Text(localizations.tr('assign')),
                  ),
                ],
                selected: {_showAssignments},
                onSelectionChanged: (v) => setState(() => _showAssignments = v.first),
              ),
              const SizedBox(width: 8),
              _buildSetupMenu(),
              const SizedBox(width: 4),
            ],
            if (!isMobile && _isFullAdmin && !_showAssignments)
              FilledButton.icon(
                onPressed: () => Routefly.navigate('/admin/rooms/room_form'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(localizations.tr('addRoom')),
              ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: isMobile && _isFullAdmin && !_showAssignments
            ? FloatingActionButton(
                onPressed: () => Routefly.navigate('/admin/rooms/room_form'),
                child: const Icon(Icons.add),
              )
            : null,
        body: _showAssignments
            ? _buildAssignmentsTab()
            : Column(
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
Text(localizations.tr('noItems'),
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
        onTap: _isFullAdmin ? () {
          RoomFormPage.pendingRoom = room;
          Routefly.navigate('/admin/rooms/room_form');
        } : null,
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
                  GestureDetector(
                    onTap: () {
                      final next = RoomStatus.values[
                          (RoomStatus.values.indexOf(room.status) + 1) %
                              RoomStatus.values.length];
                      _roomService.updateRoomStatus(room.id, next);
                    },
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
                  if (_isFullAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      PopupMenuItem(
                          value: 'edit', child: Text(localizations.tr('edit'))),
                      PopupMenuItem(
                          value: 'delete', child: Text(localizations.tr('delete'))),
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
          columns: [
            DataColumn(label: Text(localizations.tr('room'))),
            DataColumn(label: Text(localizations.tr('roomType'))),
            DataColumn(label: Text(localizations.tr('floor'))),
            DataColumn(label: Text(localizations.tr('description'))),
            DataColumn(label: Text(localizations.tr('status'))),
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
      tooltip: localizations.tr('manageSetup'),
      onSelected: (value) {
        switch (value) {
          case 'room_types':
            _showRoomTypesSheet();
            break;
          case 'manage_rooms':
            _showManageRoomsSheet();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'room_types',
          child: ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(localizations.tr('roomTypes')),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'manage_rooms',
          child: ListTile(
            leading: const Icon(Icons.meeting_room_outlined),
            title: Text(localizations.tr('rooms')),
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
              decoration: InputDecoration(
                labelText: localizations.tr('floor'),
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
                items: [
                DropdownMenuItem(
                    value: null, child: Text(localizations.tr('all'))),
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
              decoration: InputDecoration(
                labelText: localizations.tr('status'),
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(localizations.tr('all'))),
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
              decoration: InputDecoration(
                labelText: localizations.tr('roomType'),
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(localizations.tr('all'))),
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
              label: Text(localizations.tr('clear')),
            ),
        ],
      ),
    );
  }

  // --- Assignments Tab ---

  Widget _buildAssignmentsTab() {
    final cleaners = _staffService.staff
        .where((s) => s.role == StaffRole.cleaner && s.isActive)
        .toList();
    final floors = _roomService.floors;
    final selectedCount = _selectedFloorIds.length * _selectedStaffIds.length * _selectedDates.length;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: MultiSelectCalendar(
            selectedDates: _selectedDates,
            onSelectionChanged: (dates) =>
                setState(() => _selectedDates
                  ..clear()
                  ..addAll(dates)),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildStaffMultiSelect(cleaners),
                const SizedBox(height: 4),
                _buildFloorMultiSelect(floors),
              ],
            ),
          ),
        ),
        if (_selectedDates.isNotEmpty &&
            _selectedStaffIds.isNotEmpty &&
            _selectedFloorIds.isNotEmpty)
          _buildSaveBar(selectedCount),
      ],
    );
  }

  // --- Staff Multi-Select ---

  Widget _buildStaffMultiSelect(List<StaffMember> cleaners) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                _selectedStaffIds.isEmpty
                    ? localizations.tr('selectStaff')
                    : '${_selectedStaffIds.length} ${localizations.tr('selected')}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedStaffIds.length == cleaners.length) {
                      _selectedStaffIds.clear();
                    } else {
                      _selectedStaffIds.addAll(cleaners.map((c) => c.id));
                    }
                  });
                },
                child: Text(
                  _selectedStaffIds.length == cleaners.length ? localizations.tr('none') : localizations.tr('all'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (cleaners.isEmpty)
            Text(localizations.tr('noActiveStaff'),
                style: TextStyle(color: Colors.grey[500], fontSize: 13))
          else
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cleaners.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cleaner = cleaners[index];
                  final selected = _selectedStaffIds.contains(cleaner.id);
                  return FilterChip(
                    label: Text(cleaner.name, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedStaffIds.add(cleaner.id);
                        } else {
                          _selectedStaffIds.remove(cleaner.id);
                        }
                      });
                    },
                    avatar: CircleAvatar(
                      radius: 10,
                      backgroundColor: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[400],
                      child: Text(
                        cleaner.name.isNotEmpty ? cleaner.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // --- Floor Multi-Select ---

  Widget _buildFloorMultiSelect(List floors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                _selectedFloorIds.isEmpty
                    ? localizations.tr('floors')
                    : '${_selectedFloorIds.length} ${localizations.tr('selected')}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedFloorIds.length == floors.length) {
                      _selectedFloorIds.clear();
                    } else {
                      _selectedFloorIds.addAll(floors.map((f) => f.id as String));
                    }
                  });
                },
                child: Text(
                  _selectedFloorIds.length == floors.length ? localizations.tr('none') : localizations.tr('all'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (floors.isEmpty)
            Text(localizations.tr('noItems'),
                style: TextStyle(color: Colors.grey[500], fontSize: 13))
          else
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: floors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final floor = floors[index];
                  final selected = _selectedFloorIds.contains(floor.id);
                  return FilterChip(
                    label: Text(floor.displayName, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedFloorIds.add(floor.id);
                        } else {
                          _selectedFloorIds.remove(floor.id);
                        }
                      });
                    },
                    avatar: CircleAvatar(
                      radius: 10,
                      backgroundColor: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[400],
                      child: Text(
                        floor.number,
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // --- Save Bar ---

  Widget _buildSaveBar(int selectedCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$selectedCount assignment${selectedCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${_selectedStaffIds.length} cleaner${_selectedStaffIds.length == 1 ? '' : 's'} x '
                    '${_selectedFloorIds.length} floor${_selectedFloorIds.length == 1 ? '' : 's'} x '
                    '${_selectedDates.length} day${_selectedDates.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _assigning ? null : _saveAssignments,
              icon: _assigning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(localizations.tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  // --- Save Logic ---

  Future<void> _saveAssignments() async {
    setState(() => _assigning = true);

    final sortedDates = _selectedDates.toList()..sort();
    final dateRangeStr =
        '${sortedDates.first.day}/${sortedDates.first.month} - ${sortedDates.last.day}/${sortedDates.last.month}/${sortedDates.last.year}';

    int totalCreated = 0;
    final staffNames = <String>[];

    for (final staffId in _selectedStaffIds) {
      final staff = _staffService.staff.firstWhere(
        (s) => s.id == staffId,
        orElse: () => StaffMember(
            id: staffId, name: 'Unknown', role: StaffRole.cleaner),
      );
      staffNames.add(staff.name);

      for (final date in _selectedDates) {
        for (final floorId in _selectedFloorIds) {
          final ok = await _assignmentService.assignFloorToStaff(
            staffId: staffId,
            floorId: floorId,
            date: date,
          );
          if (ok) totalCreated++;
        }
      }

      if (_selectedFloorIds.isNotEmpty) {
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000 + staffId.hashCode,
          title: 'Floor Assignment',
          body: '${staff.name}: ${_selectedFloorIds.length} floor(s) assigned for $dateRangeStr',
        );
      }
    }

    setState(() {
      _assigning = false;
      _selectedDates.clear();
      _selectedStaffIds.clear();
      _selectedFloorIds.clear();
    });

    if (mounted) {
      showTimedSnackBar(
        SnackBar(
          content: Text(
            '$totalCreated assignment${totalCreated == 1 ? '' : 's'} saved for '
            '${staffNames.join(", ")}',
          ),
        ),
      );
    }
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
        GestureDetector(
          onTap: () {
            final next = RoomStatus.values[
                (RoomStatus.values.indexOf(room.status) + 1) %
                    RoomStatus.values.length];
            _roomService.updateRoomStatus(room.id, next);
          },
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
        _isFullAdmin ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: localizations.tr('editRoom'),
              onPressed: () {
                RoomFormPage.pendingRoom = room;
                Routefly.navigate('/admin/rooms/room_form');
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.error),
              tooltip: localizations.tr('deleteRoom'),
              onPressed: () => _confirmDelete(room),
            ),
          ],
        ) : const SizedBox.shrink(),
      ),
    ]);
  }

  void _confirmDelete(Room room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.tr('deleteRoom')),
        content: Text(
            '${localizations.tr('deleteRoomConfirm')} ${room.number}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(localizations.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _roomService.deleteRoom(room.id);
              if (mounted) {
                showTimedSnackBar(
                  SnackBar(
                    content: Text(localizations.tr('deleted')),
                    action: SnackBarAction(
                      label: localizations.tr('undo'),
                      onPressed: () async {
                        final re = await _roomService.createRoom(
                          number: room.number,
                          roomTypeId: room.roomTypeId,
                          floorId: room.floorId,
                          description: room.description,
                        );
                        if (re != null && re.status != room.status) {
                          await _roomService.updateRoomStatus(re.id, room.status);
                        }
                      },
                    ),
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
            child: Text(localizations.tr('delete')),
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

  void _showManageRoomsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ManageRoomsSheet(roomService: _roomService),
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
  String? _editingId;

  @override
  void dispose() {
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
                    localizations.tr('roomTypes'),
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
                      decoration: InputDecoration(
                        hintText: localizations.tr('description'),
                        border: const OutlineInputBorder(),
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
                                _editingId != null ? localizations.tr('update') : localizations.tr('add')),
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
                      decoration: InputDecoration(
                        hintText: localizations.tr('typeName'),
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
                        decoration: InputDecoration(
                          hintText: localizations.tr('description'),
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
                          Text(_editingId != null ? localizations.tr('update') : localizations.tr('add')),
                    ),
                    if (_editingId != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: _resetForm,
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: localizations.tr('cancel'),
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
                            tooltip: localizations.tr('edit'),
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
                            tooltip: localizations.tr('delete'),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                   title:
                                       Text(localizations.tr('editRoomType')),
                                       content: Text(
                                           '${localizations.tr('delete')} "${type.name}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(localizations.tr('cancel')),
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
                                      child: Text(localizations.tr('delete')),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await widget.roomService
                                    .deleteRoomType(type.id);
                                if (mounted) {
                                  showTimedSnackBar(
                                    SnackBar(
                                      content: Text(
                                          localizations.tr('deleted')),
                                       action: SnackBarAction(
                                        label: localizations.tr('undo'),
                                        onPressed: () async {
                                          await widget.roomService
                                              .createRoomType(
                                            name: type.name,
                                            description: type.description,
                                          );
                                        },
                                      ),
                                      duration:
                                          const Duration(seconds: 5),
                                    ),
                                  );
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

// --- Manage Rooms Sheet ---

class _ManageRoomsSheet extends StatefulWidget {
  final RoomService roomService;

  const _ManageRoomsSheet({required this.roomService});

  @override
  State<_ManageRoomsSheet> createState() => _ManageRoomsSheetState();
}

class _ManageRoomsSheetState extends State<_ManageRoomsSheet> {
  final _floorNumberController = TextEditingController();
  final _floorNameController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _roomDescController = TextEditingController();
  String? _addRoomTypeId;
  String? _expandedFloorId;

  @override
  void dispose() {
    _floorNumberController.dispose();
    _floorNameController.dispose();
    _roomNumberController.dispose();
    _roomDescController.dispose();
    super.dispose();
  }

  Future<void> _addFloor() async {
    final numberText = _floorNumberController.text.trim();
    if (numberText.isEmpty) return;

    final exists =
        widget.roomService.floors.any((f) => f.number == numberText);
    if (exists) {
      showTimedSnackBar(
        SnackBar(content: Text(localizations.tr('floorNumber'))),
      );
      await NotificationService().notifyError(
        title: 'Floor Already Exists',
        message: 'Floor number $numberText is already in use',
      );
      return;
    }

    await widget.roomService.createFloor(
      number: numberText,
      name: _floorNameController.text.trim().isEmpty
          ? null
          : _floorNameController.text.trim(),
    );

    _floorNumberController.clear();
    _floorNameController.clear();
    setState(() {});
  }

  Future<void> _addRoom(String floorId) async {
    final numberText = _roomNumberController.text.trim();
    if (numberText.isEmpty || _addRoomTypeId == null) return;

    final exists =
        widget.roomService.rooms.any((r) => r.number == numberText);
    if (exists) {
      showTimedSnackBar(
        SnackBar(content: Text(localizations.tr('roomNumber'))),
      );
      await NotificationService().notifyError(
        title: 'Room Already Exists',
        message: 'Room number $numberText is already in use',
      );
      return;
    }

    final room = await widget.roomService.createRoom(
      number: numberText,
      roomTypeId: _addRoomTypeId!,
      floorId: floorId,
      description: _roomDescController.text.trim().isEmpty
          ? null
          : _roomDescController.text.trim(),
    );

    if (room != null) {
      _roomNumberController.clear();
      _roomDescController.clear();
      _addRoomTypeId = null;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return DraggableScrollableSheet(
      initialChildSize: isMobile ? 0.85 : 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
                    localizations.tr('rooms'),
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
              const SizedBox(height: 12),
              Text(
                localizations.tr('addFloor'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              if (isMobile)
                Column(
                  children: [
                    TextField(
                      controller: _floorNumberController,
                      decoration: InputDecoration(
                        hintText: localizations.tr('floorNumber'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _floorNameController,
                      decoration: InputDecoration(
                        hintText: localizations.tr('floorName'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _addFloor,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(localizations.tr('addFloor')),
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
                        controller: _floorNumberController,
                        decoration: InputDecoration(
                          hintText: localizations.tr('floorNumber'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _floorNameController,
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
                        label: Text(localizations.tr('add')),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.roomService.floors.length,
                  itemBuilder: (context, index) {
                    final floor = widget.roomService.floors[index];
                    final floorRooms = widget.roomService.rooms
                        .where((r) => r.floorId == floor.id)
                        .toList()
                      ..sort(Room.compare);
                    final isExpanded = _expandedFloorId == floor.id;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                _expandedFloorId =
                                    isExpanded ? null : floor.id;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    child: Text(floor.number,
                                        style: const TextStyle(
                                            fontSize: 13)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(floor.displayName,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w600)),
                                        Text(
                                          '${floorRooms.length} room${floorRooms.length == 1 ? '' : 's'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error),
                                    tooltip: localizations.tr('editFloor'),
                                    onPressed: () async {
                                      if (floorRooms.isNotEmpty) {
                                        showTimedSnackBar(
                                          SnackBar(
                                                 content: Text(
                                                 localizations.tr('deleted')),
                                          ),
                                        );
                                        return;
                                      }
                                      final confirmed =
                                          await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                           title: Text(
                                               localizations.tr('editFloor')),
                                           content: Text(
                                               '${localizations.tr('delete')} "${floor.displayName}"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      ctx, false),
                                                   child:
                                                   Text(localizations.tr('cancel')),
                                            ),
                                            FilledButton(
                                              style: FilledButton
                                                  .styleFrom(
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .error,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      ctx, true),
                                                   child:
                                                   Text(localizations.tr('delete')),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await widget.roomService
                                            .deleteFloor(floor.id);
                                        if (mounted) {
                                          showTimedSnackBar(
                                            SnackBar(
                                               content: Text(
                                                   localizations.tr('deleted')),
                                              action: SnackBarAction(
                                                label: localizations.tr('undo'),
                                                onPressed: () async {
                                                  await widget.roomService
                                                      .createFloor(
                                                    number: floor.number,
                                                    name: floor.name,
                                                  );
                                                },
                                              ),
                                              duration: const Duration(
                                                  seconds: 5),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0,
                                    duration: const Duration(
                                        milliseconds: 200),
                                    child: const Icon(
                                        Icons.expand_more,
                                        size: 22),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration:
                                const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: isExpanded
                                ? Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                      borderRadius:
                                          const BorderRadius.only(
                                        bottomLeft:
                                            Radius.circular(10),
                                        bottomRight:
                                            Radius.circular(10),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (floorRooms.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                vertical: 12),
                                            child: Text(
                                              localizations.tr('noItems'),
                                              style: TextStyle(
                                                  color: Colors
                                                      .grey[500],
                                                  fontSize: 13),
                                            ),
                                          )
                                        else
                                          ...floorRooms.map(
                                            (room) => Padding(
                                              padding:
                                                  const EdgeInsets
                                                      .only(
                                                      bottom: 6),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .meeting_room_outlined,
                                                    size: 16,
                                                    color: Colors
                                                        .grey[600],
                                                  ),
                                                  const SizedBox(
                                                      width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      room.number,
                                                      style:
                                                          const TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .w500,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    room.roomTypeName ??
                                                        '-',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors
                                                          .grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      width: 8),
                                                  PopupMenuButton<
                                                      RoomStatus>(
                                                     tooltip:
                                                         localizations.tr('status'),
                                                    padding:
                                                        EdgeInsets
                                                            .zero,
                                                    onSelected: (s) =>
                                                        widget
                                                            .roomService
                                                            .updateRoomStatus(
                                                                room.id,
                                                                s),
                                                    itemBuilder:
                                                        (context) =>
                                                            RoomStatus
                                                                .values
                                                                .map((s) => PopupMenuItem(
                                                                    value:
                                                                        s,
                                                                    child:
                                                                        Text(s.label)))
                                                                .toList(),
                                                    child: Chip(
                                                      label: Text(
                                                          room.status
                                                              .label,
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .white,
                                                              fontSize:
                                                                  10)),
                                                      backgroundColor:
                                                          room.status
                                                              .color,
                                                      side: BorderSide
                                                          .none,
                                                      padding:
                                                          EdgeInsets
                                                              .zero,
                                                      materialTapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                      visualDensity:
                                                          VisualDensity
                                                              .compact,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                        Icons
                                                            .delete_outline,
                                                        size: 16,
                                                        color: Theme.of(
                                                                context)
                                                            .colorScheme
                                                            .error),
                                                    tooltip:
                                                        localizations.tr('deleteRoom'),
                                                    visualDensity:
                                                        VisualDensity
                                                            .compact,
                                                    onPressed:
                                                        () async {
                                                      final confirmed =
                                                          await showDialog<
                                                              bool>(
                                                        context:
                                                            context,
                                                        builder: (ctx) =>
                                                            AlertDialog(
                                                          title: Text(
                                                              localizations.tr('deleteRoom')),
                                                          content:
                                                              Text(
                                                                   '${localizations.tr('delete')} ${room.number}?'),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(ctx,
                                                                      false),
                                                              child: Text(
                                                                  localizations.tr('cancel')),
                                                            ),
                                                            FilledButton(
                                                              style: FilledButton
                                                                  .styleFrom(
                                                                backgroundColor:
                                                                    Theme.of(context)
                                                                        .colorScheme
                                                                        .error,
                                                              ),
                                                              onPressed: () =>
                                                                  Navigator.pop(ctx,
                                                                      true),
                                                              child: Text(
                                                                  localizations.tr('delete')),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirmed ==
                                                          true) {
                                                        await widget
                                                            .roomService
                                                            .deleteRoom(room.id);
                                                        if (mounted) {
                                                          showTimedSnackBar(
                                                            SnackBar(
                                                              content:
                                                                   Text(
                                                                       localizations.tr('deleted')),
                                                              action:
                                                                  SnackBarAction(
                                                                label:
                                                                    localizations.tr('undo'),
                                                                onPressed:
                                                                    () async {
                                                                  final re = await widget
                                                                      .roomService
                                                                      .createRoom(
                                                                    number: room.number,
                                                                    roomTypeId: room.roomTypeId,
                                                                    floorId: room.floorId,
                                                                    description: room.description,
                                                                  );
                                                                  if (re != null && re.status != room.status) {
                                                                    await widget.roomService.updateRoomStatus(re.id, room.status);
                                                                  }
                                                                },
                                                              ),
                                                              duration:
                                                                  const Duration(seconds: 5),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                        const Divider(height: 1),
                                        const SizedBox(height: 10),
                                        Text(
                                          '${localizations.tr('addRoom')} ${floor.displayName}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (isMobile)
                                          Column(
                                            children: [
                                              TextField(
                                                controller:
                                                    _roomNumberController,
                                                decoration:
                                                    InputDecoration(
                                                  hintText:
                                                      localizations.tr('roomNumber'),
                                                  border:
                                                      OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                              const SizedBox(
                                                  height: 8),
                                              DropdownButtonFormField<
                                                  String>(
                                                initialValue:
                                                    _addRoomTypeId,
                                                isDense: true,
                                                decoration:
                                                    InputDecoration(
                                                  labelText:
                                                      localizations.tr('roomType'),
                                                  border:
                                                      OutlineInputBorder(),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          horizontal:
                                                              8,
                                                          vertical:
                                                              6),
                                                ),
                                                items: widget
                                                    .roomService
                                                    .roomTypes
                                                    .map((rt) =>
                                                        DropdownMenuItem(
                                                          value:
                                                              rt.id,
                                                          child: Text(
                                                              rt.name),
                                                        ))
                                                    .toList(),
                                                onChanged: (v) =>
                                                    setState(() =>
                                                        _addRoomTypeId =
                                                            v),
                                              ),
                                              const SizedBox(
                                                  height: 8),
                                              TextField(
                                                controller:
                                                    _roomDescController,
                                               decoration:
                                                    InputDecoration(
                                                   hintText:
                                                       localizations.tr('description'),
                                                  border:
                                                      OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                              const SizedBox(
                                                  height: 8),
                                              SizedBox(
                                                width:
                                                    double.infinity,
                                                child:
                                                    FilledButton
                                                        .icon(
                                                  onPressed: () =>
                                                      _addRoom(
                                                          floor.id),
                                                  icon: const Icon(
                                                      Icons.add,
                                                      size: 18),
                                                   label: Text(
                                                       localizations.tr('addRoom')),
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Row(
                                            children: [
                                              SizedBox(
                                                width: 100,
                                                child: TextField(
                                                  controller:
                                                      _roomNumberController,
                                                  decoration:
                                                      InputDecoration(
                                                    hintText:
                                                        localizations.tr('roomNumber'),
                                                    border:
                                                        OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                  width: 8),
                                              SizedBox(
                                                width: 150,
                                                child:
                                                    DropdownButtonFormField<
                                                        String>(
                                                  initialValue:
                                                      _addRoomTypeId,
                                                  isDense: true,
                                                    decoration:
                                                       InputDecoration(
                                                     labelText:
                                                         localizations.tr('roomType'),
                                                    border:
                                                        OutlineInputBorder(),
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                            horizontal:
                                                                8,
                                                            vertical:
                                                                6),
                                                  ),
                                                  items: widget
                                                      .roomService
                                                      .roomTypes
                                                      .map((rt) =>
                                                          DropdownMenuItem(
                                                            value:
                                                                rt.id,
                                                            child: Text(
                                                                rt.name),
                                                          ))
                                                      .toList(),
                                                  onChanged: (v) =>
                                                      setState(() =>
                                                          _addRoomTypeId =
                                                              v),
                                                ),
                                              ),
                                              const SizedBox(
                                                  width: 8),
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      _roomDescController,
                                                  decoration:
                                                      InputDecoration(
                                                    hintText:
                                                        localizations.tr('description'),
                                                    border:
                                                        OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                  width: 8),
                                              FilledButton.icon(
                                                onPressed: () =>
                                                    _addRoom(
                                                        floor.id),
                                                icon: const Icon(
                                                    Icons.add,
                                                    size: 18),
                        label: Text(localizations.tr('add')),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
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
