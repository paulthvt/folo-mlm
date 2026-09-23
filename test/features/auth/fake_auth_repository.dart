import 'dart:async';

import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_change.dart';

/// Records what a screen asked for, and fails or stalls on demand.
class FakeAuthRepository implements AuthRepository {
  /// One entry per call, e.g. `signIn(pauline@example.com, hunter22)`.
  final List<String> calls = <String>[];

  /// Thrown by the next call when set. Use an [AuthFailure].
  Object? failWith;

  /// When set, calls wait on it — for testing in-flight behaviour.
  Completer<void>? gate;

  bool session = false;

  final StreamController<AuthChange> _changes =
      StreamController<AuthChange>.broadcast();

  void emit(AuthChange change) => _changes.add(change);

  void dispose() => _changes.close();

  @override
  bool get hasSession => session;

  @override
  Stream<AuthChange> get changes => _changes.stream;

  Future<void> _record(String call) async {
    calls.add(call);
    if (gate != null) await gate!.future;
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _record('signIn($email, $password)');

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
  }) => _record('signUp($email, $password, $firstName)');

  @override
  Future<void> signInWithGoogle() => _record('signInWithGoogle()');

  @override
  Future<void> sendPasswordReset(String email) =>
      _record('sendPasswordReset($email)');

  @override
  Future<void> resendConfirmation(String email) =>
      _record('resendConfirmation($email)');

  @override
  Future<void> updatePassword(String password) =>
      _record('updatePassword($password)');

  @override
  Future<void> signOut() => _record('signOut()');
}
