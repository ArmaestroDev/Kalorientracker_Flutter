import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  factory AppDatabase() => _instance;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kalorientracker.db');

    return await openDatabase(
      path,
      version: 2,
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute("ALTER TABLE food_entries ADD COLUMN amount REAL");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE food_entries ADD COLUMN unit TEXT");
          } catch (_) {}
          try {
            await db.execute(
              "ALTER TABLE food_entries ADD COLUMN food_item_id TEXT",
            );
          } catch (_) {}
          try {
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
          } catch (_) {}
        }
      },
    );
  }
}
