class TodoListItem {
  final String id;
  final String todoId;
  String title;
  bool isDone;
  final int sortOrder;
  final DateTime createdAt;

  TodoListItem({
    required this.id,
    required this.todoId,
    required this.title,
    required this.isDone,
    required this.sortOrder,
    required this.createdAt,
  });

  factory TodoListItem.fromJson(Map<String, dynamic> json) {
    return TodoListItem(
      id: json['id'] as String,
      todoId: json['todo_id'] as String,
      title: json['title'] as String,
      isDone: json['is_done'] as bool,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
