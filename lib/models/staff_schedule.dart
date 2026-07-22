class StaffSchedule {
  final String id;
  final String staffId;
  final DateTime date;
  final bool isOnShift;
  final String? notes;
  final DateTime createdAt;

  StaffSchedule({
    required this.id,
    required this.staffId,
    required this.date,
    this.isOnShift = true,
    this.notes,
    required this.createdAt,
  });

  factory StaffSchedule.fromJson(Map<String, dynamic> json) {
    return StaffSchedule(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      date: DateTime.parse(json['date'] as String),
      isOnShift: json['is_on_shift'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'staff_id': staffId,
      'date': date.toIso8601String().substring(0, 10),
      'is_on_shift': isOnShift,
      'notes': notes,
    };
  }
}
