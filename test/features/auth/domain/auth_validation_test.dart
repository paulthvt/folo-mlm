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
      expect(validateEmail(''), EmailProblem.empty);
      expect(validateEmail(null), EmailProblem.empty);
    });

    test('rejects a string with no domain', () {
      expect(validateEmail('pauline@'), EmailProblem.malformed);
      expect(validateEmail('pauline'), EmailProblem.malformed);
      expect(validateEmail('a b@example.com'), EmailProblem.malformed);
    });
  });

  group('validatePassword', () {
    test('accepts eight characters', () {
      expect(validatePassword('abcdefgh'), isNull);
    });

    test('rejects seven', () {
      expect(validatePassword('abcdefg'), PasswordProblem.tooShort);
    });

    test('rejects empty', () {
      expect(validatePassword(''), PasswordProblem.empty);
    });

    test('does not trim \u2014 a space is a character in a password', () {
      expect(validatePassword(' abcdefg'), isNull);
    });
  });

  group('validateFirstName', () {
    test('accepts a name', () => expect(validateFirstName('Pauline'), isNull));

    test('rejects blank and whitespace-only', () {
      expect(validateFirstName(''), FirstNameProblem.empty);
      expect(validateFirstName('   '), FirstNameProblem.empty);
    });
  });

  group('validatePasswordConfirmation', () {
    test('accepts a match', () {
      expect(validatePasswordConfirmation('abcdefgh', 'abcdefgh'), isNull);
    });

    test('rejects a mismatch', () {
      expect(
        validatePasswordConfirmation('abcdefgi', 'abcdefgh'),
        PasswordConfirmationProblem.mismatch,
      );
    });

    test('rejects empty', () {
      expect(
        validatePasswordConfirmation('', 'abcdefgh'),
        PasswordConfirmationProblem.empty,
      );
    });
  });
}
