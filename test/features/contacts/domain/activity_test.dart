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

  group('parseAmount in English', () {
    double? en(String typed) => parseAmount(typed, 'en');

    test('a whole number, or up to two decimals', () {
      expect(en('100'), 100);
      expect(en('99.5'), 99.5);
      expect(en('99.50'), 99.5);
    });

    test('a comma groups thousands', () {
      expect(en('6,000'), 6000);
      expect(en('1,840.5'), 1840.5);
      expect(en('1,234,567'), 1234567);
    });

    test('a comma that does not group thousands is refused, not guessed', () {
      expect(en('1,5'), isNull);
      expect(en('6,00'), isNull);
      expect(en('12,34,567'), isNull);
    });

    test('spaces are ignored', () {
      expect(en(' 1 840 '), 1840);
    });

    test('zero, negative, text, empty, too precise or too big: refused', () {
      expect(en('0'), isNull);
      expect(en('0.00'), isNull);
      expect(en('-5'), isNull);
      expect(en('abc'), isNull);
      expect(en(''), isNull);
      expect(en('1.005'), isNull);
      expect(en('12345678901'), isNull);
    });

    test('the largest the column holds is accepted', () {
      expect(en('9,999,999,999.99'), 9999999999.99);
    });
  });

  group('parseAmount in French', () {
    double? fr(String typed) => parseAmount(typed, 'fr');

    test('a comma is the decimal point', () {
      expect(fr('12,5'), 12.5);
      expect(fr('1,84'), 1.84);
    });

    test('a point is one too: some number pads only offer it', () {
      expect(fr('12.5'), 12.5);
    });

    test('spaces group thousands, the narrow no-break one too', () {
      expect(fr('1 840'), 1840);
      expect(fr('1\u202F840,5'), 1840.5);
    });

    test('three decimals are refused, never read as thousands', () {
      expect(fr('6.000'), isNull);
      expect(fr('6,000'), isNull);
    });
  });
}
