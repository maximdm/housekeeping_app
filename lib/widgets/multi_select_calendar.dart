import 'package:flutter/material.dart';

import '../main.dart';

class MultiSelectCalendar extends StatefulWidget {
  final Set<DateTime> selectedDates;
  final ValueChanged<Set<DateTime>> onSelectionChanged;

  const MultiSelectCalendar({
    super.key,
    required this.selectedDates,
    required this.onSelectionChanged,
  });

  @override
  State<MultiSelectCalendar> createState() => _MultiSelectCalendarState();
}

class _MultiSelectCalendarState extends State<MultiSelectCalendar> {
  late DateTime _focusedDate;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _focusedDate = DateTime.now();
  }

  DateTime get _weekStart {
    final d = _focusedDate;
    return d.subtract(Duration(days: d.weekday - 1));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSelected(DateTime date) =>
      widget.selectedDates.any((d) =>
          d.year == date.year && d.month == date.month && d.day == date.day);

  void _toggleDay(DateTime date) {
    final normalized = _normalize(date);
    final next = Set<DateTime>.from(widget.selectedDates);
    if (_isSelected(date)) {
      next.removeWhere((d) =>
          d.year == normalized.year &&
          d.month == normalized.month &&
          d.day == normalized.day);
    } else {
      next.add(normalized);
    }
    widget.onSelectionChanged(next);
  }

  void _applyPreset(Set<DateTime> dates) {
    widget.onSelectionChanged(dates);
  }

  void _prev() {
    setState(() {
      _focusedDate = _focusedDate.subtract(const Duration(days: 7));
    });
  }

  void _next() {
    setState(() {
      _focusedDate = _focusedDate.add(const Duration(days: 7));
    });
  }

  void _goToToday() {
    setState(() {
      _focusedDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToolbar(),
        _buildPresets(),
        _buildDayLabels(),
        const SizedBox(height: 4),
        _buildSwipeableWeekRow(),
      ],
    );
  }

  Widget _buildToolbar() {
    final months = [
      '', localizations.tr('january'), localizations.tr('february'), localizations.tr('march'), localizations.tr('april'), localizations.tr('may'), localizations.tr('june'),
      localizations.tr('july'), localizations.tr('august'), localizations.tr('september'), localizations.tr('october'), localizations.tr('november'), localizations.tr('december')
    ];

    final ws = _weekStart;
    final we = _weekEnd;
    String title;
    if (ws.month == we.month) {
      title = '${ws.day}–${we.day} ${months[ws.month]} ${ws.year}';
    } else if (ws.year == we.year) {
      title =
          '${ws.day} ${months[ws.month]} – ${we.day} ${months[we.month]} ${ws.year}';
    } else {
      title =
          '${ws.day} ${months[ws.month]} ${ws.year} – ${we.day} ${months[we.month]} ${we.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _prev,
          ),
          GestureDetector(
            onTap: _goToToday,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    final now = DateTime.now();
    final today = _normalize(now);
    final tomorrow = today.add(const Duration(days: 1));

    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));

    final nextWeekStart = thisWeekStart.add(const Duration(days: 7));

    final next7 = List.generate(7, (i) => today.add(Duration(days: i + 1)));

    final weekdays = List.generate(
      5,
      (i) => thisWeekStart.add(Duration(days: i)),
    );

    final thisMonthRemaining = List.generate(
      DateTime(now.year, now.month + 1, 0).day - now.day + 1,
      (i) => DateTime(now.year, now.month, now.day + i),
    );

    final nextMonthStart = DateTime(now.year, now.month + 1, 1);
    final nextMonthDays = DateTime(now.year, now.month + 2, 0).day;
    final nextMonthAll = List.generate(
      nextMonthDays,
      (i) => DateTime(nextMonthStart.year, nextMonthStart.month, i + 1),
    );

    final presets = <_Preset>[
      _Preset(localizations.tr('today'), [today]),
      _Preset(localizations.tr('tomorrow'), [tomorrow]),
      _Preset(localizations.tr('thisWeek'), List.generate(
        7, (i) => thisWeekStart.add(Duration(days: i)))),
      _Preset(localizations.tr('weekdays'), weekdays),
      _Preset(localizations.tr('next7Days'), next7),
      _Preset(localizations.tr('nextWeek'), List.generate(
        7, (i) => nextWeekStart.add(Duration(days: i)))),
      _Preset(localizations.tr('thisMonth'), thisMonthRemaining),
      _Preset(localizations.tr('nextMonth'), nextMonthAll),
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final p = presets[index];
          final allSelected = p.dates.every((d) => _isSelected(d));
          return FilterChip(
            label: Text(p.label, style: const TextStyle(fontSize: 11)),
            selected: allSelected,
            onSelected: (_) {
              if (allSelected) {
                final next = Set<DateTime>.from(widget.selectedDates);
                for (final d in p.dates) {
                  next.removeWhere((e) =>
                      e.year == d.year &&
                      e.month == d.month &&
                      e.day == d.day);
                }
                _applyPreset(next);
              } else {
                final next = Set<DateTime>.from(widget.selectedDates);
                for (final d in p.dates) {
                  final n = _normalize(d);
                  if (!next.any((e) =>
                      e.year == n.year &&
                      e.month == n.month &&
                      e.day == n.day)) {
                    next.add(n);
                  }
                }
                _applyPreset(next);
              }
            },
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            selectedColor:
                Theme.of(context).colorScheme.primaryContainer,
          );
        },
      ),
    );
  }

  Widget _buildDayLabels() {
    final days = [localizations.tr('mon'), localizations.tr('tue'), localizations.tr('wed'), localizations.tr('thu'), localizations.tr('fri'), localizations.tr('sat'), localizations.tr('sun')];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 11,
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

  Widget _buildSwipeableWeekRow() {
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
          final offset = _dragOffset > 0 ? -1.0 : 1.0;
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
          key: ValueKey(_weekStart),
          child: _buildWeekRow(),
        ),
      ),
    );
  }

  Widget _buildWeekRow() {
    final today = _normalize(DateTime.now());
    final start = _weekStart;
    final cells = List.generate(7, (i) {
      return _buildDayCell(start.add(Duration(days: i)), today);
    });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: cells.map((c) => Expanded(child: c)).toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, DateTime today) {
    final selected = _isSelected(date);
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isPast = date.isBefore(today);

    return GestureDetector(
      onTap: () => _toggleDay(date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : isToday
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3)
                  : null,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? null
              : isToday
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
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
                  fontSize: 14,
                  fontWeight:
                      (isToday || selected) ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? Colors.white
                      : isPast
                          ? Colors.grey[400]
                          : null,
                ),
              ),
              if (selected)
                const Icon(Icons.check, size: 10, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preset {
  final String label;
  final List<DateTime> dates;
  _Preset(this.label, this.dates);
}
