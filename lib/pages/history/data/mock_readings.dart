import '../models/reading.dart';

List<Reading> mockReadings = [
  Reading(
    id: "SMP-0001-R03",
    sampleLabel: "Sample_01",
    capacitance: 65,
    timestamp: DateTime(2025, 12, 6, 16, 00),
    category: FreshnessCategory.spoiled,
  ),
  Reading(
    id: "SMP-0001-R02",
    sampleLabel: "Sample_01",
    capacitance: 30,
    timestamp: DateTime(2025, 12, 6, 8, 13),
    category: FreshnessCategory.moderate,
  ),
  Reading(
    id: "SMP-0001-R01",
    sampleLabel: "Sample_01",
    capacitance: 10,
    timestamp: DateTime(2025, 12, 6, 4, 13),
    category: FreshnessCategory.fresh,
  ),
  Reading(
    id: "SMP-0002-R01",
    sampleLabel: "Sample_02",
    capacitance: 20,
    timestamp: DateTime(2025, 12, 5, 16, 13),
    category: FreshnessCategory.moderate,
  ),

  Reading(
    id: "SMP-0001-R03",
    sampleLabel: "Sample_01",
    capacitance: 60,
    timestamp: DateTime(2025, 12, 6, 12, 0), // 12:00 PM
    category: FreshnessCategory.spoiled,
  ),

  Reading(
    id: "SMP-0003-R01",
    sampleLabel: "Sample_03",
    capacitance: 10,
    timestamp: DateTime(2025, 12, 6, 4, 0), // 12:00 PM
    category: FreshnessCategory.fresh,
  ),

  Reading(
    id: "SMP-0003-R02",
    sampleLabel: "Sample_03",
    capacitance: 18,
    timestamp: DateTime(2025, 12, 6, 8, 0), // 12:00 PM
    category: FreshnessCategory.fresh,
  ),

  Reading(
    id: "SMP-0003-R03",
    sampleLabel: "Sample_03",
    capacitance: 25,
    timestamp: DateTime(2025, 12, 6, 12, 0), // 12:00 PM
    category: FreshnessCategory.moderate,
  ),

  Reading(
    id: "SMP-0003-R04",
    sampleLabel: "Sample_03",
    capacitance: 30,
    timestamp: DateTime(2025, 12, 6, 16, 0), // 12:00 PM
    category: FreshnessCategory.moderate,
  ),

  Reading(
    id: "SMP-0003-R05",
    sampleLabel: "Sample_03",
    capacitance: 50,
    timestamp: DateTime(2025, 12, 6, 20, 0), // 12:00 PM
    category: FreshnessCategory.spoiled,
  ),

  Reading(
    id: "SMP-0003-R05",
    sampleLabel: "Sample_03",
    capacitance: 7,
    timestamp: DateTime(2025, 12, 6, 0, 0), // 12:00 PM
    category: FreshnessCategory.fresh,
  ),
];
