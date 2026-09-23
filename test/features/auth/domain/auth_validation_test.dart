import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';

void main() {
  group('normalizeEmail', () {
    test('trims surrounding whitespace and lowercases', () {
      expect(normalizeEmail('  Pauline@Example.COM '), 'pauline@example.com');
    });

    test('leaves an already-normal address alone', () {
      expect(normalizeEmail('pauline@example.com'), 'pauline@example.com');
    });
  });

  group('validateEmail', () {
    test('accepts an address with surrounding whitespace', () {
      expect(validateEmail(' pauline@example.com '), isNull);
    });

    test('rejects empty', () {
      expect(validateEmail(''), 'Enter your email address.');
      expect(validateEmail(null), 'Enter your email address.');
    });

    test('rejects a string with no domain', () {
      expect(validateEmail('pauline@'), 'That address does not look right.');
      expect(validateEmail('pauline'), 'That address does not look right.');
      expect(
        validateEmail('a b@example.com'),
        'That address does not look right.',
      );
    });
  });

  group('validatePassword', () {
    test('accepts eight characters', () {
      expect(validatePassword('abcdefgh'), isNull);
    });

    test('rejects seven', () {
      expect(validatePassword('abcdefg'), 'At least 8 characters.');
    });

    test('rejects empty', () {
      expect(validatePassword(''), 'Enter a password.');
    });

    test('does not trim — a space is a character in a password', () {
      expect(validatePassword(' abcdefg'), isNull);
    });
  });

  group('validateFirstName', () {
    test('accepts a name', () => expect(validateFirstName('Pauline'), isNull));

    test('rejects blank and whitespace-only', () {
      expect(validateFirstName(''), 'Enter your first name.');
      expect(validateFirstName('   '), 'Enter your first name.');
    });
  });

  group('validatePasswordConfirmation', () {
    test('accepts a match', () {
      expect(validatePasswordConfirmation('abcdefgh', 'abcdefgh'), isNull);
    });

    test('rejects a mismatch', () {
      expect(
        validatePasswordConfirmation('abcdefgi', 'abcdefgh'),
        'Those passwords do not match.',
      );
    });

    test('rejects empty', () {
      expect(
        validatePasswordConfirmation('', 'abcdefgh'),
        'Confirm your password.',
      );
    });
  });
}
