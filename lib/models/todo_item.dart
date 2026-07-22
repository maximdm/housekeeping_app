class TodoItem {
  final String id;
  final String staffId;
  final String title;
  bool isDone;
  final String type;
  final DateTime createdAt;

  TodoItem({
    required this.id,
    required this.staffId,
    required this.title,
    required this.isDone,
    this.type = 'single',
    required this.createdAt,
  });

  bool get isList => type == 'list';

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      title: json['title'] as String,
      isDone: json['is_done'] as bool,
      type: json['type'] as String? ?? 'single',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
