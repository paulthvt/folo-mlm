import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/account.dart';
import 'package:folo/features/contacts/data/people_repository.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:folo/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_people_repository.dart';

/// Pumps a screen with one "Open" button that runs [open], with the book
/// already loaded from [people]. Returns what [open] resolved to via [result].
Future<void> pumpFormHarness(
  WidgetTester tester, {
  required FakePeopleRepository people,
  required Future<Object?> Function(BuildContext context) open,
  required void Function(Object? value) result,
}) async {
  final auth = FakeAuthRepository()
    ..session = true
    ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        peopleRepositoryProvider.overrideWithValue(people),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Consumer(
          builder: (context, ref, _) {
            // Loaded, as it is when the list opens the form.
            ref.watch(peopleProvider(ref.watch(accountProvider)?.email));
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async => result(await open(context)),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
