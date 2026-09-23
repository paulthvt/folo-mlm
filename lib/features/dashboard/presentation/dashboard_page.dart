import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';

/// Temporary entry screen. The real "What should I do today?" dashboard is
/// built in a later step; this exists so the router has a signed-in
/// destination, and so there is somewhere to sign out from.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            // The router sends the user to /welcome as soon as the session
            // goes; a failure here leaves them signed in, which is the safe
            // outcome and needs no screen state.
            onPressed: () => ref
                .read(authRepositoryProvider)
                .signOut()
                .onError<AuthFailure>((error, stack) {}),
          ),
        ],
      ),
      body: Center(
        child: Text('Folo', style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}
