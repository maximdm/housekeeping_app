import 'dart:async';

import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';

import '../../../main.dart';
import '../../../models/staff_member.dart';
import '../../../services/staff_service.dart';
import '../../../services/schedule_service.dart';
import '../../../services/assignment_service.dart';
import '../../../layouts/admin_layout.dart';
import '../../../widgets/schedule_calendar.dart';
import 'staff_form_page.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final StaffService _staffService = StaffService();
  final ScheduleService _scheduleService = ScheduleService();
  final List<Timer> _pendingTimers = [];
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _staffService.addListener(_onDataChanged);
    _staffService.loadStaff();
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _staffService.removeListener(_onDataChanged);
    _staffService.dispose();
    _scheduleService.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return AdminLayout(
      currentRoute: '/admin/staff',
      floatingActionButton: isMobile && !_showCalendar
          ? FloatingActionButton(
              heroTag: 'staff_add_fab',
              onPressed: _staffService.canAddMore
                  ? () => Routefly.navigate('/admin/staff/staff_form')
                  : null,
              child: const Icon(Icons.person_add),
            )
          : null,
      child: Scaffold(
        appBar: AppBar(
          title: isMobile
              ? Text(
                  'Staff (${_staffService.staffCount}/${StaffService.maxAccounts})')
              : const Text('Staff'),
          actions: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.people_outline, size: 20),
                  label: Text('Cards'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.calendar_month, size: 20),
                  label: Text('Schedule'),
                ),
              ],
              selected: {_showCalendar},
              onSelectionChanged: (v) => setState(() => _showCalendar = v.first),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _staffService.canAddMore
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3)
                      : Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _staffService.canAddMore
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      size: 16,
                      color: _staffService.canAddMore
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_staffService.staffCount}/${StaffService.maxAccounts}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _staffService.canAddMore
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _staffService.canAddMore
                    ? () =>
                        Routefly.navigate('/admin/staff/staff_form')
                    : null,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Staff'),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
        body: _showCalendar
            ? ScheduleCalendar(
                staffList: _staffService.staff,
                scheduleService: _scheduleService,
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: _staffService.staff.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 600) {
                            return ListView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: _staffService.staff.length,
                              itemBuilder: (context, index) =>
                                  _buildStaffCard(
                                      _staffService.staff[index]),
                            );
                          }

                          int crossAxisCount = constraints.maxWidth > 1200
                              ? 4
                              : constraints.maxWidth > 800
                                  ? 3
                                  : 2;

                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.6,
                            ),
                            itemCount: _staffService.staff.length,
                            itemBuilder: (context, index) =>
                                _buildStaffCard(
                                    _staffService.staff[index]),
                          );
                        },
                      ),
              ),
      ),
    );
  }

  Widget _buildStaffCard(StaffMember staff) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    if (isCompact) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              staff.name.isNotEmpty
                  ? staff.name[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(staff.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  staff.role.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (staff.assignedRooms > 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showRoomAssignments(staff),
                  child: Text('${staff.assignedRooms} rooms',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _staffService.toggleOnShift(staff.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        staff.status.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    staff.status.label,
                    style: TextStyle(
                      color: staff.status.color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon:
                    const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) =>
                    <PopupMenuEntry<String>>[
                  const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Profile')),
                  PopupMenuItem(
                    value: staff.isActive
                        ? 'deactivate'
                        : 'activate',
                    child: Text(
                      staff.isActive
                          ? 'Deactivate'
                          : 'Activate',
                      style: TextStyle(
                        color: staff.isActive
                            ? Colors.red
                            : Theme.of(context)
                                .colorScheme
                                .primary,
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .error)),
                  ),
                ],
                onSelected: (value) =>
                    _handleMenuAction(value, staff),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    staff.name.isNotEmpty
                        ? staff.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  itemBuilder: (context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Profile')),
                    PopupMenuItem(
                      value: staff.isActive
                          ? 'deactivate'
                          : 'activate',
                      child: Text(
                        staff.isActive
                            ? 'Deactivate'
                            : 'Activate',
                        style: TextStyle(
                          color: staff.isActive
                              ? Colors.red
                              : Theme.of(context)
                                  .colorScheme
                                  .primary,
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error)),
                    ),
                  ],
                  onSelected: (value) =>
                      _handleMenuAction(value, staff),
                ),
              ],
            ),
            const Spacer(),
            Text(staff.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(staff.role.label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _staffService.toggleOnShift(staff.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          staff.status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      staff.status.label,
                      style: TextStyle(
                        color: staff.status.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showRoomAssignments(staff),
                  child: staff.assignedRooms > 0
                      ? Text('${staff.assignedRooms} Rooms',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              decoration: TextDecoration.underline))
                      : Text('No rooms',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500])),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomAssignments(StaffMember staff) async {
    final assignmentService = AssignmentService();
    final assignments = await assignmentService.getStaffAssignments(staff.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${staff.name} - Rooms',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: assignments.isEmpty
                  ? const Center(
                      child: Text('No rooms assigned'),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: assignments.length,
                      itemBuilder: (ctx, index) {
                        final a = assignments[index];
                        final room = a['rooms'] as Map<String, dynamic>?;
                        final roomNumber = room?['number'] ?? '?';
                        final completed = a['completed_at'] != null;
                        return ListTile(
                          leading: Icon(
                            completed
                                ? Icons.check_circle
                                : Icons.meeting_room,
                            color: completed
                                ? Colors.green
                                : Theme.of(context).colorScheme.primary,
                          ),
                          title: Text('Room $roomNumber'),
                          subtitle: Text(
                            completed ? 'Completed' : 'In progress',
                            style: TextStyle(
                              color: completed ? Colors.green : Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                          trailing: completed
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Unassign',
                                  onPressed: () async {
                                    final roomId = a['room_id'] as String;
                                    final staffId = a['staff_id'] as String;
                                    await assignmentService
                                        .unassignRoom(a['id'] as String);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                    if (mounted) {
                                      Timer? undoTimer;
                                      showTimedSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Room unassigned from ${staff.name}'),
                                          action: SnackBarAction(
                                            label: 'Undo',
                                            onPressed: () async {
                                              undoTimer?.cancel();
                                              await assignmentService
                                                  .assignRoom(
                                                roomId: roomId,
                                                staffId: staffId,
                                              );
                                              if (mounted) _staffService.loadStaff();
                                            },
                                          ),
                                          duration: const Duration(
                                              seconds: 5),
                                        ),
                                      );
                                      undoTimer = Timer(
                                          const Duration(seconds: 5),
                                          () async {
                                        if (mounted) _staffService.loadStaff();
                                      });
                                      _pendingTimers.add(undoTimer);
                                    }
                                  },
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action, StaffMember staff) {
    switch (action) {
      case 'edit':
        StaffFormPage.pendingStaff = staff;
        Routefly.navigate('/admin/staff/staff_form');
        break;
      case 'deactivate':
        _confirmDeactivate(staff);
        break;
      case 'activate':
        _staffService.activateStaff(staff.id);
        break;
      case 'delete':
        _confirmDelete(staff);
        break;
    }
  }

  void _confirmDeactivate(StaffMember staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Staff'),
        content: Text(
          'Deactivate ${staff.name}? They will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _staffService.deactivateStaff(staff.id);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(StaffMember staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text(
          'Permanently delete ${staff.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _staffService.staff.removeWhere((s) => s.id == staff.id);
              });
              if (mounted) {
                Timer? undoTimer;
                showTimedSnackBar(
                  SnackBar(
                    content: Text('${staff.name} deleted'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        undoTimer?.cancel();
                        if (mounted) {
                          setState(() {
                            _staffService.staff.add(staff);
                          });
                        }
                      },
                    ),
                    duration: const Duration(seconds: 5),
                  ),
                );
                undoTimer = Timer(const Duration(seconds: 5), () async {
                  if (mounted) {
                    await _staffService.deleteStaff(staff.id);
                  }
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
}
