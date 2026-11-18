enum Currency {
  inr('INR', '₹', 2, 'en_IN'),
  usd('USD', r'$', 2, 'en_US'),
  eur('EUR', '€', 2, 'en_US'),
  gbp('GBP', '£', 2, 'en_GB'),
  aed('AED', 'AED ', 2, 'en_US'),
  sgd('SGD', r'S$', 2, 'en_US'),
  aud('AUD', r'A$', 2, 'en_US'),
  cad('CAD', r'CA$', 2, 'en_US'),
  jpy('JPY', '¥', 0, 'en_US'),
  cny('CNY', 'CN¥', 2, 'en_US'),
  brl('BRL', r'R$', 2, 'en_US');

  const Currency(this.code, this.symbol, this.decimals, this.locale);

  final String code;
  final String symbol;

  /// Minor-unit digits (ISO 4217). JPY has none.
  final int decimals;
  final String locale;

  static Currency fromCode(String code) => values.firstWhere(
    (c) => c.code == code,
    orElse: () => throw FormatException('Unknown currency: $code'),
  );
}
