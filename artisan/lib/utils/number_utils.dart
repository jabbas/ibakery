/// Parses a number string, accepting both comma and dot as decimal separator
double? parseNumber(String? value) {
  if (value == null || value.isEmpty) return null;
  return double.tryParse(value.replaceAll(',', '.'));
}

/// Parses a number string with a default value
double parseNumberOr(String? value, double defaultValue) {
  return parseNumber(value) ?? defaultValue;
}

/// Parses and rounds to 2 decimal places (for quantities/prices)
double parseNumberRounded(String? value, double defaultValue) {
  final num = parseNumber(value) ?? defaultValue;
  return (num * 100).round() / 100;
}

/// Formats a number for display
String formatNum(dynamic value, [int decimals = 4]) {
  final num = double.tryParse(value?.toString() ?? '0') ?? 0;
  return num.toStringAsFixed(decimals);
}
