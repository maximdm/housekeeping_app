import 'package:flutter/material.dart';

import '../models/staff_member.dart';
import '../services/schedule_service.dart';

class ScheduleCalendar extends StatefulWidget {
  final List<StaffMember> staffList;
  final ScheduleService scheduleService;

  const ScheduleCalendar({
    super.key,
    required this.staffList,
    required this.scheduleService,
  });

  @override
  State<ScheduleCalendar> createState() => _ScheduleCalendarState();
}

class _ScheduleCalendarState extends State<ScheduleCalendar> {
  DateTime _currentMonth = DateTime.now();
  String? _selectedStaffId;

  @override
  void initState() {
    super.initState();
    if (widget.staffList.isNotEmpty) {
      _selectedStaffId = widget.staffList.first.id;
      _loadMonth();
    }
    widget.scheduleService.addListener(_onScheduleChanged);
  }

  @override
  void dispose() {
    widget.scheduleService.removeListener(_onScheduleChanged);
    super.dispose();
  }

  void _onScheduleChanged() {
    if (mounted) setState(() {});
  }

  void _loadMonth() {
    if (_selectedStaffId != null) {
      widget.scheduleService.loadMonth(_selectedStaffId!, _currentMonth);
    }
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadMonth();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedStaffId,
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'Staff Member',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: widget.staffList
                .where((s) => s.isActive)
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedStaffId = v);
              _loadMonth();
            },
          ),
        ),
        _buildMonthHeader(),
        _buildDayLabels(),
        Expanded(child: _buildCalendarGrid()),
      ],
    );
  }

  Widget _buildMonthHeader() {
    final months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _prevMonth,
          ),
          Text(
            '${months[_currentMonth.month]} ${_currentMonth.year}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildDayLabels() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday - 1;
    final totalDays = lastDay.day;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final onShift = widget.scheduleService.isOnShift(date);
      final hasSchedule = widget.scheduleService.hasSchedule(date);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;

      cells.add(
        GestureDetector(
          onTap: _selectedStaffId != null
              ? () => widget.scheduleService.toggleDay(_selectedStaffId!, date)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: !hasSchedule
                  ? Colors.transparent
                  : onShift
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15)
                      : Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: isToday
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : hasSchedule
                      ? Border.all(
                          color: onShift
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.3)
                              : Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.normal,
                      color: onShift
                          ? Theme.of(context).colorScheme.primary
                          : hasSchedule
                              ? Theme.of(context).colorScheme.error
                              : null,
                    ),
                  ),
                  if (hasSchedule)
                    Icon(
                      onShift ? Icons.check_circle : Icons.cancel,
                      size: 12,
                      color: onShift
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 7,
        children: cells,
      ),
    );
  }
}
