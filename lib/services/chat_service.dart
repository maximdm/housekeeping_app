import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../models/staff_member.dart';
import 'database_helper.dart';
import 'activity_service.dart';

class ChatService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  RealtimeChannel? _chatChannel;
  String? _currentStaffId;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Stream<ChatMessage> get onMessageInserted {
    final controller = StreamController<ChatMessage>();

    if (_chatChannel != null) {
      _client.removeChannel(_chatChannel!);
    }
    _chatChannel = _client
        .channel('chat-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) async {
            final data = payload.newRecord;
            if (data.isNotEmpty) {
              // Fetch full message with sender info
              final full = await _client
                  .from('chat_messages')
                  .select('''
                    id, sender_id, content, created_at,
                    sender:staff(name, role)
                  ''')
                  .eq('id', data['id'])
                  .single();

              final msg = ChatMessage.fromJson(full);
              _messages.add(msg);
              notifyListeners();
              controller.add(msg);
              await _cacheMessages(_messages);
            }
          },
        )
        .subscribe();

    return controller.stream;
  }

  void setCurrentStaffId(String staffId) {
    _currentStaffId = staffId;
  }

  Future<void> loadMessages({int limit = 50}) async {
    try {
      final data = await _client
          .from('chat_messages')
          .select('''
            id, sender_id, content, created_at,
            sender:staff(name, role)
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      _messages = (data as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList()
          .reversed
          .toList();

      _hasMore = data.length >= limit;
      await _cacheMessages(_messages);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      await _loadCachedMessages();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final oldest = _messages.first;
      final data = await _client
          .from('chat_messages')
          .select('''
            id, sender_id, content, created_at,
            sender:staff(name, role)
          ''')
          .filter('created_at', 'lt', oldest.createdAt.toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      final older = (data as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList()
          .reversed
          .toList();

      _messages = [...older, ..._messages];
      _hasMore = data.length >= 50;
      await _cacheMessages(_messages);
    } catch (e) {
      debugPrint('Error loading more messages: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _currentStaffId == null) return;

    try {
      await _client.from('chat_messages').insert({
        'sender_id': _currentStaffId,
        'content': content.trim(),
      });

      await ActivityService().log(
        action: 'message_sent',
        details: {'content': content.trim()},
      );

      // Realtime callback handles adding to list
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      await ActivityService().log(
        action: 'message_deleted',
        details: {'message_id': messageId},
      );

      await _client.from('chat_messages').delete().eq('id', messageId);
      _messages.removeWhere((m) => m.id == messageId);
      await _cacheMessages(_messages);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return false;
    }
  }

  Future<bool> restoreMessage(ChatMessage message) async {
    try {
      await _client.from('chat_messages').insert({
        'id': message.id,
        'sender_id': message.senderId,
        'content': message.content,
        'created_at': message.createdAt.toIso8601String(),
      });
      _messages.add(message);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      await _cacheMessages(_messages);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error restoring message: $e');
      return false;
    }
  }

  Future<int> clearAllMessages() async {
    try {
      final all = List<ChatMessage>.from(_messages);

      await ActivityService().log(
        action: 'chat_cleared',
        details: {'message_count': all.length},
      );

      await _client.from('chat_messages').delete().neq('id', '');
      _messages.clear();
      await _cacheMessages(_messages);
      notifyListeners();
      return all.length;
    } catch (e) {
      debugPrint('Error clearing messages: $e');
      return 0;
    }
  }

  Future<void> restoreAllMessages(List<ChatMessage> messages) async {
    try {
      for (final msg in messages) {
        await _client.from('chat_messages').insert({
          'id': msg.id,
          'sender_id': msg.senderId,
          'content': msg.content,
          'created_at': msg.createdAt.toIso8601String(),
        });
      }
      _messages = messages;
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      await _cacheMessages(_messages);
      notifyListeners();
    } catch (e) {
      debugPrint('Error restoring messages: $e');
    }
  }

  void subscribeToChat() {
    if (_chatChannel != null) {
      _client.removeChannel(_chatChannel!);
    }
    _chatChannel = _client
        .channel('chat-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) async {
            final data = payload.newRecord;
            if (data.isNotEmpty) {
              final full = await _client
                  .from('chat_messages')
                  .select('''
                    id, sender_id, content, created_at,
                    sender:staff(name, role)
                  ''')
                  .eq('id', data['id'])
                  .single();

              final msg = ChatMessage.fromJson(full);
              _messages.add(msg);
              notifyListeners();
              await _cacheMessages(_messages);
            }
          },
        )
        .subscribe();
  }

  void unsubscribeFromChat() {
    if (_chatChannel != null) {
      _client.removeChannel(_chatChannel!);
      _chatChannel = null;
    }
  }

  // --- Offline Cache ---

  Future<void> _cacheMessages(List<ChatMessage> messages) async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      await db.delete('chat_cache');
      for (final msg in messages) {
        await db.insert('chat_cache', {
          'id': msg.id,
          'sender_id': msg.senderId,
          'sender_name': msg.senderName,
          'sender_role': msg.senderRole.name,
          'content': msg.content,
          'created_at': msg.createdAt.toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error caching messages: $e');
    }
  }

  Future<void> _loadCachedMessages() async {
    try {
      final db = await DatabaseHelper.database;
      if (db == null) return;
      final rows = await db.query('chat_cache', orderBy: 'created_at ASC');
      _messages = rows.map((row) => ChatMessage(
        id: row['id'] as String,
        senderId: row['sender_id'] as String,
        senderName: row['sender_name'] as String? ?? '',
        senderRole: StaffRole.fromString(row['sender_role'] as String? ?? 'cleaner'),
        content: row['content'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      )).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached messages: $e');
    }
  }

  @override
  void dispose() {
    unsubscribeFromChat();
    super.dispose();
  }
}
