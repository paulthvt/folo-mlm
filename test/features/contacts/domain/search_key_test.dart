import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';

void main() {
  test('lowercases and removes accents', () {
    expect(searchKey('Hélène'), 'helene');
    expect(searchKey('ÉLODIE'), 'elodie');
    expect(searchKey('François Müller'), 'francois muller');
  });

  test('folds ligatures and ß', () {
    expect(searchKey('Œuvre Straße'), 'oeuvre strasse');
  });

  test('strips combining marks from decomposed input', () {
    expect(searchKey('He\u0301le\u0300ne'), 'helene');
  });

  test('trims', () {
    expect(searchKey('  Marie '), 'marie');
  });
}
