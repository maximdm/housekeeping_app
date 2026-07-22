import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/room.dart';
import '../models/todo_item.dart';
import '../models/todo_list_item.dart';
import 'notification_service.dart';
import 'activity_service.dart';

class RoomNote {
  final String id;
  final String roomId;
  final String staffId;
  final String title;
  final String content;
  final String status;
  final String? staffName;
  final String? forwardedTo;
  final String? forwardedToName;
  final DateTime createdAt;

  RoomNote({
    required this.id,
    required this.roomId,
    required this.staffId,
    this.title = '',
    required this.content,
    this.status = 'none',
    this.staffName,
    this.forwardedTo,
    this.forwardedToName,
    required this.createdAt,
  });

  factory RoomNote.fromJson(Map<String, dynamic> json) {
    return RoomNote(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      staffId: json['staff_id'] as String,
      title: (json['title'] as String?) ?? '',
      content: json['content'] as String,
      status: (json['status'] as String?) ?? 'none',
      staffName: json['staff'] != null
          ? (json['staff'] as Map<String, dynamic>)['name'] as String?
          : null,
      forwardedTo: json['forwarded_to'] as String?,
      forwardedToName: json['forwarded_to_staff'] != null
          ? (json['forwarded_to_staff'] as Map<String, dynamic>)['name'] as String?
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

final Map<String, Map<String, dynamic>> noteStatusConfig = {
  'none': {'label': 'None', 'icon': Icons.circle_outlined, 'color': Colors.grey},
  'important': {'label': 'Important', 'icon': Icons.star_rounded, 'color': const Color(0xFFE53935)},
  'done': {'label': 'Done', 'icon': Icons.check_circle_rounded, 'color': const Color(0xFF43A047)},
  'problem': {'label': 'Problem', 'icon': Icons.warning_rounded, 'color': const Color(0xFFFF8F00)},
  'delegate': {'label': 'Delegate', 'icon': Icons.person_add_rounded, 'color': const Color(0xFF5C6BC0)},
  'today': {'label': 'Today', 'icon': Icons.today_rounded, 'color': const Color(0xFF00897B)},
  'tomorrow': {'label': 'Tomorrow', 'icon': Icons.fast_forward_rounded, 'color': const Color(0xFF0277BD)},
  'this_week': {'label': 'This Week', 'icon': Icons.date_range_rounded, 'color': const Color(0xFF7B1FA2)},
};

class Assignment {
  final String id;
  final String roomId;
  final String staffId;
  final DateTime assignedAt;
  final DateTime? completedAt;

  final Room? room;

  Assignment({
    required this.id,
    required this.roomId,
    required this.staffId,
    required this.assignedAt,
    this.completedAt,
    this.room,
  });

  bool get isCompleted => completedAt != null;

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      staffId: json['staff_id'] as String,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      room: json['room'] != null ? Room.fromJson(json['room']) : null,
    );
  }
}

class ActivityLogEntry {
  final String id;
  final String? staffId;
  final String action;
  final Map<String, dynamic>? details;
  final DateTime createdAt;
  final String? staffName;

  ActivityLogEntry({
    required this.id,
    this.staffId,
    required this.action,
    this.details,
    required this.createdAt,
    this.staffName,
  });

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      id: json['id'] as String,
      staffId: json['staff_id'] as String?,
      action: json['action'] as String,
      details: json['details'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      staffName: json['staff'] != null
          ? (json['staff'] as Map<String, dynamic>)['name'] as String?
          : null,
    );
  }
}

