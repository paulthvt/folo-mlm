/// Pure field validation, shared by every auth form. Each function returns what
/// is wrong with the value, or `null` when it is fine. Copy lives in the
/// presentation layer (`auth_validation_copy.dart`) so this layer stays
/// language-free.
///
/// Minimum password length is 8 here *and* in the Supabase project settings —
/// the client is not the only gate.
const int minPasswordLength = 8;

enum EmailProblem { empty, malformed }

enum PasswordProblem { empty, tooShort }

enum FirstNameProblem { empty }

enum PasswordConfirmationProblem { empty, mismatch }

/// A typed address differs from the stored one only by case and stray spaces
/// far more often than users notice. Normalise before validating and before
/// every call that carries an email.
String normalizeEmail(String value) => value.trim().toLowerCase();

// Deliberately loose: one run of non-space, an @, a dotted domain. A stricter
// pattern rejects valid addresses, and the real check is the confirmation
// email arriving.
final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

EmailProblem? validateEmail(String? value) {
  final email = normalizeEmail(value ?? '');
  if (email.isEmpty) return EmailProblem.empty;
  if (!_emailPattern.hasMatch(email)) return EmailProblem.malformed;
  return null;
}

PasswordProblem? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return PasswordProblem.empty;
  if (password.length < minPasswordLength) return PasswordProblem.tooShort;
  return null;
}

FirstNameProblem? validateFirstName(String? value) {
  if ((value ?? '').trim().isEmpty) return FirstNameProblem.empty;
  return null;
}

PasswordConfirmationProblem? validatePasswordConfirmation(
  String? value,
  String password,
) {
  if ((value ?? '').isEmpty) return PasswordConfirmationProblem.empty;
  if (value != password) return PasswordConfirmationProblem.mismatch;
  return null;
}
