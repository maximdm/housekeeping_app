import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final bool archived;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    this.archived = false,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['is_user'] as bool,
      archived: json['archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'is_user': isUser,
      'archived': archived,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ChatDayGroup {
  final DateTime date;
  final List<ChatMessage> messages;

  ChatDayGroup({required this.date, required this.messages});
}

class ChatbotService {
  static final ChatbotService _instance = ChatbotService._();
  factory ChatbotService() => _instance;
  ChatbotService._();

  final SupabaseClient _client = Supabase.instance.client;

  List<ChatMessage> messages = [];

  String? get _userId => _client.auth.currentUser?.id;

  // --- Language Detection ---

  bool _isRomanian(String text) {
    final lower = text.toLowerCase();
    final romanianPatterns = [
      'camera', 'camere', 'etaj', 'etaje', 'personal', 'angajat',
      'curat', 'murdar', 'curatenie', 'stare', 'status', 'activitate',
      'salut', 'ajutor', 'ajuta', 'poti', 'vreau', 'spune',
      'astazi', 'ieri', 'maine', 'acum', 'ieri', 'azi',
      'numar', 'detalii', 'notite', 'program', 'tura',
      'da', 'nu', 'multumesc', 'te rog',
    ];
    return romanianPatterns.any((p) => lower.contains(p));
  }

  // --- Persistence ---

  Future<void> loadMessages({bool includeArchived = false}) async {
    if (_userId == null) return;
    try {
      final data = await _client
          .from('ai_chat_messages')
          .select()
          .eq('user_id', _userId!)
          .eq('archived', includeArchived)
          .order('created_at');

      messages = (data as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading AI chat messages: $e');
    }
  }

  Future<void> saveMessage(ChatMessage msg) async {
    if (_userId == null) return;
    try {
      await _client.from('ai_chat_messages').insert({
        'user_id': _userId,
        'content': msg.content,
        'is_user': msg.isUser,
        'created_at': msg.createdAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving AI chat message: $e');
    }
  }

  Future<bool> deleteMessage(String id) async {
    if (_userId == null) return false;
    try {
      await _client
          .from('ai_chat_messages')
          .delete()
          .eq('id', id)
          .eq('user_id', _userId!);
      messages.removeWhere((m) => m.id == id);
      return true;
    } catch (e) {
      debugPrint('Error deleting AI chat message: $e');
      return false;
    }
  }

  Future<bool> archiveMessage(String id) async {
    if (_userId == null) return false;
    try {
      await _client
          .from('ai_chat_messages')
          .update({'archived': true})
          .eq('id', id)
          .eq('user_id', _userId!);
      final idx = messages.indexWhere((m) => m.id == id);
      if (idx != -1) {
        messages[idx] = ChatMessage(
          id: messages[idx].id,
          content: messages[idx].content,
          isUser: messages[idx].isUser,
          archived: true,
          createdAt: messages[idx].createdAt,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error archiving AI chat message: $e');
      return false;
    }
  }

  Future<int> archiveDay(DateTime day) async {
    if (_userId == null) return 0;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    try {
      final response = await _client
          .from('ai_chat_messages')
          .update({'archived': true})
          .eq('user_id', _userId!)
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .eq('archived', false)
          .select();
      final count = (response as List).length;
      for (var i = 0; i < messages.length; i++) {
        final m = messages[i];
        if (m.createdAt.isAfter(start) &&
            m.createdAt.isBefore(end) &&
            !m.archived) {
          messages[i] = ChatMessage(
            id: m.id,
            content: m.content,
            isUser: m.isUser,
            archived: true,
            createdAt: m.createdAt,
          );
        }
      }
      return count;
    } catch (e) {
      debugPrint('Error archiving day: $e');
      return 0;
    }
  }

  Future<List<ChatDayGroup>> loadHistory() async {
    if (_userId == null) return [];
    try {
      final data = await _client
          .from('ai_chat_messages')
          .select()
          .eq('user_id', _userId!)
          .eq('archived', false)
          .order('created_at');

      final allMessages = (data as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList();

      final grouped = <String, List<ChatMessage>>{};
      for (final msg in allMessages) {
        final key =
            '${msg.createdAt.year}-${msg.createdAt.month}-${msg.createdAt.day}';
        grouped.putIfAbsent(key, () => []).add(msg);
      }

      final groups = grouped.entries.map((e) {
        final date = e.value.first.createdAt;
        return ChatDayGroup(
          date: DateTime(date.year, date.month, date.day),
          messages: e.value,
        );
      }).toList();

      groups.sort((a, b) => b.date.compareTo(a.date));
      return groups;
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      return [];
    }
  }

  void clearHistory() {
    messages.clear();
  }

  // --- Chat Logic ---

  ChatMessage sendMessage(String text) {
    final userMessage = ChatMessage(
      id: _localId(),
      content: text,
      isUser: true,
      createdAt: DateTime.now(),
    );
    messages.add(userMessage);
    saveMessage(userMessage);
    return userMessage;
  }

  Future<ChatMessage> processQuery(String text) async {
    final lower = text.toLowerCase().trim();
    final isRo = _isRomanian(lower);

    String response;

    if (_matchesAny(lower, ['hello', 'hi', 'hey', 'help', 'salut', 'ajutor', 'ajuta'])) {
      response = isRo ? _helpResponseRo() : _helpResponse();
    } else if (_matchesAny(lower, [
      'need cleaning', 'dirty', 'need clean',
      'murdar', 'curatenie', 'necurățat', 'necurat', 'trebuie curățat',
    ])) {
      response = await _roomsNeedingCleaning(isRo: isRo);
    } else if (_matchesAny(lower, [
      'in progress', 'being cleaned',
      'se curata', 'în curs', 'se curăță', 'în lucru',
    ])) {
      response = await _roomsInProgress(isRo: isRo);
    } else if (_matchesAny(lower, [
      'clean', 'ready', 'available',
      'curat', 'pregatit', 'pregătit', 'disponibil',
    ])) {
      response = await _cleanRooms(isRo: isRo);
    } else if (_matchesAny(lower, [
      'all rooms', 'rooms status', 'room status', 'rooms',
      'toate camerele', 'stare camere', 'camere',
    ])) {
      response = await _allRoomsStatus(isRo: isRo);
    } else if (_matchesAny(lower, [
      'staff', 'cleaner', 'team', 'who',
      'personal', 'echipa', 'echipă', 'cine',
    ])) {
      response = await _activeStaff(isRo: isRo);
    } else if (_matchesAny(lower, [
      'activity', 'log', 'recent', 'history',
      'activitate', 'jurnal', 'recent', 'istoric',
    ])) {
      response = await _recentActivity(isRo: isRo);
    } else if (_matchesAny(lower, ['floor', 'floors', 'etaj', 'etaje'])) {
      response = await _roomsByFloor(isRo: isRo);
    } else if (_containsRoomNumber(lower)) {
      response = await _roomDetail(lower, isRo: isRo);
    } else {
      response = isRo ? _defaultResponseRo() : _defaultResponse();
    }

    final botMessage = ChatMessage(
      id: _localId(),
      content: response,
      isUser: false,
      createdAt: DateTime.now(),
    );
    messages.add(botMessage);
    saveMessage(botMessage);
    return botMessage;
  }

  String _localId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_randomHex(8)}';
  }

  String _randomHex(int len) {
    const chars = '0123456789abcdef';
    final rng = DateTime.now().microsecondsSinceEpoch;
    return List.generate(len, (i) => chars[(rng >> (i * 4)) & 0xf]).join();
  }

  bool _matchesAny(String input, List<String> keywords) {
    return keywords.any((k) => input.contains(k));
  }

  bool _containsRoomNumber(String input) {
    final roomPattern = RegExp(r'room\s*([A-Za-z]?\d+)', caseSensitive: false);
    final roomPatternRo = RegExp(r'camera\s*([A-Za-z]?\d+)', caseSensitive: false);
    return roomPattern.hasMatch(input) || roomPatternRo.hasMatch(input);
  }

  // --- English Responses ---

  String _helpResponse() {
    return 'Here\'s what I can help with:\n\n'
        '• "rooms needing cleaning" — see dirty rooms\n'
        '• "rooms in progress" — see rooms being cleaned\n'
        '• "clean rooms" — see available rooms\n'
        '• "all rooms" — overview of all room statuses\n'
        '• "room 101" or "room P01" — get details for a specific room\n'
        '• "staff" or "team" — see active staff\n'
        '• "activity" — recent activity log\n'
        '• "floors" — rooms grouped by floor';
  }

  String _defaultResponse() {
    return 'I\'m not sure what you mean. Try asking about:\n\n'
        '• Rooms (clean, dirty, in progress)\n'
        '• Staff availability\n'
        '• Recent activity\n'
        '• A specific room (e.g., "room 101" or "room P01")\n\n'
        'Type "help" for a full list of commands.';
  }

  // --- Romanian Responses ---

  String _helpResponseRo() {
    return 'Iată ce te pot ajuta:\n\n'
        '• "camere murdare" — vezi camerele care trebuie curățate\n'
        '• "camere în lucru" — vezi camerele care se curăță\n'
        '• "camere curate" — vezi camerele disponibile\n'
        '• "toate camerele" — privire de ansamblu asupra statusului camerelor\n'
        '• "camera 101" sau "camera P01" — detalii despre o cameră specifică\n'
        '• "personal" sau "echipa" — vezi personalul activ\n'
        '• "activitate" — jurnalul de activitate recent\n'
        '• "etaje" — camere grupate pe etaje';
  }

  String _defaultResponseRo() {
    return 'Nu sunt sigur ce vrei să spui. Încearcă să întrebi despre:\n\n'
        '• Camere (curate, murdare, în lucru)\n'
        '• Disponibilitatea personalului\n'
        '• Activitatea recentă\n'
        '• O cameră specifică (ex: "camera 101" sau "camera P01")\n\n'
        'Scrie "ajutor" pentru lista completă de comenzi.';
  }

  // --- Room Queries ---

  Future<String> _roomsNeedingCleaning({bool isRo = false}) async {
    try {
      final data = await _client
          .from('rooms')
          .select('number, room_type:room_types(name), floor:floors(name, number)')
          .eq('status', 'dirty')
          .order('number');

      final rooms = data as List;
      if (rooms.isEmpty) {
        return isRo
            ? 'Toate camerele sunt curate! Nicio cameră nu necesită curățenie în acest moment.'
            : 'All rooms are clean! No rooms currently need cleaning.';
      }

      final title = isRo ? 'Camere care necesită curățenie' : 'Rooms Needing Cleaning';
      final buffer = StringBuffer('**$title** (${rooms.length})\n\n');
      for (final room in rooms) {
        final type = (room['room_type'] as Map<String, dynamic>?)?['name'] ?? (isRo ? 'Necunoscut' : 'Unknown');
        final floor = (room['floor'] as Map<String, dynamic>?)?['name'] ??
            '${isRo ? 'Etaj' : 'Floor'} ${(room['floor'] as Map<String, dynamic>?)?['number'] ?? '?'}';
        buffer.writeln('• ${isRo ? 'Camera' : 'Room'} ${room['number']} — $type ($floor)');
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('Chatbot error: $e');
      return isRo
          ? 'Ne pare rău, nu am putut prelua datele camerelor. Te rog încearcă din nou.'
          : 'Sorry, I couldn\'t fetch room data. Please try again.';
    }
  }

  Future<String> _roomsInProgress({bool isRo = false}) async {
    try {
      final data = await _client
          .from('rooms')
          .select('number, room_type:room_types(name), floor:floors(name, number)')
          .eq('status', 'in_progress')
          .order('number');

      final rooms = data as List;
      if (rooms.isEmpty) {
        return isRo
            ? 'Nicio cameră nu este în curs de curățenie în acest moment.'
            : 'No rooms are currently being cleaned.';
      }

      final title = isRo ? 'Camere în lucru' : 'Rooms In Progress';
      final buffer = StringBuffer('**$title** (${rooms.length})\n\n');
      for (final room in rooms) {
        final type = (room['room_type'] as Map<String, dynamic>?)?['name'] ?? (isRo ? 'Necunoscut' : 'Unknown');
        final floor = (room['floor'] as Map<String, dynamic>?)?['name'] ??
            '${isRo ? 'Etaj' : 'Floor'} ${(room['floor'] as Map<String, dynamic>?)?['number'] ?? '?'}';
        buffer.writeln('• ${isRo ? 'Camera' : 'Room'} ${room['number']} — $type ($floor)');
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('Chatbot error: $e');
      return isRo
          ? 'Ne pare rău, nu am putut prelua datele camerelor. Te rog încearcă din nou.'
          : 'Sorry, I couldn\'t fetch room data. Please try again.';
    }
  }

  Future<String> _cleanRooms({bool isRo = false}) async {
    try {
      final data = await _client
          .from('rooms')
          .select('number, room_type:room_types(name), floor:floors(name, number)')
          .eq('status', 'clean')
          .order('number');

      final rooms = data as List;
      if (rooms.isEmpty) {
        return isRo
            ? 'Nicio cameră nu este curată în acest moment.'
            : 'No rooms are currently clean.';
      }

      final title = isRo ? 'Camere curate' : 'Clean Rooms';
      final buffer = StringBuffer('**$title** (${rooms.length})\n\n');
      for (final room in rooms) {
        final type = (room['room_type'] as Map<String, dynamic>?)?['name'] ?? (isRo ? 'Necunoscut' : 'Unknown');
        final floor = (room['floor'] as Map<String, dynamic>?)?['name'] ??
            '${isRo ? 'Etaj' : 'Floor'} ${(room['floor'] as Map<String, dynamic>?)?['number'] ?? '?'}';
        buffer.writeln('• ${isRo ? 'Camera' : 'Room'} ${room['number']} — $type ($floor)');
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('Chatbot error: $e');
      return isRo
          ? 'Ne pare rău, nu am putut prelua datele camerelor. Te rog încearcă din nou.'
          : 'Sorry, I couldn\'t fetch room data. Please try again.';
    }
  }

  Future<String> _allRoomsStatus({bool isRo = false}) async {
    try {
      final data = await _client.from('rooms').select('number, status');

      final rooms = data as List;
      if (rooms.isEmpty) {
        return isRo ? 'Nu s-au găsit camere în sistem.' : 'No rooms found in the system.';
      }

      final dirty = rooms.where((r) => r['status'] == 'dirty').length;
      final inProgress = rooms.where((r) => r['status'] == 'in_progress').length;
      final clean = rooms.where((r) => r['status'] == 'clean').length;

      if (isRo) {
        return '**Privire de ansamblu asupra statusului camerelor**\n\n'
            'Total camere: ${rooms.length}\n'
            '🟢 Curate: $clean\n'
            '🟡 În lucru: $inProgress\n'
            '🔴 Necesită curățenie: $dirty';
      }
      return '**Room Status Overview**\n\n'
          'Total rooms: ${rooms.length}\n'
          '🟢 Clean: $clean\n'
          '🟡 In Progress: $inProgress\n'
          '🔴 Need Cleaning: $dirty';
    } catch (e) {
      debugPrint('Chatbot error: $e');
      return isRo
          ? 'Ne pare rău, nu am putut prelua datele camerelor. Te rog încearcă din nou.'
          : 'Sorry, I couldn\'t fetch room data. Please try again.';
    }
  }

  Future<String> _activeStaff({bool isRo = false}) async {
    try {
      final data = await _client
          .from('staff')
          .select('name, role')
          .eq('is_active', true)
          .order('name');

      final staff = data as List;
      if (staff.isEmpty) {
        return isRo
            ? 'Niciun angajat nu este activ în acest moment.'
            : 'No staff members are currently active.';
      }

      final cleaners = staff.where((s) => s['role'] == 'cleaner').toList();
      final receptionists = staff.where((s) => s['role'] == 'receptionist' || s['role'] == 'manager').toList();

      final title = isRo ? 'Personal activ' : 'Active Staff';
      final buffer = StringBuffer('**$title** (${staff.length})\n\n');

      if (cleaners.isNotEmpty) {
        buffer.writeln('${isRo ? 'Curățători' : 'Cleaners'} (${cleaners.length}):');
        for (final s in cleaners) {
          buffer.writeln('  • ${s['name']}');
        }
        buffer.writeln();
      }

      if (receptionists.isNotEmpty) {
        buffer.writeln('${isRo ? 'Manageri și Recepționeri' : 'Managers & Receptionists'} (${receptionists.length}):');
        for (final s in receptionists) {
          buffer.writeln('  • ${s['name']}');
        }
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('Chatbot error: $e');
      return isRo
          ? 'Ne pare rău, nu am putut prelua datele personalului. Te rog încearcă din nou.'
          : 'Sorry, I couldn\'t fetch staff data. Please try again.';
    }
  }

  Future<String> _recentActivity({bool isRo = false}) async {
    try {
      final data = await _client
          .from('activity_log')
          .select('action, details, created_at, staff:staff(name)')
          .order('created_at', ascending: false)
          .limit(10);

      final entries = data as List;
      if (entries.isEmpty) {
        return isRo ? 'Nu s-a găsit activitate recentă.' : 'No recent activity found.';
      }

      final title = isRo ? 'Activitate recentă' : 'Recent Activity';
      final buffer = StringBuffer('**$title**\n\n');
      for (final entry in entries) {
        final name = (entry['staff'] as Map<String, dynamic>?)?['name'] ?? (isRo ? 'Sistem' : 'System');
        final action = entry['action'] as String;
        final time = DateTime.parse(entry['created_at'] as String).toLocal();
        final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        String actionText;
        if (isRo) {
          switch (action) {
            case 'status_changed':
              final status = (entry['details'] as Map<String, dynamic>?)?['new_status'] ?? '';
              actionText = 'a schimbat statusul în $status';
            case 'room_assigned':
              actionText = 'a fost repartizat la o cameră';
            case 'note_added':
              actionText = 'a adăugat o notă';
            default:
              actionText = action;
          }
        } else {
          switch (action) {
            case 'status_changed':
              final status = (entry['details'] as Map<String, dynamic>?)?['new_status'] ?? '';
              actionText = 'changed status to $status';
            case 'room_assigned':
              actionText = 'was assigned a room';
            case 'note_added':
              actionText = 'added a note';
            default:
              actionText = action;
          }
        }

        buffer.writeln('$timeStr — $name $actionText');
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('Chatbot error: $e');
      return isRo
          ? 'Ne pare rău, nu am putut prelua datele de activitate. Te rog încearcă din nou.'
          : 'Sorry, I couldn\'t fetch activity data. Please try again.';
    }
  }

  Future<String> _roomsByFloor({bool isRo = false}) async {
    try {
      final data = await _client.from('rooms').select('''
        number, status,
        floor:floors(name, number)
      ''').order('number');

      final rooms = data as List;
      if (rooms.isEmpty) return isRo ? 'Nu s-au găsit camere.' : 'No rooms found.';

      final grouped = <String, List>{};
      for (final room in rooms) {
        final floorData = room['floor'] as Map<String, dynamic>?;
        final floorName = floorData?['name'] as String? ??
            '${isRo ? 'Etaj' : 'Floor'} ${floorData?['number'] ?? '?'}';
        grouped.putIfAbsent(floorName, () => []).add(room);
      }

      final title = isRo ? 'Camere pe etaj' : 'Rooms by Floor';
      final buffer = StringBuffer('**$title**\n\n');
      for (final entry in grouped.entries) {
        buffer.writeln('${entry.key}:');
        for (final room in entry.value) {
          final status = room['status'] as String;
          final icon = status == 'clean' ? '🟢' : status == 'in_progress' ? '🟡' : '🔴';
          buffer.writeln('  $icon ${isRo ? 'Camera' : 'Room'} ${room['number']} ($status)');
        }
        buffer.writeln();
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('Chatbot error: $e');
      return isRo
          ? 'Ne pare rău, nu am putut prelua datele pe etaje. Te rog încearcă din nou.'
          : 'Sorry, I couldn\'t fetch floor data. Please try again.';
    }
  }

  Future<String> _roomDetail(String input, {bool isRo = false}) async {
    final roomPatternEn = RegExp(r'room\s*([A-Za-z]?\d+)', caseSensitive: false);
    final roomPatternRo = RegExp(r'camera\s*([A-Za-z]?\d+)', caseSensitive: false);
    final match = roomPatternEn.firstMatch(input) ?? roomPatternRo.firstMatch(input);
    if (match == null) {
      return isRo
          ? 'Te rog specifică numărul camerei, ex: "camera 101" sau "camera P01".'
          : 'Please specify a room number, e.g., "room 101" or "room P01".';
    }

    final roomNumber = match.group(1)!;

    try {
      final data = await _client.from('rooms').select('''
        id, number, status,
        room_type:room_types(name),
        floor:floors(name, number)
      ''').eq('number', roomNumber).maybeSingle();

      if (data == null) {
        return isRo
            ? 'Camera $roomNumber nu a fost găsită.'
            : 'Room $roomNumber not found.';
      }

      final type = (data['room_type'] as Map<String, dynamic>?)?['name'] ?? (isRo ? 'Necunoscut' : 'Unknown');
      final floorData = data['floor'] as Map<String, dynamic>?;
      final floor = floorData?['name'] as String? ?? '${isRo ? 'Etaj' : 'Floor'} ${floorData?['number'] ?? '?'}';
      final status = data['status'] as String;
      final statusIcon = status == 'clean' ? '🟢' : status == 'in_progress' ? '🟡' : '🔴';

      final buffer = StringBuffer('**${isRo ? 'Detalii Camera' : 'Room'} $roomNumber ${isRo ? '' : 'Details'}**\n\n');
      buffer.writeln('${isRo ? 'Tip' : 'Type'}: $type');
      buffer.writeln('${isRo ? 'Etaj' : 'Floor'}: $floor');
      buffer.writeln('${isRo ? 'Status' : 'Status'}: $statusIcon $status');

      final notes = await _client
          .from('room_notes')
          .select('content, created_at, staff:staff(name)')
          .eq('room_id', data['id'] as String)
          .order('created_at', ascending: false)
          .limit(3);

      final notesList = notes as List;
      if (notesList.isNotEmpty) {
        buffer.writeln('\n${isRo ? 'Note recente' : 'Recent Notes'}:');
        for (final note in notesList) {
          final author = (note['staff'] as Map<String, dynamic>?)?['name'] ?? (isRo ? 'Necunoscut' : 'Unknown');
          buffer.writeln('  • "$author": ${note['content']}');
        }
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('Chatbot error: $e');
      return isRo
          ? 'Ne pare rău, nu am putut prelua datele camerei. Te rog încearcă din nou.'
          : 'Sorry, I couldn\'t fetch room data. Please try again.';
    }
  }
}