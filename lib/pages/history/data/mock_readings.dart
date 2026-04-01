import '../models/reading.dart';

List<Reading> mockReadings = [
  Reading(
    id: "SMP-0001-R03",
    sampleLabel: "Sample_03",
    capacitance: 60,
    timestamp: DateTime(2025, 12, 6, 10, 13),
    category: FreshnessCategory.spoiled,
  ),
  Reading(
    id: "SMP-0001-R02",
    sampleLabel: "Sample_03",
    capacitance: 30,
    timestamp: DateTime(2025, 12, 6, 10, 13),
    category: FreshnessCategory.moderate,
  ),
  Reading(
    id: "SMP-0001-R01",
    sampleLabel: "Sample_03",
    capacitance: 10,
    timestamp: DateTime(2025, 12, 6, 10, 13),
    category: FreshnessCategory.fresh,
  ),
  Reading(
    id: "SMP-0002-R01",
    sampleLabel: "Sample_02",
    capacitance: 20,
    timestamp: DateTime(2025, 12, 5, 10, 13),
    category: FreshnessCategory.moderate,
  ),
];
