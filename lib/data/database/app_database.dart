import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;
  static Future<Database>? _openFuture;

  factory AppDatabase() => _instance;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _openFuture ??= _initDatabase().then((db) {
      _database = db;
      return db;
    });
    try {
      return await _openFuture!;
    } catch (_) {
      _openFuture = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kalorientracker.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE food_entries(
            id TEXT PRIMARY KEY,
            name TEXT,
            calories INTEGER,
            protein INTEGER,
            carbs INTEGER,
            fat INTEGER,
            date TEXT,
            amount REAL,
            unit TEXT,
            food_item_id TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE activity_entries(
            id TEXT PRIMARY KEY,
            name TEXT,
            caloriesBurned INTEGER,
            date TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE food_items(
            id TEXT PRIMARY KEY,
            name TEXT,
            category TEXT,
            calories_per_100g REAL,
            protein_per_100g REAL,
            carbs_per_100g REAL,
            fat_per_100g REAL,
            default_unit TEXT,
            last_used TEXT
          )
        ''');
        await _createWeightTable(db);
        await _createPlansTable(db);
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final cols = await db.rawQuery('PRAGMA table_info(food_entries)');
          final existing = cols.map((c) => c['name'] as String?).toSet();
          if (!existing.contains('amount')) {
            await db.execute('ALTER TABLE food_entries ADD COLUMN amount REAL');
          }
          if (!existing.contains('unit')) {
            await db.execute('ALTER TABLE food_entries ADD COLUMN unit TEXT');
          }
          if (!existing.contains('food_item_id')) {
            await db.execute(
              'ALTER TABLE food_entries ADD COLUMN food_item_id TEXT',
            );
          }
          await db.execute('''
            CREATE TABLE IF NOT EXISTS food_items(
              id TEXT PRIMARY KEY,
              name TEXT,
              category TEXT,
              calories_per_100g REAL,
              protein_per_100g REAL,
              carbs_per_100g REAL,
              fat_per_100g REAL,
              default_unit TEXT,
              last_used TEXT
            )
          ''');
        }
        if (oldVersion < 3) {
          await _createWeightTable(db);
        }
        if (oldVersion < 4) {
          await _createPlansTable(db);
          await _createIndexes(db);
        }
      },
    );
  }

  Future<void> _createWeightTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weight_entries(
        date TEXT PRIMARY KEY,
        weight_kg REAL NOT NULL
      )
    ''');
  }

  Future<void> _createPlansTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_plans(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        file_name TEXT,
        content TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_food_entries_date ON food_entries(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activity_entries_date ON activity_entries(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_food_items_last_used ON food_items(last_used)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_food_items_category ON food_items(category)',
    );
  }
}
