import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/back.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/activity_item.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/core/ui/folo_top_bar.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/contacts_page.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// A person's whole workflow, top to bottom: the steps before the current one
/// greyed, the current one ticked from here as from the card. Greyed means
/// "before", not "done": the history keeps no step ids to tell.
class WorkflowTimelinePage extends ConsumerStatefulWidget {
  const WorkflowTimelinePage({required this.id, super.key});

  final String id;

  @override
  ConsumerState<WorkflowTimelinePage> createState() =>
      _WorkflowTimelinePageState();
}

class _WorkflowTimelinePageState extends ConsumerState<WorkflowTimelinePage> {
  /// A write is in flight, as on the card.
  bool _busy = false;

  Future<void> _run(
    Future<void> Function(PeopleController people) write,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    await writePeople(context, ref, write);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(accountProvider)?.email;
    final book = peopleProvider(owner);
    final people = ref.watch(book);
    final workflows = workflowsProvider(owner);
    final list = ref.watch(workflows);

    final l10n = AppLocalizations.of(context);
    final Widget body;
    if (people.value case final loaded?) {
      final person = loaded.where((p) => p.id == widget.id).firstOrNull;
      final workflow = findWorkflow(
        list.value ?? const [],
        person?.place?.workflowId,
      );
      body = switch ((person, workflow)) {
        (final person?, final workflow?) => _timeline(person, workflow),
        (null, _) => _Gone(
          title: l10n.contactMissingTitle,
          body: l10n.contactMissingBody,
          action: l10n.contactBackToContacts,
          onAction: () => context.go(Routes.contacts),
        ),
        _ when list.isLoading => const Center(
          child: CircularProgressIndicator(),
        ),
        _ when list.hasError => _Gone(
          title: l10n.nextStepLoadFailed,
          body: l10n.contactsLoadErrorBody,
          action: l10n.contactsRetry,
          onAction: () => ref.invalidate(workflows),
        ),
        // Taken off the workflow, or it was deleted, elsewhere.
        (final person?, _) => _Gone(
          title: l10n.nextStepNothingPlanned,
          body: l10n.workflowTimelineGoneBody(firstName(person)),
          action: l10n.workflowTimelineBackTo(firstName(person)),
          onAction: () => backOr(context, Routes.contactLocation(widget.id)),
        ),
      };
    } else {
      body = people.hasError
          ? PeopleLoadError(onRetry: () => ref.invalidate(book))
          : const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => backOr(context, Routes.contactLocation(widget.id)),
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _timeline(Person person, Workflow workflow) {
    final l10n = AppLocalizations.of(context);
    final steps = workflow.steps;
    final progress = progressOf(person, workflow);
    // Done: every step is behind.
    final current = switch (person.currentStepId) {
      final id? => steps.indexWhere((step) => step.id == id),
      null => steps.length,
    };
    final paused = person.pausedAt;
    final now = today();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        FoloTopBar(
          eyebrow: current < steps.length
              ? l10n.workflowTimelineStep(
                  person.name,
                  current + 1,
                  steps.length,
                )
              : l10n.workflowTimelineDone(person.name),
          title: workflow.name,
        ),
        for (final (index, step) in steps.indexed)
          if (index != current)
            ActivityItem(
              title: step.label,
              meta: l10n.workflowTimelineDaysLater(step.days),
              showRailLine: index < steps.length - 1,
              dimmed: index < current,
            )
          else
            _Current(
              item: ActivityItem(
                title: step.label,
                meta: switch ((paused, progress)) {
                  (final since?, _) => l10n.nextStepPausedSince(
                    since.toLocal(),
                  ),
                  (_, final OnStep on) => _dueWithNote(l10n, on, now),
                  _ => l10n.workflowTimelineDaysLater(step.days),
                },
                showRailLine: index < steps.length - 1,
              ),
              action: switch ((paused, progress)) {
                (_?, _) => TextButton(
                  onPressed: _busy
                      ? null
                      : () => unawaited(
                          _run((people) => people.resume(person, today())),
                        ),
                  child: Text(l10n.contactResume),
                ),
                (_, final OnStep on) => IconButton(
                  onPressed: _busy
                      ? null
                      : () => unawaited(
                          _run(
                            (people) =>
                                people.completeStep(person, on, today()),
                          ),
                        ),
                  tooltip: l10n.nextStepMarkDone(step.label),
                  icon: const Icon(Icons.check_rounded),
                ),
                _ => null,
              },
            ),
      ],
    );
  }

  static String _dueWithNote(AppLocalizations l10n, OnStep on, DateTime now) {
    final due = dueLabel(l10n, on.due, now);
    return switch (on.step.note) {
      final note? => l10n.nextStepWithNote(due, note),
      null => due,
    };
  }
}

/// The current step, on the selected-row wash, its action beside it.
class _Current extends StatelessWidget {
  const _Current({required this.item, required this.action});

  final Widget item;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final button = action;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FoloColors.of(context).primaryMuted,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.ms,
          top: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: item),
            ?button,
          ],
        ),
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: EmptyState(
        icon: Icons.route_outlined,
        title: title,
        body: body,
        actionLabel: action,
        onAction: onAction,
      ),
    ),
  );
}
