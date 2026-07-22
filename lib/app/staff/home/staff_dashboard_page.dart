import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/room.dart';
import '../../../services/assignment_service.dart';
import '../../../layouts/staff_layout.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  final AssignmentService _assignmentService = AssignmentService();
  String? _staffId;
  List<Assignment> _assignments = [];
  bool _loading = true;

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
      _assignments = await _assignmentService.loadMyAssignments(_staffId!);
    } catch (e) {
      debugPrint('Error loading staff data: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return StaffLayout(
      currentTabIndex: 0,
      child: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _assignments.isEmpty
                  ? _buildEmptyState()
                  : _buildContent(),
        ],
      ),
    );
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
            'No tasks assigned',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no room assignments today',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: _loadData,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (_assignments.isNotEmpty) ...[
            Text(
              'My Tasks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ..._assignments.map((a) {
              final room = a.room;
              if (room == null) return const SizedBox.shrink();
              return _buildTaskCard(a, room);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskCard(Assignment assignment, Room room) {
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    await Routefly.navigate('/staff/home/room_detail');
    _loadData();
  }
}
