import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/contacts/domain/person.dart';

void main() {
  final marie = Person(
    id: 'p1',
    name: 'Marie Dupont',
    stage: Stage.prospect,
    stageSince: DateTime.utc(2026, 3, 4),
    phone: '06 12 34 56 78',
    needs: 'Sleep',
  );

  test('withStatus changes the status and nothing else', () {
    final changed = marie.withStatus(ProspectStatus.thinking);

    expect(changed.prospectStatus, ProspectStatus.thinking);
    expect(changed.id, 'p1');
    expect(changed.name, 'Marie Dupont');
    expect(changed.phone, '06 12 34 56 78');
    expect(changed.needs, 'Sleep');
    expect(changed.stageSince, DateTime.utc(2026, 3, 4));
  });

  test('withStatus(null) clears it', () {
    final cleared = marie
        .withStatus(ProspectStatus.interested)
        .withStatus(null);
    expect(cleared.prospectStatus, isNull);
  });
}
