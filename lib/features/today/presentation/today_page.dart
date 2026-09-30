import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/today/presentation/today_hero.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The home. Everything else in the product is support (design principle #1).
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  /// People whose tick is in flight: their button is gone, so a second tap
  /// can't tick the next step too.
  final Set<String> _busy = {};

  Future<void> _tick(Due due) async {
    final id = due.person.id;
    if (!_busy.add(id)) return;
    setState(() {});
    try {
      await writePeople(
        context,
        ref,
        (people) => people.completeStep(due.person, due.step, today()),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final book = peopleProvider(account?.email);
    final lists = workflowsProvider(account?.email);
    final people = ref.watch(book);
    final workflows = ref.watch(lists);

    return TodayView(
      // `.value` survives a failed refresh, so the rows stay on screen.
      due: switch ((people.value, workflows.value)) {
        (final everyone?, final all?) => AsyncData(
          dueToday(everyone, all, today()),
        ),
        _ when people.hasError => AsyncError(
          people.error!,
          people.stackTrace ?? StackTrace.empty,
        ),
        _ when workflows.hasError => AsyncError(
          workflows.error!,
          workflows.stackTrace ?? StackTrace.empty,
        ),
        _ => const AsyncLoading(),
      },
      now: DateTime.now(),
      firstName: account?.firstName ?? '',
      // With a sidebar, Settings is its account block instead.
      accountAction: context.screenSize.usesSideNavigation
          ? IconButton(
              onPressed: () => refreshPeople(context, ref),
              tooltip: AppLocalizations.of(context).contactsRefresh,
              icon: const Icon(Icons.refresh_rounded),
            )
          : const AccountButton(),
      busy: _busy,
      onTick: (due) => unawaited(_tick(due)),
      onOpen: (person) => openContact(context, person.id),
      onRetry: () {
        if (people.hasError) ref.invalidate(book);
        if (workflows.hasError) ref.invalidate(lists);
      },
      onRefresh: () => refreshPeople(context, ref),
    );
  }
}

/// "Good morning, Pauline" from the device clock: morning before noon,
/// afternoon before 6 pm, evening after. Without a first name, no comma.
String greeting(AppLocalizations l10n, DateTime now, String firstName) {
  final part = now.hour < 12
      ? 'morning'
      : now.hour < 18
      ? 'afternoon'
      : 'evening';
  final name = firstName.trim();
  return name.isEmpty
      ? l10n.todayGreeting(part)
      : l10n.todayGreetingNamed(part, name);
}

/// The screen as a function of its inputs, so it can be previewed and tested
/// without providers. One column on every size.
class TodayView extends StatefulWidget {
  const TodayView({
    required this.due,
    required this.now,
    required this.firstName,
    required this.onTick,
    required this.onOpen,
    required this.onRetry,
    required this.onRefresh,
    this.busy = const {},
    this.accountAction,
    super.key,
  });

  final AsyncValue<List<Due>> due;

  /// The device clock: the date, the greeting, and which steps are late.
  final DateTime now;

  /// Empty when the account has none: the greeting goes without.
  final String firstName;

  /// Ids of people whose tick is in flight.
  final Set<String> busy;

  final void Function(Due due) onTick;
  final void Function(Person person) onOpen;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  /// Top-bar entry to Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  /// Per `docs/design/responsive-design.md`: the priority column's width.
  static const double _column = 624;

  /// "And N more waiting" was tapped. Resets on leaving Today.
  bool _expanded = false;

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
              onRefresh: widget.onRefresh,
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
                    eyebrow: l10n.todayDate(widget.now),
                    title: greeting(l10n, widget.now, widget.firstName),
                    large: desktop,
                    action: widget.accountAction,
                    gap: AppSpacing.sm,
                  ),
                  ...switch (widget.due) {
                    AsyncData(:final value) when value.isEmpty => const [
                      _UpToDate(),
                    ],
                    AsyncData(:final value) => _due(l10n, value, desktop),
                    AsyncError() => [_Failed(onRetry: widget.onRetry)],
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

  List<Widget> _due(AppLocalizations l10n, List<Due> due, bool desktop) {
    final shown = _expanded ? due : due.take(desktop ? 6 : 5).toList();
    final now = widget.now;
    final day = DateTime(now.year, now.month, now.day);
    return [
      TodayHero(
        eyebrow: l10n.todayTitle,
        headline: l10n.todayHeadline(due.length),
      ),
      SizedBox(height: desktop ? AppSpacing.xl : AppSpacing.lg),
      SectionHeader(title: l10n.todaySectionPriority),
      for (final (index, row) in shown.indexed) ...[
        if (index > 0) const SizedBox(height: AppSpacing.ms),
        _row(l10n, row, day),
      ],
      if (shown.length < due.length) ...[
        const SizedBox(height: AppSpacing.ms),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => setState(() => _expanded = true),
            child: Text(l10n.todayShowMore(due.length - shown.length)),
          ),
        ),
      ],
    ];
  }

  Widget _row(AppLocalizations l10n, Due due, DateTime day) {
    final (:person, :step) = due;
    return ActionItem(
      name: person.name,
      reason: l10n.todayReason(
        step.step.label,
        step.workflow.name,
        step.index,
        step.total,
      ),
      // The accent chip only when a real date drives it: late.
      chip: step.due.isBefore(day)
          ? DateChip(dueLabel(l10n, step.due, day))
          : null,
      onOpen: () => widget.onOpen(person),
      onResolve: widget.busy.contains(person.id)
          ? null
          : () => widget.onTick(due),
      resolveLabel: l10n.nextStepMarkDone(step.step.label),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: l10n.todayLoadFailed,
      body: l10n.contactsLoadErrorBody,
      actionLabel: l10n.contactsRetry,
      onAction: onRetry,
    );
  }
}

class _UpToDate extends StatelessWidget {
  const _UpToDate();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.wb_twilight_rounded,
      title: l10n.todayEmptyTitle,
      body: l10n.todayEmptyBody,
    );
  }
}
