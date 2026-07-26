import 'dart:async';

import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';
import '../../../models/shift.dart';
import '../../../models/staff_member.dart';
import '../../../services/auth_service.dart';
import '../../../services/shift_service.dart';
import '../../../services/staff_service.dart';
import '../../../widgets/multi_select_calendar.dart';
import '../../../layouts/admin_layout.dart';
import 'staff_form_page.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final AuthService _authService = AuthService();
  final StaffService _staffService = StaffService();
  final ShiftService _shiftService = ShiftService();
  final List<Timer> _pendingTimers = [];
  bool _isFullAdmin = false;

  int _tabIndex = 0; // 0=Schedule, 1=Staff, 2=Manage Shifts

  // Schedule state
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  final Set<String> _selectedScheduleStaffIds = {};
  List<StaffShiftAssignment> _monthAssignments = [];

  // Manage shifts state
  final Set<DateTime> _selectedDates = {};
  final Set<String> _selectedStaffIds = {};
  String? _selectedShiftId;
  bool _assigning = false;
  bool _clearingPast = false;

  @override
  void initState() {
    super.initState();
    _authService.init();
    _detectRole();
    _staffService.addListener(_onDataChanged);
    _loadData();
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
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _staffService.removeListener(_onDataChanged);
    _staffService.dispose();
    _shiftService.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    await Future.wait([
      _staffService.loadStaff(),
      _shiftService.loadShifts(),
    ]);
    await _loadMonth();
    if (mounted) setState(() {});
  }

  Future<void> _loadMonth() async {
    final allAssignments = <StaffShiftAssignment>[];
    for (final s in _staffService.staff) {
      final assignments = await _shiftService.loadMyShiftAssignmentsForMonth(
        s.id,
        _focusedMonth,
      );
      allAssignments.addAll(assignments);
    }
    _monthAssignments = allAssignments;
  }

  List<StaffShiftAssignment> get _assignmentsForSelectedStaff {
    if (_selectedScheduleStaffIds.isEmpty) return _assignmentsForDate;
    return _assignmentsForDate
        .where((a) => _selectedScheduleStaffIds.contains(a.staffId))
        .toList();
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
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return AdminLayout(
      currentRoute: '/admin/staff',
      isFullAdmin: _isFullAdmin,
      floatingActionButton: isMobile && _tabIndex == 1 && _isFullAdmin
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
                  '${localizations.tr('staff')} (${_staffService.staffCount}/${StaffService.maxAccounts})')
              : Text(localizations.tr('staff')),
          actions: [
            _buildTabSelector(),
            if (!isMobile && _isFullAdmin && _tabIndex == 1) ...[
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
                label: Text(localizations.tr('addStaff')),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
        body: _tabIndex == 0
            ? _buildScheduleTab()
            : _tabIndex == 1
                ? _buildStaffTab()
                : _buildManageShiftsTab(),
      ),
    );
  }

  // ─── Tab Selector ──────────────────────────────────────────

  Widget _buildTabSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TabChip(
          label: localizations.tr('schedule'),
          icon: Icons.calendar_month_outlined,
          selected: _tabIndex == 0,
          onTap: () => setState(() => _tabIndex = 0),
        ),
        _TabChip(
          label: localizations.tr('staff'),
          icon: Icons.people_outline,
          selected: _tabIndex == 1,
          onTap: () => setState(() => _tabIndex = 1),
        ),
        if (_isFullAdmin)
          _TabChip(
            label: localizations.tr('shifts'),
            icon: Icons.settings_outlined,
            selected: _tabIndex == 2,
            onTap: () => setState(() => _tabIndex = 2),
          ),
      ],
    );
  }

  // ─── Schedule Tab ──────────────────────────────────────────

  Widget _buildScheduleTab() {
    return Column(
      children: [
        _buildStaffFilter(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildMonthCalendar(),
                const SizedBox(height: 16),
                _buildSelectedDayInfo(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffFilter() {
    final staff = _staffService.staff
        .where((s) => s.isActive)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                _selectedScheduleStaffIds.isEmpty
                    ? localizations.tr('allStaff')
                    : '${_selectedScheduleStaffIds.length} ${localizations.tr('staffFilter')}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showScheduleStaffFilterPopup(staff),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedScheduleStaffIds.isEmpty
                          ? localizations.tr('showingAllStaff')
                          : '${_selectedScheduleStaffIds.length} ${localizations.tr('staffFilter')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _selectedScheduleStaffIds.isEmpty
                            ? Colors.grey[500]
                            : Theme.of(context)
                                .colorScheme
                                .onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleStaffFilterPopup(List<StaffMember> staff) {
    final tempSelected = Set<String>.from(_selectedScheduleStaffIds);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Text(localizations.tr('filterByStaff')),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    if (tempSelected.length == staff.length) {
                      tempSelected.clear();
                    } else {
                      tempSelected.addAll(staff.map((s) => s.id));
                    }
                  });
                },
                child: Text(
                  tempSelected.length == staff.length
                      ? 'None'
                      : 'All',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: staff.isEmpty
                ? Text(localizations.tr('noActiveStaff'),
                    style: TextStyle(color: Colors.grey[500]))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: staff.length,
                    itemBuilder: (ctx, index) {
                      final s = staff[index];
                      final selected = tempSelected.contains(s.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              tempSelected.add(s.id);
                            } else {
                              tempSelected.remove(s.id);
                            }
                          });
                        },
                        title: Text(s.name,
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text(s.role.label,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600])),
                        secondary: CircleAvatar(
                          radius: 16,
                          backgroundColor: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                              : Colors.grey[300],
                          child: Text(
                            s.name.isNotEmpty
                                ? s.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white),
                          ),
                        ),
                        controlAffinity:
                            ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(localizations.tr('cancel')),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _selectedScheduleStaffIds
                  ..clear()
                  ..addAll(tempSelected));
                Navigator.pop(ctx);
              },
              child: Text(localizations.tr('done')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthCalendar() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;

    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
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

    final dayAssignments = _monthAssignments
        .where((a) =>
            a.assignmentDate.year == date.year &&
            a.assignmentDate.month == date.month &&
            a.assignmentDate.day == date.day)
        .toList();

    final hasAssignments = dayAssignments.isNotEmpty;
    final uniqueColors = dayAssignments
        .map((a) => parseHexColor(a.shiftColor))
        .toSet()
        .toList();

    return GestureDetector(
      onTap: () async {
        setState(() => _selectedDate = date);
        await _loadMonth();
        setState(() {});
      },
      child: Container(
        height: 48,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : isToday
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3)
                  : hasAssignments
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.12)
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
                fontWeight: (isToday || isSelected || (hasAssignments && !isPast))
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : isPast
                        ? Colors.grey[400]
                        : null,
              ),
            ),
            if (hasAssignments) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...uniqueColors.take(3).map((color) {
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : isPast
                                ? Colors.grey[400]
                                : color,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                  if (dayAssignments.length > 3)
                    Text(
                      '+${dayAssignments.length - 3}',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : isPast
                                ? Colors.grey[400]
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayInfo() {
    final assignments = _assignmentsForSelectedStaff;
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
                                a.staffName ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${a.shiftName ?? '?'}  ·  ${_formatTimeRange(a.shiftStartTime, a.shiftEndTime)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        if (_isFullAdmin)
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 20,
                                color: Theme.of(context)
                                    .colorScheme
                                    .error
                                    .withValues(alpha: 0.7)),
                            tooltip: 'Remove shift',
                            onPressed: () =>
                                _confirmUnassignShift(a),
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

  Future<void> _confirmUnassignShift(StaffShiftAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove shift assignment'),
        content: Text(
          'Remove ${assignment.shiftName ?? 'shift'} from ${assignment.staffName ?? 'this staff'} on ${_formatDate(assignment.assignmentDate)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(localizations.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _shiftService.unassignShiftFromStaff(
        staffId: assignment.staffId,
        shiftId: assignment.shiftId,
        date: assignment.assignmentDate,
      );
      if (mounted && success) {
        await _loadMonth();
        setState(() {});
      }
    }
  }

  // ─── Staff Tab ─────────────────────────────────────────────

  Widget _buildStaffTab() {
    return Padding(
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
                        _buildStaffCard(_staffService.staff[index]),
                  );
                }

                int crossAxisCount = constraints.maxWidth > 1200
                    ? 4
                    : constraints.maxWidth > 800
                        ? 3
                        : 2;

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: _staffService.staff.length,
                  itemBuilder: (context, index) =>
                      _buildStaffCard(_staffService.staff[index]),
                );
              },
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
                Text('${staff.assignedRooms} rooms',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary)),
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
                    color: staff.status.color.withValues(alpha: 0.1),
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
              if (_isFullAdmin)
                  PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem(value: 'edit', child: Text(localizations.tr('editProfile'))),
                    if (staff.role != StaffRole.manager)
                      PopupMenuItem(
                        value: staff.isActive ? 'deactivate' : 'activate',
                        child: Text(
                          staff.isActive ? localizations.tr('deactivate') : localizations.tr('activate'),
                          style: TextStyle(
                            color: staff.isActive ? Colors.red : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    if (staff.role != StaffRole.manager) ...[
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(localizations.tr('delete'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    ],
                  ],
                  onSelected: (value) => _handleMenuAction(value, staff),
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
                if (_isFullAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      PopupMenuItem(
                          value: 'edit',
                          child: Text(localizations.tr('editProfile'))),
                      if (staff.role != StaffRole.manager)
                        PopupMenuItem(
                          value: staff.isActive ? 'deactivate' : 'activate',
                          child: Text(
                            staff.isActive ? localizations.tr('deactivate') : localizations.tr('activate'),
                            style: TextStyle(
                              color: staff.isActive
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      if (staff.role != StaffRole.manager) ...[
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(localizations.tr('delete'),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ),
                      ],
                    ],
                    onSelected: (value) => _handleMenuAction(value, staff),
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
                staff.assignedRooms > 0
                    ? Text('${staff.assignedRooms} Rooms',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .primary))
                    : Text('No rooms',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500])),
              ],
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
        title: Text(localizations.tr('deactivateStaff')),
        content: Text(
          'Deactivate ${staff.name}? They will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(localizations.tr('cancel')),
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
            child: Text(localizations.tr('deactivate')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(StaffMember staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.tr('deleteStaff')),
        content: Text(
          'Permanently delete ${staff.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(localizations.tr('cancel')),
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
            child: Text(localizations.tr('delete')),
          ),
        ],
      ),
    );
  }

  // ─── Manage Shifts Tab ─────────────────────────────────────

  Widget _buildManageShiftsTab() {
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
                _buildStaffMultiSelect(),
                const SizedBox(height: 8),
                _buildShiftSelect(),
                const SizedBox(height: 8),
                _buildShiftList(),
                const SizedBox(height: 8),
                _buildClearPastShiftsButton(),
              ],
            ),
          ),
        ),
        if (_selectedDates.isNotEmpty &&
            _selectedStaffIds.isNotEmpty &&
            _selectedShiftId != null)
          _buildAssignBar(),
      ],
    );
  }

  Widget _buildStaffMultiSelect() {
    final staff = _staffService.staff
        .where((s) => s.isActive)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                _selectedStaffIds.isEmpty
                    ? localizations.tr('selectStaff')
                    : '${_selectedStaffIds.length} ${localizations.tr('staffSelected')}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showStaffMultiSelectPopup(staff),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedStaffIds.isEmpty
                          ? localizations.tr('tapToSelectStaff')
                          : '${_selectedStaffIds.length} ${localizations.tr('staffSelected')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _selectedStaffIds.isEmpty
                            ? Colors.grey[500]
                            : Theme.of(context)
                                .colorScheme
                                .onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStaffMultiSelectPopup(List<StaffMember> staff) {
    final tempSelected = Set<String>.from(_selectedStaffIds);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Text(localizations.tr('selectStaff')),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    if (tempSelected.length == staff.length) {
                      tempSelected.clear();
                    } else {
                      tempSelected.addAll(staff.map((s) => s.id));
                    }
                  });
                },
                child: Text(
                  tempSelected.length == staff.length
                      ? 'None'
                      : 'All',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: staff.isEmpty
                ? Text(localizations.tr('noActiveStaff'),
                    style: TextStyle(color: Colors.grey[500]))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: staff.length,
                    itemBuilder: (ctx, index) {
                      final s = staff[index];
                      final selected = tempSelected.contains(s.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              tempSelected.add(s.id);
                            } else {
                              tempSelected.remove(s.id);
                            }
                          });
                        },
                        title: Text(s.name,
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text(s.role.label,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600])),
                        secondary: CircleAvatar(
                          radius: 16,
                          backgroundColor: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                              : Colors.grey[300],
                          child: Text(
                            s.name.isNotEmpty
                                ? s.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white),
                          ),
                        ),
                        controlAffinity:
                            ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(localizations.tr('cancel')),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _selectedStaffIds
                  ..clear()
                  ..addAll(tempSelected));
                Navigator.pop(ctx);
              },
              child: Text(localizations.tr('done')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftSelect() {
    final shifts = _shiftService.shifts;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                _selectedShiftId == null
                    ? localizations.tr('selectShift')
                    : localizations.tr('shiftSelected'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (shifts.isEmpty)
            Text(localizations.tr('noShiftsDefined'),
                style: TextStyle(color: Colors.grey[500], fontSize: 13))
          else
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shifts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final shift = shifts[index];
                  final selected = _selectedShiftId == shift.id;
                  final color = shift.displayColor;
                  return FilterChip(
                    label: Text(shift.name,
                        style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedShiftId =
                            selected ? null : shift.id;
                      });
                    },
                    avatar: CircleAvatar(
                      radius: 10,
                      backgroundColor: color,
                    ),
                    selectedColor: color.withValues(alpha: 0.2),
                    checkmarkColor: color,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShiftList() {
    final shifts = _shiftService.shifts;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                localizations.tr('shiftTypes'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showShiftTypesPopup(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shifts.isEmpty
                          ? localizations.tr('noShiftsYet')
                          : '${shifts.length} shift type${shifts.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: shifts.isEmpty
                            ? Colors.grey[500]
                            : Theme.of(context)
                                .colorScheme
                                .onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showShiftTypesPopup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(localizations.tr('shiftTypes')),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showShiftForm();
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text(localizations.tr('add'),
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _shiftService.shifts.isEmpty
              ? Text(localizations.tr('noShiftsYet'),
                  style: TextStyle(color: Colors.grey[500]))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _shiftService.shifts.length,
                  itemBuilder: (ctx, index) {
                    final shift = _shiftService.shifts[index];
                    final color = shift.displayColor;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 4,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      title: Text(shift.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      subtitle: Text(shift.timeRange,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                size: 18,
                                color: Colors.grey[500]),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showShiftForm(shift: shift);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 18,
                                color: Colors.grey[500]),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final confirmed =
                                  await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(localizations.tr('deleteShift')),
                                  content: Text(
                                      'Delete "${shift.name}" shift?'),
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
                                      child: Text(
                                          localizations.tr('delete')),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await _shiftService
                                    .deleteShift(shift.id);
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(localizations.tr('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildClearPastShiftsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _clearingPast ? null : _clearPastShifts,
          icon: _clearingPast
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_sweep_outlined, size: 18),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .error
                    .withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          label: Text(_clearingPast ? 'Clearing...' : 'Clear Past Shifts'),
        ),
      ),
    );
  }

  Future<void> _clearPastShifts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear past shifts'),
        content: const Text(
          'This will remove all shift assignments for days that have already passed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(localizations.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _clearingPast = true);
      final count = await _shiftService.deletePastShiftAssignments();
      if (mounted) {
        setState(() => _clearingPast = false);
        await _loadMonth();
        setState(() {});
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Cleared $count past shift assignment${count == 1 ? '' : 's'}'
                  : 'No past shifts to clear',
            ),
          ),
        );
      }
    }
  }

  Widget _buildAssignBar() {
    final count = _selectedStaffIds.length * _selectedDates.length;

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
                    '$count ${localizations.tr('assignments')}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${_selectedStaffIds.length} staff x '
                    '${_selectedDates.length} day${_selectedDates.length == 1 ? '' : 's'}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(localizations.tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAssignments() async {
    setState(() => _assigning = true);

    int totalCreated = 0;

    for (final staffId in _selectedStaffIds) {
      for (final date in _selectedDates) {
        final ok = await _shiftService.assignShiftToStaff(
          staffId: staffId,
          shiftId: _selectedShiftId!,
          date: date,
        );
        if (ok) totalCreated++;
      }
    }

    setState(() {
      _assigning = false;
      _selectedDates.clear();
      _selectedStaffIds.clear();
      _selectedShiftId = null;
    });

    await _loadMonth();
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$totalCreated ${localizations.tr('assignmentSaved')}',
          ),
        ),
      );
    }
  }

  // ─── Shift Form ────────────────────────────────────────────

  void _showShiftForm({Shift? shift}) {
    final nameCtrl = TextEditingController(text: shift?.name ?? '');
    TimeOfDay startTime =
        shift?.startTime ?? const TimeOfDay(hour: 6, minute: 0);
    TimeOfDay endTime =
        shift?.endTime ?? const TimeOfDay(hour: 14, minute: 0);
    String selectedColor = shift?.color ?? '#FF9800';

    final colors = [
      '#FF9800', '#2196F3', '#9C27B0', '#4CAF50',
      '#F44336', '#00BCD4', '#FF5722', '#607D8B',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shift == null ? localizations.tr('newShift') : localizations.tr('editShift'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: localizations.tr('shiftName'),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(localizations.tr('startTime'),
                          style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: startTime,
                        );
                        if (picked != null) {
                          setSheetState(() => startTime = picked);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(localizations.tr('endTime'),
                          style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: endTime,
                        );
                        if (picked != null) {
                          setSheetState(() => endTime = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(localizations.tr('color'),
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((c) {
                  final isSel = selectedColor == c;
                  return GestureDetector(
                    onTap: () =>
                        setSheetState(() => selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: parseHexColor(c),
                        shape: BoxShape.circle,
                        border: isSel
                            ? Border.all(
                                color: Colors.black, width: 2)
                            : null,
                      ),
                      child: isSel
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final success = shift == null
                        ? await _shiftService.createShift(
                            name: nameCtrl.text.trim(),
                            startTime: startTime,
                            endTime: endTime,
                            color: selectedColor,
                          )
                        : await _shiftService.updateShift(
                            id: shift.id,
                            name: nameCtrl.text.trim(),
                            startTime: startTime,
                            endTime: endTime,
                            color: selectedColor,
                          );
                    if (success && ctx.mounted) {
                      Navigator.pop(ctx);
                      setState(() {});
                    }
                  },
                  child: Text(
                      shift == null ? localizations.tr('createShift') : localizations.tr('saveChanges')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _formatTimeRange(TimeOfDay? start, TimeOfDay? end) {
    if (start == null || end == null) return '';
    return '${_fmt(start)} – ${_fmt(end)}';
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ─── Tab Chip Widget ────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
