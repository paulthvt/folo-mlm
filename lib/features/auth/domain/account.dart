/// The signed-in user, as the app sees them. No `supabase_flutter` type, so
/// screens and tests build one directly.
class Account {
  const Account({required this.firstName, required this.email, this.locale});

  /// Empty when the user never gave one (an email sign-up always does).
  final String firstName;
  final String email;

  /// A language code the user chose in Settings, or null to follow the system.
  final String? locale;

  /// What to show where a name is expected: the first name, else the email.
  String get displayName => firstName.isEmpty ? email : firstName;
}
