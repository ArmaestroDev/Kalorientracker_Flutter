/// Parses numbers typed with either a German comma or a dot as decimal separator
double? parseLocalizedNumber(String text) {
  final cleaned = text.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Formats a number with a German decimal comma and without trailing ",0"
String formatLocalizedNumber(double value, {int decimals = 1}) {
  final rounded = double.parse(value.toStringAsFixed(decimals));
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(decimals);
  return text.replaceAll('.', ',');
}
