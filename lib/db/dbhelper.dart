import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/readings.dart';
import '../models/samples.dart';

class DBhelper {

  static final DBhelper instance = DBhelper._init();
  static Database? _database;

  DBhelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,       // ← add this
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // future schema changes go here
      },
    );
  }

  // CREATE TABLE
  Future _createDB(Database db, int version) async {

    await db.execute('''
      CREATE TABLE samples (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        label       TEXT    NOT NULL,
        created_at  TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE readings (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        sample_id      INTEGER,
        value          REAL    NOT NULL,
        carried_out_at TEXT    NOT NULL,
        is_saved       INTEGER NOT NULL DEFAULT 0,
        category       TEXT,
        FOREIGN KEY (sample_id) REFERENCES samples (id)
      )
    ''');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SAMPLE OPERATIONS
  // ───────────────────────────────────────────────────────────────────────────

  // CREATE
  Future<int> insertSample(Sample sample) async {
    final db = await database;
    return await db.insert('samples', sample.toMap());
  }

  // READ ALL
  Future<List<Sample>> fetchAllSamples() async {
    final db = await database;
    final result = await db.query(
      'samples',
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Sample.fromMap(map)).toList();
  }

  // READ ONE
  Future<Sample?> fetchSampleById(int id) async {
    final db = await database;
    final result = await db.query(
      'samples',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? Sample.fromMap(result.first) : null;
  }

  // UPDATE
  Future<int> updateSample(Sample sample) async {
    final db = await database;
    return await db.update(
      'samples',
      sample.toMap(),
      where: 'id = ?',
      whereArgs: [sample.id],
    );
  }

  // DELETE sample and all its readings
  Future<void> deleteSample(int sampleId) async {
    final db = await database;
    // delete readings first (child), then sample (parent)
    await db.delete('readings', where: 'sample_id = ?', whereArgs: [sampleId]);
    await db.delete('samples', where: 'id = ?', whereArgs: [sampleId]);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // READING OPERATIONS
  // ───────────────────────────────────────────────────────────────────────────

  // CREATE
  Future<int> insertReading(Reading reading) async {
    final db = await database;
    return await db.insert('readings', reading.toMap());
  }

  // READ ALL — for History screen (all readings)
  Future<List<Reading>> fetchAllReadings() async {
    final db = await database;
    final result = await db.query(
      'readings',
      orderBy: 'carried_out_at DESC',
    );
    return result.map((map) => Reading.fromMap(map)).toList();
  }

  // READ BY SAMPLE — for Samples screen
  Future<List<Reading>> fetchReadingsBySample(int sampleId) async {
    final db = await database;
    final result = await db.query(
      'readings',
      where: 'sample_id = ?',
      whereArgs: [sampleId],
      orderBy: 'carried_out_at DESC',
    );
    return result.map((map) => Reading.fromMap(map)).toList();
  }

  // READ UNSAVED — history only readings
  Future<List<Reading>> fetchUnsavedReadings() async {
    final db = await database;
    final result = await db.query(
      'readings',
      where: 'is_saved = 0',
      orderBy: 'carried_out_at DESC',
    );
    return result.map((map) => Reading.fromMap(map)).toList();
  }

  // UPDATE — save a reading to a sample
  Future<int> saveReadingToSample(int readingId, int sampleId) async {
    final db = await database;
    return await db.update(
      'readings',
      {
        'sample_id': sampleId,
        'is_saved': 1,
      },
      where: 'id = ?',
      whereArgs: [readingId],
    );
  }

  // UPDATE — general reading update
  Future<int> updateReading(Reading reading) async {
    final db = await database;
    return await db.update(
      'readings',
      reading.toMap(),
      where: 'id = ?',
      whereArgs: [reading.id],
    );
  }


  // ── AUTO DELETE — configurable retention window ───────────────────────────
 
  /// Deletes unsaved readings older than [retentionDays] days.
  /// Default is 2 days to match the original hard-coded behaviour.
  Future<void> deleteOldUnsavedReadings({int retentionDays = 2}) async {
    final db = await database;
 
    final cutoff = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .toIso8601String();
 
    await db.delete(
      'readings',
      where: 'carried_out_at < ? AND is_saved = 0',
      whereArgs: [cutoff],
    );
  }
 
  /// Persists the user's chosen retention setting so it survives restarts.
  /// Uses a lightweight key-value table; create it once in _createDB:
  ///
  ///   await db.execute('''
  ///     CREATE TABLE IF NOT EXISTS settings (
  ///       key   TEXT PRIMARY KEY,
  ///       value TEXT NOT NULL
  ///     )
  ///   ''');
  Future<void> setUnsavedReadingsRetentionDays(int days) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': 'unsaved_retention_days', 'value': days.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
 
  /// Reads back the persisted retention setting (defaults to 2 if never set).
  Future<int> getUnsavedReadingsRetentionDays() async {
    final db = await database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['unsaved_retention_days'],
    );
    if (result.isEmpty) return 2;
    return int.tryParse(result.first['value'] as String) ?? 2;
  }

  // DELETE — single reading
  Future<int> deleteReading(int id) async {
    final db = await database;
    return await db.delete(
      'readings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // AUTO DELETE — History cleanup
  // ───────────────────────────────────────────────────────────────────────────

  // ───────────────────────────────────────────────────────────────────────────
  // CLOSE
  // ───────────────────────────────────────────────────────────────────────────

  Future close() async {
    final db = await database;
    db.close();
  }

}