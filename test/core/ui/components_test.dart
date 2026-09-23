import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/core/ui/action_item.dart';
import 'package:folo/core/ui/folo_avatar.dart';

Future<void> pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  test('initials come from the first and last word', () {
    expect(FoloAvatar.initialsOf('Marie Dupont'), 'MD');
    expect(FoloAvatar.initialsOf('Jean-Luc De La Fontaine'), 'JF');
    expect(FoloAvatar.initialsOf('  amina  '), 'A');
    expect(FoloAvatar.initialsOf(''), '?');
  });

  testWidgets('avatars are circular at every size', (tester) async {
    for (final size in AvatarSize.values) {
      await pump(tester, FoloAvatar(name: 'Marie Dupont', size: size));
      final box = tester.getSize(find.byType(FoloAvatar));
      expect(box.width, size.diameter);
      expect(box.height, size.diameter);
      final decoration =
          tester.widget<Container>(find.byType(Container).first).decoration
              as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    }
  });

  testWidgets('an action item opens the person and resolves in one tap', (
    tester,
  ) async {
    var opened = 0;
    var resolved = 0;
    await pump(
      tester,
      ActionItem(
        name: 'Marie Dupont',
        reason: 'Back from her holiday today',
        onOpen: () => opened++,
        onResolve: () => resolved++,
      ),
    );

    await tester.tap(find.byIcon(Icons.check_rounded));
    expect((opened, resolved), (0, 1));

    await tester.tap(find.text('Marie Dupont'));
    expect((opened, resolved), (1, 1));
  });

  testWidgets('the resolve button keeps a 44px touch target', (tester) async {
    await pump(
      tester,
      ActionItem(
        name: 'Marie Dupont',
        reason: 'Back from her holiday today',
        onResolve: () {},
      ),
    );

    final button = tester.getSize(find.byType(IconButton));
    expect(button.width, greaterThanOrEqualTo(44));
    expect(button.height, greaterThanOrEqualTo(44));
  });
}
