import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/chat_message.dart';
import '../../../models/staff_member.dart';
import '../../../main.dart';
import '../../../services/chat_service.dart';
import '../../../layouts/admin_layout.dart';
import '../../../layouts/staff_layout.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<Timer> _pendingTimers = [];

  String? _currentStaffId;
  bool _loading = true;
  bool? _isAdmin;
  bool _isManager = false;

  bool _viewingHistory = false;
  DateTime? _historyDate;
  List<ChatMessage> _historyMessages = [];

  @override
  void initState() {
    super.initState();
    _initChat();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _messageController.dispose();
    _scrollController.dispose();
    _chatService.removeListener(_onMessagesChanged);
    _chatService.unsubscribeFromChat();
    _chatService.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() { _isAdmin = false; _loading = false; });
      return;
    }

    try {
      final staffData = await Supabase.instance.client
          .from('staff')
          .select('id, name, role')
          .eq('user_id', user.id)
          .maybeSingle();

      if (staffData == null || staffData['id'] == null) {
        if (mounted) setState(() { _isAdmin = false; _loading = false; });
        return;
      }

      _currentStaffId = staffData['id'] as String;
      _isAdmin = staffData['role'] == 'receptionist' || staffData['role'] == 'manager';
      _isManager = staffData['role'] == 'manager';
      _chatService.setCurrentStaffId(_currentStaffId!);

      await _chatService.loadMessages();
      _chatService.addListener(_onMessagesChanged);
      _chatService.subscribeToChat();
    } catch (e) {
      debugPrint('Error initializing chat: $e');
    }

    if (mounted) {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _onMessagesChanged() {
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _chatService.loadMore();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _chatService.sendMessage(text);
    _messageController.clear();
  }

  // --- History ---

  void _openHistory() {
    final groups = _groupByDay(_chatService.messages);
    _scaffoldKey.currentState?.openEndDrawer();
    if (!mounted) return;
    setState(() {
      _historyGroups
        ..clear()
        ..addAll(groups);
    });
  }

  final List<_ChatDayGroup> _historyGroups = [];

  List<_ChatDayGroup> _groupByDay(List<ChatMessage> messages) {
    final map = <String, List<ChatMessage>>{};
    for (final m in messages) {
      final key = '${m.createdAt.year}-${m.createdAt.month}-${m.createdAt.day}';
      map.putIfAbsent(key, () => []).add(m);
    }
    final groups = map.entries.map((e) {
      final first = e.value.first;
      return _ChatDayGroup(date: first.createdAt, messages: e.value);
    }).toList();
    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  void _viewDay(_ChatDayGroup group) {
    Navigator.pop(context);
    setState(() {
      _viewingHistory = true;
      _historyDate = group.date;
      _historyMessages = List.from(group.messages);
    });
  }

  void _exitHistory() {
    setState(() {
      _viewingHistory = false;
      _historyDate = null;
      _historyMessages = [];
    });
  }

  // --- Delete / Clear ---

  void _showMessageActions(ChatMessage message) {
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
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text(localizations.tr('deleteMessage'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMessage(ChatMessage message) {
    final deleted = message;
    setState(() => _chatService.messages.removeWhere((m) => m.id == message.id));
    Timer? undoTimer;
    showTimedSnackBar(
      SnackBar(
        content: Text(localizations.tr('deleteMessageConfirm')),
        action: SnackBarAction(
          label: localizations.tr('undo'),
          onPressed: () {
            undoTimer?.cancel();
            _chatService.restoreMessage(deleted);
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
    undoTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;
      await _chatService.deleteMessage(deleted.id);
    });
    _pendingTimers.add(undoTimer);
  }

  void _clearChat() {
    final savedMessages = List<ChatMessage>.from(_chatService.messages);
    setState(() => _chatService.messages.clear());
    Timer? undoTimer;
    showTimedSnackBar(
      SnackBar(
        content: Text(localizations.tr('clearChatConfirm')),
        action: SnackBarAction(
          label: localizations.tr('undo'),
          onPressed: () {
            undoTimer?.cancel();
            _chatService.restoreAllMessages(savedMessages);
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
    undoTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;
      for (final msg in savedMessages) {
        await _chatService.deleteMessage(msg.id);
      }
    });
    _pendingTimers.add(undoTimer);
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final body = _loading || _isAdmin == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (_viewingHistory)
                Material(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, size: 20),
                            onPressed: _exitHistory,
                          ),
                          Icon(Icons.history, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(_historyDate!),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_historyMessages.length} messages',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _viewingHistory ? _buildHistoryMessageList() : _buildMessageList(),
              ),
              if (!_viewingHistory) _buildInputBar(),
            ],
          );

    if (_isAdmin == null || _isAdmin!) {
      return AdminLayout(
        currentRoute: '/shared/chat',
        title: _viewingHistory ? localizations.tr('chatHistory') : localizations.tr('chatTitle'),
        appBarActions: _viewingHistory ? null : [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'history') _openHistory();
              if (value == 'clear') _clearChat();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'history', child: Text(localizations.tr('chatHistory'))),
              if (_isManager)
                PopupMenuItem(
                  value: 'clear',
                  enabled: _chatService.messages.isNotEmpty,
                  child: Text(localizations.tr('clearChat')),
                ),
            ],
          ),
        ],
        scaffoldKey: _scaffoldKey,
        endDrawer: _buildHistoryDrawer(),
        child: body,
      );
    }
    return StaffLayout(
      currentTabIndex: 3,
      title: _viewingHistory ? localizations.tr('chatHistory') : localizations.tr('chatTitle'),
      appBarActions: _viewingHistory ? null : [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'history') _openHistory();
            if (value == 'clear') _clearChat();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'history', child: Text(localizations.tr('chatHistory'))),
            if (_isManager)
              PopupMenuItem(
                value: 'clear',
                enabled: _chatService.messages.isNotEmpty,
                child: Text(localizations.tr('clearChat')),
              ),
          ],
        ),
      ],
      scaffoldKey: _scaffoldKey,
      endDrawer: _buildHistoryDrawer(),
      child: body,
    );
  }

  // --- History Drawer ---

  Widget _buildHistoryDrawer() {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                localizations.tr('chatHistory'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _historyGroups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(localizations.tr('noMessages'), style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _historyGroups.length,
                    itemBuilder: (context, index) {
                      final group = _historyGroups[index];
                      return _buildHistoryDayTile(group);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryDayTile(_ChatDayGroup group) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(group.date, now)) {
      label = localizations.tr('today');
    } else if (_isSameDay(group.date, now.subtract(const Duration(days: 1)))) {
      label = localizations.tr('yesterday');
    } else {
      label = _formatDate(group.date);
    }

    final senders = group.messages.map((m) => m.senderId).toSet().length;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(Icons.chat_bubble_outline,
            size: 18, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${group.messages.length} messages · $senders participant${senders == 1 ? '' : 's'}',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () => _viewDay(group),
    );
  }

  Widget _buildHistoryMessageList() {
    if (_historyMessages.isEmpty) {
      return const Center(child: Text('No messages for this day'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _historyMessages.length,
      itemBuilder: (context, index) {
        final message = _historyMessages[index];
        final isMe = message.senderId == _currentStaffId;
        final showHeader = index == 0 ||
            _historyMessages[index - 1].senderId != message.senderId;

        return Column(
          children: [
            if (showHeader) _buildMessageHeader(message),
            _buildMessageBubble(message, isMe),
          ],
        );
      },
    );
  }

  // --- Current Chat ---

  Widget _buildMessageList() {
    if (_chatService.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No messages yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Start a conversation with your team',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _chatService.messages.length + (_chatService.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _chatService.messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final message = _chatService.messages[index];
        final isMe = message.senderId == _currentStaffId;

        final showHeader = index == 0 ||
            _chatService.messages[index - 1].senderId != message.senderId;

        final showDateHeader = index == 0 ||
            !_isSameDay(
              _chatService.messages[index - 1].createdAt,
              message.createdAt,
            );

        return Column(
          children: [
            if (showDateHeader) _buildDateHeader(message.createdAt),
            if (showHeader) _buildMessageHeader(message),
            _buildMessageBubble(message, isMe),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = localizations.tr('today');
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = localizations.tr('yesterday');
    } else {
      label = _formatDate(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMessageHeader(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              message.senderName.isNotEmpty ? message.senderName : 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (message.senderRole == StaffRole.receptionist || message.senderRole == StaffRole.manager)
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              message.senderRole.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: (message.senderRole == StaffRole.receptionist || message.senderRole == StaffRole.manager)
                    ? Theme.of(context).colorScheme.primary
                    : Colors.blue,
              ),
            ),
          ),
          const Spacer(),
          Text(
            _formatTime(message.createdAt),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.70,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: isMe
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );

    if (!_isManager) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) bubble,
          GestureDetector(
            onTap: () => _showMessageActions(message),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 12,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (isMe) bubble,
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: localizations.tr('typeMessage'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ChatDayGroup {
  final DateTime date;
  final List<ChatMessage> messages;
  _ChatDayGroup({required this.date, required this.messages});
}
