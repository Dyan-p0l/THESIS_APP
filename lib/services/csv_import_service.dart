import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../db/dbhelper.dart';
import '../models/readings.dart';
import '../models/samples.dart';

/// Result returned by [CsvImportService.importReadings] so the caller can
/// show a meaningful summary to the user.
class CsvImportResult {
  final int samplesInserted;
  final int readingsInserted;
  final int rowsSkipped;
  final List<String> errors;

  const CsvImportResult({
    required this.samplesInserted,
    required this.readingsInserted,
    required this.rowsSkipped,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() =>
      'Imported $samplesInserted sample(s) and $readingsInserted reading(s). '
      '$rowsSkipped row(s) skipped.';
}

class CsvImportService {
  // Column names as they appear in the CSV header.
  static const _colSampleId = 'sample_id';
  static const _colSampleLabel = 'sample_label';
  static const _colValue = 'capacitance_pf';
  static const _colCarriedOutAt = 'carried_out_at';
  static const _colCategory = 'category';

  static const _requiredColumns = [
    _colSampleId,
    _colSampleLabel,
    _colValue,
    _colCarriedOutAt,
    _colCategory,
  ];

  /// Imports all samples and readings from a CSV asset into SQLite.
  ///
  /// - [assetPath]   : path registered in pubspec.yaml, e.g.
  ///                   `'assets/data/readings_final.csv'`
  /// - [skipIfExists]: when `true`, aborts if the readings table already
  ///                   has any rows — safe for one-time first-launch seeding.
  ///
  /// Duplicate samples (same label) are reused rather than re-inserted.
  /// The original CSV `id` column is ignored; SQLite assigns new IDs so
  /// there are no primary-key conflicts with live data.
  static Future<CsvImportResult> importReadings({
    String assetPath = 'assets/data/readings_final.csv',
    bool skipIfExists = false,
  }) async {
    // ── Guard: skip if table already has data ──────────────────────────────
    if (skipIfExists) {
      final existing = await DBhelper.instance.fetchAllReadings();
      if (existing.isNotEmpty) {
        return const CsvImportResult(
          samplesInserted: 0,
          readingsInserted: 0,
          rowsSkipped: 0,
          errors: [],
        );
      }
    }

    // ── Load asset ─────────────────────────────────────────────────────────
    final raw = await rootBundle.loadString(assetPath);

    // ── Parse CSV ──────────────────────────────────────────────────────────
    // eol: '\n' handles both LF and CRLF because CsvToListConverter strips \r
    final rows = const CsvToListConverter(eol: '\n').convert(raw);
    if (rows.isEmpty) {
      return const CsvImportResult(
        samplesInserted: 0,
        readingsInserted: 0,
        rowsSkipped: 0,
        errors: ['CSV file is empty.'],
      );
    }

    // ── Validate header ────────────────────────────────────────────────────
    final header = rows.first
        .map((e) => e.toString().trim().toLowerCase())
        .toList();

    for (final col in _requiredColumns) {
      if (!header.contains(col)) {
        throw FormatException(
          'CSV is missing required column "$col". '
          'Found: ${header.join(', ')}',
        );
      }
    }

    final iSampleId = header.indexOf(_colSampleId);
    final iSampleLabel = header.indexOf(_colSampleLabel);
    final iValue = header.indexOf(_colValue);
    final iCarriedOutAt = header.indexOf(_colCarriedOutAt);
    final iCategory = header.indexOf(_colCategory);

    // ── Build a sample-label → inserted-DB-id map to avoid duplicates ──────
    // Pre-load any samples that may already exist in the DB.
    final existingSamples = await DBhelper.instance.fetchAllSamples();
    final Map<String, int> labelToDbId = {
      for (final s in existingSamples) s.label: s.id!,
    };

    int samplesInserted = 0;
    int readingsInserted = 0;
    int rowsSkipped = 0;
    final List<String> errors = [];

    // ── Process data rows ──────────────────────────────────────────────────
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      // Skip blank / short rows
      if (row.length < header.length) {
        rowsSkipped++;
        continue;
      }

      final rawValue = row[iValue].toString().trim();
      if (rawValue.isEmpty) {
        rowsSkipped++;
        continue;
      }

      try {
        final sampleLabel = row[iSampleLabel].toString().trim();
        final carriedOutAt = _normaliseTimestamp(
          row[iCarriedOutAt].toString().trim(),
        );
        final value = double.parse(rawValue);
        final category = row[iCategory].toString().trim();

        // ── Upsert sample ──────────────────────────────────────────────────
        int dbSampleId;
        if (labelToDbId.containsKey(sampleLabel)) {
          dbSampleId = labelToDbId[sampleLabel]!;
        } else {
          final newId = await DBhelper.instance.insertSample(
            Sample(
              label: sampleLabel,
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
          labelToDbId[sampleLabel] = newId;
          dbSampleId = newId;
          samplesInserted++;
        }

        // ── Insert reading ─────────────────────────────────────────────────
        // id is intentionally omitted so SQLite auto-increments it.
        await DBhelper.instance.insertReading(
          Reading(
            value: value,
            carriedOutAt: carriedOutAt,
            isSaved: true, // imported data is treated as saved
            category: category,
            sampleId: dbSampleId,
          ),
        );
        readingsInserted++;
      } catch (e) {
        final msg = 'Row $i skipped: $e  →  $row';
        errors.add(msg);
        rowsSkipped++;
        // ignore: avoid_print
        print('[CsvImport] $msg');
      }
    }

    return CsvImportResult(
      samplesInserted: samplesInserted,
      readingsInserted: readingsInserted,
      rowsSkipped: rowsSkipped,
      errors: errors,
    );
  }

  /// Normalises the two timestamp formats found in the CSV:
  ///   `2026-04-11 08:31:36.922829`  (space separator)
  ///   `2026-04-16T11:33:25.907839`  (T separator)
  /// Both are converted to the ISO-8601 form your app already uses:
  ///   `2026-04-11T08:31:36.922829`
  static String _normaliseTimestamp(String raw) {
    // Replace the first space between date and time with 'T' if needed.
    // e.g. "2026-04-11 08:31:36.922829" → "2026-04-11T08:31:36.922829"
    final normalised = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');

    // Validate it actually parses — throws FormatException on bad data.
    DateTime.parse(normalised);

    return normalised;
  }
}
