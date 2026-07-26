import 'package:flutter/material.dart';

import '../main.dart';
import '../models/staff_member.dart';
import '../services/assignment_service.dart';
import '../services/room_service.dart';
import '../services/schedule_service.dart';
import 'assignment_panel.dart';

enum _ViewMode { month, week }

class ScheduleCalendar extends StatefulWidget {
  final List<StaffMember> staffList;
  final ScheduleService scheduleService;
  final AssignmentService assignmentService;
  final RoomService roomService;

  const ScheduleCalendar({
    super.key,
    required this.staffList,
    required this.scheduleService,
    required this.assignmentService,
    required this.roomService,
  });

  @override
  State<ScheduleCalendar> createState() => _ScheduleCalendarState();
}

class _ScheduleCalendarState extends State<ScheduleCalendar> {
  DateTime _currentMonth = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  _ViewMode _viewMode = _ViewMode.month;
  String? _selectedStaffId;
  DateTime? _selectedDate;
  double _dragOffset = 0;

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

  DateTime get _weekStart {
    final d = _focusedDate;
    return d.subtract(Duration(days: d.weekday - 1));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  void _prev() {
    setState(() {
      if (_viewMode == _ViewMode.month) {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
        _focusedDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
      } else {
        _focusedDate = _focusedDate.subtract(const Duration(days: 7));
        _currentMonth = DateTime(_focusedDate.year, _focusedDate.month);
      }
    });
    _loadMonth();
  }

  void _next() {
    setState(() {
      if (_viewMode == _ViewMode.month) {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
        _focusedDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
      } else {
        _focusedDate = _focusedDate.add(const Duration(days: 7));
        _currentMonth = DateTime(_focusedDate.year, _focusedDate.month);
      }
    });
    _loadMonth();
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDate = now;
      _currentMonth = DateTime(now.year, now.month);
      _selectedDate = null;
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
            decoration: InputDecoration(
              labelText: localizations.tr('staffMember'),
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: widget.staffList
                .where((s) => s.isActive)
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedStaffId = v;
                _selectedDate = null;
              });
              _loadMonth();
            },
          ),
        ),
        _buildToolbar(),
        _buildDayLabels(),
        Expanded(child: _buildSwipeableCalendarGrid()),
        if (_selectedDate != null && _selectedStaffId != null)
          FloorAssignmentPanel(
            key: ValueKey('$_selectedDate$_selectedStaffId'),
            selectedDate: _selectedDate!,
            staffId: _selectedStaffId!,
            assignmentService: widget.assignmentService,
            roomService: widget.roomService,
            onAssignmentChanged: _loadMonth,
          ),
      ],
    );
  }

  Widget _buildToolbar() {
    final months = [
      '', localizations.tr('january'), localizations.tr('february'), localizations.tr('march'), localizations.tr('april'), localizations.tr('may'), localizations.tr('june'),
      localizations.tr('july'), localizations.tr('august'), localizations.tr('september'), localizations.tr('october'), localizations.tr('november'), localizations.tr('december')
    ];

    String title;
    if (_viewMode == _ViewMode.month) {
      title = '${months[_currentMonth.month]} ${_currentMonth.year}';
    } else {
      final ws = _weekStart;
      final we = _weekEnd;
      if (ws.month == we.month) {
        title = '${ws.day}–${we.day} ${months[ws.month]} ${ws.year}';
      } else if (ws.year == we.year) {
        title = '${ws.day} ${months[ws.month]} – ${we.day} ${months[we.month]} ${ws.year}';
      } else {
        title = '${ws.day} ${months[ws.month]} ${ws.year} – ${we.day} ${months[we.month]} ${we.year}';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _prev,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _goToToday,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _next,
          ),
          const SizedBox(width: 4),
          SegmentedButton<_ViewMode>(
            segments: const [
              ButtonSegment(
                value: _ViewMode.month,
                icon: Icon(Icons.calendar_month, size: 16),
              ),
              ButtonSegment(
                value: _ViewMode.week,
                icon: Icon(Icons.view_week, size: 16),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (sel) {
              setState(() => _viewMode = sel.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayLabels() {
    final days = [localizations.tr('mon'), localizations.tr('tue'), localizations.tr('wed'), localizations.tr('thu'), localizations.tr('fri'), localizations.tr('sat'), localizations.tr('sun')];
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

  Widget _buildSwipeableCalendarGrid() {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() => _dragOffset += details.delta.dx);
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_dragOffset.abs() > 50 || velocity.abs() > 300) {
          if (_dragOffset > 0 || velocity > 0) {
            _prev();
          } else {
            _next();
          }
        }
        setState(() => _dragOffset = 0);
      },
      onHorizontalDragStart: (_) {
        setState(() => _dragOffset = 0);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) {
          final isNew = child.key != ValueKey('$_currentMonth-$_viewMode');
          final offset = isNew ? (_dragOffset > 0 ? -1.0 : 1.0) : 0.0;
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(offset, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey('$_currentMonth-$_viewMode'),
          child: _buildCalendarGrid(),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final today = DateTime.now();

    if (_viewMode == _ViewMode.week) {
      final start = _weekStart;
      final cells = List.generate(7, (i) {
        final date = start.add(Duration(days: i));
        return _buildDayCell(date, today);
      });
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: cells.map((c) => Expanded(child: c)).toList()),
      );
    }

    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday - 1;
    final totalDays = lastDay.day;

    final cells = <Widget>[];
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      cells.add(_buildDayCell(date, today));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 7,
        children: cells,
      ),
    );
  }

  Widget _buildDayCell(DateTime date, DateTime today) {
    final onShift = widget.scheduleService.isOnShift(date);
    final hasSchedule = widget.scheduleService.hasSchedule(date);
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isPast = date.isBefore(today) && !isToday;
    final isSelected = _selectedDate != null &&
        date.year == _selectedDate!.year &&
        date.month == _selectedDate!.month &&
        date.day == _selectedDate!.day;

    return GestureDetector(
      onTap: _selectedStaffId != null
          ? () => setState(() => _selectedDate = date)
          : null,
      onLongPress: _selectedStaffId != null
          ? () => widget.scheduleService.toggleDay(_selectedStaffId!, date)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
              : !hasSchedule
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
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : isToday
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
                '${date.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
                  color: isPast
                      ? Colors.grey[400]
                      : onShift
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
                  color: isPast
                      ? Colors.grey[400]
                      : onShift
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
