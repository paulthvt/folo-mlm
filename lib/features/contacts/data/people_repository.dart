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
  Future<List<Person>> list() => _guard(() async {
    final rows = await _client.from(_table).select();
    return rows.map(personFromRow).toList();
  });

  Future<Person> add(PersonDraft draft) => _guard(() async {
    final row = await _client
        .from(_table)
        .insert(draftToRow(draft))
        .select()
        .single();
    return personFromRow(row);
  });

  Future<Person> update(Person person) => _guard(() async {
    final row = await _client
        .from(_table)
        .update(personToRow(person))
        .eq('id', person.id)
        .select()
        .single();
    return personFromRow(row);
  });

  Future<void> delete(String id) =>
      _guard(() => _client.from(_table).delete().eq('id', id));

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (error) {
      throw peopleFailureFrom(error);
    }
  }
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
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

/// What an update writes: everything the user can edit.
Map<String, dynamic> personToRow(Person person) => {
  'name': person.name.trim(),
  'stage': person.stage.name,
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
