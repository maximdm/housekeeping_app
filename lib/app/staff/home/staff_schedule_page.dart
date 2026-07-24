import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../layouts/staff_layout.dart';
import '../../../models/shift.dart';
import '../../../services/shift_service.dart';

class StaffSchedulePage extends StatefulWidget {
  const StaffSchedulePage({super.key});

  @override
  State<StaffSchedulePage> createState() => _StaffSchedulePageState();
}

class _StaffSchedulePageState extends State<StaffSchedulePage> {
  final ShiftService _shiftService = ShiftService();

  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  String? _staffId;
  bool _loading = true;

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

      if (staffData == null) return;
      _staffId = staffData['id'] as String;

      await _loadMonth();
    } catch (e) {
      debugPrint('Error loading schedule: $e');
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
      currentTabIndex: 5,
      title: 'My Schedule',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildCalendar(),
                  const SizedBox(height: 16),
                  _buildSelectedDayInfo(),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;

    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Card(
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
    );
  }

  Widget _buildDayCell(DateTime date) {
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
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
    final shiftColor = hasShift
        ? parseHexColor(dayAssignment.shiftColor)
        : null;

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
                fontWeight:
                    (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : null,
              ),
            ),
            if (hasShift)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.8)
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
                          'No shift assigned',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...assignments.map((a) {
                  final color = parseHexColor(
                      a.shiftColor, fallback: Theme.of(context).colorScheme.primary);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
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
                                    fontSize: 12, color: Colors.grey[600]),
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

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _formatTimeRange(TimeOfDay? start, TimeOfDay? end) {
    if (start == null || end == null) return '';
    return '${_fmt(start)} – ${_fmt(end)}';
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
