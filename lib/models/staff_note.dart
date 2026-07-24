class StaffNote {
  final String id;
  final String title;
  final String content;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final List<String> sharedWithIds;
  final List<String> sharedWithNames;
  final bool isRead;

  StaffNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    this.sharedWithIds = const [],
    this.sharedWithNames = const [],
    this.isRead = false,
  });

  factory StaffNote.fromJson(Map<String, dynamic> json) {
    return StaffNote(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdBy: json['created_by'] as String,
      createdByName: json['created_by_staff'] != null
          ? (json['created_by_staff'] as Map<String, dynamic>)['name'] as String?
          : json['createdByName'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      sharedWithIds: json['sharedWithIds'] != null
          ? List<String>.from(json['sharedWithIds'] as List)
          : const [],
      sharedWithNames: json['sharedWithNames'] != null
          ? List<String>.from(json['sharedWithNames'] as List)
          : const [],
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  StaffNote copyWith({
    String? title,
    String? content,
    List<String>? sharedWithIds,
    List<String>? sharedWithNames,
    bool? isRead,
  }) {
    return StaffNote(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: createdAt,
      sharedWithIds: sharedWithIds ?? this.sharedWithIds,
      sharedWithNames: sharedWithNames ?? this.sharedWithNames,
      isRead: isRead ?? this.isRead,
    );
  }
}
