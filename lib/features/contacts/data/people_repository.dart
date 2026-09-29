import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/core/supabase/supabase_provider.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `person` table. Every method throws [PeopleFailure] and nothing else, so
/// screens never see a `supabase_flutter` type.
///
/// RLS scopes every query to the signed-in user, and `owner_id` defaults to
/// them on insert, so no call here names an owner.
class PeopleRepository {
  PeopleRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'person';

  /// Unordered: the controller sorts by `searchKey`, which Postgres collation
  /// does not match.
  Future<List<Person>> list() => guardPeople(() async {
    final rows = await _client.from(_table).select();
    return rows.map(personFromRow).toList();
  });

  Future<Person> add(PersonDraft draft, {WorkflowPlace? place}) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .insert({...draftToRow(draft), ...placeToRow(place)})
            .select()
            .single();
        return personFromRow(row);
      });

  Future<Person> update(Person person) =>
      _write(person.id, personToRow(person));

  Future<void> delete(String id) =>
      guardPeople(() => _client.from(_table).delete().eq('id', id));

  /// Writes the stage and the workflow that follows it, in one update; a null
  /// [place] is "nothing for now". The database sets [Person.stageSince],
  /// clears a leaving prospect's status and any pause, and records the change
  /// in the history; the returned person is the row as it left it.
  Future<Person> setStage(String id, Stage stage, {WorkflowPlace? place}) =>
      _write(id, {'stage': stage.name, ...placeToRow(place)});

  /// Change workflow. Picking what comes next also ends a pause.
  Future<Person> setPlace(String id, WorkflowPlace? place) =>
      _write(id, {...placeToRow(place), 'paused_at': null});

  /// [notNow] also sets a prospect's status to Not now.
  Future<Person> pause(String id, DateTime at, {required bool notNow}) =>
      _write(id, {
        'paused_at': at.toUtc().toIso8601String(),
        if (notNow) 'prospect_status': _statusColumn[ProspectStatus.notNow],
      });

  /// The same step comes back, due counted from [today].
  Future<Person> resume(String id, DateTime today) =>
      _write(id, {'paused_at': null, 'last_tick': dayColumn(today)});

  /// The history entry and the move, in one transaction on the server.
  Future<Person> completeStep(
    String personId,
    String stepId,
    num nextPosition,
    DateTime on,
  ) => guardPeople(() async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'complete_step',
      params: {
        'p_person': personId,
        'p_step': stepId,
        'p_next_position': nextPosition,
        'p_on': dayColumn(on),
      },
    );
    return personFromRow(row);
  });

  Future<Person> _write(String id, Map<String, dynamic> values) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .update(values)
            .eq('id', id)
            .select()
            .single();
        return personFromRow(row);
      });
}

final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => PeopleRepository(ref.watch(supabaseClientProvider)),
);

/// A refusal from the server is [PeopleFailure.unknown]; any other exception
/// on the way (socket, timeout, `http.ClientException`) is the connection.
/// Errors — bugs, a malformed row — are unknown.
PeopleFailure peopleFailureFrom(Object error) => switch (error) {
  final PeopleFailure failure => failure,
  PostgrestException() => PeopleFailure.unknown,
  FormatException() => PeopleFailure.unknown,
  Exception() => PeopleFailure.network,
  _ => PeopleFailure.unknown,
};

/// Runs [call] and turns whatever it throws into a [PeopleFailure]. Every
/// contacts repository goes through it.
Future<T> guardPeople<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (error) {
    throw peopleFailureFrom(error);
  }
}

const Map<ProspectStatus, String> _statusColumn = {
  ProspectStatus.interested: 'interested',
  ProspectStatus.thinking: 'thinking',
  ProspectStatus.notNow: 'not_now',
  ProspectStatus.noReply: 'no_reply',
};

final Map<String, ProspectStatus> _statusFromColumn = {
  for (final MapEntry(:key, :value) in _statusColumn.entries) value: key,
};

Person personFromRow(Map<String, dynamic> row) {
  final status = row['prospect_status'] as String?;
  return Person(
    id: row['id'] as String,
    name: row['name'] as String,
    stage:
        Stage.values.asNameMap()[row['stage']] ?? (throw PeopleFailure.unknown),
    prospectStatus: status == null
        ? null
        : _statusFromColumn[status] ?? (throw PeopleFailure.unknown),
    phone: _text(row['phone']),
    email: _text(row['email']),
    instagram: _text(row['instagram']),
    needs: _text(row['needs']),
    products: _text(row['products']),
    profession: _text(row['profession']),
    address: _text(row['address']),
    notes: _text(row['notes']),
    stageSince: DateTime.parse(row['stage_since'] as String),
    place: switch ((row['workflow_id'], row['at_position'], row['last_tick'])) {
      (final String id, final num at, final String tick) => (
        workflowId: id,
        atPosition: at,
        // A bare date parses as local midnight, which is what a day is here.
        lastTick: DateTime.parse(tick),
      ),
      _ => null,
    },
    pausedAt: switch (row['paused_at']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
  );
}

/// What an update writes: everything the user can edit, except the stage and
/// the workflow fields. Only [PeopleRepository.setStage] writes it, so a stale
/// copy never moves someone back (and into the history).
Map<String, dynamic> personToRow(Person person) => {
  'name': person.name.trim(),
  'prospect_status': _statusColumn[person.prospectStatus],
  'phone': _text(person.phone),
  'email': _text(person.email),
  'instagram': _text(person.instagram),
  'needs': _text(person.needs),
  'products': _text(person.products),
  'profession': _text(person.profession),
  'address': _text(person.address),
  'notes': _text(person.notes),
};

Map<String, dynamic> draftToRow(PersonDraft draft) => {
  'name': draft.name.trim(),
  'stage': draft.stage.name,
  'phone': _text(draft.phone),
  'email': _text(draft.email),
  'instagram': _text(draft.instagram),
};

/// Blank is absent, in both directions.
String? _text(Object? value) {
  final text = (value as String?)?.trim();
  return text == null || text.isEmpty ? null : text;
}

Map<String, dynamic> placeToRow(WorkflowPlace? place) => {
  'workflow_id': place?.workflowId,
  'at_position': place?.atPosition,
  'last_tick': place == null ? null : dayColumn(place.lastTick),
};

/// `yyyy-MM-dd`, what a `date` column takes; no locale involved.
String dayColumn(DateTime day) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}
