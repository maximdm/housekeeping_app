import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/room.dart';
import '../models/shared_note.dart';
import '../models/staff_note.dart';
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
          ? (json['forwarded_to_staff'] as Map<String, dynamic>)['name']
              as String?
          : null,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

final Map<String, Map<String, dynamic>> noteStatusConfig = {
  'none': {
    'label': 'None',
    'icon': Icons.circle_outlined,
    'color': Colors.grey,
  },
  'important': {
    'label': 'Important',
    'icon': Icons.star_rounded,
    'color': const Color(0xFFE53935),
  },
  'done': {
    'label': 'Done',
    'icon': Icons.check_circle_rounded,
    'color': const Color(0xFF43A047),
  },
  'problem': {
    'label': 'Problem',
    'icon': Icons.warning_rounded,
    'color': const Color(0xFFFF8F00),
  },
  'delegate': {
    'label': 'Delegate',
    'icon': Icons.person_add_rounded,
    'color': const Color(0xFF5C6BC0),
  },
  'today': {
    'label': 'Today',
    'icon': Icons.today_rounded,
    'color': const Color(0xFF00897B),
  },
  'tomorrow': {
    'label': 'Tomorrow',
    'icon': Icons.fast_forward_rounded,
    'color': const Color(0xFF0277BD),
  },
  'this_week': {
    'label': 'This Week',
    'icon': Icons.date_range_rounded,
    'color': const Color(0xFF7B1FA2),
  },
};

class FloorAssignment {
  final String id;
  final String staffId;
  final String floorId;
  final DateTime assignmentDate;
  final String? staffName;
  final String? floorName;
  final String? floorNumber;

  FloorAssignment({
    required this.id,
    required this.staffId,
    required this.floorId,
    required this.assignmentDate,
    this.staffName,
    this.floorName,
    this.floorNumber,
  });

  factory FloorAssignment.fromJson(Map<String, dynamic> json) {
    return FloorAssignment(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      floorId: json['floor_id'] as String,
      assignmentDate:
          DateTime.parse(json['assignment_date'] as String).toLocal(),
      staffName: json['staff'] != null
          ? (json['staff'] as Map<String, dynamic>)['name'] as String?
          : null,
      floorName: json['floor'] != null
          ? (json['floor'] as Map<String, dynamic>)['name'] as String?
          : null,
      floorNumber: json['floor'] != null
          ? (json['floor'] as Map<String, dynamic>)['number']?.toString()
          : null,
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
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      staffName: json['staff'] != null
          ? (json['staff'] as Map<String, dynamic>)['name'] as String?
          : null,
    );
  }
}

class StaffSelectedRoom {
  static Room? instance;
}

