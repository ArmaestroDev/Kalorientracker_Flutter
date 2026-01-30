import '../models/food_entry.dart';
import '../models/activity_entry.dart';
import '../models/food_item.dart';
import '../database/dao/log_dao.dart';
import '../database/dao/food_item_dao.dart';

class LogRepository {
  final LogDao _logDao = LogDao();
  final FoodItemDao _foodItemDao = FoodItemDao();

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

  // Food Items (History/Database)
  Future<void> saveFoodItem(FoodItem item) => _foodItemDao.insertOrUpdate(item);
  Future<List<FoodItem>> getRecentFoodItems() => _foodItemDao.getRecents();
  Future<List<FoodItem>> searchFoodItems(String query) =>
      _foodItemDao.searchFoods(query);
  Future<List<String>> getFoodCategories() => _foodItemDao.getAllCategories();
  Future<List<FoodItem>> getFoodItemsByCategory(String category) =>
      _foodItemDao.getByCategory(category);
}
