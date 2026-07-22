class Floor {
  final String id;
  final String number;
  final String? name;

  Floor({
    required this.id,
    required this.number,
    this.name,
  });

  String get displayName => name ?? 'Floor $number';

  factory Floor.fromJson(Map<String, dynamic> json) {
    return Floor(
      id: json['id'] as String,
      number: json['number'].toString(),
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'name': name,
    };
  }
}
