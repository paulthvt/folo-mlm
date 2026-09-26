import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';

/// Busy and failure state for a Settings screen that saves through
/// [AuthRepository]. One action at a time; a failure stays until the next one.
mixin SettingsAction<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;
  AuthFailure? failure;

  Future<void> run(Future<void> Function(AuthRepository auth) action) async {
    if (busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await action(ref.read(authRepositoryProvider));
    } on AuthFailure catch (error) {
      if (mounted) setState(() => failure = error);
    }
    if (mounted) setState(() => busy = false);
  }
}
