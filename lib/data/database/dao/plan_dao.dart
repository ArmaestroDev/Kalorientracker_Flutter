import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../models/user_plan.dart';

class PlanDao {
  final AppDatabase _appDatabase = AppDatabase();

  Future<List<UserPlan>> getAllPlans() async {
    final db = await _appDatabase.database;
    final maps = await db.query('user_plans', orderBy: 'updated_at DESC');
    return maps.map(UserPlan.fromMap).toList();
  }

  Future<void> upsertPlan(UserPlan plan) async {
    final db = await _appDatabase.database;
    await db.insert(
      'user_plans',
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePlan(String id) async {
    final db = await _appDatabase.database;
    await db.delete('user_plans', where: 'id = ?', whereArgs: [id]);
  }
}
