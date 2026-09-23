/// Pure field validation, shared by every auth form. Each function returns the
/// message to show, or `null` when the value is fine, so it can be passed
/// straight to `TextFormField.validator`.
///
/// Minimum password length is 8 here *and* in the Supabase project settings —
/// the client is not the only gate.
const int minPasswordLength = 8;

/// A typed address differs from the stored one only by case and stray spaces
/// far more often than users notice. Normalise before validating and before
/// every call that carries an email.
String normalizeEmail(String value) => value.trim().toLowerCase();

// Deliberately loose: one run of non-space, an @, a dotted domain. A stricter
// pattern rejects valid addresses, and the real check is the confirmation
// email arriving.
final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String? value) {
  final email = normalizeEmail(value ?? '');
  if (email.isEmpty) return 'Enter your email address.';
  if (!_emailPattern.hasMatch(email)) {
    return 'That address does not look right.';
  }
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Enter a password.';
  if (password.length < minPasswordLength) return 'At least 8 characters.';
  return null;
}

String? validateFirstName(String? value) {
  if ((value ?? '').trim().isEmpty) return 'Enter your first name.';
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if ((value ?? '').isEmpty) return 'Confirm your password.';
  if (value != password) return 'Those passwords do not match.';
  return null;
}
