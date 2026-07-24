class SharedNote {
  final String noteId;
  final String noteType;
  final bool isRead;
  final String sharedByName;
  final String? roomNumber;
  final String? noteTitle;
  final String? noteContent;
  final String? noteStatus;
  final DateTime sharedAt;

  SharedNote({
    required this.noteId,
    required this.noteType,
    required this.isRead,
    required this.sharedByName,
    this.roomNumber,
    this.noteTitle,
    this.noteContent,
    this.noteStatus,
    required this.sharedAt,
  });

  factory SharedNote.fromJson(Map<String, dynamic> json) {
    final noteType = json['note_type'] as String;
    Map<String, dynamic>? noteData;
    if (noteType == 'room_note' && json['room_notes'] != null) {
      noteData = json['room_notes'] as Map<String, dynamic>;
    } else if (noteType == 'todo' && json['personal_todos'] != null) {
      noteData = json['personal_todos'] as Map<String, dynamic>;
    }

    String? roomNumber;
    if (noteType == 'room_note' && noteData != null) {
      final room = noteData['room'];
      if (room != null) {
        roomNumber = (room as Map<String, dynamic>)['number'] as String?;
      }
    }

    return SharedNote(
      noteId: json['note_id'] as String,
      noteType: noteType,
      isRead: json['is_read'] as bool? ?? false,
      sharedByName: json['shared_by_staff'] != null
          ? (json['shared_by_staff'] as Map<String, dynamic>)['name'] as String? ?? 'Unknown'
          : 'Unknown',
      roomNumber: roomNumber,
      noteTitle: noteData?['title'] as String?,
      noteContent: noteData?['content'] as String?,
      noteStatus: noteData?['status'] as String?,
      sharedAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
