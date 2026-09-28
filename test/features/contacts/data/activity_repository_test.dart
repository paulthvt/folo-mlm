import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/contacts/data/activity_repository.dart';
import 'package:folo/features/contacts/domain/activity.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';

Map<String, dynamic> _row([Map<String, dynamic> changes = const {}]) => {
  'id': 'a1',
  'owner_id': 'u1',
  'person_id': 'p1',
  'kind': 'call',
  'happened_on': '2026-09-20',
  'text': 'Asked about the cream',
  'stage': null,
  'created_at': '2026-09-28T12:00:00+00:00',
  ...changes,
};

void main() {
  group('activityFromRow', () {
    test('maps columns to fields, the day as local midnight', () {
      final activity = activityFromRow(_row());

      expect(activity.id, 'a1');
      expect(activity.personId, 'p1');
      expect(activity.kind, ActivityKind.call);
      expect(activity.happenedOn, DateTime(2026, 9, 20));
      expect(activity.text, 'Asked about the cream');
      expect(activity.stage, isNull);
      expect(activity.createdAt, DateTime.utc(2026, 9, 28, 12));
    });

    test('reads a stage entry', () {
      final activity = activityFromRow(
        _row({'kind': 'stage', 'text': null, 'stage': 'team'}),
      );

      expect(activity.kind, ActivityKind.stage);
      expect(activity.stage, Stage.team);
    });

    test('an unknown kind is a failure, never a default', () {
      expect(
        () => activityFromRow(_row({'kind': 'visit'})),
        throwsA(PeopleFailure.unknown),
      );
    });

    test('an unknown stage is a failure, never a default', () {
      expect(
        () => activityFromRow(
          _row({'kind': 'stage', 'text': null, 'stage': 'partner'}),
        ),
        throwsA(PeopleFailure.unknown),
      );
    });
  });

  test('activityDraftToRow writes the day as yyyy-MM-dd and trims', () {
    expect(
      activityDraftToRow('p1', (
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 3, 4),
        text: '  Two creams ',
      )),
      {
        'person_id': 'p1',
        'kind': 'order',
        'happened_on': '2026-03-04',
        'text': 'Two creams',
      },
    );
  });
}
