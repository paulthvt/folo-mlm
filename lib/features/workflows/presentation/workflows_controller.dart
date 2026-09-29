import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/workflows/data/workflow_repository.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

/// One account's workflows, `workflowsProvider(account?.email)`. Keyed by
/// account for the same reason as `peopleProvider`. The first load of an
/// account with none seeds the defaults.
///
/// No automatic retry: a failed load shows its error with a Retry button.
final workflowsProvider =
    AsyncNotifierProvider.family<WorkflowsController, List<Workflow>, String?>(
      WorkflowsController.new,
      retry: (error, _) => null,
    );

class WorkflowsController extends AsyncNotifier<List<Workflow>> {
  WorkflowsController(this.owner);

  /// The email of the account; null when signed out.
  final String? owner;

  @override
  Future<List<Workflow>> build() async {
    final repository = ref.watch(workflowRepositoryProvider);
    if (owner == null) return const [];
    final workflows = await repository.list();
    if (workflows.isNotEmpty) return workflows;

    await repository.seed(
      seedLanguage(ref.read(accountProvider)?.locale),
      today(),
    );
    final seeded = await repository.list();
    // The seed started people on a workflow.
    if (ref.mounted) ref.invalidate(peopleProvider(owner));
    return seeded;
  }
}

/// The app's language when the account has none: French or English, the two
/// the defaults are written in. Workflows are never translated afterwards.
String seedLanguage(String? accountLocale) =>
    (accountLocale ?? PlatformDispatcher.instance.locale.languageCode) == 'fr'
    ? 'fr'
    : 'en';
