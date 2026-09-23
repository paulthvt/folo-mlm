/// What just happened to the session, in the app's own vocabulary.
///
/// `supabase_flutter` has a longer list; the router only distinguishes these,
/// and mapping here is what keeps its type out of `presentation`.
enum AuthChange { signedIn, signedOut, passwordRecovery, userUpdated, other }
