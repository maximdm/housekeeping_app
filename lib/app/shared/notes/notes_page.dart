import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/room.dart';
import '../../../models/shared_note.dart';
import '../../../models/staff_note.dart';
import '../../../models/todo_item.dart';
import '../../../models/todo_list_item.dart';
import '../../../main.dart';
import '../../../services/assignment_service.dart';
import '../../../services/room_service.dart';
import '../../../models/staff_member.dart';
import '../../../services/staff_service.dart';
import '../../../widgets/sharing_section.dart';
import '../../../layouts/admin_layout.dart';
import '../../../layouts/staff_layout.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with SingleTickerProviderStateMixin {
  final AssignmentService _assignmentService = AssignmentService();
  final RoomService _roomService = RoomService();
  final List<Timer> _pendingTimers = [];
  final ValueNotifier<bool> _saving = ValueNotifier(false);

  String? _staffId;
  bool _loading = true;
  bool? _isAdmin;
  bool _isManager = false;

  List<RoomNote> _notes = [];
  List<TodoItem> _todos = [];
  final Map<String, List<TodoListItem>> _listItems = {};
  final Map<String, bool> _expandedLists = {};
  List<Room> _assignedRooms = [];

  List<SharedNote> _receivedNotes = [];
  int _unreadCount = 0;

  List<StaffNote> _staffNotes = [];
  List<StaffNote> _receivedStaffNotes = [];

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _detectRoleAndLoad();
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController?.index == 1 && _staffId != null) {
      for (final note in _receivedNotes.where((n) => !n.isRead)) {
        _assignmentService.markAsRead(note.noteType, note.noteId, _staffId!);
      }
      setState(() {
        _unreadCount = 0;
        _receivedNotes = _receivedNotes.map((n) =>
            SharedNote(
              noteId: n.noteId,
              noteType: n.noteType,
              isRead: true,
              sharedByName: n.sharedByName,
              roomNumber: n.roomNumber,
              noteTitle: n.noteTitle,
              noteContent: n.noteContent,
              noteStatus: n.noteStatus,
              sharedAt: n.sharedAt,
            )).toList();
      });
    }
  }

  Future<void> _detectRoleAndLoad() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() { _isAdmin = false; _loading = false; });
      return;
    }
    final staffData = await Supabase.instance.client
        .from('staff')
        .select('id, role')
        .eq('user_id', user.id)
        .maybeSingle();
    if (staffData == null) {
      if (mounted) setState(() { _isAdmin = false; _loading = false; });
      return;
    }
    if (!mounted) return;
    _staffId = staffData['id'] as String;
    _isAdmin = staffData['role'] == 'receptionist' || staffData['role'] == 'manager';
    _isManager = staffData['role'] == 'manager';
    final tabLength = _isManager ? 3 : 2;
    _tabController = TabController(length: tabLength, vsync: this);
    _tabController!.addListener(_onTabChanged);
    if (!_isAdmin!) {
      _tabController!.index = 1;
    }
    setState(() {});
    await _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      if (_staffId == null) {
        final staffData = await Supabase.instance.client
            .from('staff')
            .select('id, role')
            .eq('user_id', user.id)
            .maybeSingle();

        if (staffData == null) return;
        _staffId = staffData['id'] as String;
        _isAdmin = staffData['role'] == 'receptionist' || staffData['role'] == 'manager';
      }

      _todos = await _assignmentService.loadTodos(_staffId!);

      for (final todo in _todos) {
        if (todo.isList) {
          _listItems[todo.id] = await _assignmentService.loadTodoListItems(todo.id);
        }
      }

      if (_isAdmin!) {
        await _roomService.loadRooms();
        _notes = await _assignmentService.loadRecentNotes(limit: 50);
      } else {
        _assignedRooms = await _assignmentService.loadMyDirtyRoomsForDate(
          _staffId!,
          DateTime.now(),
        );
        for (final room in _assignedRooms) {
          final roomNotes = await _assignmentService.loadNotes(room.id);
          _notes.addAll(roomNotes);
        }
        _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      _receivedNotes = await _assignmentService.loadReceivedNotes(_staffId!);
      _unreadCount = _receivedNotes.where((n) => !n.isRead).length;

      if (_isManager) {
        _staffNotes = await _assignmentService.loadStaffNotesCreatedBy(_staffId!);
      }
      _receivedStaffNotes = await _assignmentService.loadReceivedStaffNotes(_staffId!);
    } catch (e) {
      debugPrint('Error loading notes data: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: _buildContent(),
          );

    if (_isAdmin == null || _isAdmin!) {
      return AdminLayout(
        currentRoute: '/shared/notes',
        title: 'Notes & To-Dos',
        floatingActionButton: _buildFab(),
        child: body,
      );
    }
    return StaffLayout(
      currentTabIndex: 1,
      title: 'Notes & To-Dos',
      floatingActionButton: _buildFab(),
      child: body,
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              const Tab(text: 'My Notes'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Received'),
                    if (_unreadCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_isManager) const Tab(text: 'Staff Notes'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyNotesTab(),
              _buildReceivedNotesTab(),
              if (_isManager) _buildStaffNotesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyNotesTab() {
    final hasNotes = _notes.isNotEmpty;
    final hasTodos = _todos.isNotEmpty;

    if (!hasNotes && !hasTodos) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (hasTodos) ...[
          _buildSectionHeader('To-Do Lists', Icons.checklist),
          const SizedBox(height: 8),
          ..._todos.map((todo) => _buildTodoCard(todo)),
          const SizedBox(height: 16),
        ],
        if (hasNotes) ...[
          _buildSectionHeader(localizations.tr('roomNotes'), Icons.notes),
          const SizedBox(height: 8),
          ..._notes.map((note) => _buildNoteCard(note)),
        ],
      ],
    );
  }

  Widget _buildReceivedNotesTab() {
    final hasNotes = _receivedNotes.isNotEmpty;
    final hasStaffNotes = _receivedStaffNotes.isNotEmpty;

    if (!hasNotes && !hasStaffNotes) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No received notes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Notes shared with you will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    final totalItems = _receivedNotes.length + _receivedStaffNotes.length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: totalItems + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmClearAllReceived(),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          );
        }
        if (index - 1 < _receivedNotes.length) {
          final note = _receivedNotes[index - 1];
          return _buildReceivedNoteCard(note);
        }
        final staffIndex = index - 1 - _receivedNotes.length;
        return _buildStaffNoteCard(_receivedStaffNotes[staffIndex]);
      },
    );
  }

  Widget _buildStaffNotesTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: localizations.tr('sent')),
              Tab(text: localizations.tr('received')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSentStaffNotes(),
                _buildReceivedStaffNotes(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentStaffNotes() {
    if (_staffNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.send_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(localizations.tr('noSentNotes'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    )),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _staffNotes.length,
      itemBuilder: (context, index) =>
          _buildStaffNoteCard(_staffNotes[index]),
    );
  }

  Widget _buildReceivedStaffNotes() {
    if (_receivedStaffNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(localizations.tr('noStaffNotes'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    )),
            const SizedBox(height: 8),
            Text(localizations.tr('staffNotesEmptyHint'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    )),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _receivedStaffNotes.length,
      itemBuilder: (context, index) =>
          _buildStaffNoteCard(_receivedStaffNotes[index]),
    );
  }

  Widget _buildStaffNoteCard(StaffNote note) {
    final isMine = note.createdBy == _staffId;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showStaffNoteDetail(note),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_pin_outlined,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(note.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  if (isMine)
                    PopupMenuButton<String>(
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: 8),
                                Text(localizations.tr('delete')),
                              ],
                            )),
                      ],
                      onSelected: (v) {
                        if (v == 'delete') _confirmDeleteStaffNote(note);
                      },
                    ),
                ],
              ),
              if (note.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(note.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    isMine
                        ? '${localizations.tr('sentTo')}: ${note.sharedWithNames.join(', ')}'
                        : '${localizations.tr('from')}: ${note.createdByName ?? '-'}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const Spacer(),
                  Text(_formatTime(note.createdAt),
                      style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notes_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No notes or to-dos yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add a note or create a to-do list',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildReceivedNoteCard(SharedNote note) {
    final isUnread = !note.isRead;
    final statusCfg = noteStatusConfig[note.noteStatus ?? 'none'] ?? noteStatusConfig['none']!;
    final statusColor = statusCfg['color'] as Color;

    return Dismissible(
      key: ValueKey('${note.noteType}_${note.noteId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove Note'),
            content: const Text('Remove this shared note from your list?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(localizations.tr('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        final staffId = _staffId ?? await _assignmentService.getStaffId();
        if (staffId == null) return;
        await _assignmentService.removeReceivedShare(
          noteType: note.noteType,
          noteId: note.noteId,
          sharedWithStaffId: staffId,
        );
        setState(() {
          _receivedNotes.removeWhere((n) =>
              n.noteType == note.noteType && n.noteId == note.noteId);
          if (!note.isRead) _unreadCount = (_unreadCount - 1).clamp(0, 999);
        });
        if (mounted) {
          showTimedSnackBar(const SnackBar(content: Text('Note removed')));
        }
      },
      child: Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isUnread
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outlineVariant,
          width: isUnread ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onReceivedNoteTap(note),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isUnread)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusCfg['icon'] as IconData, size: 12, color: statusColor),
                        const SizedBox(width: 3),
                        Text(
                          statusCfg['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: note.noteType == 'todo'
                          ? Colors.orange.withValues(alpha: 0.12)
                          : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      note.noteType == 'todo' ? localizations.tr('toDo') : localizations.tr('roomNotes'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: note.noteType == 'todo'
                            ? Colors.orange[700]
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  if (note.roomNumber != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Room ${note.roomNumber}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _formatTime(note.sharedAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove Note'),
                          content: const Text('Remove this shared note from your list?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(localizations.tr('cancel')),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      final staffId = _staffId ?? await _assignmentService.getStaffId();
                      if (staffId == null) return;
                      await _assignmentService.removeReceivedShare(
                        noteType: note.noteType,
                        noteId: note.noteId,
                        sharedWithStaffId: staffId,
                      );
                      setState(() {
                        _receivedNotes.removeWhere((n) =>
                            n.noteType == note.noteType && n.noteId == note.noteId);
                        if (!note.isRead) _unreadCount = (_unreadCount - 1).clamp(0, 999);
                      });
                      if (mounted) {
                        showTimedSnackBar(const SnackBar(content: Text('Note removed')));
                      }
                    },
                    child: Icon(Icons.delete_outline,
                        size: 18, color: Colors.grey[400]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (note.noteTitle != null && note.noteTitle!.isNotEmpty)
                Text(
                  note.noteTitle!,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              if (note.noteContent != null) ...[
                const SizedBox(height: 4),
                Text(
                  note.noteContent!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Shared by ${note.sharedByName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
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

  void _onReceivedNoteTap(SharedNote note) {
    if (_staffId != null && !note.isRead) {
      _assignmentService.markAsRead(note.noteType, note.noteId, _staffId!);
    }
  }

  void _confirmClearAllReceived() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notes'),
        content: Text('Remove all ${_receivedNotes.length} shared notes from your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(localizations.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final staffId = _staffId ?? await _assignmentService.getStaffId();
              if (staffId == null) return;
              await _assignmentService.clearAllReceivedNotes(staffId);
              setState(() {
                _receivedNotes.clear();
                _unreadCount = 0;
              });
              if (mounted) {
                showTimedSnackBar(const SnackBar(content: Text('All shared notes cleared')));
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  // --- Todo Cards (checkable lists) ---

  Widget _buildTodoCard(TodoItem todo) {
    final items = _listItems[todo.id] ?? [];
    final isExpanded = _expandedLists[todo.id] ?? false;
    final doneCount = items.where((i) => i.isDone).length;

    if (todo.isList) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: GestureDetector(
                onTap: () => _showEditListTitleDialog(todo),
                child: Text(
                  todo.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              subtitle: items.isNotEmpty
                  ? Text(
                      '$doneCount/${items.length} completed',
                      style: TextStyle(
                        fontSize: 12,
                        color: doneCount == items.length && items.isNotEmpty
                            ? Colors.green
                            : Colors.grey[500],
                      ),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (items.isNotEmpty)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              value: items.isNotEmpty ? doneCount / items.length : 0,
                              strokeWidth: 3,
                              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                              color: doneCount == items.length && items.isNotEmpty
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            '$doneCount',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    color: Colors.grey[400],
                    onPressed: () => _showShareDialogForTodo(todo),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () => _confirmDeleteTodo(todo),
                  ),
                ],
              ),
              onTap: () {
                setState(() => _expandedLists[todo.id] = !isExpanded);
              },
            ),
            if (isExpanded) ...[
              const Divider(height: 1),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No items yet. Tap + to add one.',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ...items.map((item) => _buildListItem(item)),
              _buildAddItemField(todo.id),
            ],
          ],
        ),
      );
    }

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDeleteTodo(todo),
      onDismissed: (_) async {
        final deletedTodo = todo;
        final deletedListItems = _listItems[todo.id] ?? [];
        setState(() {
          _todos.removeWhere((t) => t.id == todo.id);
          _listItems.remove(todo.id);
          _expandedLists.remove(todo.id);
        });
        if (mounted) {
          Timer? undoTimer;
          showTimedSnackBar(
            SnackBar(
              content: Text('To-do "${deletedTodo.title}" deleted'),
              action: SnackBarAction(
                label: localizations.tr('undo'),
                onPressed: () {
                  undoTimer?.cancel();
                  setState(() {
                    _todos.insert(0, deletedTodo);
                    if (deletedListItems.isNotEmpty) {
                      _listItems[deletedTodo.id] = deletedListItems;
                    }
                  });
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
          undoTimer = Timer(const Duration(seconds: 5), () async {
            if (!mounted) return;
            await _assignmentService.deleteTodo(deletedTodo.id);
          });
          _pendingTimers.add(undoTimer);
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Checkbox(
            value: todo.isDone,
            onChanged: (v) async {
              await _assignmentService.toggleTodo(todo.id, v ?? false);
              setState(() => todo.isDone = v ?? false);
            },
          ),
          title: GestureDetector(
            onTap: () => _showEditTodoDialog(todo),
            child: Text(
              todo.title,
              style: TextStyle(
                decoration: todo.isDone ? TextDecoration.lineThrough : null,
                color: todo.isDone ? Colors.grey[500] : null,
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 20),
                color: Colors.grey[400],
                onPressed: () => _showShareDialogForTodo(todo),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(TodoListItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) async {
        final deletedItem = item;
        final todoId = item.todoId;
        setState(() {
          for (final key in _listItems.keys) {
            _listItems[key]?.removeWhere((i) => i.id == item.id);
          }
        });
        if (mounted) {
          Timer? undoTimer;
          showTimedSnackBar(
            SnackBar(
              content: Text('Item "${deletedItem.title}" deleted'),
              action: SnackBarAction(
                label: localizations.tr('undo'),
                onPressed: () {
                  undoTimer?.cancel();
                  setState(() {
                    _listItems[todoId] = [
                      ...(_listItems[todoId] ?? []),
                      deletedItem,
                    ];
                  });
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
          undoTimer = Timer(const Duration(seconds: 5), () async {
            if (!mounted) return;
            await _assignmentService.deleteTodoListItem(deletedItem.id);
          });
          _pendingTimers.add(undoTimer);
        }
      },
      child: ListTile(
        dense: true,
        leading: Checkbox(
          value: item.isDone,
          onChanged: (v) async {
            await _assignmentService.toggleTodoListItem(item.id, v ?? false);
            setState(() => item.isDone = v ?? false);
            _updateTodoDoneState(item.todoId);
          },
        ),
        title: GestureDetector(
          onTap: () => _showEditListItemDialog(item, item.todoId),
          child: Text(
            item.title,
            style: TextStyle(
              decoration: item.isDone ? TextDecoration.lineThrough : null,
              color: item.isDone ? Colors.grey[500] : null,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _updateTodoDoneState(String todoId) {
    final items = _listItems[todoId] ?? [];
    if (items.isEmpty) return;
    final allDone = items.every((i) => i.isDone);
    final todo = _todos.firstWhere((t) => t.id == todoId);
    if (todo.isDone != allDone) {
      _assignmentService.toggleTodo(todoId, allDone);
      setState(() => todo.isDone = allDone);
    }
  }

  Widget _buildAddItemField(String todoId) {
    final controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Add item...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onSubmitted: (v) => _addItemToList(todoId, v, controller),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () => _addItemToList(todoId, controller.text, controller),
          ),
        ],
      ),
    );
  }

  Future<void> _addItemToList(String todoId, String title, TextEditingController controller) async {
    if (title.trim().isEmpty) return;
    final item = await _assignmentService.addTodoListItem(
      todoId: todoId,
      title: title.trim(),
    );
    if (item != null) {
      setState(() {
        _listItems[todoId] = [...(_listItems[todoId] ?? []), item];
        controller.clear();
      });
    }
  }

  Future<bool> _confirmDeleteTodo(TodoItem todo) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete To-Do'),
        content: Text('Delete "${todo.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.tr('delete')),
          ),
        ],
      ),
    ).then((v) {
      if (v == true) {
        final deletedTodo = todo;
        final deletedListItems = _listItems[todo.id] ?? [];
        setState(() {
          _todos.removeWhere((t) => t.id == todo.id);
          _listItems.remove(todo.id);
          _expandedLists.remove(todo.id);
        });
        if (mounted) {
          Timer? undoTimer;
          showTimedSnackBar(
            SnackBar(
              content: Text('To-do "${deletedTodo.title}" deleted'),
              action: SnackBarAction(
                label: localizations.tr('undo'),
                onPressed: () {
                  undoTimer?.cancel();
                  setState(() {
                    _todos.insert(0, deletedTodo);
                    if (deletedListItems.isNotEmpty) {
                      _listItems[deletedTodo.id] = deletedListItems;
                    }
                  });
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
          undoTimer = Timer(const Duration(seconds: 5), () async {
            if (!mounted) return;
            await _assignmentService.deleteTodo(deletedTodo.id);
          });
          _pendingTimers.add(undoTimer);
        }
        return true;
      }
      return false;
    });
  }

  // --- Delete Note (shared by Dismissible and icon) ---

  void _deleteNote(RoomNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.tr('deleteNoteConfirm')),
        content: const Text('This can be undone from the undo bar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(localizations.tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(localizations.tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _performDeleteNote(note);
  }

  void _performDeleteNote(RoomNote note) {
    final deletedNote = note;
    setState(() => _notes.removeWhere((n) => n.id == note.id));
    if (mounted) {
      Timer? undoTimer;
      showTimedSnackBar(
        SnackBar(
          content: const Text('Note deleted'),
          action: SnackBarAction(
            label: localizations.tr('undo'),
            onPressed: () {
              undoTimer?.cancel();
              setState(() => _notes.insert(0, deletedNote));
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      undoTimer = Timer(const Duration(seconds: 5), () async {
        if (!mounted) return;
        await _assignmentService.deleteNote(deletedNote.id);
      });
      _pendingTimers.add(undoTimer);
    }
  }

  // --- Status Picker ---

  void _showStatusPicker(RoomNote note) {
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
                child: Text('Set status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
            ...noteStatusConfig.entries.map((entry) {
              final key = entry.key;
              final cfg = entry.value;
              final color = cfg['color'] as Color;
              final icon = cfg['icon'] as IconData;
              final label = cfg['label'] as String;
              final isSelected = note.status == key;
              return ListTile(
                leading: Icon(icon, color: color, size: 22),
                title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                trailing: isSelected ? Icon(Icons.check, color: color, size: 20) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (key == note.status) return;
                  await _assignmentService.updateNoteStatus(note.id, key);
                  if (mounted) {
                    setState(() {
                      final idx = _notes.indexWhere((n) => n.id == note.id);
                      if (idx != -1) {
                        _notes[idx] = RoomNote(
                          id: note.id, roomId: note.roomId, staffId: note.staffId,
                          title: note.title, content: note.content, status: key,
                          staffName: note.staffName, createdAt: note.createdAt,
                        );
                      }
                    });
                  }
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // --- Note Cards ---

  Widget _buildNoteCard(RoomNote note) {
    String roomNumber = '';
    if (_isAdmin!) {
      final room = _roomService.rooms.where((r) => r.id == note.roomId).toList();
      if (room.isNotEmpty) roomNumber = room.first.number;
    } else {
      final match = _assignedRooms.where((r) => r.id == note.roomId);
      if (match.isNotEmpty) roomNumber = match.first.number;
    }

    final statusCfg = noteStatusConfig[note.status] ?? noteStatusConfig['none']!;
    final statusColor = statusCfg['color'] as Color;
    final statusIcon = statusCfg['icon'] as IconData;
    final statusLabel = statusCfg['label'] as String;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: note.status != 'none'
              ? statusColor.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.outlineVariant,
          width: note.status != 'none' ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showStatusPicker(note),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 3),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_drop_down, size: 14, color: statusColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (roomNumber.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Room $roomNumber',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    note.staffName ?? 'Staff',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(note.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showShareDialog(note),
                  child: Icon(Icons.share_outlined, size: 18, color: Colors.grey[400]),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showEditNoteDialog(note),
                  child: Icon(Icons.edit_outlined, size: 18, color: Colors.grey[400]),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _deleteNote(note),
                  child: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showEditNoteDialog(note),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.title.isNotEmpty) ...[
                      Text(
                        note.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(note.content),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('note_${note.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(localizations.tr('deleteNoteConfirm')),
            content: const Text('This can be undone from the undo bar.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(localizations.tr('cancel'))),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: Text(localizations.tr('delete')),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          _performDeleteNote(note);
          return true;
        }
        return false;
      },
      onDismissed: (_) {},
      child: card,
    );
  }

  // --- Share Dialog ---

  Widget _buildSharingSectionForDialog({
    required SharingMode shareMode,
    required List<String> selectedStaffIds,
    required ValueChanged<SharingMode> onModeChanged,
    required ValueChanged<List<String>> onStaffIdsChanged,
  }) {
    return FutureBuilder<List<StaffMember>>(
      future: _loadActiveStaff(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return SharingSection(
          initialMode: shareMode,
          initialStaffIds: selectedStaffIds,
          availableStaff: snapshot.data!,
          onModeChanged: onModeChanged,
          onStaffIdsChanged: onStaffIdsChanged,
        );
      },
    );
  }

  Future<List<StaffMember>> _loadActiveStaff() async {
    final staffService = StaffService();
    await staffService.loadStaff();
    return staffService.staff.where((s) => s.isActive).toList();
  }

  void _showShareDialogForTodo(TodoItem todo) async {
    final activeStaff = await _loadActiveStaff();

    if (!mounted) return;

    SharingMode shareMode = SharingMode.none;
    List<String> selectedStaffIds = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Share To-Do',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    todo.title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SharingSection(
                    initialMode: shareMode,
                    initialStaffIds: selectedStaffIds,
                    availableStaff: activeStaff,
                    onModeChanged: (mode) => setSheetState(() => shareMode = mode),
                    onStaffIdsChanged: (ids) => setSheetState(() => selectedStaffIds = ids),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final staffId = _staffId ?? await _assignmentService.getStaffId();
                      if (staffId == null) return;

                      if (shareMode == SharingMode.none) {
                        await _assignmentService.unshareNote(
                          noteType: 'todo',
                          noteId: todo.id,
                        );
                      } else {
                        await _assignmentService.shareNote(
                          noteType: 'todo',
                          noteId: todo.id,
                          sharedWithStaffIds: selectedStaffIds,
                          sharedByStaffId: staffId,
                        );
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        showTimedSnackBar(
                          const SnackBar(content: Text('Sharing updated')),
                        );
                      }
                    },
                    child: Text(localizations.tr('save')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showShareDialog(RoomNote note) async {
    final staffService = StaffService();
    await staffService.loadStaff();
    final activeStaff = staffService.staff.where((s) => s.isActive).toList();

    if (!mounted) return;

    SharingMode shareMode = SharingMode.none;
    List<String> selectedStaffIds = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Share Note',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SharingSection(
                    initialMode: shareMode,
                    initialStaffIds: selectedStaffIds,
                    availableStaff: activeStaff,
                    onModeChanged: (mode) => setSheetState(() => shareMode = mode),
                    onStaffIdsChanged: (ids) => setSheetState(() => selectedStaffIds = ids),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final staffId = _staffId ?? await _assignmentService.getStaffId();
                      if (staffId == null) return;

                      if (shareMode == SharingMode.none) {
                        await _assignmentService.unshareNote(
                          noteType: 'room_note',
                          noteId: note.id,
                        );
                      } else {
                        await _assignmentService.shareNote(
                          noteType: 'room_note',
                          noteId: note.id,
                          sharedWithStaffIds: selectedStaffIds,
                          sharedByStaffId: staffId,
                        );
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        showTimedSnackBar(
                          const SnackBar(content: Text('Sharing updated')),
                        );
                      }
                    },
                    child: Text(localizations.tr('save')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- FAB ---

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _showAddSheet,
      icon: const Icon(Icons.add),
      label: Text(localizations.tr('add')),
    );
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localizations.tr('add'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.notes_outlined),
                  title: Text(localizations.tr('addNote')),
                  subtitle: const Text('Add a note to a room'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddNoteDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.checklist_outlined),
                  title: Text(localizations.tr('addToDoList')),
                  subtitle: const Text('A checkable list of items'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreateListDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_task),
                  title: Text(localizations.tr('addToDo')),
                  subtitle: const Text('A simple checkable item'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddSingleTodoDialog();
                  },
                ),
                if (_isManager) ...[
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.person_pin_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(localizations.tr('addStaffNote')),
                    subtitle: Text(localizations.tr('staffNoteSubtitle')),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddStaffNoteDialog();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Add Note Dialog ---

  void _showAddNoteDialog() async {
    List<Room> rooms;
    if (_isAdmin!) {
      await _roomService.loadRooms();
      rooms = _roomService.rooms;
    } else {
      rooms = _assignedRooms;
    }

    if (!mounted) return;
    if (rooms.isEmpty) {
      showTimedSnackBar(
        const SnackBar(content: Text('No rooms available')),
      );
      return;
    }

    String? selectedRoomId;
    String selectedStatus = 'none';
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    SharingMode shareMode = SharingMode.none;
    List<String> selectedStaffIds = [];

    final staffService = StaffService();
    await staffService.loadStaff();
    final activeStaff = staffService.staff.where((s) => s.isActive).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      localizations.tr('addNote'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRoomId,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: localizations.tr('room'),
                        border: const OutlineInputBorder(),
                      ),
                      items: rooms
                          .map((r) => DropdownMenuItem(
                                value: r.id,
                                child: Text('Room ${r.number}'),
                              ))
                          .toList(),
                      onChanged: (v) => setSheetState(() => selectedRoomId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. Missing towels',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: localizations.tr('description'),
                        border: const OutlineInputBorder(),
                        hintText: 'e.g. Towels need replacing in bathroom',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(localizations.tr('status'), style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: noteStatusConfig.entries.map((entry) {
                        final key = entry.key;
                        final cfg = entry.value;
                        final color = cfg['color'] as Color;
                        final icon = cfg['icon'] as IconData;
                        final label = cfg['label'] as String;
                        final isSelected = selectedStatus == key;
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 14, color: isSelected ? Colors.white : color),
                              const SizedBox(width: 4),
                              Text(label, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: color,
                          backgroundColor: color.withValues(alpha: 0.08),
                          side: BorderSide(
                            color: isSelected ? color : color.withValues(alpha: 0.3),
                          ),
                          onSelected: (_) => setSheetState(() => selectedStatus = key),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    SharingSection(
                      initialMode: shareMode,
                      initialStaffIds: selectedStaffIds,
                      availableStaff: activeStaff,
                      onModeChanged: (mode) => setSheetState(() => shareMode = mode),
                      onStaffIdsChanged: (ids) => setSheetState(() => selectedStaffIds = ids),
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<bool>(
                      valueListenable: _saving,
                      builder: (ctx, saving, child) {
                        return FilledButton(
                          onPressed: saving ? null : () async {
                            if (selectedRoomId == null) return;
                            _saving.value = true;
                            try {
                              final staffId = _staffId ?? await _assignmentService.getStaffId();
                              if (staffId == null) return;
                              final ok = await _assignmentService.addNote(
                                roomId: selectedRoomId!,
                                staffId: staffId,
                                title: titleController.text.trim(),
                                content: noteController.text.trim(),
                                status: selectedStatus,
                              );
                              if (ok && selectedStaffIds.isNotEmpty) {
                                final noteData = await _assignmentService.loadNotes(selectedRoomId!);
                                if (noteData.isNotEmpty) {
                                  await _assignmentService.shareNote(
                                    noteType: 'room_note',
                                    noteId: noteData.first.id,
                                    sharedWithStaffIds: selectedStaffIds,
                                    sharedByStaffId: staffId,
                                  );
                                }
                              }
                              if (ok && ctx.mounted) Navigator.pop(ctx);
                              if (ok && mounted) {
                                showTimedSnackBar(
                                  const SnackBar(content: Text('Note added')),
                                );
                                _loadData();
                              }
                            } finally {
                              _saving.value = false;
                            }
                          },
                          child: saving
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(localizations.tr('save')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Create List Dialog ---

  void _showCreateListDialog() {
    final controller = TextEditingController();
    SharingMode shareMode = SharingMode.none;
    List<String> selectedStaffIds = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      localizations.tr('newList'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: localizations.tr('listName'),
                        border: const OutlineInputBorder(),
                        hintText: 'e.g. Floor 2 supplies',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSharingSectionForDialog(
                      shareMode: shareMode,
                      selectedStaffIds: selectedStaffIds,
                      onModeChanged: (mode) => setSheetState(() => shareMode = mode),
                      onStaffIdsChanged: (ids) => setSheetState(() => selectedStaffIds = ids),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        if (controller.text.trim().isEmpty || _staffId == null) return;
                        final item = await _assignmentService.addTodo(
                          staffId: _staffId!,
                          title: controller.text.trim(),
                          isList: true,
                        );
                        if (item != null) {
                          if (shareMode != SharingMode.none && selectedStaffIds.isNotEmpty) {
                            await _assignmentService.shareNote(
                              noteType: 'todo',
                              noteId: item.id,
                              sharedWithStaffIds: selectedStaffIds,
                              sharedByStaffId: _staffId!,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() {
                              _todos.insert(0, item);
                              _listItems[item.id] = [];
                              _expandedLists[item.id] = true;
                            });
                            showTimedSnackBar(
                              const SnackBar(content: Text('To-Do list created')),
                            );
                          }
                        }
                      },
                      child: const Text('Create List'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Add Single Todo Dialog ---

  void _showAddSingleTodoDialog() {
    final controller = TextEditingController();
    SharingMode shareMode = SharingMode.none;
    List<String> selectedStaffIds = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'New To-Do',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Task',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. Check stock levels',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSharingSectionForDialog(
                      shareMode: shareMode,
                      selectedStaffIds: selectedStaffIds,
                      onModeChanged: (mode) => setSheetState(() => shareMode = mode),
                      onStaffIdsChanged: (ids) => setSheetState(() => selectedStaffIds = ids),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        if (controller.text.trim().isEmpty || _staffId == null) return;
                        final item = await _assignmentService.addTodo(
                          staffId: _staffId!,
                          title: controller.text.trim(),
                        );
                        if (item != null) {
                          if (shareMode != SharingMode.none && selectedStaffIds.isNotEmpty) {
                            await _assignmentService.shareNote(
                              noteType: 'todo',
                              noteId: item.id,
                              sharedWithStaffIds: selectedStaffIds,
                              sharedByStaffId: _staffId!,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() => _todos.insert(0, item));
                            showTimedSnackBar(
                              const SnackBar(content: Text('To-Do added')),
                            );
                          }
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Edit Note Dialog ---

  void _showEditNoteDialog(RoomNote note) {
    final titleController = TextEditingController(text: note.title);
    final contentController = TextEditingController(text: note.content);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Note',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final newTitle = titleController.text.trim();
                  final newContent = contentController.text.trim();
                  if (newContent.isEmpty) return;
                  final ok = await _assignmentService.updateNote(
                    noteId: note.id,
                    title: newTitle,
                    content: newContent,
                  );
                  if (ok && ctx.mounted) Navigator.pop(ctx);
                  if (ok && mounted) {
                    setState(() {
                      final idx = _notes.indexWhere((n) => n.id == note.id);
                      if (idx != -1) {
                        _notes[idx] = RoomNote(
                          id: note.id, roomId: note.roomId, staffId: note.staffId,
                          title: newTitle, content: newContent, status: note.status,
                          staffName: note.staffName, createdAt: note.createdAt,
                        );
                      }
                    });
                    showTimedSnackBar(
                      const SnackBar(content: Text('Note updated')),
                    );
                  }
                },
                child: Text(localizations.tr('save')),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Edit Single To-Do Dialog ---

  void _showEditTodoDialog(TodoItem todo) {
    final controller = TextEditingController(text: todo.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit To-Do',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Task',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;
                  final ok = await _assignmentService.updateTodoTitle(
                    todo.id, controller.text.trim(),
                  );
                  if (ok && ctx.mounted) Navigator.pop(ctx);
                  if (ok && mounted) {
                    _todos = await _assignmentService.loadTodos(_staffId!);
                    if (mounted) {
                      setState(() {});
                      showTimedSnackBar(
                        const SnackBar(content: Text('To-Do updated')),
                      );
                    }
                  }
                },
                child: Text(localizations.tr('save')),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Edit List Title Dialog ---

  void _showEditListTitleDialog(TodoItem todo) {
    final controller = TextEditingController(text: todo.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit List Title',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'List Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;
                  final ok = await _assignmentService.updateTodoTitle(
                    todo.id, controller.text.trim(),
                  );
                  if (ok && ctx.mounted) Navigator.pop(ctx);
                  if (ok && mounted) {
                    _todos = await _assignmentService.loadTodos(_staffId!);
                    if (mounted) {
                      setState(() {});
                      showTimedSnackBar(
                        const SnackBar(content: Text('List title updated')),
                      );
                    }
                  }
                },
                child: Text(localizations.tr('save')),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Edit List Item Dialog ---

  void _showEditListItemDialog(TodoListItem item, String todoId) {
    final controller = TextEditingController(text: item.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Item',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Item',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;
                  final ok = await _assignmentService.updateTodoListItemTitle(
                    item.id, controller.text.trim(),
                  );
                  if (ok && ctx.mounted) Navigator.pop(ctx);
                  if (ok && mounted) {
                    setState(() {
                      item.title = controller.text.trim();
                    });
                    showTimedSnackBar(
                      const SnackBar(content: Text('Item updated')),
                    );
                  }
                },
                child: Text(localizations.tr('save')),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Staff Notes ---

  void _showAddStaffNoteDialog() async {
    final staffService = StaffService();
    await staffService.loadStaff();
    final activeStaff = staffService.staff.where((s) => s.isActive).toList();

    if (!mounted) return;

    final titleController = TextEditingController();
    final contentController = TextEditingController();
    List<String> selectedStaffIds = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      localizations.tr('addStaffNote'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: localizations.tr('noteTitle'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: localizations.tr('noteContent'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    Text(localizations.tr('sendTo'),
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    ...activeStaff.map((s) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: selectedStaffIds.contains(s.id),
                          title: Text(s.name),
                          subtitle: Text(s.role.label,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                          onChanged: (v) {
                            setSheetState(() {
                              if (v == true) {
                                selectedStaffIds.add(s.id);
                              } else {
                                selectedStaffIds.remove(s.id);
                              }
                            });
                          },
                        )),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<bool>(
                      valueListenable: _saving,
                      builder: (ctx, saving, child) {
                        return FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (titleController.text.trim().isEmpty) return;
                                  if (selectedStaffIds.isEmpty) return;
                                  _saving.value = true;
                                  try {
                                    final staffId = _staffId ??
                                        await _assignmentService.getStaffId();
                                    if (staffId == null) return;
                                    final note =
                                        await _assignmentService.createStaffNote(
                                      title: titleController.text.trim(),
                                      content: contentController.text.trim(),
                                      createdByStaffId: staffId,
                                      sharedWithStaffIds: selectedStaffIds,
                                    );
                                    if (note != null && ctx.mounted) {
                                      Navigator.pop(ctx);
                                      showTimedSnackBar(SnackBar(
                                        content: Text(localizations
                                            .tr('staffNoteSent')),
                                      ));
                                      _loadData();
                                    }
                                  } finally {
                                    _saving.value = false;
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(localizations.tr('send')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStaffNoteDetail(StaffNote note) {
    final isMine = note.createdBy == _staffId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(note.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 8),
                Text(
                  isMine
                      ? '${localizations.tr('sentTo')}: ${note.sharedWithNames.join(', ')}'
                      : '${localizations.tr('from')}: ${note.createdByName ?? '-'}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(_formatTime(note.createdAt),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                const SizedBox(height: 16),
                Text(note.content.isEmpty
                    ? '-'
                    : note.content),
                const SizedBox(height: 20),
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(localizations.tr('close')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteStaffNote(StaffNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.tr('delete')),
        content: Text(localizations.tr('deleteStaffNoteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _assignmentService.deleteStaffNote(note.id);
    if (mounted) {
      showTimedSnackBar(
          SnackBar(content: Text(localizations.tr('staffNoteDeleted'))));
      _loadData();
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}';
  }
}
