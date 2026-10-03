import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/person.dart';

void main() {
  test('an entry shows under the day the user gave', () {
    final call = Activity(
      id: 'a1',
      personId: 'p1',
      kind: ActivityKind.call,
      happenedOn: DateTime(2026, 9, 20),
      text: 'Asked about the cream',
      createdAt: DateTime.utc(2026, 9, 28, 12),
    );

    expect(call.day, DateTime(2026, 9, 20));
  });

  test('a stage entry shows under the local day it was made', () {
    // 00:30 local is the previous day in UTC east of Greenwich, and the
    // server's happened_on is that UTC day.
    final createdAt = DateTime(2026, 9, 28, 0, 30).toUtc();
    final moved = Activity(
      id: 'a2',
      personId: 'p1',
      kind: ActivityKind.stage,
      happenedOn: DateTime(2026, 9, 27),
      stage: Stage.customer,
      createdAt: createdAt,
    );

    expect(moved.day, DateTime(2026, 9, 28));
  });

  test('a stage entry without a stage is a bug', () {
    expect(
      () => Activity(
        id: 'a3',
        personId: 'p1',
        kind: ActivityKind.stage,
        happenedOn: DateTime(2026, 9, 28),
        createdAt: DateTime.utc(2026, 9, 28),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('a non-stage entry with blank text is a bug', () {
    expect(
      () => Activity(
        id: 'a4',
        personId: 'p1',
        kind: ActivityKind.note,
        happenedOn: DateTime(2026, 9, 28),
        text: '  ',
        createdAt: DateTime.utc(2026, 9, 28),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('an order may have an amount and no text', () {
    final order = Activity(
      id: 'a5',
      personId: 'p1',
      kind: ActivityKind.order,
      happenedOn: DateTime(2026, 9, 28),
      amount: 100,
      createdAt: DateTime.utc(2026, 9, 28),
    );

    expect(order.text, isNull);
    expect(order.amount, 100);
  });

  test('an order with neither text nor amount is a bug', () {
    expect(
      () => Activity(
        id: 'a6',
        personId: 'p1',
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 9, 28),
        createdAt: DateTime.utc(2026, 9, 28),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('an amount on anything but an order is a bug', () {
    expect(
      () => Activity(
        id: 'a7',
        personId: 'p1',
        kind: ActivityKind.call,
        happenedOn: DateTime(2026, 9, 28),
        text: 'Called',
        amount: 100,
        createdAt: DateTime.utc(2026, 9, 28),
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
