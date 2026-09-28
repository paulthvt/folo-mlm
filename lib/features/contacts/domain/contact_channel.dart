enum ChannelKind { phone, email, instagram }

typedef ContactChannel = ({ChannelKind kind, String value});

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _phoneChars = RegExp(r'^[\d\s+.\-()]+$');
final _digit = RegExp(r'\d');

/// Reads the single "Phone, email or Instagram" field of Add someone.
///
/// Null for blank input. Anything that is neither an email nor a phone is taken
/// as an Instagram handle — the one channel with no recognisable shape.
ContactChannel? guessChannel(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  if (_email.hasMatch(text)) return (kind: ChannelKind.email, value: text);
  if (_phoneChars.hasMatch(text) && _digit.allMatches(text).length >= 6) {
    return (kind: ChannelKind.phone, value: text);
  }
  final handle = text.startsWith('@') ? text.substring(1) : text;
  return (kind: ChannelKind.instagram, value: handle);
}
