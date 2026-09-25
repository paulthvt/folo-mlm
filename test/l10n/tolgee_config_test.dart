import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `.tolgeerc` is what makes the two workflows speak Flutter instead of the
/// CLI's own JSON. None of it can be exercised without a live project, so these
/// are the invariants a wrong value would silently break — every one of them
/// produces a pull request full of files `gen-l10n` ignores, or a push that
/// uploads `@key` metadata as keys.
void main() {
  final config =
      jsonDecode(File('.tolgeerc').readAsStringSync()) as Map<String, dynamic>;

  test('the format is Flutter ARB, not the CLI default JSON_TOLGEE', () {
    expect(config['format'], 'FLUTTER_ARB');
  });

  test('push reads the English file this repo actually has', () {
    final template = (config['push'] as Map)['filesTemplate'] as String;
    final english = template.replaceAll('{languageTag}', 'en');

    expect(File(english).existsSync(), isTrue, reason: '$english is missing');
  });

  // gen-l10n matches `app_*.arb`, and a pulled file that lands as `fr.arb` is
  // invisible to it. The default template has no prefix, so this has to be set.
  test('pulled files keep the app_ prefix gen-l10n looks for', () {
    final pull = config['pull'] as Map;
    final template = pull['fileStructureTemplate'] as String;

    expect(template, startsWith('app_'));
    expect(template, contains('{languageTag}'));
    expect(pull['path'], isNot('lib/l10n'));
  });
}
