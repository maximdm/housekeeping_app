import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';
import '../../../models/room.dart';
import '../../../models/shift.dart';
import '../../../services/assignment_service.dart';
import '../../../services/shift_service.dart';
import '../../../services/database_helper.dart';
import '../../../layouts/staff_layout.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  final AssignmentService _assignmentService = AssignmentService();
  final ShiftService _shiftService = ShiftService();
  String? _staffId;
  List<Room> _dirtyRooms = [];
  bool _loading = true;
  int _unreadStaffNotes = 0;

  // Schedule state
  bool _showSchedule = false;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  List<StaffShiftAssignment> _monthAssignments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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

      if (staffData != null) {
        _staffId = staffData['id'] as String;
      }
    } catch (e) {
      debugPrint('Error loading staff data, trying cache: $e');
    }

    if (_staffId == null) {
      try {
        final db = await DatabaseHelper.database;
        if (db != null) {
          final rows = await db.query(
            'staff_cache',
            where: 'user_id = ?',
            whereArgs: [user.id],
          );
          if (rows.isNotEmpty) {
            _staffId = rows.first['id'] as String;
          }
        }
      } catch (e2) {
        debugPrint('Error loading staff from cache: $e2');
      }
    }

    if (_staffId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      _dirtyRooms = await _assignmentService.loadMyDirtyRoomsForDate(
        _staffId!,
        DateTime.now(),
      );
      final receivedNotes = await _assignmentService.loadReceivedStaffNotes(_staffId!);
      _unreadStaffNotes = receivedNotes.where((n) => !n.isRead).length;
      await _loadMonth();
    } catch (e) {
      debugPrint('Error loading staff data: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMonth() async {
    if (_staffId == null) return;
    _monthAssignments = await _shiftService.loadMyShiftAssignmentsForMonth(
      _staffId!,
      _focusedMonth,
    );
  }

  List<StaffShiftAssignment> get _assignmentsForDate {
    return _monthAssignments
        .where((a) =>
            a.assignmentDate.year == _selectedDate.year &&
            a.assignmentDate.month == _selectedDate.month &&
            a.assignmentDate.day == _selectedDate.day)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return StaffLayout(
      currentTabIndex: 0,
      title: localizations.tr('tasks'),
      appBarActions: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.checklist_outlined, size: 20),
              label: Text(localizations.tr('tasks')),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.calendar_month_outlined, size: 20),
              label: Text(localizations.tr('schedule')),
            ),
          ],
          selected: {_showSchedule},
          onSelectionChanged: (v) => setState(() => _showSchedule = v.first),
        ),
        const SizedBox(width: 8),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _showSchedule
              ? _buildScheduleView()
              : _buildTasksView(),
    );
  }

  // ─── Tasks View ─────────────────────────────────────────────

  Widget _buildTasksView() {
    return _dirtyRooms.isEmpty ? _buildEmptyState() : _buildTasksContent();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            localizations.tr('noTasksAssigned'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.tr('noRoomAssignments'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: _loadData,
            child: Text(localizations.tr('refresh')),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksContent() {
    final grouped = <String, List<Room>>{};
    for (final room in _dirtyRooms) {
      final floorName = room.floorName ?? 'Unassigned';
      grouped.putIfAbsent(floorName, () => []).add(room);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (_unreadStaffNotes > 0) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Routefly.navigate('/shared/notes'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.tr('staffNotes'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              localizations.tr('newStaffNotesCount')
                                  .replaceAll('{count}', '$_unreadStaffNotes'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onPrimaryContainer),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            localizations.tr('todaysTasks'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...grouped.entries.map((entry) {
            final rooms = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${rooms.length} rooms',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ...rooms.map((room) => _buildTaskCard(room)),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Room room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openRoomDetail(room),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: room.status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    room.number,
                    style: TextStyle(
                      color: room.status.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room ${room.number}',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${room.roomTypeName ?? 'Room'} · ${room.floorName ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRoomDetail(Room room) async {
    StaffSelectedRoom.instance = room;
    await Routefly.navigate('/staff/home/room_detail');
    _loadData();
  }

  // ─── Schedule View ──────────────────────────────────────────

  Widget _buildScheduleView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildMonthCalendar(),
          const SizedBox(height: 16),
          _buildSelectedDayInfo(),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;

    final months = [
      '', localizations.tr('january'), localizations.tr('february'),
      localizations.tr('march'), localizations.tr('april'),
      localizations.tr('may'), localizations.tr('june'),
      localizations.tr('july'), localizations.tr('august'),
      localizations.tr('september'), localizations.tr('october'),
      localizations.tr('november'), localizations.tr('december'),
    ];

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 100) return;
        setState(() {
          _focusedMonth = v > 0
              ? DateTime(_focusedMonth.year, _focusedMonth.month, _focusedMonth.day - 7)
              : DateTime(_focusedMonth.year, _focusedMonth.month, _focusedMonth.day + 7);
        });
        _loadMonth().then((_) { if (mounted) setState(() {}); });
      },
      child: Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: () async {
                    setState(() {
                      _focusedMonth = DateTime(
                          _focusedMonth.year, _focusedMonth.month - 1);
                    });
                    await _loadMonth();
                    setState(() {});
                  },
                ),
                GestureDetector(
                  onTap: () async {
                    setState(() => _focusedMonth = DateTime.now());
                    await _loadMonth();
                    setState(() {});
                  },
                  child: Text(
                    '${months[_focusedMonth.month]} ${_focusedMonth.year}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: () async {
                    setState(() {
                      _focusedMonth = DateTime(
                          _focusedMonth.year, _focusedMonth.month + 1);
                    });
                    await _loadMonth();
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [localizations.tr('mon'), localizations.tr('tue'), localizations.tr('wed'), localizations.tr('thu'), localizations.tr('fri'), localizations.tr('sat'), localizations.tr('sun')]
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            ...List.generate(
              ((startWeekday - 1 + daysInMonth + 6) ~/ 7),
              (week) {
                return Row(
                  children: List.generate(7, (dayIndex) {
                    final dayNum =
                        week * 7 + dayIndex - (startWeekday - 1) + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 44));
                    }
                    final date = DateTime(
                        _focusedMonth.year, _focusedMonth.month, dayNum);
                    return Expanded(child: _buildDayCell(date));
                  }),
                );
              },
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildDayCell(DateTime date) {
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isPast = date.isBefore(today) && !isToday;
    final isSelected = date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;

    final dayAssignment = _monthAssignments.firstWhere(
      (a) =>
          a.assignmentDate.year == date.year &&
          a.assignmentDate.month == date.month &&
          a.assignmentDate.day == date.day,
      orElse: () => StaffShiftAssignment(
        id: '',
        staffId: '',
        shiftId: '',
        assignmentDate: date,
      ),
    );

    final hasShift = dayAssignment.id.isNotEmpty;
    final shiftColor =
        hasShift ? parseHexColor(dayAssignment.shiftColor) : null;

    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: Container(
        height: 44,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : isToday
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3)
                  : null,
          borderRadius: BorderRadius.circular(8),
          border: !isSelected && isToday
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: (isToday || isSelected)
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : isPast
                        ? Colors.grey[400]
                        : null,
              ),
            ),
            if (hasShift)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: isPast
                      ? Colors.grey[400]
                      : shiftColor ?? Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayInfo() {
    final assignments = _assignmentsForDate;
    final today = DateTime.now();
    final isToday = _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    isToday ? 'Today' : _formatDate(_selectedDate),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (assignments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy,
                            size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text(
                          localizations.tr('noShiftAssigned'),
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...assignments.map((a) {
                  final color = parseHexColor(a.shiftColor,
                      fallback:
                          Theme.of(context).colorScheme.primary);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.shiftName ?? 'Unknown Shift',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTimeRange(
                                    a.shiftStartTime, a.shiftEndTime),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _formatTimeRange(TimeOfDay? start, TimeOfDay? end) {
    if (start == null || end == null) return '';
    return '${_fmt(start)} – ${_fmt(end)}';
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
