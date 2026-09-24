import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/core/supabase/supabase_config.dart';
import 'package:folo/core/supabase/supabase_provider.dart';
import 'package:folo/features/auth/data/auth_failure_mapping.dart';
import 'package:folo/features/auth/domain/auth_change.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The only file in the app that imports `supabase_flutter`.
///
/// Every method throws [AuthFailure] and nothing else, so screens never see a
/// `supabase_flutter` type. Callers pass an already-normalised email
/// (`normalizeEmail`).
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// On web the browser already knows where it came from; the custom scheme is
  /// for Android and iOS only.
  String? get _redirect => kIsWeb ? null : SupabaseConfig.redirectUrl;

  bool get hasSession => _auth.currentSession != null;

  Stream<AuthChange> get changes => _auth.onAuthStateChange.map((state) {
    final change = switch (state.event) {
      AuthChangeEvent.signedIn => AuthChange.signedIn,
      AuthChangeEvent.signedOut => AuthChange.signedOut,
      AuthChangeEvent.passwordRecovery => AuthChange.passwordRecovery,
      AuthChangeEvent.userUpdated => AuthChange.userUpdated,
      _ => AuthChange.other,
    };
    if (change == AuthChange.signedIn) _backfillFirstName(state.session?.user);
    return change;
  });

  /// Google and Apple return a name; keep it where the email flow puts it, so
  /// the greeting has one place to read from. Best effort — a failure here must
  /// never block a sign-in.
  void _backfillFirstName(User? user) {
    if (user == null) return;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final existing = (metadata['first_name'] as String?)?.trim() ?? '';
    if (existing.isNotEmpty) return;
    final full =
        (metadata['full_name'] as String? ?? metadata['name'] as String? ?? '')
            .trim();
    if (full.isEmpty) return;
    final first = full.split(' ').first;
    _auth.updateUser(UserAttributes(data: {'first_name': first})).ignore();
  }

  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithPassword(email: email, password: password));

  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
  }) => _guard(
    () => _auth.signUp(
      email: email,
      password: password,
      data: {'first_name': firstName.trim()},
      emailRedirectTo: _redirect,
    ),
  );

  /// Apple is the other provider the product wants; it needs a paid Apple
  /// Developer account, so it is not wired up yet (issue #22).
  Future<void> signInWithGoogle() => _guard(
    () => _auth.signInWithOAuth(OAuthProvider.google, redirectTo: _redirect),
  );

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email, redirectTo: _redirect));

  Future<void> resendConfirmation(String email) => _guard(
    () => _auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: _redirect,
    ),
  );

  Future<void> updatePassword(String password) =>
      _guard(() => _auth.updateUser(UserAttributes(password: password)));

  Future<void> signOut() => _guard(_auth.signOut);

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (error) {
      throw authFailureFrom(error);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
