import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/room.dart';
import '../../../models/todo_item.dart';
import '../../../models/todo_list_item.dart';
import '../../../main.dart';
import '../../../services/assignment_service.dart';
import '../../../services/room_service.dart';
import '../../../services/staff_service.dart';
import '../../../layouts/admin_layout.dart';
import '../../../layouts/staff_layout.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final AssignmentService _assignmentService = AssignmentService();
  final RoomService _roomService = RoomService();
  final List<Timer> _pendingTimers = [];

  String? _staffId;
  bool _loading = true;
  bool? _isAdmin;

  List<RoomNote> _notes = [];
  List<RoomNote> _forwardedNotes = [];
  List<TodoItem> _todos = [];
  final Map<String, List<TodoListItem>> _listItems = {};
  final Map<String, bool> _expandedLists = {};
  List<Assignment> _assignments = [];

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
    super.dispose();
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
    _isAdmin = staffData['role'] == 'receptionist';
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
        _isAdmin = staffData['role'] == 'receptionist';
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
        _assignments = await _assignmentService.loadMyAssignments(_staffId!);
        for (final a in _assignments) {
          if (a.room != null) {
            final roomNotes = await _assignmentService.loadNotes(a.room!.id);
            _notes.addAll(roomNotes);
          }
        }
        _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _forwardedNotes = await _assignmentService.loadForwardedNotes(_staffId!);
      }
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
      currentTabIndex: 4,
      title: 'Notes & To-Dos',
      floatingActionButton: _buildFab(),
      child: body,
    );
  }

  Widget _buildContent() {
    final hasNotes = _notes.isNotEmpty;
    final hasTodos = _todos.isNotEmpty;
    final hasForwarded = _forwardedNotes.isNotEmpty;

    if (!hasNotes && !hasTodos && !hasForwarded) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (hasForwarded) ...[
          _buildSectionHeader('Forwarded to me', Icons.forward_to_inbox),
          const SizedBox(height: 8),
          ..._forwardedNotes.map((note) => _buildNoteCard(note, isForwarded: true)),
          const SizedBox(height: 16),
        ],
        if (hasTodos) ...[
          _buildSectionHeader('To-Do Lists', Icons.checklist),
          const SizedBox(height: 8),
          ..._todos.map((todo) => _buildTodoCard(todo)),
          const SizedBox(height: 16),
        ],
        if (hasNotes) ...[
          _buildSectionHeader('Room Notes', Icons.notes),
          const SizedBox(height: 8),
          ..._notes.map((note) => _buildNoteCard(note)),
        ],
      ],
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

    // Single todo (legacy style)
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
                label: 'Undo',
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
                label: 'Undo',
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
                label: 'Undo',
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

  // --- Forward Note ---

  void _showForwardDialog(RoomNote note) async {
    final staffService = StaffService();
    await staffService.loadStaff();
    final activeStaff = staffService.staff.where((s) => s.isActive).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
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
                  child: Text(
                    'Forward note to...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              if (note.forwardedTo != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Currently forwarded to: ${note.forwardedToName ?? 'Unknown'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: activeStaff.map((member) {
                    final isCurrentForward = note.forwardedTo == member.id;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isCurrentForward
                            ? Colors.deepPurple.withValues(alpha: 0.15)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Text(
                          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isCurrentForward ? Colors.deepPurple : null,
                          ),
                        ),
                      ),
                      title: Text(
                        member.name,
                        style: TextStyle(
                          fontWeight: isCurrentForward ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        member.role.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isCurrentForward
                          ? const Icon(Icons.check_circle, color: Colors.deepPurple, size: 20)
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        final ok = await _assignmentService.forwardNote(
                          noteId: note.id,
                          staffId: member.id,
                        );
                        if (ok && mounted) {
                          showTimedSnackBar(
                            SnackBar(content: Text('Note forwarded to ${member.name}')),
                          );
                          _loadData();
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Delete Note (shared by Dismissible and icon) ---

  void _deleteNote(RoomNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This can be undone from the undo bar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
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
            label: 'Undo',
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

  Widget _buildNoteCard(RoomNote note, {bool isForwarded = false}) {
    String roomNumber = '';
    if (_isAdmin!) {
      final room = _roomService.rooms.where((r) => r.id == note.roomId).toList();
      if (room.isNotEmpty) roomNumber = room.first.number;
    } else {
      final match = _assignments.where((a) => a.roomId == note.roomId && a.room != null);
      if (match.isNotEmpty) roomNumber = match.first.room!.number;
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
          color: isForwarded
              ? Colors.deepPurple.withValues(alpha: 0.5)
              : note.status != 'none'
                  ? statusColor.withValues(alpha: 0.4)
                  : Theme.of(context).colorScheme.outlineVariant,
          width: isForwarded ? 1.5 : note.status != 'none' ? 1.5 : 1,
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
                if (isForwarded) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forward_to_inbox, size: 12, color: Colors.deepPurple),
                        SizedBox(width: 3),
                        Text(
                          'Forwarded',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
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
                ],
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
                if (_isAdmin!) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showForwardDialog(note),
                    child: Icon(Icons.forward_to_inbox, size: 18, color: note.forwardedTo != null ? Colors.deepPurple : Colors.grey[400]),
                  ),
                ],
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
            title: const Text('Delete note?'),
            content: const Text('This can be undone from the undo bar.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Delete'),
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

  // --- FAB ---

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _showAddSheet,
      icon: const Icon(Icons.add),
      label: const Text('Add'),
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
                  'Add',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.notes_outlined),
                  title: const Text('Add Room Note'),
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
                  title: const Text('Create To-Do List'),
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
                  title: const Text('Add Single To-Do'),
                  subtitle: const Text('A simple checkable item'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddSingleTodoDialog();
                  },
                ),
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
      rooms = _assignments.where((a) => a.room != null).map((a) => a.room!).toList();
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
                    'Add Note to Room',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRoomId,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Room',
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Towels need replacing in bathroom',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Status', style: Theme.of(context).textTheme.labelLarge),
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
                            Text(label, style: TextStyle(fontSize: 12)),
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
                  FilledButton(
                    onPressed: () async {
                      if (selectedRoomId == null || noteController.text.trim().isEmpty) return;
                      final staffId = _staffId ?? await _assignmentService.getStaffId();
                      if (staffId == null) return;
                      final ok = await _assignmentService.addNote(
                        roomId: selectedRoomId!,
                        staffId: staffId,
                        title: titleController.text.trim(),
                        content: noteController.text.trim(),
                        status: selectedStatus,
                      );
                      if (ok && ctx.mounted) Navigator.pop(ctx);
                      if (ok && mounted) {
                        showTimedSnackBar(
                          const SnackBar(content: Text('Note added')),
                        );
                        _loadData();
                      }
                    },
                    child: const Text('Save Note'),
                  ),
                ],
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
                'New To-Do List',
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
                  hintText: 'e.g. Floor 2 supplies',
                ),
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
                  if (item != null && ctx.mounted) Navigator.pop(ctx);
                  if (item != null && mounted) {
                    setState(() {
                      _todos.insert(0, item);
                      _listItems[item.id] = [];
                      _expandedLists[item.id] = true;
                    });
                    showTimedSnackBar(
                      const SnackBar(content: Text('To-Do list created')),
                    );
                  }
                },
                child: const Text('Create List'),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Add Single Todo Dialog ---

  void _showAddSingleTodoDialog() {
    final controller = TextEditingController();

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
              FilledButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty || _staffId == null) return;
                  final item = await _assignmentService.addTodo(
                    staffId: _staffId!,
                    title: controller.text.trim(),
                  );
                  if (item != null && ctx.mounted) Navigator.pop(ctx);
                  if (item != null && mounted) {
                    setState(() => _todos.insert(0, item));
                    showTimedSnackBar(
                      const SnackBar(content: Text('To-Do added')),
                    );
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
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
                child: const Text('Save'),
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
                child: const Text('Save'),
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
                child: const Text('Save'),
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
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
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
