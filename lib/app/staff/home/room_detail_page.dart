import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';
import '../../../models/room.dart';
import '../../../services/assignment_service.dart';
import '../../../services/database_helper.dart';
import '../../../layouts/staff_layout.dart';

class RoomDetailPage extends StatefulWidget {
  const RoomDetailPage({super.key});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  final AssignmentService _assignmentService = AssignmentService();
  final _noteController = TextEditingController();
  final List<Timer> _pendingTimers = [];

  Room? _room;
  List<RoomNote> _notes = [];
  String? _staffId;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _noteController.dispose();
    super.dispose();
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

      if (staffData != null) {
        _staffId = staffData['id'] as String;
      }
    } catch (e) {
      debugPrint('Error loading staff data, trying cache: $e');
    }

    if (_staffId == null) {
      try {
        final db = await DatabaseHelper.database;
        if (db != null) {
          final rows = await db.query(
            'staff_cache',
            where: 'user_id = ?',
            whereArgs: [user.id],
          );
          if (rows.isNotEmpty) {
            _staffId = rows.first['id'] as String;
          }
        }
      } catch (e2) {
        debugPrint('Error loading staff from cache: $e2');
      }
    }

    _room = StaffSelectedRoom.instance;
    if (_room != null) {
      try {
        _notes = await _assignmentService.loadNotes(_room!.id);
      } catch (e) {
        debugPrint('Error loading notes: $e');
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateStatus(RoomStatus newStatus) async {
    if (_room == null || _updating) return;

    setState(() => _updating = true);

    final success = await _assignmentService.updateRoomStatus(
      _room!.id,
      newStatus,
    );

    if (success && mounted) {
      setState(() {
        _room!.status = newStatus;
        _updating = false;
      });

      showTimedSnackBar(SnackBar(
        content: Text(localizations.tr('roomStatusUpdated').replaceAll('{status}', newStatus.label)),
        backgroundColor: newStatus.color,
      ));
    } else {
      setState(() => _updating = false);
    }
  }

  Future<void> _addNote() async {
    if (_noteController.text.trim().isEmpty || _room == null || _staffId == null) {
      return;
    }

    final success = await _assignmentService.addNote(
      roomId: _room!.id,
      staffId: _staffId!,
      title: '',
      content: _noteController.text.trim(),
    );

    if (success && mounted) {
      _noteController.clear();
      _notes = await _assignmentService.loadNotes(_room!.id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StaffLayout(
      currentTabIndex: 0,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _room == null
              ? Center(child: Text(localizations.tr('noRoomAssigned')))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoomHeader(),
          const SizedBox(height: 24),
          _buildStatusSection(),
          const SizedBox(height: 24),
          _buildNotesSection(),
        ],
      ),
    );
  }

  Widget _buildRoomHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _room!.status.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _room!.number,
                  style: TextStyle(
                    color: _room!.status.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.tr('roomLabel').replaceAll('{number}', _room!.number),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_room!.roomTypeName ?? localizations.tr('room')} · ${_room!.floorName ?? ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.tr('status'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: RoomStatus.values.map((status) {
                final isSelected = _room!.status == status;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton(
                      onPressed: _updating
                          ? null
                          : isSelected
                              ? null
                              : () => _updateStatus(status),
                      style: FilledButton.styleFrom(
                        backgroundColor: isSelected
                            ? status.color
                            : status.color.withValues(alpha: 0.1),
                        foregroundColor: isSelected
                            ? Colors.white
                            : status.color,
                        disabledBackgroundColor: isSelected
                            ? status.color
                            : status.color.withValues(alpha: 0.1),
                        disabledForegroundColor: isSelected
                            ? Colors.white
                            : status.color,
                      ),
                      child: _updating && !isSelected
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(status.label),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.tr('notes_'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: localizations.tr('addNoteHint'),
                      border: const OutlineInputBorder(),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addNote,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
            if (_notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ..._notes.map((note) => _buildNoteItem(note)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(RoomNote note) {
    final statusCfg = noteStatusConfig[note.status] ?? noteStatusConfig['none']!;
    final statusColor = statusCfg['color'] as Color;
    final statusIcon = statusCfg['icon'] as IconData;
    final statusLabel = statusCfg['label'] as String;

    return Dismissible(
      key: ValueKey('room_note_${note.id}'),
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
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(localizations.tr('deleteNoteQuestion')),
            content: Text(localizations.tr('thisActionUndone')),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: note.status != 'none'
                ? statusColor.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.outlineVariant,
            width: note.status != 'none' ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
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
                Flexible(
                  child: Text(
                    note.staffName ?? localizations.tr('staffFallback'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(note.createdAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
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
                ),
              ],
            ),
            const SizedBox(height: 4),
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
  }

  void _deleteNote(RoomNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.tr('deleteNoteQuestion')),
        content: Text(localizations.tr('thisActionUndone')),
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
      showTimedSnackBar(SnackBar(
        content: Text(localizations.tr('noteDeleted')),
        action: SnackBarAction(
          label: localizations.tr('undo'),
          onPressed: () {
            undoTimer?.cancel();
            _assignmentService.restoreNote(
              noteId: deletedNote.id,
              roomId: deletedNote.roomId,
              staffId: deletedNote.staffId,
              title: deletedNote.title,
              content: deletedNote.content,
              status: deletedNote.status,
              createdAt: deletedNote.createdAt,
            );
            if (mounted) {
              _assignmentService.loadNotes(_room!.id).then((notes) {
                if (mounted) setState(() => _notes = notes);
              });
            }
          },
        ),
        duration: const Duration(seconds: 5),
      ));
      undoTimer = Timer(const Duration(seconds: 5), () async {
        if (!mounted) return;
        await _assignmentService.deleteNote(deletedNote.id);
      });
      _pendingTimers.add(undoTimer);
    }
  }

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
                child: Text(localizations.tr('setNoteStatus'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                    _notes = await _assignmentService.loadNotes(_room!.id);
                    setState(() {});
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
                localizations.tr('editNoteTitle'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: localizations.tr('noteTitleLabel'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: localizations.tr('noteDescriptionLabel'),
                  border: const OutlineInputBorder(),
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
                    _notes = await _assignmentService.loadNotes(_room!.id);
                    if (mounted) {
                      setState(() {});
                      showTimedSnackBar(SnackBar(content: Text(localizations.tr('noteUpdated'))));
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 60) return localizations.tr('minutesAgo').replaceAll('{minutes}', '${diff.inMinutes}');
    if (diff.inHours < 24) return localizations.tr('hoursAgo').replaceAll('{hours}', '${diff.inHours}');
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
