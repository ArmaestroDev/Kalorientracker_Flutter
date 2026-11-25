import 'package:uuid/uuid.dart';

enum PlanType {
  meal('Ernährungsplan'),
  training('Trainingsplan'),
  combined('Ernährungs- & Trainingsplan');

  final String label;
  const PlanType(this.label);

  static PlanType fromStored(String? value) {
    return values.firstWhere((t) => t.name == value, orElse: () => combined);
  }
}

class UserPlan {
  final String id;
  final PlanType type;
  final String title;
  final String? fileName;
  final String content;
  final bool isActive;
  final DateTime updatedAt;

  UserPlan({
    String? id,
    required this.type,
    required this.title,
    this.fileName,
    required this.content,
    this.isActive = true,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       updatedAt = updatedAt ?? DateTime.now();

  UserPlan copyWith({
    String? id,
    PlanType? type,
    String? title,
    String? fileName,
    String? content,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return UserPlan(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'file_name': fileName,
      'content': content,
      'is_active': isActive ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserPlan.fromMap(Map<String, dynamic> map) {
    final updatedRaw = map['updated_at'] as String?;
    return UserPlan(
      id: map['id'] as String? ?? const Uuid().v4(),
      type: PlanType.fromStored(map['type'] as String?),
      title: map['title'] as String? ?? 'Plan',
      fileName: map['file_name'] as String?,
      content: map['content'] as String? ?? '',
      isActive: ((map['is_active'] as num?)?.toInt() ?? 1) == 1,
      updatedAt: updatedRaw != null
          ? DateTime.tryParse(updatedRaw) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
