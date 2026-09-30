# Team tab with the roster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Team tab (#102) listing every team member under a summary card that says nobody is being measured.

**Architecture:** Team members are `peopleProvider` filtered to `Stage.team`; no new provider, table or migration. `TeamView` is a provider-free screen (like `TodayView`) fed an `AsyncValue<List<Person>>`; `TeamPage` wires it to providers. A `/team` route joins the shell, and `AppShell` gains a third destination.

**Tech Stack:** Flutter, `flutter_riverpod`, `go_router`, `material_ui`, gen-l10n.

**Spec:** `docs/superpowers/specs/2026-09-30-team-tab-design.md`

## Global Constraints

- Imports: `package:loomia/...` only; Material from `package:material_ui/material_ui.dart`.
- No hard-coded colour, radius, font size or spacing: `Theme.of(context)`, `LoomiaColors.of(context)`, `AppSpacing.*`, `AppRadii.*`, `AppTypography.*`.
- Layout branches on `context.screenSize`, never raw widths. One 624px column on every size.
- Copy in `lib/l10n/app_en.arb` only, every key with a description. Never edit `app_fr.arb`.
- No volumes, ranks, comparisons or totals across members in copy or UI.
- Path literals only in `lib/app/router/routes.dart`.
- Never commit goldens made locally; they come from CI.
- Done = `dart format .`, `flutter analyze` ("No issues found!"), `flutter test` all clean.
- `pubspec.lock` and `devtools_options.yaml` are unrelated local changes: never stage them.

## Review Focus

