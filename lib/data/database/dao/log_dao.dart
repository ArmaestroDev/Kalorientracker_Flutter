import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../models/food_entry.dart';
import '../../models/activity_entry.dart';

/// Data Access Object for food and activity entries
class LogDao {
  final AppDatabase _appDatabase = AppDatabase();

  // Food Entry operations

  Future<List<FoodEntry>> getFoodEntriesForDate(DateTime date) async {
    final db = await _appDatabase.database;
    final dateString = date.toIso8601String().split('T')[0];

    final maps = await db.query(
      'food_entries',
      where: 'date = ?',
      whereArgs: [dateString],
    );

    return maps.map((map) => FoodEntry.fromMap(map)).toList();
  }

  Future<List<FoodEntry>> getFoodEntriesForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _appDatabase.database;
    final startString = start.toIso8601String().split('T')[0];
    final endString = end.toIso8601String().split('T')[0];

    final maps = await db.query(
      'food_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startString, endString],
      orderBy: 'date ASC',
    );

    return maps.map((map) => FoodEntry.fromMap(map)).toList();
  }

  Future<void> insertFoodEntry(FoodEntry entry) async {
    final db = await _appDatabase.database;
    await db.insert(
      'food_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateFoodEntry(FoodEntry entry) async {
    final db = await _appDatabase.database;
    await db.update(
      'food_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteFoodEntry(FoodEntry entry) async {
    final db = await _appDatabase.database;
    await db.delete('food_entries', where: 'id = ?', whereArgs: [entry.id]);
  }

  // Activity Entry operations

  Future<List<ActivityEntry>> getActivityEntriesForDate(DateTime date) async {
    final db = await _appDatabase.database;
    final dateString = date.toIso8601String().split('T')[0];

    final maps = await db.query(
      'activity_entries',
      where: 'date = ?',
      whereArgs: [dateString],
    );

    return maps.map((map) => ActivityEntry.fromMap(map)).toList();
  }

  Future<List<ActivityEntry>> getActivityEntriesForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _appDatabase.database;
    final startString = start.toIso8601String().split('T')[0];
    final endString = end.toIso8601String().split('T')[0];

    final maps = await db.query(
      'activity_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startString, endString],
      orderBy: 'date ASC',
    );

    return maps.map((map) => ActivityEntry.fromMap(map)).toList();
  }

  Future<void> insertActivityEntry(ActivityEntry entry) async {
    final db = await _appDatabase.database;
    await db.insert(
      'activity_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateActivityEntry(ActivityEntry entry) async {
    final db = await _appDatabase.database;
    await db.update(
      'activity_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteActivityEntry(ActivityEntry entry) async {
    final db = await _appDatabase.database;
    await db.delete('activity_entries', where: 'id = ?', whereArgs: [entry.id]);
  }
}
