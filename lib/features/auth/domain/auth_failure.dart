/// The auth failures a screen can react to differently. Everything else is
/// [unknown] — a longer enum would be a copy list pretending to be a domain.
///
/// Thrown by `AuthRepository`; no `supabase_flutter` type crosses into
/// `presentation`.
enum AuthFailure {
  invalidCredentials,
  emailNotConfirmed,
  rateLimited,
  network,
  unknown,
}
