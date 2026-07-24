import 'package:flutter/material.dart';

import '../main.dart';
import '../models/staff_member.dart';

enum SharingMode {
  none,
  allStaff,
  custom,
}

class SharingSection extends StatefulWidget {
  final SharingMode initialMode;
  final List<String> initialStaffIds;
  final List<StaffMember> availableStaff;
  final ValueChanged<SharingMode> onModeChanged;
  final ValueChanged<List<String>> onStaffIdsChanged;

  const SharingSection({
    super.key,
    this.initialMode = SharingMode.none,
    this.initialStaffIds = const [],
    required this.availableStaff,
    required this.onModeChanged,
    required this.onStaffIdsChanged,
  });

  @override
  State<SharingSection> createState() => _SharingSectionState();
}

class _SharingSectionState extends State<SharingSection> {
  late SharingMode _mode;
  late Set<String> _selectedStaffIds;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _selectedStaffIds = Set<String>.from(widget.initialStaffIds);
    _expanded = _mode != SharingMode.none;
  }

  void _updateMode(SharingMode mode) {
    setState(() {
      _mode = mode;
      if (mode == SharingMode.allStaff) {
        _selectedStaffIds = widget.availableStaff.map((s) => s.id).toSet();
      } else if (mode == SharingMode.none) {
        _selectedStaffIds.clear();
      }
    });
    widget.onModeChanged(_mode);
    widget.onStaffIdsChanged(_selectedStaffIds.toList());
  }

  void _toggleStaff(String staffId) {
    setState(() {
      if (_selectedStaffIds.contains(staffId)) {
        _selectedStaffIds.remove(staffId);
      } else {
        _selectedStaffIds.add(staffId);
      }
      if (_selectedStaffIds.isEmpty) {
        _mode = SharingMode.none;
      } else if (_selectedStaffIds.length == widget.availableStaff.length) {
        _mode = SharingMode.allStaff;
      } else {
        _mode = SharingMode.custom;
      }
    });
    widget.onModeChanged(_mode);
    widget.onStaffIdsChanged(_selectedStaffIds.toList());
  }

  String get _summaryText {
    switch (_mode) {
      case SharingMode.none:
        return localizations.tr('shareWithNone');
      case SharingMode.allStaff:
        return localizations.tr('shareWithAll').replaceAll('{count}', '${widget.availableStaff.length}');
      case SharingMode.custom:
        return localizations.tr('shareWithCustom').replaceAll('{count}', '${_selectedStaffIds.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.share_outlined,
                  size: 18,
                  color: _mode != SharingMode.none
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _summaryText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _mode != SharingMode.none
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          _buildRadioOption(
            title: localizations.tr('none'),
            subtitle: localizations.tr('onlyAssignedStaff'),
            mode: SharingMode.none,
          ),
          _buildRadioOption(
            title: localizations.tr('all'),
            subtitle: localizations.tr('shareWithAllStaff').replaceAll('{count}', '${widget.availableStaff.length}'),
            mode: SharingMode.allStaff,
          ),
          _buildRadioOption(
            title: localizations.tr('filter'),
            subtitle: localizations.tr('chooseSpecificStaff'),
            mode: SharingMode.custom,
          ),
          if (_mode == SharingMode.custom) ...[
            const SizedBox(height: 8),
            ...widget.availableStaff.map((staff) => _buildStaffCheckbox(staff)),
          ],
        ],
      ],
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String subtitle,
    required SharingMode mode,
  }) {
    final isSelected = _mode == mode;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
        size: 20,
      ),
      onTap: () => _updateMode(mode),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildStaffCheckbox(StaffMember staff) {
    final isSelected = _selectedStaffIds.contains(staff.id);
    return CheckboxListTile(
      value: isSelected,
      onChanged: (_) => _toggleStaff(staff.id),
      title: Text(staff.name, style: const TextStyle(fontSize: 13)),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              staff.role.label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
