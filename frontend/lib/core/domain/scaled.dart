/// Decimal values exchanged with the API as strings ("2500000.50", "12.5"),
/// held in the domain as integers scaled by 100 (hundredths, or basis points
/// for rates). Parsing never goes through `double`, so values stay exact.
abstract final class Scaled {
  static final _pattern = RegExp(r'^(-)?(\d+)(?:\.(\d{1,2}))?$');

  /// Returns null when [value] isn't a number with at most two decimal places.
  static int? tryParse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) return null;
    final whole = int.parse(match.group(2)!);
    final fraction = int.parse((match.group(3) ?? '0').padRight(2, '0'));
    final scaled = whole * 100 + fraction;
    return match.group(1) == null ? scaled : -scaled;
  }

  static int parse(String value) =>
      tryParse(value) ?? (throw FormatException('Not a decimal: $value'));

  static String format(int scaled) {
    final sign = scaled < 0 ? '-' : '';
    final abs = scaled.abs();
    return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  /// Shortest string for form fields: 1250 -> "12.5", 700 -> "7".
  static String formatCompact(int scaled) {
    final text = format(scaled);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static double toDouble(int scaled) => scaled / 100;
}
