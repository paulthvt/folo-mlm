import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/app_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../contacts/fake_people_repository.dart';
import '../fake_workflow_repository.dart';

/// The app signed in as Pauline, gone to [location]: a phone unless [size]
/// says otherwise. With [settle] false it pumps past the route transition
/// only, for a load gated on purpose.
Future<ProviderContainer> openWorkflows(
  WidgetTester tester,
  String location, {
  Size size = const Size(390, 844),
  FakeWorkflowRepository? workflows,
  FakePeopleRepository? people,
  bool settle = true,
}) async {
  final container = await pumpFolo(
    tester,
    size: size,
    workflows: workflows,
    people: people,
    settle: settle,
  );
  container.read(routerProvider).go(location);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
  return container;
}
