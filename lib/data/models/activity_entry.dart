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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'caloriesBurned': caloriesBurned,
      'date': date.toIso8601String().split('T')[0],
    };
  }

  factory ActivityEntry.fromMap(Map<String, dynamic> map) {
    return ActivityEntry(
      id: map['id'] as String? ?? const Uuid().v4(),
      name: map['name'] as String? ?? 'Unbekannte Aktivität',
      caloriesBurned: map['caloriesBurned'] as int? ?? 0,
      date: map['date'] != null
          ? DateTime.parse(map['date'] as String)
          : DateTime.now(),
    );
  }
}
