import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/contacts/domain/contact_channel.dart';

void main() {
  test('blank input is no channel', () {
    expect(guessChannel(''), isNull);
    expect(guessChannel('   '), isNull);
  });

  test('an address with @ and a dot after it is an email', () {
    expect(guessChannel(' marie@example.com '), (
      kind: ChannelKind.email,
      value: 'marie@example.com',
    ));
  });

  test('digits and phone punctuation, six digits or more, is a phone', () {
    expect(guessChannel('+33 6 12-34.56 (78)'), (
      kind: ChannelKind.phone,
      value: '+33 6 12-34.56 (78)',
    ));
    expect(guessChannel('061234'), (kind: ChannelKind.phone, value: '061234'));
  });

  test('too few digits is not a phone', () {
    expect(guessChannel('12345'), (
      kind: ChannelKind.instagram,
      value: '12345',
    ));
  });

  test('anything else is an Instagram handle, without its @', () {
    expect(guessChannel('@marie.dupont'), (
      kind: ChannelKind.instagram,
      value: 'marie.dupont',
    ));
    expect(guessChannel('marie_d'), (
      kind: ChannelKind.instagram,
      value: 'marie_d',
    ));
  });

  test('an @ with no dot after it is a handle, not an email', () {
    expect(guessChannel('marie@home'), (
      kind: ChannelKind.instagram,
      value: 'marie@home',
    ));
  });
}
