import '../domain/currency.dart';

/// Spells an amount the way people say it: Indian units for INR
/// ("5 lakh 55 thousand 5 rupees"), international units for the rest
/// ("1 million 250 thousand dollars and 50 cents").
abstract final class AmountWords {
  static const _indian = [(10000000, 'crore'), (100000, 'lakh'), (1000, 'thousand')];
  static const _international = [
    (1000000000000, 'trillion'),
    (1000000000, 'billion'),
    (1000000, 'million'),
    (1000, 'thousand'),
  ];

  /// (singular, plural) for the main unit and the minor unit.
  static const _names = {
    Currency.inr: (('rupee', 'rupees'), ('paisa', 'paise')),
    Currency.usd: (('dollar', 'dollars'), ('cent', 'cents')),
    Currency.eur: (('euro', 'euros'), ('cent', 'cents')),
    Currency.gbp: (('pound', 'pounds'), ('penny', 'pence')),
    Currency.aed: (('dirham', 'dirhams'), ('fils', 'fils')),
    Currency.sgd: (('Singapore dollar', 'Singapore dollars'), ('cent', 'cents')),
    Currency.aud: (('Australian dollar', 'Australian dollars'), ('cent', 'cents')),
    Currency.cad: (('Canadian dollar', 'Canadian dollars'), ('cent', 'cents')),
    Currency.jpy: (('yen', 'yen'), ('sen', 'sen')),
    Currency.cny: (('yuan', 'yuan'), ('fen', 'fen')),
    Currency.brl: (('real', 'reais'), ('centavo', 'centavos')),
  };

  /// [scaled] is in hundredths, as held by the domain.
  static String of(int scaled, Currency currency) {
    final ((one, many), (minorOne, minorMany)) = _names[currency] ?? (('', ''), ('', ''));
    final whole = scaled.abs() ~/ 100;
    final minor = scaled.abs() % 100;

    final parts = <String>[];
    var rest = whole;
    for (final (size, word) in currency == Currency.inr ? _indian : _international) {
      if (rest >= size) {
        // Indian: anything above 99 crore stays in crores ("120 crore").
        parts.add('${rest ~/ size} $word');
        rest %= size;
      }
    }
    if (rest > 0 || parts.isEmpty) parts.add('$rest');

    final main = '${parts.join(' ')} ${whole == 1 ? one : many}';
    return minor == 0 ? main : '$main and $minor ${minor == 1 ? minorOne : minorMany}';
  }
}
