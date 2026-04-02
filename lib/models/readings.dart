class Reading {

  final int? id;
  final int? sampleId;
  final double value;
  final String carriedOutAt;
  final bool isSaved;
  final String? category;

  Reading({
    this.id,
    this.sampleId,
    required this.value,
    required this.carriedOutAt,
    this.isSaved = false,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sample_id': sampleId,
      'value': value,
      'carried_out_at': carriedOutAt,
      'is_saved': isSaved ? 1 : 0,
      'category': category,
    };
  }

  factory Reading.fromMap(Map<String, dynamic> map) {
    return Reading(
      id: map['id'],
      sampleId: map['sample_id'],
      value: map['value'],
      carriedOutAt: map['carried_out_at'],
      isSaved: map['is_saved'] == 1,
      category: map['category'],
    );
  }

}