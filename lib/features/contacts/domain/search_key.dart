/// What a name is compared and sorted by: lowercase, accents removed, so
/// "helene" finds "Hélène".
///
/// ponytail: a fold table for Latin letters, no Unicode normalisation package;
/// add one if names in other scripts need accent-insensitive search.
String searchKey(String text) {
  final out = StringBuffer();
  for (final rune in text.trim().toLowerCase().runes) {
    // Combining diacritical marks, when the input arrives decomposed.
    if (rune >= 0x300 && rune <= 0x36f) continue;
    final char = String.fromCharCode(rune);
    out.write(_fold[char] ?? char);
  }
  return out.toString();
}

final Map<String, String> _fold = {
  for (final (from, to) in const [
    ('àáâãäåā', 'a'),
    ('ç', 'c'),
    ('èéêëē', 'e'),
    ('ìíîïī', 'i'),
    ('ñ', 'n'),
    ('òóôõöøō', 'o'),
    ('ùúûüū', 'u'),
    ('ýÿ', 'y'),
  ])
    for (final char in from.split('')) char: to,
  'æ': 'ae',
  'œ': 'oe',
  'ß': 'ss',
};
