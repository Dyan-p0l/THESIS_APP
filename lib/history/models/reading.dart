enum FreshnessCategory { fresh, moderate, spoiled }

class Reading {
  final String id;
  final String sampleLabel;
  final double capacitance;
  final DateTime timestamp;
  final FreshnessCategory category;

  Reading({
    required this.id,
    required this.sampleLabel,
    required this.capacitance,
    required this.timestamp,
    required this.category,
  });
}
