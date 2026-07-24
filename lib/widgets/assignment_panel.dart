import 'package:flutter/material.dart';

import '../main.dart';
import '../models/floor.dart';
import '../services/assignment_service.dart';
import '../services/room_service.dart';

class FloorAssignmentPanel extends StatefulWidget {
  final DateTime selectedDate;
  final String staffId;
  final AssignmentService assignmentService;
  final RoomService roomService;
  final VoidCallback onAssignmentChanged;

  const FloorAssignmentPanel({
    super.key,
    required this.selectedDate,
    required this.staffId,
    required this.assignmentService,
    required this.roomService,
    required this.onAssignmentChanged,
  });

  @override
  State<FloorAssignmentPanel> createState() => _FloorAssignmentPanelState();
}

class _FloorAssignmentPanelState extends State<FloorAssignmentPanel> {
  List<FloorAssignment> _assignments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  @override
  void didUpdateWidget(covariant FloorAssignmentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.staffId != widget.staffId) {
      _loadAssignments();
    }
  }

  Future<void> _loadAssignments() async {
    setState(() => _loading = true);
    _assignments = await widget.assignmentService.loadMyFloorAssignmentsForDate(
      widget.staffId,
      widget.selectedDate,
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                localizations.tr('assignedFloors'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: Text(localizations.tr('addFloor'), style: const TextStyle(fontSize: 12)),
                onPressed: _showFloorPicker,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_assignments.isEmpty)
            Text(
              localizations.tr('noFloorsAssigned'),
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _assignments.map((a) {
                final floor = widget.roomService.floors.firstWhere(
                  (f) => f.id == a.floorId,
                  orElse: () => Floor(id: a.floorId, number: '?', name: a.floorName),
                );
                return Chip(
                  avatar: CircleAvatar(
                    radius: 12,
                    child: Text(floor.number, style: const TextStyle(fontSize: 11)),
                  ),
                  label: Text(floor.displayName),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _unassignFloor(a),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _showFloorPicker() {
    final assignedFloorIds = _assignments.map((a) => a.floorId).toSet();
    final availableFloors = widget.roomService.floors
        .where((f) => !assignedFloorIds.contains(f.id))
        .toList();

    if (availableFloors.isEmpty) {
      showTimedSnackBar(SnackBar(
        content: Text(localizations.tr('allFloorsAssigned')),
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(localizations.tr('selectFloor'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold)),
              ),
            ),
            ...availableFloors.map((floor) => ListTile(
                  leading: CircleAvatar(
                    child: Text(floor.number),
                  ),
                  title: Text(floor.displayName),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await widget.assignmentService.assignFloorToStaff(
                      staffId: widget.staffId,
                      floorId: floor.id,
                      date: widget.selectedDate,
                    );
                    if (ok) {
                      _loadAssignments();
                      widget.onAssignmentChanged();
                    }
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _unassignFloor(FloorAssignment assignment) async {
    final floor = widget.roomService.floors.firstWhere(
      (f) => f.id == assignment.floorId,
      orElse: () => Floor(id: assignment.floorId, number: '?'),
    );

    final ok = await widget.assignmentService.unassignFloorFromStaff(
      staffId: widget.staffId,
      floorId: assignment.floorId,
      date: widget.selectedDate,
    );
    if (ok) {
      _loadAssignments();
      widget.onAssignmentChanged();
      if (mounted) {
        showTimedSnackBar(SnackBar(
          content: Text(localizations.tr('floorUnassigned').replaceAll('{floor}', floor.displayName)),
        ));
      }
    }
  }
}
