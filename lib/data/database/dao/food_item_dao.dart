import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../models/food_item.dart';

/// Data Access Object for food items (local database)
class FoodItemDao {
  final AppDatabase _appDatabase = AppDatabase();

  Future<void> insertOrUpdate(FoodItem item) async {
    final db = await _appDatabase.database;
    await db.insert(
      'food_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FoodItem>> searchFoods(String query) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'food_items',
      where: 'name LIKE ? OR category LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'last_used DESC', // Most recent first
      limit: 50,
    );
    return maps.map((map) => FoodItem.fromMap(map)).toList();
  }

  Future<List<FoodItem>> getRecents({int limit = 20}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'food_items',
      orderBy: 'last_used DESC',
      limit: limit,
    );
    return maps.map((map) => FoodItem.fromMap(map)).toList();
  }

  Future<List<String>> getAllCategories() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM food_items ORDER BY category ASC',
    );
    return result
        .map((row) => row['category'] as String)
        .where((c) => c.isNotEmpty)
        .toList();
  }

  Future<List<FoodItem>> getByCategory(String category) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'food_items',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name ASC',
    );
    return maps.map((map) => FoodItem.fromMap(map)).toList();
  }
}