class AssignmentService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  List<RoomNote> _notes = [];
  List<RoomNote> get notes => _notes;

  List<ActivityLogEntry> _activityLog = [];
  List<ActivityLogEntry> get activityLog => _activityLog;

  // --- Floor Assignments ---

  Future<bool> assignFloorToStaff({
    required String staffId,
    required String floorId,
    required DateTime date,
  }) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);

      final floorData = await _client
          .from('floors')
          .select('name')
          .eq('id', floorId)
          .single();

      await _client.from('floor_assignments').upsert({
        'staff_id': staffId,
        'floor_id': floorId,
        'assignment_date': dateStr,
      }, onConflict: 'staff_id,floor_id,assignment_date');

      await _logActivity(
        action: 'floor_assigned',
        details: {
          'floor_id': floorId,
          'floor_name': floorData['name'] as String,
          'staff_id': staffId,
          'date': dateStr,
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error assigning floor: $e');
      return false;
    }
  }

  Future<bool> unassignFloorFromStaff({
    required String staffId,
    required String floorId,
    required DateTime date,
  }) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      await _client
          .from('floor_assignments')
          .delete()
          .eq('staff_id', staffId)
          .eq('floor_id', floorId)
          .eq('assignment_date', dateStr);

      await _logActivity(
        action: 'floor_unassigned',
        details: {
          'floor_id': floorId,
          'staff_id': staffId,
          'date': dateStr,
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error unassigning floor: $e');
      return false;
    }
  }

  Future<List<FloorAssignment>> loadFloorAssignmentsForDate(
      DateTime date) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final data = await _client
          .from('floor_assignments')
          .select('''
            id, staff_id, floor_id, assignment_date,
            staff:staff(name),
            floor:floors(name, number)
          ''')
          .eq('assignment_date', dateStr);

      return (data as List)
          .map((json) => FloorAssignment.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading floor assignments: $e');
      return [];
    }
  }

  Future<List<FloorAssignment>> loadMyFloorAssignmentsForDate(
      String staffId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final data = await _client
          .from('floor_assignments')
          .select('''
            id, staff_id, floor_id, assignment_date,
            floor:floors(name, number)
          ''')
          .eq('staff_id', staffId)
          .eq('assignment_date', dateStr);

      return (data as List)
          .map((json) => FloorAssignment.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading my floor assignments: $e');
      return [];
    }
  }

  Future<List<Room>> loadMyDirtyRoomsForDate(
      String staffId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);

      final floorData = await _client
          .from('floor_assignments')
          .select('floor_id')
          .eq('staff_id', staffId)
          .eq('assignment_date', dateStr);

      if (floorData.isEmpty) return [];

      final floorIds =
          (floorData as List).map((f) => f['floor_id'] as String).toList();

      final roomsData = await _client
          .from('rooms')
          .select('''
            id, number, status, room_type_id, floor_id, description,
            room_type:room_types(name),
            floor:floors(name, number)
          ''')
          .inFilter('floor_id', floorIds)
          .inFilter('status', ['dirty', 'in_progress']);

      return (roomsData as List)
          .map((json) => Room.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading dirty rooms: $e');
      return [];
    }
  }

  // --- Room Status ---

  Future<bool> updateRoomStatus(String roomId, RoomStatus status) async {
    try {
      final roomData = await _client
          .from('rooms')
          .select('number')
          .eq('id', roomId)
          .single();

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

  // --- Room Notes ---

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
      final roomData = await _client
          .from('rooms')
          .select('number')
          .eq('id', roomId)
          .single();
      final staffData = await _client
          .from('staff')
          .select('name')
          .eq('id', staffId)
          .single();

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

      await _client
          .from('room_notes')
          .update({'status': status})
          .eq('id', noteId);
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

      await _client
          .from('room_notes')
          .update({'title': title, 'content': content})
          .eq('id', noteId);
      return true;
    } catch (e) {
      debugPrint('Error updating note: $e');
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

  // --- Activity Log ---

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
          .update({'is_done': isDone})
          .eq('id', todoId);
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

  Future<bool> updateTodoTitle(String todoId, String title) async {
    try {
      await _client
          .from('personal_todos')
          .update({'title': title})
          .eq('id', todoId);
      return true;
    } catch (e) {
      debugPrint('Error updating todo title: $e');
      return false;
    }
  }

  // --- Todo List Items ---

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
          .insert({'todo_id': todoId, 'title': title})
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
          .update({'is_done': isDone})
          .eq('id', itemId);
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
          .update({'title': title})
          .eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error updating todo list item title: $e');
      return false;
    }
  }

  // --- Note Sharing ---

  Future<void> shareNote({
    required String noteType,
    required String noteId,
    required List<String> sharedWithStaffIds,
    required String sharedByStaffId,
  }) async {
    try {
      final shares = sharedWithStaffIds
          .map((staffId) => {
                'note_type': noteType,
                'note_id': noteId,
                'shared_with': staffId,
                'shared_by': sharedByStaffId,
              })
          .toList();

      await _client.from('note_shares').upsert(
            shares,
            onConflict: 'note_type,note_id,shared_with',
          );
    } catch (e) {
      debugPrint('Error sharing note: $e');
    }
  }

  Future<void> unshareNote({
    required String noteType,
    required String noteId,
  }) async {
    try {
      await _client
          .from('note_shares')
          .delete()
          .eq('note_type', noteType)
          .eq('note_id', noteId);
    } catch (e) {
      debugPrint('Error unsharing note: $e');
    }
  }

  Future<void> removeReceivedShare({
    required String noteType,
    required String noteId,
    required String sharedWithStaffId,
  }) async {
    try {
      await _client
          .from('note_shares')
          .delete()
          .eq('note_type', noteType)
          .eq('note_id', noteId)
          .eq('shared_with', sharedWithStaffId);
    } catch (e) {
      debugPrint('Error removing received share: $e');
    }
  }

  Future<void> clearAllReceivedNotes(String staffId) async {
    try {
      await _client.from('note_shares').delete().eq('shared_with', staffId);
    } catch (e) {
      debugPrint('Error clearing received notes: $e');
    }
  }

  Future<List<SharedNote>> loadReceivedNotes(String staffId) async {
    try {
      final data = await _client
          .from('note_shares')
          .select('''
            id, note_type, note_id, is_read, created_at,
            shared_by_staff:shared_by(name)
          ''')
          .eq('shared_with', staffId)
          .order('created_at', ascending: false);

      final shares = (data as List).toList();
      if (shares.isEmpty) return [];

      final roomNoteIds = <String>[];
      final todoIds = <String>[];
      for (final share in shares) {
        if (share['note_type'] == 'room_note') {
          roomNoteIds.add(share['note_id'] as String);
        } else if (share['note_type'] == 'todo') {
          todoIds.add(share['note_id'] as String);
        }
      }

      final Map<String, dynamic> roomNotesMap = {};
      if (roomNoteIds.isNotEmpty) {
        final notesData = await _client
            .from('room_notes')
            .select('id, title, content, status, room:rooms(number)')
            .inFilter('id', roomNoteIds);
        for (final n in notesData as List) {
          roomNotesMap[n['id'] as String] = n;
        }
      }

      final Map<String, dynamic> todosMap = {};
      if (todoIds.isNotEmpty) {
        final todosData = await _client
            .from('personal_todos')
            .select('id, title, is_done')
            .inFilter('id', todoIds);
        for (final t in todosData as List) {
          todosMap[t['id'] as String] = t;
        }
      }

      return shares.map((json) {
        final noteType = json['note_type'] as String;
        final noteId = json['note_id'] as String;
        final sharedByName =
            (json['shared_by_staff'] as Map<String, dynamic>?)?['name']
                as String?;

        String? noteTitle;
        String? noteContent;
        String? noteStatus;
        String? roomNumber;

        if (noteType == 'room_note') {
          final note = roomNotesMap[noteId];
          if (note != null) {
            noteTitle = note['title'] as String?;
            noteContent = note['content'] as String?;
            noteStatus = note['status'] as String?;
            roomNumber = (note['room'] as Map<String, dynamic>?)?['number']
                as String?;
          }
        } else if (noteType == 'todo') {
          final todo = todosMap[noteId];
          if (todo != null) {
            noteTitle = todo['title'] as String?;
            noteContent = null;
            noteStatus =
                (todo['is_done'] as bool?) == true ? 'done' : 'none';
          }
        }

        return SharedNote(
          noteId: noteId,
          noteType: noteType,
          isRead: json['is_read'] as bool? ?? false,
          sharedByName: sharedByName ?? 'Unknown',
          roomNumber: roomNumber,
          noteTitle: noteTitle,
          noteContent: noteContent,
          noteStatus: noteStatus,
          sharedAt:
              DateTime.parse(json['created_at'] as String).toLocal(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading received notes: $e');
      return [];
    }
  }

  Future<void> markAsRead(String noteType, String noteId, String staffId) async {
    try {
      await _client
          .from('note_shares')
          .update({'is_read': true})
          .eq('note_type', noteType)
          .eq('note_id', noteId)
          .eq('shared_with', staffId);
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<int> getUnreadCount(String staffId) async {
    try {
      final data = await _client
          .from('note_shares')
          .select('id')
          .eq('shared_with', staffId)
          .eq('is_read', false);

      return (data as List).length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> updateShares({
    required String noteType,
    required String noteId,
    required List<String> newStaffIds,
    required String sharedByStaffId,
  }) async {
    try {
      await _client
          .from('note_shares')
          .delete()
          .eq('note_type', noteType)
          .eq('note_id', noteId);

      if (newStaffIds.isNotEmpty) {
        await shareNote(
          noteType: noteType,
          noteId: noteId,
          sharedWithStaffIds: newStaffIds,
          sharedByStaffId: sharedByStaffId,
        );
      }
    } catch (e) {
      debugPrint('Error updating shares: $e');
    }
  }

  // --- Staff Notes ---

  Future<StaffNote?> createStaffNote({
    required String title,
    required String content,
    required String createdByStaffId,
    required List<String> sharedWithStaffIds,
  }) async {
    try {
      final data = await _client
          .from('staff_notes')
          .insert({
            'title': title,
            'content': content,
            'created_by': createdByStaffId,
          })
          .select()
          .single();

      final note = StaffNote.fromJson(data);

      if (sharedWithStaffIds.isNotEmpty) {
        await shareNote(
          noteType: 'staff_note',
          noteId: note.id,
          sharedWithStaffIds: sharedWithStaffIds,
          sharedByStaffId: createdByStaffId,
        );
      }

      return note;
    } catch (e) {
      debugPrint('Error creating staff note: $e');
      return null;
    }
  }

  Future<List<StaffNote>> loadStaffNotesCreatedBy(String staffId) async {
    try {
      final data = await _client
          .from('staff_notes')
          .select('''
            *,
            created_by_staff:staff!staff_notes_created_by_fkey(name)
          ''')
          .eq('created_by', staffId)
          .order('created_at', ascending: false);

      final notes = <StaffNote>[];
      for (final json in data as List) {
        final note = StaffNote.fromJson(json);

        final shares = await _client
            .from('note_shares')
            .select('shared_with, staff!note_shares_shared_with_fkey(name)')
            .eq('note_type', 'staff_note')
            .eq('note_id', note.id);

        final shareList = shares as List;
        notes.add(StaffNote(
          id: note.id,
          title: note.title,
          content: note.content,
          createdBy: note.createdBy,
          createdByName: note.createdByName,
          createdAt: note.createdAt,
          sharedWithIds: shareList
              .map((s) => s['shared_with'] as String)
              .toList(),
          sharedWithNames: shareList
              .map((s) =>
                  (s['staff'] as Map<String, dynamic>?)?['name'] as String? ??
                  '')
              .toList(),
        ));
      }

      return notes;
    } catch (e) {
      debugPrint('Error loading staff notes: $e');
      return [];
    }
  }

  Future<bool> updateStaffNote({
    required String noteId,
    required String title,
    required String content,
    required String sharedByStaffId,
    required List<String> newStaffIds,
  }) async {
    try {
      await _client
          .from('staff_notes')
          .update({'title': title, 'content': content})
          .eq('id', noteId);

      await updateShares(
        noteType: 'staff_note',
        noteId: noteId,
        newStaffIds: newStaffIds,
        sharedByStaffId: sharedByStaffId,
      );

      return true;
    } catch (e) {
      debugPrint('Error updating staff note: $e');
      return false;
    }
  }

  Future<bool> deleteStaffNote(String noteId) async {
    try {
      await _client.from('staff_notes').delete().eq('id', noteId);
      return true;
    } catch (e) {
      debugPrint('Error deleting staff note: $e');
      return false;
    }
  }

  Future<List<StaffNote>> loadReceivedStaffNotes(String staffId) async {
    try {
      final shares = await _client
          .from('note_shares')
          .select('note_id, is_read')
          .eq('note_type', 'staff_note')
          .eq('shared_with', staffId);

      final shareList = shares as List;
      if (shareList.isEmpty) return [];

      final noteIds = shareList.map((s) => s['note_id'] as String).toList();
      final readMap = {
        for (final s in shareList) s['note_id'] as String: s['is_read'] as bool
      };

      final notesData = await _client
          .from('staff_notes')
          .select('''
            id, title, content, created_by, created_at,
            created_by_staff:staff!staff_notes_created_by_fkey(name)
          ''')
          .inFilter('id', noteIds);

      final notes = <StaffNote>[];
      for (final json in notesData as List) {
        notes.add(StaffNote(
          id: json['id'] as String,
          title: json['title'] as String,
          content: json['content'] as String,
          createdBy: json['created_by'] as String,
          createdByName:
              (json['created_by_staff'] as Map<String, dynamic>?)?['name']
                  as String?,
          createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
          isRead: readMap[json['id'] as String] ?? false,
        ));
      }

      return notes;
    } catch (e) {
      debugPrint('Error loading received staff notes: $e');
      return [];
    }
  }
}
