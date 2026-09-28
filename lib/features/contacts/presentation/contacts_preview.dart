import 'package:flutter/widget_previews.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/contact_details.dart';
import 'package:folo/features/contacts/presentation/contact_list.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:folo/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Contacts and a person in both modes, for `flutter widget-preview start`.
///
/// The sample book lives here and only here. Nothing in the app imports this
/// file.
@Preview(group: 'Contacts', name: 'List — light', size: Size(390, 844))
Widget contactsMobileLight() => _app(AppTheme.light, _list());

@Preview(group: 'Contacts', name: 'List — dark', size: Size(390, 844))
Widget contactsMobileDark() => _app(AppTheme.dark, _list());

@Preview(group: 'Contacts', name: 'Person — light', size: Size(390, 844))
Widget contactMobileLight() => _app(AppTheme.light, _details());

@Preview(group: 'Contacts', name: 'Person — dark', size: Size(390, 844))
Widget contactMobileDark() => _app(AppTheme.dark, _details());

@Preview(group: 'Contacts', name: 'Desktop — light', size: Size(1440, 900))
Widget contactsDesktopLight() => _app(
  AppTheme.light,
  Builder(
    builder: (context) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 440,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: FoloColors.of(context).borderSubtle),
            ),
          ),
          child: _list(selectedId: _sample.first.id, showRefresh: true),
        ),
        Expanded(child: _details()),
      ],
    ),
  ),
);

final _sample = [
  Person(
    id: 'p1',
    name: 'Marie Dupont',
    stage: Stage.prospect,
    prospectStatus: ProspectStatus.thinking,
    phone: '06 12 34 56 78',
    email: 'marie@example.com',
    needs: 'Sleep, stress',
    profession: 'Nurse',
    notes: 'Met at the Saturday market. Asked about lavender.',
    createdAt: DateTime.utc(2026, 3, 4),
  ),
  Person(
    id: 'p2',
    name: 'Lucas Martin',
    stage: Stage.customer,
    products: 'Lavender, Peppermint',
    needs: 'Headaches',
    createdAt: DateTime.utc(2026, 5, 1),
  ),
  Person(
    id: 'p3',
    name: 'Hélène Bernard',
    stage: Stage.team,
    instagram: 'helene.b',
    profession: 'Yoga teacher',
    createdAt: DateTime.utc(2025, 11, 12),
  ),
  Person(
    id: 'p4',
    name: 'Sarah Cohen',
    stage: Stage.prospect,
    createdAt: DateTime.utc(2026, 9, 20),
  ),
];

Widget _list({String? selectedId, bool showRefresh = false}) => ContactList(
  people: _sample,
  onOpen: (_) {},
  onAdd: () {},
  onRefresh: () async {},
  selectedId: selectedId,
  showRefresh: showRefresh,
);

Widget _details() => ContactDetails(
  person: _sample.first,
  onStatus: (_) {},
  onEdit: () {},
  onDelete: () {},
  onLaunch: (_) {},
  onRefresh: () async {},
);

Widget _app(ThemeData theme, Widget body) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // The preview is its own app: without the delegates, any component that
    // reads AppLocalizations throws here.
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: Scaffold(body: SafeArea(child: body)),
  );
}
