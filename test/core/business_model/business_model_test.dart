import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/business_model/business_model.dart';

void main() {
  test('nothing stored is Other', () {
    expect(BusinessModel.parse(null), BusinessModel.other);
  });

  test('doterra is read back', () {
    expect(BusinessModel.parse('doterra'), BusinessModel.doterra);
  });

  test('an unknown value reads as Other', () {
    expect(BusinessModel.parse('young_living'), BusinessModel.other);
    expect(BusinessModel.parse(42), BusinessModel.other);
  });

  test('Other is stored as nothing, so it round-trips', () {
    expect(BusinessModel.other.stored, isNull);
    expect(BusinessModel.doterra.stored, 'doterra');
    for (final model in BusinessModel.values) {
      expect(BusinessModel.parse(model.stored), model);
    }
  });
}
