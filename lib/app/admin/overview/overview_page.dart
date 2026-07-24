import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/assignment_service.dart';
import '../../../services/activity_service.dart';
import '../../../main.dart';
import '../../../layouts/admin_layout.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final _client = Supabase.instance.client;

  int _cleanRooms = 0;
  int _dirtyRooms = 0;
  int _inProgressRooms = 0;
  int _skippedRooms = 0;

  List<ActivityLogEntry> _recentActivity = [];
  List<_PriorityAlert> _priorityAlerts = [];
  int _activityLimit = 10;

  List<Map<String, dynamic>> _allRooms = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        _client.from('rooms').select('''
          id, number, status, description,
          room_type:room_types(name),
          floor:floors(name, number)
        '''),
        _client.from('activity_log').select('''
          id, staff_id, action, details, created_at,
          staff:staff(name)
        ''').order('created_at', ascending: false).limit(_activityLimit),
      ]);

      final rooms = results[0] as List;
      _allRooms = rooms.cast<Map<String, dynamic>>();
      _cleanRooms =
          rooms.where((r) => r['status'] == 'clean').length;
      _dirtyRooms =
          rooms.where((r) => r['status'] == 'dirty').length;
      _inProgressRooms =
          rooms.where((r) => r['status'] == 'in_progress').length;
      _skippedRooms =
          rooms.where((r) => r['status'] == 'skipped').length;

      final activity = results[1] as List;
      _recentActivity = activity
          .map((json) => ActivityLogEntry.fromJson(json))
          .toList();

      _priorityAlerts = [];
      if (_skippedRooms > 0) {
        _priorityAlerts.add(_PriorityAlert(
          icon: Icons.warning_amber_rounded,
          color: Colors.red,
          text:
              '$_skippedRooms room${_skippedRooms > 1 ? 's' : ''} skipped — requires attention',
        ));
      }
      if (_dirtyRooms > 0) {
        _priorityAlerts.add(_PriorityAlert(
          icon: Icons.cleaning_services_outlined,
          color: Colors.orange,
          text:
              '$_dirtyRooms room${_dirtyRooms > 1 ? 's' : ''} need cleaning',
        ));
      }
      if (_inProgressRooms > 0) {
        _priorityAlerts.add(_PriorityAlert(
          icon: Icons.sync,
          color: Colors.blue,
          text:
              '$_inProgressRooms room${_inProgressRooms > 1 ? 's' : ''} in progress',
        ));
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadActivity() async {
    try {
      final data = await _client.from('activity_log').select('''
        id, staff_id, action, details, created_at,
        staff:staff(name)
      ''').order('created_at', ascending: false).limit(_activityLimit);

      _recentActivity = (data as List)
          .map((json) => ActivityLogEntry.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading activity: $e');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return AdminLayout(
      currentRoute: '/admin/overview',
      child: Scaffold(
        appBar: AppBar(
          title: Text(localizations.tr('dashboard')),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDashboard,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.tr('todayProgress'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildMetricsGrid(isMobile),
                      const SizedBox(height: 24),
                      if (isMobile) ...[
                        _buildPriorityTasksCard(context),
                        const SizedBox(height: 16),
                        _buildRecentActivityCard(context, isMobile),
                      ] else
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child:
                                  _buildRecentActivityCard(context, isMobile),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 1,
                              child:
                                  _buildPriorityTasksCard(context),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMetricsGrid(bool isMobile) {
    final metrics = [
      (localizations.tr('cleanRooms'), '$_cleanRooms', Icons.check_circle_outline,
          Colors.green, 'clean'),
      (localizations.tr('needsCleaning'), '$_dirtyRooms',
          Icons.cleaning_services_outlined, Colors.orange, 'dirty'),
      (localizations.tr('inProgress'), '$_inProgressRooms', Icons.sync,
          Colors.blue, 'in_progress'),
      (localizations.tr('skipped'), '$_skippedRooms', Icons.skip_next_outlined,
          Colors.red, 'skipped'),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.8,
        children: metrics
            .map((m) => _buildMetricCard(
                context, m.$1, m.$2, m.$3, m.$4, () => _showMetricDetail(m.$5)))
            .toList(),
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: metrics
          .map((m) => SizedBox(
                width: 220,
                child: _buildMetricCard(
                    context, m.$1, m.$2, m.$3, m.$4, () => _showMetricDetail(m.$5)),
              ))
          .toList(),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showMetricDetail(String filter) {
    String title;
    Color accentColor;
    List<Widget> items;

    final filtered = _allRooms.where((r) => r['status'] == filter).toList();
    final labels = {
      'clean': 'Clean',
      'dirty': 'Needs Cleaning',
      'in_progress': 'In Progress',
      'skipped': 'Skipped',
    };
    final colors = {
      'clean': Colors.green,
      'dirty': Colors.orange,
      'in_progress': Colors.blue,
      'skipped': Colors.red,
    };
    title = '${labels[filter] ?? filter} Rooms (${filtered.length})';
    accentColor = colors[filter] ?? Colors.grey;

    items = filtered.map((r) {
      final typeName = (r['room_type'] as Map<String, dynamic>?)?['name'] as String? ?? '';
      final floorNum = (r['floor'] as Map<String, dynamic>?)?['number']?.toString() ?? '';
      final floorName = (r['floor'] as Map<String, dynamic>?)?['name'] as String?;
      final floorLabel = floorName != null ? '$floorName ($floorNum)' : 'Floor $floorNum';
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: accentColor.withValues(alpha: 0.15),
          child: Text(
            r['number'] as String? ?? '?',
            style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        title: Text('Room ${r['number']}'),
        subtitle: Text('$typeName  ·  $floorLabel'),
      );
    }).toList();

    final finalAccent = accentColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 20,
                    decoration: BoxDecoration(
                      color: finalAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Divider(color: finalAccent.withValues(alpha: 0.3), height: 1),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        localizations.tr('noItems'),
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView(controller: scrollController, children: items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context, bool isMobile) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  localizations.tr('recentActivity'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (isMobile)
                  DropdownButton<int>(
                    value: _activityLimit,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    items: [
                      DropdownMenuItem(value: 5, child: Text('5 ${localizations.tr('items')}')),
                      DropdownMenuItem(value: 10, child: Text('10 ${localizations.tr('items')}')),
                      DropdownMenuItem(value: 20, child: Text('20 ${localizations.tr('items')}')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _activityLimit = value;
                        _loadActivity();
                      }
                    },
                  )
                else
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 5, label: Text('5')),
                      ButtonSegment(value: 10, label: Text('10')),
                      ButtonSegment(value: 20, label: Text('20')),
                    ],
                    selected: {_activityLimit},
                    onSelectionChanged: (selected) {
                      _activityLimit = selected.first;
                      _loadActivity();
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 32),
            if (_recentActivity.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    localizations.tr('noRecentActivity'),
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              )
            else ...[
              ..._recentActivity.map((entry) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _activityIcon(entry.action),
                          size: 18,
                          color: _activityColor(entry.action),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatActivityText(entry),
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatActivityTime(entry.createdAt),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(localizations.tr('clearActivity')),
                        content: Text(
                            localizations.tr('clearActivityConfirm')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(localizations.tr('cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ActivityService().clearAll();
                      if (mounted) {
                        setState(() => _recentActivity = []);
                        showTimedSnackBar(
                          SnackBar(
                              content: Text(localizations.tr('activityCleared'))),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(localizations.tr('clearActivity')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityTasksCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.orange.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color:
                Colors.orange.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    localizations.tr('priorityAttention'),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            if (_priorityAlerts.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  localizations.tr('allClear'),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              ..._priorityAlerts.map((alert) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(alert.icon,
                            color: alert.color, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(alert.text)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  IconData _activityIcon(String action) {
    switch (action) {
      case 'status_changed':
        return Icons.color_lens_outlined;
      case 'room_assigned':
      case 'room_unassigned':
        return Icons.person_add_outlined;
      case 'note_added':
        return Icons.note_add_outlined;
      case 'note_deleted':
        return Icons.delete_sweep_outlined;
      case 'note_updated':
        return Icons.edit_note_outlined;
      case 'note_status_changed':
        return Icons.flag_outlined;
      case 'assignment_completed':
        return Icons.check_circle_outline;
      case 'message_sent':
        return Icons.chat_bubble_outline;
      case 'message_deleted':
        return Icons.delete_outline;
      case 'chat_cleared':
        return Icons.cleaning_services_outlined;
      case 'todo_created':
      case 'todo_list_created':
      case 'todo_list_item_added':
        return Icons.check_box_outlined;
      case 'todo_deleted':
        return Icons.check_box_outline_blank;
      case 'room_created':
        return Icons.add_home_outlined;
      case 'room_updated':
        return Icons.home_outlined;
      case 'room_deleted':
        return Icons.home_repair_service_outlined;
      case 'room_type_created':
      case 'room_type_updated':
      case 'room_type_deleted':
        return Icons.category_outlined;
      case 'floor_created':
      case 'floor_updated':
      case 'floor_deleted':
        return Icons.layers_outlined;
      case 'staff_created':
        return Icons.person_add_outlined;
      case 'staff_updated':
        return Icons.manage_accounts_outlined;
      case 'staff_deleted':
        return Icons.person_remove_outlined;
      case 'staff_deactivated':
        return Icons.person_off_outlined;
      case 'staff_activated':
        return Icons.how_to_reg_outlined;
      case 'note_forwarded':
        return Icons.forward_to_inbox;
      default:
        return Icons.info_outline;
    }
  }

  Color _activityColor(String action) {
    switch (action) {
      case 'status_changed':
        return Colors.blue;
      case 'room_assigned':
      case 'assignment_completed':
        return Colors.green;
      case 'room_unassigned':
        return Colors.orange;
      case 'note_added':
      case 'note_updated':
      case 'note_status_changed':
        return Colors.teal;
      case 'note_deleted':
        return Colors.red;
      case 'message_sent':
        return Colors.purple;
      case 'message_deleted':
      case 'chat_cleared':
        return Colors.red;
      case 'todo_created':
      case 'todo_list_created':
      case 'todo_list_item_added':
        return Colors.green;
      case 'todo_deleted':
        return Colors.red;
      case 'room_created':
        return Colors.green;
      case 'room_updated':
        return Colors.blue;
      case 'room_deleted':
        return Colors.red;
      case 'staff_created':
      case 'staff_activated':
        return Colors.green;
      case 'staff_updated':
        return Colors.blue;
      case 'staff_deleted':
      case 'staff_deactivated':
        return Colors.red;
      case 'note_forwarded':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  String _formatActivityTime(DateTime dateTime) {
    final minute =
        dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final displayHour =
        dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    return '$displayHour:$minute $period';
  }

  String _formatActivityText(ActivityLogEntry entry) {
    final name = entry.staffName ?? 'System';
    final roomNum = entry.details?['room_number'] as String?;
    final roomRef = roomNum != null ? 'Room $roomNum' : 'a room';
    switch (entry.action) {
      case 'status_changed':
        final status = entry.details?['new_status'] as String? ?? '';
        return '$name changed $roomRef status to $status';
      case 'room_assigned':
        return '$name was assigned to $roomRef';
      case 'room_unassigned':
        return '$name was unassigned from $roomRef';
      case 'note_added':
        return '$name added a note to $roomRef';
      case 'note_deleted':
        return '$name deleted a note from $roomRef';
      case 'note_updated':
        return '$name updated a note on $roomRef';
      case 'note_status_changed':
        final status = entry.details?['new_status'] as String? ?? '';
        return '$name marked a note as $status on $roomRef';
      case 'note_forwarded':
        return '$name forwarded a note to a staff member';
      case 'assignment_completed':
        return '$name completed an assignment on $roomRef';
      case 'message_sent':
        return '$name sent a chat message';
      case 'message_deleted':
        return '$name deleted a chat message';
      case 'chat_cleared':
        final count = entry.details?['message_count'] ?? 0;
        return '$name cleared the chat ($count messages)';
      case 'todo_created':
        final title = entry.details?['title'] as String? ?? '';
        return '$name created a to-do${title.isNotEmpty ? ': $title' : ''}';
      case 'todo_list_created':
        final title = entry.details?['title'] as String? ?? '';
        return '$name created a to-do list${title.isNotEmpty ? ': $title' : ''}';
      case 'todo_deleted':
        return '$name deleted a to-do';
      case 'todo_list_item_added':
        final title = entry.details?['title'] as String? ?? '';
        return '$name added${title.isNotEmpty ? ': $title' : 'an item'} to a to-do list';
      case 'room_created':
        return '$name created $roomRef';
      case 'room_updated':
        return '$name updated $roomRef';
      case 'room_deleted':
        return '$name deleted $roomRef';
      case 'room_type_created':
        final name2 = entry.details?['name'] as String? ?? '';
        return '$name created room type${name2.isNotEmpty ? ': $name2' : ''}';
      case 'room_type_updated':
        return '$name updated a room type';
      case 'room_type_deleted':
        final name2 = entry.details?['name'] as String? ?? '';
        return '$name deleted room type${name2.isNotEmpty ? ': $name2' : ''}';
      case 'floor_created':
        return '$name created a floor';
      case 'floor_updated':
        return '$name updated a floor';
      case 'floor_deleted':
        return '$name deleted a floor';
      case 'staff_created':
        return '$name added a new staff member';
      case 'staff_updated':
        return '$name updated a staff member';
      case 'staff_deleted':
        return '$name deleted a staff member';
      case 'staff_deactivated':
        return '$name deactivated a staff member';
      case 'staff_activated':
        return '$name activated a staff member';
      default:
        return '$name: ${entry.action.replaceAll('_', ' ')}';
    }
  }

}

class _PriorityAlert {
  final IconData icon;
  final Color color;
  final String text;

  _PriorityAlert({
    required this.icon,
    required this.color,
    required this.text,
  });
}
