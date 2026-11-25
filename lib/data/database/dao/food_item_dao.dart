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

  Future<void> deleteFoodItem(String id) async {
    final db = await _appDatabase.database;
    await db.delete('food_items', where: 'id = ?', whereArgs: [id]);
  }

  static String _escapeLike(String input) => input
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  Future<List<FoodItem>> searchFoods(String query) async {
    final db = await _appDatabase.database;
    final escaped = _escapeLike(query.trim());
    final pattern = '%$escaped%';
    final maps = await db.query(
      'food_items',
      where: "name LIKE ? ESCAPE '\\' OR category LIKE ? ESCAPE '\\'",
      whereArgs: [pattern, pattern],
      orderBy: 'last_used DESC',
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
      "SELECT DISTINCT category FROM food_items WHERE category IS NOT NULL AND category != '' ORDER BY category ASC",
    );
    return result
        .map((row) => row['category'])
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
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