class AssignmentService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  List<Assignment> _assignments = [];
  List<Assignment> get assignments => _assignments;

  List<RoomNote> _notes = [];
  List<RoomNote> get notes => _notes;

  List<ActivityLogEntry> _activityLog = [];
  List<ActivityLogEntry> get activityLog => _activityLog;

  Future<List<Assignment>> loadMyAssignments(String staffId) async {
    try {
      final data = await _client
          .from('room_assignments')
          .select('''
            id, room_id, staff_id, assigned_at, completed_at,
            room:rooms(id, number, status, room_type_id, floor_id,
              room_type:room_types(name),
              floor:floors(name, number))
          ''')
          .eq('staff_id', staffId)
          .filter('completed_at', 'is', null)
          .order('assigned_at', ascending: false);

      _assignments = (data as List)
          .map((json) => Assignment.fromJson(json))
          .toList();
      notifyListeners();
      return _assignments;
    } catch (e) {
      debugPrint('Error loading assignments: $e');
      return [];
    }
  }

  Future<bool> assignRoom({
    required String roomId,
    required String staffId,
  }) async {
    try {
      // Get room number and staff name for notification
      final roomData =
          await _client.from('rooms').select('number').eq('id', roomId).single();
      final staffData =
          await _client.from('staff').select('name').eq('id', staffId).single();

      await _client.from('room_assignments').insert({
        'room_id': roomId,
        'staff_id': staffId,
      });

      await _logActivity(
        action: 'room_assigned',
        details: {
          'room_id': roomId,
          'room_number': roomData['number'] as String,
          'staff_id': staffId,
        },
      );

      NotificationService().notifyRoomAssigned(
        roomNumber: roomData['number'] as String,
        staffName: staffData['name'] as String,
      );

      return true;
    } catch (e) {
      debugPrint('Error assigning room: $e');
      return false;
    }
  }

  Future<bool> completeAssignment(String assignmentId) async {
    try {
      final assignment = _assignments.firstWhere(
        (a) => a.id == assignmentId,
        orElse: () => Assignment(id: '', roomId: '', staffId: '', assignedAt: DateTime.now()),
      );
      final roomNumber = assignment.room?.number;

      await _client
          .from('room_assignments')
          .update({'completed_at': DateTime.now().toIso8601String()})
          .eq('id', assignmentId);

      await _logActivity(
        action: 'assignment_completed',
        details: {
          'assignment_id': assignmentId,
          'room_number': roomNumber,
        },
      );

      _assignments.removeWhere((a) => a.id == assignmentId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error completing assignment: $e');
      return false;
    }
  }

  Future<bool> unassignRoom(String assignmentId) async {
    try {
      final assignment = _assignments.firstWhere(
        (a) => a.id == assignmentId,
        orElse: () => Assignment(id: '', roomId: '', staffId: '', assignedAt: DateTime.now()),
      );
      final roomNumber = assignment.room?.number;

      await _client.from('room_assignments').delete().eq('id', assignmentId);

      await _logActivity(
        action: 'room_unassigned',
        details: {
          'assignment_id': assignmentId,
          'room_number': roomNumber,
        },
      );

      _assignments.removeWhere((a) => a.id == assignmentId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error unassigning room: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getStaffAssignments(String staffId) async {
    try {
      final data = await _client
          .from('room_assignments')
          .select('id, room_id, assigned_at, completed_at, rooms!inner(id, number, status)')
          .eq('staff_id', staffId)
          .order('assigned_at', ascending: false);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error getting staff assignments: $e');
      return [];
    }
  }

  Future<bool> updateRoomStatus(String roomId, RoomStatus status) async {
    try {
      final roomData =
          await _client.from('rooms').select('number').eq('id', roomId).single();

      await _client
          .from('rooms')
          .update({'status': status.dbValue})
          .eq('id', roomId);

      await _logActivity(
        action: 'status_changed',
        details: {
          'room_id': roomId,
          'room_number': roomData['number'] as String,
          'new_status': status.dbValue,
        },
      );

      NotificationService().notifyStatusChanged(
        roomNumber: roomData['number'] as String,
        newStatus: status.label,
      );

      return true;
    } catch (e) {
      debugPrint('Error updating room status: $e');
      return false;
    }
  }

  Future<List<RoomNote>> loadNotes(String roomId) async {
    try {
      final data = await _client
          .from('room_notes')
          .select('''
            id, room_id, staff_id, title, content, status, created_at, forwarded_to,
            staff:staff!room_notes_staff_id_fkey(name),
            forwarded_to_staff:staff!room_notes_forwarded_to_fkey(name)
          ''')
          .eq('room_id', roomId)
          .order('created_at', ascending: false);

      _notes = (data as List)
          .map((json) => RoomNote.fromJson(json))
          .toList();
      notifyListeners();
      return _notes;
    } catch (e) {
      debugPrint('Error loading notes: $e');
      return [];
    }
  }

  Future<bool> addNote({
    required String roomId,
    required String staffId,
    required String title,
    required String content,
    String status = 'none',
  }) async {
    try {
      final roomData =
          await _client.from('rooms').select('number').eq('id', roomId).single();
      final staffData =
          await _client.from('staff').select('name').eq('id', staffId).single();

      await _client.from('room_notes').insert({
        'room_id': roomId,
        'staff_id': staffId,
        'title': title,
        'content': content,
        'status': status,
      });

      await _logActivity(
        action: 'note_added',
        details: {
          'room_id': roomId,
          'room_number': roomData['number'] as String,
          'staff_id': staffId,
        },
      );

      NotificationService().notifyNoteAdded(
        roomNumber: roomData['number'] as String,
        authorName: staffData['name'] as String,
      );

      await loadNotes(roomId);
      return true;
    } catch (e) {
      debugPrint('Error adding note: $e');
      return false;
    }
  }

  Future<bool> deleteNote(String noteId) async {
    try {
      await _logActivity(
        action: 'note_deleted',
        details: {'note_id': noteId},
      );

      await _client.from('room_notes').delete().eq('id', noteId);
      return true;
    } catch (e) {
      debugPrint('Error deleting note: $e');
      return false;
    }
  }

  Future<bool> updateNoteStatus(String noteId, String status) async {
    try {
      await _logActivity(
        action: 'note_status_changed',
        details: {'note_id': noteId, 'new_status': status},
      );

      await _client.from('room_notes').update({'status': status}).eq('id', noteId);
      return true;
    } catch (e) {
      debugPrint('Error updating note status: $e');
      return false;
    }
  }

  Future<bool> updateNote({
    required String noteId,
    required String title,
    required String content,
  }) async {
    try {
      await _logActivity(
        action: 'note_updated',
        details: {'note_id': noteId},
      );

      await _client.from('room_notes').update({
        'title': title,
        'content': content,
      }).eq('id', noteId);
      return true;
    } catch (e) {
      debugPrint('Error updating note: $e');
      return false;
    }
  }

  Future<bool> updateTodoTitle(String todoId, String title) async {
    try {
      await _client.from('personal_todos').update({'title': title}).eq('id', todoId);
      return true;
    } catch (e) {
      debugPrint('Error updating todo title: $e');
      return false;
    }
  }

  Future<bool> restoreNote({
    required String noteId,
    required String roomId,
    required String staffId,
    required String title,
    required String content,
    String status = 'none',
    required DateTime createdAt,
  }) async {
    try {
      await _client.from('room_notes').insert({
        'id': noteId,
        'room_id': roomId,
        'staff_id': staffId,
        'title': title,
        'content': content,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error restoring note: $e');
      return false;
    }
  }

  Future<void> loadActivityLog({int limit = 20}) async {
    try {
      final data = await _client
          .from('activity_log')
          .select('''
            id, staff_id, action, details, created_at,
            staff:staff(name)
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      _activityLog = (data as List)
          .map((json) => ActivityLogEntry.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading activity log: $e');
    }
  }

  Future<void> _logActivity({
    required String action,
    Map<String, dynamic>? details,
  }) async {
    await ActivityService().log(action: action, details: details);
  }

  // --- Recent Notes (all rooms) ---

  Future<List<RoomNote>> loadRecentNotes({int limit = 30}) async {
    try {
      final data = await _client
          .from('room_notes')
          .select('''
            id, room_id, staff_id, title, content, status, created_at, forwarded_to,
            staff:staff!room_notes_staff_id_fkey(name),
            forwarded_to_staff:staff!room_notes_forwarded_to_fkey(name),
            room:rooms(number)
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      return (data as List).map((json) => RoomNote.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading recent notes: $e');
      return [];
    }
  }

  // --- Note Forwarding ---

  Future<bool> forwardNote({
    required String noteId,
    required String staffId,
  }) async {
    try {
      await _client
          .from('room_notes')
          .update({'forwarded_to': staffId})
          .eq('id', noteId);

      await _logActivity(
        action: 'note_forwarded',
        details: {'note_id': noteId, 'forwarded_to': staffId},
      );

      return true;
    } catch (e) {
      debugPrint('Error forwarding note: $e');
      return false;
    }
  }

  Future<List<RoomNote>> loadForwardedNotes(String staffId) async {
    try {
      final data = await _client
          .from('room_notes')
          .select('''
            id, room_id, staff_id, title, content, status, created_at, forwarded_to,
            staff:staff!room_notes_staff_id_fkey(name),
            forwarded_to_staff:staff!room_notes_forwarded_to_fkey(name),
            room:rooms(number)
          ''')
          .eq('forwarded_to', staffId)
          .order('created_at', ascending: false);

      return (data as List).map((json) => RoomNote.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading forwarded notes: $e');
      return [];
    }
  }

  // --- Personal To-Do ---

  Future<String?> getStaffId() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client
        .from('staff')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();
    return data?['id'] as String?;
  }

  Future<List<TodoItem>> loadTodos(String staffId) async {
    try {
      final data = await _client
          .from('personal_todos')
          .select()
          .eq('staff_id', staffId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((json) => TodoItem.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading todos: $e');
      return [];
    }
  }

  Future<TodoItem?> addTodo({
    required String staffId,
    required String title,
    bool isList = false,
  }) async {
    try {
      final data = await _client
          .from('personal_todos')
          .insert({
            'staff_id': staffId,
            'title': title,
            'type': isList ? 'list' : 'single',
          })
          .select()
          .single();

      await _logActivity(
        action: isList ? 'todo_list_created' : 'todo_created',
        details: {'title': title},
      );

      return TodoItem.fromJson(data);
    } catch (e) {
      debugPrint('Error adding todo: $e');
      return null;
    }
  }

  Future<bool> toggleTodo(String todoId, bool isDone) async {
    try {
      await _client
          .from('personal_todos')
          .update({'is_done': isDone}).eq('id', todoId);
      return true;
    } catch (e) {
      debugPrint('Error toggling todo: $e');
      return false;
    }
  }

  Future<bool> deleteTodo(String todoId) async {
    try {
      await _logActivity(
        action: 'todo_deleted',
        details: {'todo_id': todoId},
      );

      await _client.from('todo_list_items').delete().eq('todo_id', todoId);
      await _client.from('personal_todos').delete().eq('id', todoId);
      return true;
    } catch (e) {
      debugPrint('Error deleting todo: $e');
      return false;
    }
  }

  // --- Todo List Items (checkable lists) ---

  Future<List<TodoListItem>> loadTodoListItems(String todoId) async {
    try {
      final data = await _client
          .from('todo_list_items')
          .select()
          .eq('todo_id', todoId)
          .order('created_at');
      return (data as List)
          .map((json) => TodoListItem.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading todo list items: $e');
      return [];
    }
  }

  Future<TodoListItem?> addTodoListItem({
    required String todoId,
    required String title,
  }) async {
    try {
      final data = await _client
          .from('todo_list_items')
          .insert({
            'todo_id': todoId,
            'title': title,
          })
          .select()
          .single();

      await _logActivity(
        action: 'todo_list_item_added',
        details: {'todo_id': todoId, 'title': title},
      );

      return TodoListItem.fromJson(data);
    } catch (e) {
      debugPrint('Error adding todo list item: $e');
      return null;
    }
  }

  Future<bool> toggleTodoListItem(String itemId, bool isDone) async {
    try {
      await _client
          .from('todo_list_items')
          .update({'is_done': isDone}).eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error toggling todo list item: $e');
      return false;
    }
  }

  Future<bool> deleteTodoListItem(String itemId) async {
    try {
      await _client.from('todo_list_items').delete().eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error deleting todo list item: $e');
      return false;
    }
  }

  Future<bool> updateTodoListItemTitle(String itemId, String title) async {
    try {
      await _client
          .from('todo_list_items')
          .update({'title': title}).eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error updating todo list item: $e');
      return false;
    }
  }
}
