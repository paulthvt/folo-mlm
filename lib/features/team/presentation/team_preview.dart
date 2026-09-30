import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/team/presentation/team_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Team in both modes, for `flutter widget-preview start`, on a fixed day so
/// the goldens never follow the clock. Six members: the AvatarGroup shows
/// three and "+3". Nothing in the app imports this file.
@Preview(group: 'Team', name: 'Mobile — light', size: Size(390, 844))
Widget teamMobileLight() => _app(AppTheme.light);

@Preview(group: 'Team', name: 'Mobile — dark', size: Size(390, 844))
Widget teamMobileDark() => _app(AppTheme.dark);

@Preview(group: 'Team', name: 'Desktop — light', size: Size(1440, 900))
Widget teamDesktopLight() => _app(AppTheme.light);

final _today = DateTime(2026, 9, 30);

Person _member(String name, DateTime since) =>
    Person(id: name, name: name, stage: Stage.team, stageSince: since);

/// Sorted as the book is, by name.
final _book = [
  _member('Bruno Keller', DateTime(2026, 6, 2)),
  _member('Inès Moreau', DateTime(2026, 9, 29)),
  _member('John Baptiste', DateTime(2026, 9, 9)),
  _member('Léa Fontaine', DateTime(2026, 8, 19)),
  _member('Marc Lambert', DateTime(2026, 9, 25)),
  _member('Sophie Laurent', DateTime(2026, 3, 4)),
];

Widget _app(ThemeData theme) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // The preview is its own app: without the delegates, any component that
    // reads AppLocalizations throws here.
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: TeamView(
      people: AsyncData(_book),
      today: _today,
      onOpen: (_) {},
      onRetry: () {},
      onRefresh: () async {},
    ),
  );
}
