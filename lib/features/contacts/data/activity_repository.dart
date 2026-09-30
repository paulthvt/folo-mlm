import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `activity` table: every person's history. Every method throws
/// [PeopleFailure] and nothing else.
///
/// RLS scopes every query to the signed-in user and refuses stage entries,
/// which only the database writes.
class ActivityRepository {
  ActivityRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'activity';

  /// Unordered: the controller sorts by the local day, which the server
  /// doesn't know.
  // ponytail: whole history in one fetch, paginate when a person has hundreds.
  Future<List<Activity>> list(String personId) => guardPeople(() async {
    final rows = await _client.from(_table).select().eq('person_id', personId);
    return rows.map(activityFromRow).toList();
  });

  Future<Activity> add(String personId, ActivityDraft draft) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .insert(activityDraftToRow(personId, draft))
            .select()
            .single();
        return activityFromRow(row);
      });

  Future<void> delete(String id) =>
      guardPeople(() => _client.from(_table).delete().eq('id', id));
}

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(supabaseClientProvider)),
);

Activity activityFromRow(Map<String, dynamic> row) {
  final stage = row['stage'] as String?;
  return Activity(
    id: row['id'] as String,
    personId: row['person_id'] as String,
    kind:
        ActivityKind.values.asNameMap()[row['kind']] ??
        (throw PeopleFailure.unknown),
    // A bare date parses as local midnight, which is what a day is here.
    happenedOn: DateTime.parse(row['happened_on'] as String),
    text: row['text'] as String?,
    stage: stage == null
        ? null
        : Stage.values.asNameMap()[stage] ?? (throw PeopleFailure.unknown),
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

Map<String, dynamic> activityDraftToRow(String personId, ActivityDraft draft) {
  assert(
    draft.kind.byUser,
    'Only the database writes stage entries; step entries come from complete_step',
  );
  return {
    'person_id': personId,
    'kind': draft.kind.name,
    'happened_on': dayColumn(draft.happenedOn),
    'text': draft.text.trim(),
  };
}
