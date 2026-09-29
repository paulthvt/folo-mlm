import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

List<WorkflowStep> _at(List<num> positions) => [
  for (final position in positions)
    WorkflowStep(id: '$position', position: position, label: 'x', days: 0),
];

void main() {
  test('dropped first: one before the first', () {
    expect(positionAt(_at([2, 3]), 0), 1);
  });

  test('dropped in the middle: the midpoint of its neighbours', () {
    expect(positionAt(_at([1, 3, 4]), 1), 2);
  });

  test('dropped last: one past the last', () {
    expect(positionAt(_at([1, 2.5]), 2), 3.5);
  });

  test('nothing else: 1', () {
    expect(positionAt(const [], 0), 1);
  });

  test('between adjacent integers: the half', () {
    expect(positionAt(_at([1, 2]), 1), 1.5);
  });
}
