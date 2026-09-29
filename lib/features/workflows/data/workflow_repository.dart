import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/core/supabase/supabase_provider.dart';
import 'package:folo/features/contacts/data/people_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `workflow` and `workflow_step` tables. Every method throws
/// [PeopleFailure] and nothing else. RLS scopes everything to the user.
class WorkflowRepository {
  WorkflowRepository(this._client);

  final SupabaseClient _client;

  Future<List<Workflow>> list() => guardPeople(() async {
    final rows = await _client.from('workflow').select('*, workflow_step(*)');
    return rows.map(workflowFromRow).toList();
  });

  /// The default workflows in [lang]; a no-op once the user has any. Also
  /// starts everyone without a workflow on their stage's default.
  Future<void> seed(String lang, DateTime today) => guardPeople(() async {
    await _client.rpc<void>(
      'seed_workflows',
      params: {'p_lang': lang, 'p_today': dayColumn(today)},
    );
  });
}

final workflowRepositoryProvider = Provider<WorkflowRepository>(
  (ref) => WorkflowRepository(ref.watch(supabaseClientProvider)),
);

Workflow workflowFromRow(Map<String, dynamic> row) => Workflow(
  id: row['id'] as String,
  stage:
      Stage.values.asNameMap()[row['stage']] ?? (throw PeopleFailure.unknown),
  name: row['name'] as String,
  isDefault: row['is_default'] as bool,
  steps: [
    for (final step
        in (row['workflow_step'] as List).cast<Map<String, dynamic>>())
      WorkflowStep(
        id: step['id'] as String,
        position: step['position'] as num,
        label: step['label'] as String,
        days: step['days'] as int,
        note: step['note'] as String?,
      ),
  ],
);
