import 'package:uuid/uuid.dart';

/// Represents an activity entry in the calorie tracker
class ActivityEntry {
  final String id;
  final String name;
  final int caloriesBurned;
  final DateTime date;

  ActivityEntry({
    String? id,
    required this.name,
    required this.caloriesBurned,
    required this.date,
  }) : id = id ?? const Uuid().v4();

  ActivityEntry copyWith({
    String? id,
    String? name,
    int? caloriesBurned,
    DateTime? date,
  }) {
    return ActivityEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      date: date ?? this.date,
    );
  }

  static String _sqlDate(DateTime d) {
    final local = d.isUtc ? d.toLocal() : d;
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'caloriesBurned': caloriesBurned,
      'date': _sqlDate(date),
    };
  }

  factory ActivityEntry.fromMap(Map<String, dynamic> map) {
    final dateRaw = map['date'] as String?;
    return ActivityEntry(
      id: map['id'] as String? ?? const Uuid().v4(),
      name: map['name'] as String? ?? 'Unbekannte Aktivität',
      caloriesBurned: (map['caloriesBurned'] as num?)?.toInt() ?? 0,
      date: dateRaw != null
          ? DateTime.tryParse(dateRaw) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
