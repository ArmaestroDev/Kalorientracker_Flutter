import '../models/food_entry.dart';
import '../models/activity_entry.dart';
import '../models/food_item.dart';
import '../models/user_plan.dart';
import '../models/weight_entry.dart';
import '../database/dao/log_dao.dart';
import '../database/dao/food_item_dao.dart';
import '../database/dao/plan_dao.dart';

class LogRepository {
  final LogDao _logDao;
  final FoodItemDao _foodItemDao;
  final PlanDao _planDao;

  LogRepository({
    LogDao? logDao,
    FoodItemDao? foodItemDao,
    PlanDao? planDao,
  }) : _logDao = logDao ?? LogDao(),
       _foodItemDao = foodItemDao ?? FoodItemDao(),
       _planDao = planDao ?? PlanDao();

  // Food Entries
  Future<List<FoodEntry>> getFoodEntriesForDate(DateTime date) =>
      _logDao.getFoodEntriesForDate(date);
  Future<List<FoodEntry>> getFoodEntriesForDateRange(
    DateTime start,
    DateTime end,
  ) => _logDao.getFoodEntriesForDateRange(start, end);
  Future<void> addFoodEntry(FoodEntry entry) => _logDao.insertFoodEntry(entry);
  Future<void> updateFoodEntry(FoodEntry entry) =>
      _logDao.updateFoodEntry(entry);
  Future<void> deleteFoodEntry(FoodEntry entry) =>
      _logDao.deleteFoodEntry(entry);

  // Activity Entries
  Future<List<ActivityEntry>> getActivityEntriesForDate(DateTime date) =>
      _logDao.getActivityEntriesForDate(date);
  Future<List<ActivityEntry>> getActivityEntriesForDateRange(
    DateTime start,
    DateTime end,
  ) => _logDao.getActivityEntriesForDateRange(start, end);
  Future<void> addActivityEntry(ActivityEntry entry) =>
      _logDao.insertActivityEntry(entry);
  Future<void> updateActivityEntry(ActivityEntry entry) =>
      _logDao.updateActivityEntry(entry);
  Future<void> deleteActivityEntry(ActivityEntry entry) =>
      _logDao.deleteActivityEntry(entry);

  // Weight Entries
  Future<List<WeightEntry>> getWeightEntriesForDateRange(
    DateTime start,
    DateTime end,
  ) => _logDao.getWeightEntriesForDateRange(start, end);
  Future<void> saveWeightEntry(WeightEntry entry) =>
      _logDao.upsertWeightEntry(entry);
  Future<void> deleteWeightEntry(DateTime date) =>
      _logDao.deleteWeightEntry(date);

  // Food Items (History/Database)
  Future<void> saveFoodItem(FoodItem item) => _foodItemDao.insertOrUpdate(item);
  Future<void> deleteFoodItem(String id) => _foodItemDao.deleteFoodItem(id);
  Future<List<FoodItem>> getRecentFoodItems() => _foodItemDao.getRecents();
  Future<List<FoodItem>> searchFoodItems(String query) =>
      _foodItemDao.searchFoods(query);
  Future<List<String>> getFoodCategories() => _foodItemDao.getAllCategories();
  Future<List<FoodItem>> getFoodItemsByCategory(String category) =>
      _foodItemDao.getByCategory(category);

  // User Plans (Meal & Training PDFs)
  Future<List<UserPlan>> getPlans() => _planDao.getAllPlans();
  Future<void> savePlan(UserPlan plan) => _planDao.upsertPlan(plan);
  Future<void> deletePlan(String id) => _planDao.deletePlan(id);
}
