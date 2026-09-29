import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/workflows/data/workflow_repository.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

/// One account's workflows, `workflowsProvider(account?.email)`. Keyed by
/// account for the same reason as `peopleProvider`. Every load asks the server
/// to seed; it does so once per account, ever.
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
    // The server seeds an account once, ever, and no-ops after, even when
    // every workflow has since been deleted. A notifier does not outlive a
    // rebuild, so the device cannot remember having asked.
    await repository.seed(
      seedLanguage(ref.read(accountProvider)?.locale),
      today(),
    );
    final workflows = await repository.list();
    // A first seed started people on a workflow, and an edit (see [edit]) may
    // have moved their current step or due day.
    // ponytail: people reload on every workflows load; have seed_workflows
    // return whether it seeded if that extra request ever matters.
    if (ref.mounted) ref.invalidate(peopleProvider(owner));
    return workflows;
  }

  /// Runs [write], then reloads: the workflows, and through [build] the
  /// people, whose current step and due day the server may now compute
  /// differently. Rethrows the write's `PeopleFailure`. Nothing is
  /// optimistic: screens show the saved state until the reload lands.
  Future<T> edit<T>(
    Future<T> Function(WorkflowRepository repository) write,
  ) async {
    final result = await write(ref.read(workflowRepositoryProvider));
    if (ref.mounted) ref.invalidateSelf();
    return result;
  }
}

/// The app's language when the account has none: French or English, the two
/// the defaults are written in. Workflows are never translated afterwards.
String seedLanguage(String? accountLocale) =>
    (accountLocale ?? PlatformDispatcher.instance.locale.languageCode) == 'fr'
    ? 'fr'
    : 'en';

/// [WorkflowsController.edit] on the signed-in account's workflows, read at
/// call time: a notifier does not outlive a rebuild.
Future<T> editWorkflows<T>(
  WidgetRef ref,
  Future<T> Function(WorkflowRepository repository) write,
) => ref
    .read(workflowsProvider(ref.read(accountProvider)?.email).notifier)
    .edit(write);
