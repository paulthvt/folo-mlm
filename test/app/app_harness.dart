import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/app.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/account.dart';
import 'package:folo/features/contacts/data/people_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/fake_auth_repository.dart';
import '../features/contacts/fake_people_repository.dart';

/// The whole app, signed in as Pauline, at [size]. Returns the container so a
/// test can drive `routerProvider` the way a URL would.
Future<ProviderContainer> pumpFolo(
  WidgetTester tester, {
  required Size size,
  FakePeopleRepository? people,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAuthRepository()
    ..session = true
    ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        peopleRepositoryProvider.overrideWithValue(
          people ?? FakePeopleRepository(),
        ),
      ],
      child: const FoloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(FoloApp)));
}
