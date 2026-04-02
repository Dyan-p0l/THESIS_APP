class Sample {
  final int? id;
  final String label;
  final String createdAt;

  Sample({
    this.id,
    required this.label,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'created_at': createdAt,
    };
  }

  factory Sample.fromMap(Map<String, dynamic> map) {
    return Sample(
      id: map['id'],
      label: map['label'],
      createdAt: map['created_at'],
    );
  }
}