import '../database/dao/log_dao.dart';
import '../models/food_entry.dart';
import '../models/activity_entry.dart';

/// Repository for managing food and activity log entries
class LogRepository {
  final LogDao _logDao = LogDao();

  Future<List<FoodEntry>> getFoodEntriesForDate(DateTime date) {
    return _logDao.getFoodEntriesForDate(date);
  }

  Future<List<ActivityEntry>> getActivityEntriesForDate(DateTime date) {
    return _logDao.getActivityEntriesForDate(date);
  }

  Future<void> addFoodEntry(FoodEntry entry) {
    return _logDao.insertFoodEntry(entry);
  }

  Future<void> addActivityEntry(ActivityEntry entry) {
    return _logDao.insertActivityEntry(entry);
  }

  Future<void> updateFoodEntry(FoodEntry entry) {
    return _logDao.updateFoodEntry(entry);
  }

  Future<void> updateActivityEntry(ActivityEntry entry) {
    return _logDao.updateActivityEntry(entry);
  }

  Future<void> deleteFoodEntry(FoodEntry entry) {
    return _logDao.deleteFoodEntry(entry);
  }

  Future<void> deleteActivityEntry(ActivityEntry entry) {
    return _logDao.deleteActivityEntry(entry);
  }
}
