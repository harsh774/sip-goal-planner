/// Half-up to 2 places, matching the backend's `round_money`. Rounding to
/// 6 places first strips float noise (1.005 * 100 = 100.49999…).
double roundMoney(double value) {
  final cents = (double.parse((value.abs() * 100).toStringAsFixed(6)) + 0.5).floorToDouble();
  return (value < 0 ? -cents : cents) / 100;
}

bool hasCents(double value) => (value * 100).round() % 100 != 0;
