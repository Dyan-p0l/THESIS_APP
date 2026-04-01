import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/readings.dart';
import '../models/samples.dart';

class DBhelper {

  static final DBhelper _instance = DBhelper._init();
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
      onOpen: (db) async {
        // Enable foreign key support
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Handle future schema changes here
        // Example:
        // if (oldVersion < 2) {
        //   await db.execute('ALTER TABLE readings ADD COLUMN notes TEXT');
        // }
      },
    );
  }



}