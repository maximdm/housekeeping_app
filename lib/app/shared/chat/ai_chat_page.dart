import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';
import '../../../services/chatbot_service.dart';
import '../../../services/database_helper.dart';
import '../../../layouts/admin_layout.dart';
import '../../../layouts/staff_layout.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _chatbot = ChatbotService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _undoTimer;
  final List<Timer> _pendingTimers = [];

  bool _isLoading = false;
  bool? _isAdmin;
  bool _viewingHistory = false;
  DateTime? _historyDate;
  final List<ChatDayGroup> _historyGroups = [];

  @override
  void initState() {
    super.initState();
    _detectRole();
    _loadTodayMessages();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTodayMessages() async {
    await _chatbot.loadMessages();
    if (_chatbot.messages.isEmpty) {
      _chatbot.messages.add(ChatMessage(
        id: 'welcome',
        content: 'Hello! I\'m your housekeeping assistant. Ask me about:\n\n'
            '• Room statuses\n'
            '• Staff availability\n'
            '• Recent activity\n\n'
            'Type "help" for more options.',
        isUser: false,
        createdAt: DateTime.now(),
      ));
    }
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  TextSpan _parseMarkdown(String text, TextStyle baseStyle, bool isUser) {
    final spans = <TextSpan>[];
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in boldPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(fontWeight: FontWeight.bold),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _viewingHistory) return;

    setState(() {
      _chatbot.sendMessage(text);
      _controller.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    await _chatbot.processQuery(text);

    setState(() {
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _detectRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    String? role;
    try {
      final staffData = await Supabase.instance.client
          .from('staff')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
      role = staffData?['role'] as String?;
    } catch (e) {
      debugPrint('Error detecting role, trying cache: $e');
      try {
        final db = await DatabaseHelper.database;
        if (db != null) {
          final rows = await db.query(
            'staff_cache',
            where: 'user_id = ?',
            whereArgs: [user.id],
          );
          if (rows.isNotEmpty) {
            role = rows.first['role'] as String?;
          }
        }
      } catch (e2) {
        debugPrint('Error loading role from cache: $e2');
      }
    }

    if (mounted) {
      setState(() => _isAdmin = role == 'receptionist' || role == 'manager');
    }
  }

  // --- History ---

  Future<void> _openHistory() async {
    final groups = await _chatbot.loadHistory();
    if (!mounted) return;
    setState(() {
      _historyGroups
        ..clear()
        ..addAll(groups);
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _viewDay(ChatDayGroup group) {
    Navigator.pop(context);
    setState(() {
      _viewingHistory = true;
      _historyDate = group.date;
      _chatbot.messages
        ..clear()
        ..addAll(group.messages);
    });
  }

  void _exitHistory() {
    setState(() {
      _viewingHistory = false;
      _historyDate = null;
    });
    _loadTodayMessages();
  }

  void _clearChat() {
    final savedMessages = List<ChatMessage>.from(_chatbot.messages);
    setState(() {
      _chatbot.clearHistory();
      _chatbot.messages.add(ChatMessage(
        id: 'welcome',
        content: 'Hello! I\'m your housekeeping assistant. Ask me about:\n\n'
            '• Room statuses\n'
            '• Staff availability\n'
            '• Recent activity\n\n'
            'Type "help" for more options.',
        isUser: false,
        createdAt: DateTime.now(),
      ));
    });
    showTimedSnackBar(
      SnackBar(
        content: const Text('Chat history cleared'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _chatbot.messages
                ..clear()
                ..addAll(savedMessages);
            });
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // --- Delete / Archive ---

  void _showMessageActions(ChatMessage message) {
    if (message.id == 'welcome') return;
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
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive message'),
              onTap: () {
                Navigator.pop(ctx);
                _archiveMessage(message);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete message',
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
    setState(() => _chatbot.messages.removeWhere((m) => m.id == message.id));
    Timer? undoTimer;
    showTimedSnackBar(
      SnackBar(
        content: const Text('Message deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            undoTimer?.cancel();
            setState(() {
              _chatbot.messages.add(deleted);
              _chatbot.messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            });
            _chatbot.saveMessage(deleted);
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
    undoTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;
      await _chatbot.deleteMessage(deleted.id);
    });
    _pendingTimers.add(undoTimer);
  }

  void _archiveMessage(ChatMessage message) {
    final archived = message;
    setState(() => _chatbot.messages.removeWhere((m) => m.id == message.id));
    Timer? undoTimer;
    showTimedSnackBar(
      SnackBar(
        content: const Text('Message archived'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            undoTimer?.cancel();
            setState(() {
              _chatbot.messages.add(archived);
              _chatbot.messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            });
            _chatbot.saveMessage(archived);
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
    undoTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;
      await _chatbot.archiveMessage(archived.id);
    });
    _pendingTimers.add(undoTimer);
  }

  Future<void> _archiveDay(DateTime day) async {
    final count = await _chatbot.archiveDay(day);
    if (!mounted) return;
    showTimedSnackBar(
      SnackBar(content: Text('$count message${count == 1 ? '' : 's'} archived')),
    );
    _exitHistory();
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final body = Column(
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
                      '${_chatbot.messages.length} messages',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: _viewingHistory
              ? _buildMessageList()
              : _buildBody(),
        ),
        if (!_viewingHistory) _buildInputBar(),
      ],
    );

    if (_isAdmin == null || _isAdmin!) {
      return AdminLayout(
        currentRoute: '/shared/chat/ai_chat',
        title: _viewingHistory ? localizations.tr('aiHistory') : localizations.tr('aiChatTitle'),
        appBarActions: _viewingHistory ? null : [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'history') _openHistory();
              if (value == 'clear') _clearChat();
            },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'history', child: Text(localizations.tr('aiHistory'))),
                PopupMenuItem(value: 'clear', child: Text(localizations.tr('clearChat'))),
              ],
            ),
          ],
          scaffoldKey: _scaffoldKey,
          endDrawer: _buildHistoryDrawer(),
          child: body,
        );
      }
      return StaffLayout(
        currentTabIndex: 4,
        title: _viewingHistory ? localizations.tr('aiHistory') : localizations.tr('aiChatTitle'),
        appBarActions: _viewingHistory ? null : [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'history') _openHistory();
              if (value == 'clear') _clearChat();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'history', child: Text(localizations.tr('aiHistory'))),
              PopupMenuItem(value: 'clear', child: Text(localizations.tr('clearChat'))),
            ],
        ),
      ],
      scaffoldKey: _scaffoldKey,
      endDrawer: _buildHistoryDrawer(),
      child: body,
    );
  }

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
                localizations.tr('aiHistory'),
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
                        Icon(Icons.history,
                            size: 48,
                            color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(localizations.tr('noMessages'),
                            style: TextStyle(color: Colors.grey[600])),
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

  Widget _buildHistoryDayTile(ChatDayGroup group) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(group.date, now)) {
      label = localizations.tr('today');
    } else if (_isSameDay(group.date, now.subtract(const Duration(days: 1)))) {
      label = localizations.tr('yesterday');
    } else {
      label = _formatDate(group.date);
    }

    final userMessages = group.messages.where((m) => m.isUser).length;
    final botMessages = group.messages.where((m) => !m.isUser).length;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(Icons.chat_bubble_outline,
            size: 18, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '$userMessages sent · $botMessages received',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (value) {
          if (value == 'view') {
            _viewDay(group);
          } else if (value == 'archive') {
            _archiveDay(group.date);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'view', child: Text('View')),
          PopupMenuItem(
            value: 'archive',
            child: Text('Archive day',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
      onTap: () => _viewDay(group),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _chatbot.messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _chatbot.messages.length) {
                return _buildTypingIndicator();
              }
              return _buildMessage(_chatbot.messages[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _chatbot.messages.length,
      itemBuilder: (context, index) {
        return _buildMessage(_chatbot.messages[index]);
      },
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final isUser = message.isUser;
    final isWelcome = message.id == 'welcome';
    return GestureDetector(
      onLongPress: () => _showMessageActions(message),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              margin: const EdgeInsets.only(bottom: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.smart_toy_outlined,
                              size: 14,
                              color:
                                  Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Assistant',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SelectableText.rich(
                    _parseMarkdown(
                      message.content,
                      TextStyle(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      isUser,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isWelcome) _buildSuggestionChips(),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = [
      'What needs cleaning?',
      'Room status',
      'Active staff',
      'Recent activity',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: suggestions.map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 13)),
                onPressed: () {
                  _controller.text = s;
                  _send();
                },
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                side: BorderSide.none,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.touch_app, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                'Long-press a message to delete or archive it',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              localizations.tr('aiThinking'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: localizations.tr('aiPlaceholder'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isLoading ? null : _send,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