1. `stageSince` is UTC from the server: a member who joined late last night must read "joined yesterday", not "today" — `joinedLabel` converts to local before counting days (test in Task 1).
2. Exactly one team member: summary reads "One person on your team", not "1 people" (test in Task 1).
3. Book with people but nobody at the team stage shows the empty state, not an empty card (test in Task 1).
4. More than three members: AvatarGroup shows three and `+N` (covered by `LoomiaAvatarGroup`; the preview uses six members).
5. Deep link to `/team` on web while signed out goes through the existing auth redirect (no change needed: `/team` is not in `authPaths`, so the redirect already guards it; checked in Task 2's router test).

---

## File Structure

- Create `lib/features/team/presentation/team_page.dart` — `TeamPage` (providers) and `TeamView` (pure), summary card, `joinedLabel`.
- Create `lib/features/team/presentation/team_preview.dart` — `@Preview`s.
- Delete `lib/features/team/.gitkeep`.
- Modify `lib/app/router/routes.dart` — `team`, `teamName`.
- Modify `lib/app/router/app_router.dart` — `GoRoute` for `/team`.
- Modify `lib/app/shell/app_shell.dart` — Team destination, bottom nav and sidebar.
- Modify `lib/l10n/app_en.arb` — new keys.
- Modify `test/previews_test.dart` — register previews.
- Modify `docs/design/screens.md` §4 — what is built and what is not.
- Create `test/features/team/team_page_test.dart`.
- Modify `test/app/shell/app_shell_test.dart`.

---

### Task 1: TeamView and its copy

**Files:**
- Create: `lib/features/team/presentation/team_page.dart`
- Modify: `lib/l10n/app_en.arb`
- Delete: `lib/features/team/.gitkeep`
- Test: `test/features/team/team_page_test.dart`

**Interfaces:**
- Consumes: `Person`, `Stage` (`lib/features/contacts/domain/person.dart`); `daysBetween(DateTime from, DateTime to)` (`lib/features/workflows/domain/progress.dart`); `ContactRow`, `LoomiaChip`, `LoomiaAvatarGroup`, `SectionHeader`, `EmptyState`, `LoomiaTopBar` (`lib/core/ui/`); `stageLabel(l10n, stage)` (`people_copy.dart`).
- Produces:
  - `String joinedLabel(AppLocalizations l10n, DateTime since, DateTime today)` — `today` is local midnight.
  - `class TeamView extends StatelessWidget` with `required AsyncValue<List<Person>> people` (the whole book; the view filters to `Stage.team`), `required DateTime today`, `required void Function(Person) onOpen`, `required VoidCallback onRetry`, `required Future<void> Function() onRefresh`, `Widget? accountAction`.

- [ ] **Step 1: Add the copy to `lib/l10n/app_en.arb`**

Insert after the `navContacts` entry (keep the file's two-space JSON style):

```json
  "navTeam": "Team",
  "@navTeam": {
    "description": "Navigation destination (bottom bar, sidebar) that opens the Team screen: the people who work with the user."
  },
  "teamTitle": "Team",
  "@teamTitle": {
    "description": "Title of the Team screen."
  },
  "teamCount": "{count, plural, =1{One person on your team} other{{count} people on your team}}",
  "@teamCount": {
    "description": "Heading of the summary card on the Team screen. A sentence, not a score.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "teamNotMeasured": "Nobody is being measured here — this is just who might need you.",
  "@teamNotMeasured": {
    "description": "Body of the summary card on the Team screen. States the rule out loud: the screen is about helping, never about performance. Informal register."
  },
  "teamSectionEveryone": "Everyone",
  "@teamSectionEveryone": {
    "description": "Section header above every team member, with their count beside it. Shown in capitals."
  },
  "teamJoinedToday": "Team · joined today",
  "@teamJoinedToday": {
    "description": "Second line of a team member's row: they joined the team today."
  },
  "teamJoinedYesterday": "Team · joined yesterday",
  "@teamJoinedYesterday": {
    "description": "Second line of a team member's row: they joined the team yesterday."
  },
  "teamJoinedDaysAgo": "{count, plural, other{Team · joined {count} days ago}}",
  "@teamJoinedDaysAgo": {
    "description": "Second line of a team member's row, 2 to 6 days after they joined the team.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "teamJoinedWeeksAgo": "{count, plural, =1{Team · joined a week ago} other{Team · joined {count} weeks ago}}",
  "@teamJoinedWeeksAgo": {
    "description": "Second line of a team member's row, 1 to 8 weeks after they joined the team. count is whole weeks.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "teamJoinedIn": "Team · joined in {date}",
  "@teamJoinedIn": {
    "description": "Second line of a team member's row, more than 8 weeks after they joined: the month, e.g. 'Team · joined in March 2026'.",
    "placeholders": {
      "date": { "type": "DateTime", "format": "yMMMM" }
    }
  },
  "teamEmptyTitle": "No one on your team yet",
  "@teamEmptyTitle": {
    "description": "Heading of the Team screen when nobody in the user's contacts is at the team stage."
  },
  "teamEmptyBody": "Move someone to Team from their page.",
  "@teamEmptyBody": {
    "description": "Body under teamEmptyTitle: how someone joins the team, from the ⋯ menu of their contact page. Informal register."
  },
  "teamLoadFailed": "Couldn't load your team.",
  "@teamLoadFailed": {
    "description": "Heading in place of the Team screen when the contacts could not be loaded. Above contactsLoadErrorBody and a Try again button."
  },
```

Run: `flutter gen-l10n`
Expected: exits 0 (a `l10n_missing.json` listing the new keys for French is normal).

- [ ] **Step 2: Write the failing widget test**

`test/features/team/team_page_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/team/presentation/team_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

final _today = DateTime(2026, 9, 30);

Person _person(String id, String name, Stage stage, DateTime since) => Person(
  id: id,
  name: name,
  stage: stage,
  stageSince: since,
);

Future<void> _pump(
  WidgetTester tester,
  AsyncValue<List<Person>> people, {
  void Function(Person)? onOpen,
  VoidCallback? onRetry,
}) async {
  tester.view
    ..physicalSize = const Size(390, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TeamView(
        people: people,
        today: _today,
        onOpen: onOpen ?? (_) {},
        onRetry: onRetry ?? () {},
        onRefresh: () async {},
      ),
    ),
  );
}

void main() {
  group('joinedLabel', () {
    late AppLocalizations l10n;
    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('counts local calendar days, then weeks, then the month', () {
      expect(joinedLabel(l10n, DateTime(2026, 9, 30, 8), _today),
          'Team · joined today');
      expect(joinedLabel(l10n, DateTime(2026, 9, 29, 23), _today),
          'Team · joined yesterday');
      expect(joinedLabel(l10n, DateTime(2026, 9, 24), _today),
          'Team · joined 6 days ago');
      expect(joinedLabel(l10n, DateTime(2026, 9, 23), _today),
          'Team · joined a week ago');
      expect(joinedLabel(l10n, DateTime(2026, 9, 9), _today),
          'Team · joined 3 weeks ago');
      expect(joinedLabel(l10n, DateTime(2026, 8, 5), _today),
          'Team · joined 8 weeks ago');
      expect(joinedLabel(l10n, DateTime(2026, 3, 4), _today),
          'Team · joined in March 2026');
    });

    test('a UTC timestamp is read on the local calendar', () {
      final lateYesterday = DateTime(2026, 9, 29, 23, 30).toUtc();
      expect(joinedLabel(l10n, lateYesterday, _today),
          'Team · joined yesterday');
    });
  });

  testWidgets('only team members, with the summary and the rule', (
    tester,
  ) async {
    await _pump(
      tester,
      AsyncData([
        _person('p1', 'Bruno Keller', Stage.team, DateTime(2026, 9, 9)),
        _person('p2', 'Claire Dubois', Stage.customer, DateTime(2026, 9, 9)),
        _person('p3', 'Léa Fontaine', Stage.team, DateTime(2026, 3, 4)),
      ]),
    );

    expect(find.text('2 people on your team'), findsOneWidget);
    expect(
      find.text(
        'Nobody is being measured here — this is just who might need you.',
      ),
      findsOneWidget,
    );
    expect(find.text('EVERYONE'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Bruno Keller'), findsOneWidget);
    expect(find.text('Team · joined 3 weeks ago'), findsOneWidget);
    expect(find.text('Léa Fontaine'), findsOneWidget);
    expect(find.text('Claire Dubois'), findsNothing);
  });

  testWidgets('one member reads as a sentence', (tester) async {
    await _pump(
      tester,
      AsyncData([
        _person('p1', 'Bruno Keller', Stage.team, DateTime(2026, 9, 9)),
      ]),
    );

    expect(find.text('One person on your team'), findsOneWidget);
  });

  testWidgets('tapping a row opens the person', (tester) async {
    Person? opened;
    await _pump(
      tester,
      AsyncData([
        _person('p1', 'Bruno Keller', Stage.team, DateTime(2026, 9, 9)),
      ]),
      onOpen: (person) => opened = person,
    );

    await tester.tap(find.text('Bruno Keller'));
    expect(opened?.id, 'p1');
  });

  testWidgets('no team member: the empty state, no summary', (tester) async {
    await _pump(
      tester,
      AsyncData([
        _person('p2', 'Claire Dubois', Stage.customer, DateTime(2026, 9, 9)),
      ]),
    );

    expect(find.text('No one on your team yet'), findsOneWidget);
    expect(find.text('Move someone to Team from their page.'), findsOneWidget);
    expect(find.text('EVERYONE'), findsNothing);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    var retried = false;
    await _pump(
      tester,
      AsyncError(Exception('offline'), StackTrace.empty),
      onRetry: () => retried = true,
    );

    expect(find.text("Couldn't load your team."), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('loading shows a spinner', (tester) async {
    await _pump(tester, const AsyncLoading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/team/team_page_test.dart`
Expected: FAIL — `team_page.dart` does not exist.

- [ ] **Step 4: Implement `TeamView` and `joinedLabel`**

Delete `lib/features/team/.gitkeep`. Create `lib/features/team/presentation/team_page.dart` with the view part (Task 2 adds `TeamPage` above it):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/loomia_chip.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// "Team · joined 3 weeks ago": days for a week, weeks up to 8, then the
/// month. Counted on the device's calendar, so a UTC [since] is read locally.
String joinedLabel(AppLocalizations l10n, DateTime since, DateTime today) {
  final local = since.toLocal();
  return switch (daysBetween(local, today)) {
    <= 0 => l10n.teamJoinedToday,
    1 => l10n.teamJoinedYesterday,
    < 7 && final days => l10n.teamJoinedDaysAgo(days),
    <= 56 && final days => l10n.teamJoinedWeeksAgo(days ~/ 7),
    _ => l10n.teamJoinedIn(local),
  };
}

/// Who on the team might need the user, never who is performing
/// (`docs/design/screens.md` §4). The screen as a function of its inputs, so
/// it can be previewed and tested without providers. One column on every size.
class TeamView extends StatelessWidget {
  const TeamView({
    required this.people,
    required this.today,
    required this.onOpen,
    required this.onRetry,
    required this.onRefresh,
    this.accountAction,
    super.key,
  });

  /// The whole book; the team is everyone at [Stage.team], in its order.
  final AsyncValue<List<Person>> people;

  /// Local midnight: how long ago each member joined.
  final DateTime today;

  final void Function(Person person) onOpen;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  /// Top-bar entry to Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  /// Per `docs/design/responsive-design.md`: the same column as Today.
  static const double _column = 624;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = context.screenSize.isDesktop;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _column),
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                // Pull to refresh works on a short list too.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: desktop
                    ? const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                        vertical: AppSpacing.xl,
                      )
                    : const EdgeInsets.all(AppSpacing.md),
                children: [
                  LoomiaTopBar(
                    title: l10n.teamTitle,
                    large: desktop,
                    action: accountAction,
                  ),
                  ...switch (people) {
                    // `.value` survives a failed refresh, so the rows stay.
                    AsyncValue(value: final book?) => _team(
                      l10n,
                      [for (final p in book) if (p.stage == Stage.team) p],
                    ),
                    AsyncError() => [
                      EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: l10n.teamLoadFailed,
                        body: l10n.contactsLoadErrorBody,
                        actionLabel: l10n.contactsRetry,
                        onAction: onRetry,
                      ),
                    ],
                    _ => const [Center(child: CircularProgressIndicator())],
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _team(AppLocalizations l10n, List<Person> team) {
    if (team.isEmpty) {
      return [
        EmptyState(
          icon: Icons.diversity_3_outlined,
          title: l10n.teamEmptyTitle,
          body: l10n.teamEmptyBody,
        ),
      ];
    }
    return [
      _Summary(team: team),
      const SizedBox(height: AppSpacing.lg),
      SectionHeader(
        title: l10n.teamSectionEveryone,
        actionLabel: '${team.length}',
      ),
      for (final person in team)
        ContactRow(
          name: person.name,
          subtitle: joinedLabel(l10n, person.stageSince, today),
          trailing: LoomiaChip(label: stageLabel(l10n, person.stage)),
          onTap: () => onOpen(person),
        ),
    ];
  }
}

/// How many, who, and the rule said out loud. No totals, no scores.
class _Summary extends StatelessWidget {
  const _Summary({required this.team});

  final List<Person> team;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.teamCount(team.length),
                    style: AppTypography.titleLarge.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                LoomiaAvatarGroup(names: [for (final p in team) p.name]),
              ],
            ),
            const SizedBox(height: AppSpacing.ms),
            Text(
              l10n.teamNotMeasured,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: the `AsyncValue(value: final book?)` pattern matches data and a failed *refresh* (error with a previous value), exactly as Today keeps rows on screen. A first-load error has no value and falls to `AsyncError()`. If `LoomiaAvatarGroup` or `AppTypography.titleLarge` names differ from these, check `lib/core/ui/loomia_avatar.dart` and `lib/app/theme/app_typography.dart`; both were read when this plan was written.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/team/team_page_test.dart`
Expected: PASS, all tests.

- [ ] **Step 6: Commit**

```bash
git rm -q lib/features/team/.gitkeep
git add lib/features/team lib/l10n/app_en.arb test/features/team
git commit -m "feat(team): the roster and its summary (#102)"
```

---

### Task 2: `/team` route, TeamPage and the nav destination

**Files:**
- Modify: `lib/features/team/presentation/team_page.dart` (add `TeamPage` at the top)
- Modify: `lib/app/router/routes.dart`
- Modify: `lib/app/router/app_router.dart`
- Modify: `lib/app/shell/app_shell.dart`
- Test: `test/app/shell/app_shell_test.dart`, `test/features/team/team_page_test.dart`

**Interfaces:**
- Consumes: `TeamView` (Task 1); `accountProvider` (`features/auth/data/auth_repository.dart`); `peopleProvider(String? email)` (`contacts/presentation/people_controller.dart`); `openContact(context, id)`, `refreshPeople(context, ref)` (`contacts/presentation/contacts_page.dart`); `today()` (`core/ui/pick_day.dart`); `AccountButton` (`app/shell/app_shell.dart`); test harness `pumpLoomia(tester, size:, people:)` (`test/app/app_harness.dart`), `FakePeopleRepository(List<Person>)` (`test/features/contacts/fake_people_repository.dart`).
- Produces: `Routes.team = '/team'`, `Routes.teamName = 'team'`; `class TeamPage extends ConsumerWidget`.

- [ ] **Step 1: Write the failing tests**

Append to `test/app/shell/app_shell_test.dart` inside `main()` (add imports `package:loomia/features/team/presentation/team_page.dart` and `package:go_router/go_router.dart` if missing):

```dart
  testWidgets('mobile: Team is the third tab and opens the team', (
    tester,
  ) async {
    await pumpLoomia(tester, size: const Size(390, 844));

    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();

    expect(find.byType(TeamPage), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });

  testWidgets('desktop: the sidebar opens the team', (tester) async {
    await pumpLoomia(tester, size: const Size(1440, 900));

    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();

    expect(find.byType(TeamPage), findsOneWidget);
  });
```

Append to `test/features/team/team_page_test.dart` a full-app test (add imports `../../app/app_harness.dart`, `../contacts/fake_people_repository.dart`, `package:loomia/features/contacts/presentation/contact_page.dart`):

```dart
  testWidgets('in the app: a team member opens their contact page', (
    tester,
  ) async {
    await pumpLoomia(
      tester,
      size: const Size(390, 844),
      people: FakePeopleRepository([
        _person('p1', 'Bruno Keller', Stage.team, DateTime.utc(2026, 9, 9)),
      ]),
    );
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bruno Keller'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactPage), findsOneWidget);
  });
```

If `ContactPage` is not the class name shown for a person on mobile, use the one `test/features/today/today_page_test.dart` imports from `contact_page.dart`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/app/shell/app_shell_test.dart test/features/team/team_page_test.dart`
Expected: FAIL — no "Team" destination (`Bad state: No element` / `findsNothing`).

- [ ] **Step 3: Add the route constants**

In `lib/app/router/routes.dart`, after the contact workflow block:

```dart
  static const String team = '/team';
  static const String teamName = 'team';
```

- [ ] **Step 4: Add `TeamPage`**

At the top of the widget code in `team_page.dart` (after `joinedLabel`), and add imports `package:loomia/app/shell/app_shell.dart`, `package:loomia/core/ui/pick_day.dart`, `package:loomia/features/auth/data/auth_repository.dart`, `package:loomia/features/contacts/presentation/contacts_page.dart`, `package:loomia/features/contacts/presentation/people_controller.dart`:

```dart
/// The team, read from the book the Contacts tab already holds.
class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = peopleProvider(ref.watch(accountProvider)?.email);
    return TeamView(
      people: ref.watch(book),
      today: today(),
      // With a sidebar, Settings is its account block instead.
      accountAction: context.screenSize.usesSideNavigation
          ? IconButton(
              onPressed: () => refreshPeople(context, ref),
              tooltip: AppLocalizations.of(context).contactsRefresh,
              icon: const Icon(Icons.refresh_rounded),
            )
          : const AccountButton(),
      onOpen: (person) => openContact(context, person.id),
      onRetry: () => ref.invalidate(book),
      onRefresh: () => refreshPeople(context, ref),
    );
  }
}
```

If `app_shell.dart` importing nothing from team and `team_page.dart` importing `AccountButton` from `app_shell.dart` creates an import cycle with the router, it is the same shape as `today_page.dart` (which imports `app_shell.dart`), so it is fine.

- [ ] **Step 5: Add the `GoRoute`**

In `lib/app/router/app_router.dart`, inside the outer `ShellRoute`'s `routes`, right after the nested contacts `ShellRoute` and before the settings `GoRoute`, and import `package:loomia/features/team/presentation/team_page.dart`:

```dart
          GoRoute(
            path: Routes.team,
            name: Routes.teamName,
            builder: (context, state) => const TeamPage(),
          ),
```

- [ ] **Step 6: Add the destination to `AppShell`**

In `lib/app/shell/app_shell.dart`, update the class doc (`Team and Goals join when they exist` → `Goals joins when it exists, never as a placeholder.`), then replace the mobile `NavigationBar`:

```dart
      const tabs = [Routes.today, Routes.contacts, Routes.team];
      final selected = tabs.lastIndexWhere(
        (path) => path == Routes.today
            ? location == Routes.today
            : location.startsWith(path),
      );
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          // A pushed page outside the tabs keeps Today marked, as before.
          selectedIndex: selected < 0 ? 0 : selected,
          onDestinationSelected: (index) => context.go(tabs[index]),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.wb_sunny_outlined),
              label: l10n.navToday,
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline),
              label: l10n.navContacts,
            ),
            NavigationDestination(
              icon: const Icon(Icons.diversity_3_outlined),
              label: l10n.navTeam,
            ),
          ],
        ),
      );
```

And in `_Sidebar`, after the Contacts `_SidebarItem`:

```dart
                _SidebarItem(
                  icon: const Icon(Icons.diversity_3_outlined),
                  label: l10n.navTeam,
                  selected: location.startsWith(Routes.team),
                  expanded: expanded,
                  onTap: () => context.go(Routes.team),
                ),
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/app test/features/team`
Expected: PASS. If an existing shell or router test counted exactly two destinations, update its expectation to three.

- [ ] **Step 8: Commit**

```bash
git add lib/app lib/features/team test/app test/features/team
git commit -m "feat(team): a Team tab in the bottom bar and the sidebar (#102)"
```

---

### Task 3: Previews, goldens registration, docs, full check

**Files:**
- Create: `lib/features/team/presentation/team_preview.dart`
- Modify: `test/previews_test.dart`
- Modify: `docs/design/screens.md` (§4 Team)

**Interfaces:**
- Consumes: `TeamView` (Task 1), `AppTheme.light` / `AppTheme.dark` (`lib/app/theme/app_theme.dart`), `localizationsDelegates`.
- Produces: `teamMobileLight()`, `teamMobileDark()`, `teamDesktopLight()`.

- [ ] **Step 1: Write the previews**

`lib/features/team/presentation/team_preview.dart`:

```dart
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
```

- [ ] **Step 2: Register them in `test/previews_test.dart`**

Add the import `package:loomia/features/team/presentation/team_preview.dart` and, after the `today_empty_light` entry:

```dart
    'team_mobile_light': (const Size(390, 844), teamMobileLight),
    'team_mobile_dark': (const Size(390, 844), teamMobileDark),
    'team_desktop_light': (const Size(1440, 900), teamDesktopLight),
```

Run: `flutter test test/previews_test.dart`
Expected: PASS on macOS (renders without exception; pixels are compared on Linux only). Do NOT create PNGs locally.

- [ ] **Step 3: Update `docs/design/screens.md` §4**

Append to the end of section "## 4. Team" (after "The copy states the rule out loud."):

```markdown
**Built** ([#101](https://github.com/paulthvt/loomia/issues/101)): the summary
card and `EVERYONE` (#102); `WORTH A CHECK-IN` follows in #103. A row's second
line is "Team · joined 3 weeks ago". Tapping a member opens their contact page
under Contacts. Every size is one 624px column, like Today.

Not built: "has not added a contact yet". It would read the member's own book,
which stays private (#67).
```

- [ ] **Step 4: Full check**

Run: `dart format . && flutter analyze && flutter test`
Expected: format changes nothing unexpected, analyze prints "No issues found!", all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/team/presentation/team_preview.dart test/previews_test.dart docs/design/screens.md
git commit -m "test(team): previews for the Team screen (#102)"
```

- [ ] **Step 6: Push and regenerate goldens through CI**

```bash
git push -u origin feature/102-team-roster
gh workflow run CI --ref feature/102-team-roster -f update-goldens=true
```

Then follow README.md → *Golden tests* for fetching the CI-made PNGs. Open the PR with `Closes #102` in the **Ticket** section only after the user asks.
