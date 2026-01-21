import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite database helper for the Kalorientracker app
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
    final path = join(dbPath, 'calorie_tracker_database.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE food_entries(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein INTEGER NOT NULL,
        carbs INTEGER NOT NULL,
        fat INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_entries(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        caloriesBurned INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    // Create index for faster date queries
    await db.execute('CREATE INDEX idx_food_date ON food_entries(date)');
    await db.execute(
      'CREATE INDEX idx_activity_date ON activity_entries(date)',
    );
  }
}
