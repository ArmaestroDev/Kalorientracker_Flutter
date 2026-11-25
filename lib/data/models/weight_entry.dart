/// Body weight measurement for a single day
class WeightEntry {
  final DateTime date;
  final double weightKg;

  const WeightEntry({required this.date, required this.weightKg});

  WeightEntry copyWith({DateTime? date, double? weightKg}) {
    return WeightEntry(
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
    );
  }

  static String _sqlDate(DateTime d) {
    final local = d.isUtc ? d.toLocal() : d;
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {'date': _sqlDate(date), 'weight_kg': weightKg};
  }

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    final dateRaw = map['date'] as String?;
    return WeightEntry(
      date: dateRaw != null
          ? DateTime.tryParse(dateRaw) ?? DateTime.now()
          : DateTime.now(),
      weightKg: (map['weight_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
