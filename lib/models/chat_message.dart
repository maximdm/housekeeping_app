import 'staff_member.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final StaffRole senderRole;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    String senderName = '';
    StaffRole senderRole = StaffRole.cleaner;

    if (json['sender'] != null) {
      final sender = json['sender'] as Map<String, dynamic>;
      senderName = sender['name'] as String? ?? '';
      senderRole = StaffRole.fromString(sender['role'] as String? ?? 'cleaner');
    }

    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      senderName: senderName,
      senderRole: senderRole,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
