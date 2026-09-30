/// Everything a people call can fail with. Screens react to exactly these two,
/// as they do to `AuthFailure`.
enum PeopleFailure implements Exception { network, unknown }
