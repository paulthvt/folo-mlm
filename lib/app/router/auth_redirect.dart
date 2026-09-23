import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_change.dart';

/// The whole guard, as a pure function of three facts — which is why it is
/// testable without a router, a widget tree or a client.
String? authRedirect({
  required bool hasSession,
  required bool recoveringPassword,
  required String location,
}) {
  // Recovery outranks everything: the link signs the user in before they choose
  // the new password, so "has a session" must not send them to Today.
  if (recoveringPassword) {
    return location == Routes.resetPassword ? null : Routes.resetPassword;
  }
  if (location == Routes.resetPassword) {
    return hasSession ? null : Routes.welcome;
  }
  final isAuthRoute = Routes.authPaths.contains(location);
  if (!hasSession) return isAuthRoute ? null : Routes.welcome;
  return isAuthRoute ? Routes.today : null;
}

/// The two pieces of session state the router needs, as a `Listenable` so
/// `GoRouter.refreshListenable` can re-run the redirect.
class AuthStatus extends ChangeNotifier {
  AuthStatus(AuthRepository repository) : _hasSession = repository.hasSession {
    _subscription = repository.changes.listen(_apply);
  }

  bool _hasSession;
  bool _recoveringPassword = false;
  late final StreamSubscription<AuthChange> _subscription;

  bool get hasSession => _hasSession;
  bool get recoveringPassword => _recoveringPassword;

  void _apply(AuthChange change) {
    switch (change) {
      case AuthChange.signedIn:
        _hasSession = true;
      case AuthChange.passwordRecovery:
        _hasSession = true;
        _recoveringPassword = true;
      case AuthChange.userUpdated:
        // The new password has been saved, so recovery is over.
        _recoveringPassword = false;
      case AuthChange.signedOut:
        _hasSession = false;
        _recoveringPassword = false;
      case AuthChange.other:
        return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final authStatusProvider = Provider<AuthStatus>((ref) {
  final status = AuthStatus(ref.watch(authRepositoryProvider));
  ref.onDispose(status.dispose);
  return status;
});
