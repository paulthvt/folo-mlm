import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/data/people_repository.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/domain/search_key.dart';

/// The whole book, loaded once and kept in memory; every contacts screen reads
/// from it. Sorted by [searchKey] of the name.
///
/// No automatic retry: a failed load shows its error with a Retry button.
final peopleProvider = AsyncNotifierProvider<PeopleController, List<Person>>(
  PeopleController.new,
  retry: (error, _) => null,
);

class PeopleController extends AsyncNotifier<List<Person>> {
  /// How old the book may be before returning to the app reloads it. There is
  /// no realtime: this and pull to refresh are how other devices' changes
  /// arrive.
  static const Duration staleAfter = Duration(minutes: 1);

  DateTime? _loadedAt;

  PeopleRepository get _repository => ref.read(peopleRepositoryProvider);

  @override
  Future<List<Person>> build() async {
    // A new account is a new book; signed out, there is none. Returning [] here
    // also clears the previous user's list before the next one loads.
    final email = ref.watch(
      accountProvider.select((account) => account?.email),
    );
    final repository = ref.watch(peopleRepositoryProvider);
    if (email == null) {
      _loadedAt = null;
      return const [];
    }
    final people = await repository.list();
    _loadedAt = DateTime.now();
    return _sorted(people);
  }

  bool isStaleAt(DateTime now) {
    final loadedAt = _loadedAt;
    return loadedAt != null && now.difference(loadedAt) > staleAfter;
  }

  Future<Person> add(PersonDraft draft) async {
    final person = await _repository.add(draft);
    _change((people) => [...people, person]);
    return person;
  }

  Future<void> save(Person person) async {
    final saved = await _repository.update(person);
    _change(
      (people) => [
        for (final other in people) other.id == saved.id ? saved : other,
      ],
    );
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    _change((people) => [...people.where((other) => other.id != id)]);
  }

  /// Shown at once, saved behind. A failure puts the previous status back —
  /// unless a newer tap has replaced this one meanwhile — and rethrows.
  Future<void> setStatus(Person person, ProspectStatus? status) async {
    final before = _find(person.id)?.prospectStatus;
    _setStatusLocally(person.id, status);
    try {
      await _repository.update((_find(person.id) ?? person).withStatus(status));
    } catch (_) {
      if (_find(person.id)?.prospectStatus == status) {
        _setStatusLocally(person.id, before);
      }
      rethrow;
    }
  }

  Person? _find(String id) =>
      state.value?.where((person) => person.id == id).firstOrNull;

  void _setStatusLocally(String id, ProspectStatus? status) => _change(
    (people) => [
      for (final other in people)
        other.id == id ? other.withStatus(status) : other,
    ],
  );

  void _change(List<Person> Function(List<Person> people) change) {
    final people = state.value;
    // Rebuilt or disposed while a save was in flight: the new build has the
    // truth.
    if (!ref.mounted || people == null) return;
    state = AsyncData(_sorted(change(people)));
  }

  static List<Person> _sorted(Iterable<Person> people) =>
      [...people]
        ..sort((a, b) => searchKey(a.name).compareTo(searchKey(b.name)));
}
