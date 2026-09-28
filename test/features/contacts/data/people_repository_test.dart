import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/contacts/data/people_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _row([Map<String, dynamic> changes = const {}]) => {
  'id': 'p1',
  'owner_id': 'u1',
  'name': 'Marie Dupont',
  'stage': 'prospect',
  'prospect_status': 'not_now',
  'phone': '06 12 34 56 78',
  'email': null,
  'instagram': '  ',
  'needs': 'Sleep, stress',
  'products': null,
  'profession': 'Nurse',
  'address': null,
  'notes': '',
  'created_at': '2026-03-04T10:00:00+00:00',
  'stage_since': '2026-04-01T08:00:00+00:00',
  'updated_at': '2026-03-05T10:00:00+00:00',
  ...changes,
};

void main() {
  group('personFromRow', () {
    test('maps columns to fields', () {
      final person = personFromRow(_row());

      expect(person.id, 'p1');
      expect(person.name, 'Marie Dupont');
      expect(person.stage, Stage.prospect);
      expect(person.prospectStatus, ProspectStatus.notNow);
      expect(person.phone, '06 12 34 56 78');
      expect(person.needs, 'Sleep, stress');
      expect(person.profession, 'Nurse');
      expect(person.stageSince, DateTime.utc(2026, 4, 1, 8));
    });

    test('reads blank text as null', () {
      final person = personFromRow(_row());
      expect(person.email, isNull);
      expect(person.instagram, isNull);
      expect(person.notes, isNull);
    });

    test('reads no_reply', () {
      expect(
        personFromRow(_row({'prospect_status': 'no_reply'})).prospectStatus,
        ProspectStatus.noReply,
      );
    });

    test('an unknown stage is a failure, never a default', () {
      expect(
        () => personFromRow(_row({'stage': 'partner'})),
        throwsA(PeopleFailure.unknown),
      );
    });

    test('an unknown status is a failure, never a default', () {
      expect(
        () => personFromRow(_row({'prospect_status': 'maybe'})),
        throwsA(PeopleFailure.unknown),
      );
    });
  });

  test('personToRow writes snake_case values and nulls for blanks', () {
    final row = personToRow(
      Person(
        id: 'p1',
        name: ' Marie Dupont ',
        stage: Stage.prospect,
        stageSince: DateTime.utc(2026, 3, 4),
        prospectStatus: ProspectStatus.noReply,
        phone: '',
        notes: 'Met at the market',
      ),
    );

    expect(row, {
      'name': 'Marie Dupont',
      'stage': 'prospect',
      'prospect_status': 'no_reply',
      'phone': null,
      'email': null,
      'instagram': null,
      'needs': null,
      'products': null,
      'profession': null,
      'address': null,
      'notes': 'Met at the market',
    });
  });

  test('draftToRow writes the name, stage and channels', () {
    final row = draftToRow((
      name: ' Lucas ',
      stage: Stage.customer,
      phone: null,
      email: 'lucas@example.com',
      instagram: null,
    ));

    expect(row, {
      'name': 'Lucas',
      'stage': 'customer',
      'phone': null,
      'email': 'lucas@example.com',
      'instagram': null,
    });
  });

  group('peopleFailureFrom', () {
    test('passes a PeopleFailure through', () {
      expect(peopleFailureFrom(PeopleFailure.network), PeopleFailure.network);
    });

    test('a lost connection is network', () {
      expect(
        peopleFailureFrom(const SocketException('offline')),
        PeopleFailure.network,
      );
      expect(
        peopleFailureFrom(TimeoutException('slow')),
        PeopleFailure.network,
      );
    });

    test('a server refusal is unknown', () {
      expect(
        peopleFailureFrom(const PostgrestException(message: 'denied')),
        PeopleFailure.unknown,
      );
    });

    test('a malformed row is unknown', () {
      expect(
        peopleFailureFrom(const FormatException('bad timestamp')),
        PeopleFailure.unknown,
      );
    });

    test('a bug is unknown', () {
      expect(peopleFailureFrom(StateError('bad')), PeopleFailure.unknown);
    });
  });
}
