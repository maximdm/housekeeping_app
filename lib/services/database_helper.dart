import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;
    _database = await _initDatabase();
  }

  static Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    await init();
    return _database;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'housekeeping.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE rooms_cache ADD COLUMN description TEXT');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE floors_cache ALTER COLUMN number TEXT");
        await db.execute("ALTER TABLE rooms_cache ALTER COLUMN floor_number TEXT");
      } catch (_) {}
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE rooms_cache (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        room_type_id TEXT NOT NULL,
        floor_id TEXT NOT NULL,
        status TEXT NOT NULL,
        description TEXT,
        room_type_name TEXT,
        floor_name TEXT,
        floor_number TEXT,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE room_types_cache (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE floors_cache (
        id TEXT PRIMARY KEY,
        number INTEGER NOT NULL,
        name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_cache (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        sender_name TEXT,
        sender_role TEXT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
