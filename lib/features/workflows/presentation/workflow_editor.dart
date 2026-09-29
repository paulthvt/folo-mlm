import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/back.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_typography.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/section_header.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/settings/presentation/widgets/settings_group.dart';
import 'package:folo/features/settings/presentation/widgets/settings_scroll.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/step_sheet.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/features/workflows/presentation/workflows_settings.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// One workflow, found in the loaded list (there is no second fetch), wired
/// to saving.
class WorkflowEditor extends ConsumerWidget {
  const WorkflowEditor({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final owner = ref.watch(accountProvider)?.email;
    final workflows = workflowsProvider(owner);
    final state = ref.watch(workflows);
    final list = state.value;
    final workflow = list == null ? null : findWorkflow(list, id);

    // Keeps the people loaded: Delete counts who follows this workflow, and
    // every write reloads them (see WorkflowsController.edit).
    ref.listen(peopleProvider(owner), (_, _) {});

    if (workflow == null) {
      // Still loading, or reloading right after New workflow created it.
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (list == null) {
        return WorkflowsLoadError(onRetry: () => ref.invalidate(workflows));
      }
      // Deleted elsewhere, or a bad link.
      return Center(
        child: EmptyState(
          icon: Icons.route_rounded,
          title: l10n.workflowMissingTitle,
          body: l10n.workflowMissingBody,
          actionLabel: l10n.workflowBackToList,
          onAction: () => context.go(Routes.settingsWorkflows),
        ),
      );
    }

    return SettingsScroll(
      eyebrow: stageLabel(l10n, workflow.stage),
      title: workflow.name,
      child: WorkflowEditorView(
        workflow: workflow,
        onRename: (name) => editWorkflows(
          ref,
          (repository) => repository.rename(workflow.id, name),
        ),
        onAddStep: () => unawaited(showStepSheet(context, workflow)),
        onOpenStep: (index) =>
            unawaited(showStepSheet(context, workflow, index: index)),
        onMove: (step, position) => editWorkflows(
          ref,
          (repository) => repository.moveStep(step.id, position),
        ),
        onDefault: (on) => editWorkflows(
          ref,
          (repository) => repository.setDefault(workflow.id, on),
        ),
        onDelete: () => _delete(context, ref, workflow),
      ),
    );
  }

  /// Asks first, saying who follows it; then deletes and returns to the list.
  static Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Workflow workflow,
  ) async {
    final l10n = AppLocalizations.of(context);
    final people =
        ref.read(peopleProvider(ref.read(accountProvider)?.email)).value ??
        const [];
    final followers = people
        .where((person) => person.place?.workflowId == workflow.id)
        .length;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.workflowDeleteTitle(workflow.name),
      action: l10n.workflowDeleteConfirm,
      body: l10n.workflowDeleteBody(followers),
    );
    if (!confirmed || !context.mounted) return;
    await editWorkflows(ref, (repository) => repository.delete(workflow.id));
    if (context.mounted) backOr(context, Routes.settingsWorkflows);
  }
}

/// What a write in flight disables: the control that started it.
enum _Control { name, steps, isDefault, delete }

/// The editor, fed the saved workflow and one callback per write; each
/// write callback throws `PeopleFailure`. Nothing is optimistic: a dropped
/// step shows in its saved place until the reload lands. Also what the
/// preview shows.
class WorkflowEditorView extends StatefulWidget {
  const WorkflowEditorView({
    required this.workflow,
    required this.onRename,
    required this.onAddStep,
    required this.onOpenStep,
    required this.onMove,
    required this.onDefault,
    required this.onDelete,
    super.key,
  });

  final Workflow workflow;

  /// A trimmed name, different from the saved one.
  final Future<void> Function(String name) onRename;
  final VoidCallback onAddStep;
  final ValueChanged<int> onOpenStep;

  /// [step] goes to [position], among the others' saved positions.
  final Future<void> Function(WorkflowStep step, num position) onMove;
  final Future<void> Function(bool on) onDefault;

  /// Asks first; does nothing when the user cancels.
  final Future<void> Function() onDelete;

  @override
  State<WorkflowEditorView> createState() => _WorkflowEditorViewState();
}

class _WorkflowEditorViewState extends State<WorkflowEditorView> {
  late final _name = TextEditingController(text: widget.workflow.name);
  final _nameFocus = FocusNode();
  final Set<_Control> _busy = {};
  String? _written;
  WorkflowsController? _notifier;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) unawaited(_saveName());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_notifier == null && mounted) {
      final container = ProviderScope.containerOf(context);
      final email = container.read(accountProvider)?.email;
      if (email != null) {
        _notifier = container.read(workflowsProvider(email).notifier);
      }
    }
  }

  @override
  void didUpdateWidget(WorkflowEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reload brought a name saved here or elsewhere; never under the
    // user's fingers.
    if (!_nameFocus.hasFocus && widget.workflow.name != _name.text) {
      _name.text = widget.workflow.name;
    }
    // Clear written if the workflow name changed (saved elsewhere or failed).
    if (widget.workflow.name != oldWidget.workflow.name) {
      _written = null;
    }
  }

  @override
  void deactivate() {
    // Save before dispose() clears the focus listener: the user typed a name
    // and is leaving. Empty or unchanged names write nothing.
    final saved = widget.workflow.name;
    final name = _name.text.trim();
    final notifier = _notifier;
    if (name.isNotEmpty &&
        name != saved &&
        name != _written &&
        !_busy.contains(_Control.name) &&
        notifier != null) {
      _written = name;
      // ponytail: failure after leaving can't show (no SnackBar on dead context)
      unawaited(
        notifier.edit(
          (repository) => repository.rename(widget.workflow.id, name),
        ),
      );
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Runs [write] unless [control] is already writing, and says so when it
  /// fails. Returns whether it saved.
  Future<bool> _run(_Control control, Future<void> Function() write) async {
    if (_busy.contains(control)) return false;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy.add(control));
    try {
      await write();
      return true;
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _busy.remove(control));
    }
  }

  Future<void> _saveName() async {
    final saved = widget.workflow.name;
    final name = _name.text.trim();
    // Empty, unchanged, or already written: put the saved name back, write nothing.
    if (name.isEmpty || name == saved || name == _written) {
      _name.text = saved;
      return;
    }
    _name.text = name;
    _written = name;
    final ok = await _run(_Control.name, () => widget.onRename(name));
    if (!ok) {
      _written = null;
      if (mounted) _name.text = widget.workflow.name;
    }
  }

  /// [from] and [to] are indexes in the saved order, [to] counted once [from]
  /// is out of the list: what `onReorderItem` gives, drag or Move down alike.
  void _reorder(int from, int to) {
    final steps = widget.workflow.steps;
    final rest = [...steps]..removeAt(from);
    unawaited(
      _run(
        _Control.steps,
        () => widget.onMove(steps[from], positionAt(rest, to)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final workflow = widget.workflow;
    final steps = workflow.steps;
    final moving = _busy.contains(_Control.steps);
    final error = theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          focusNode: _nameFocus,
          readOnly: _busy.contains(_Control.name),
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: l10n.workflowName),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: l10n.workflowSteps,
          actionLabel: l10n.workflowAddStep,
          onAction: widget.onAddStep,
        ),
        SettingsGroup(
          children: [
            if (steps.isEmpty)
              ListTile(title: Text(l10n.workflowNoSteps))
            else
              // Also gives each row Move up / Move down semantics actions.
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: steps.length,
                onReorderItem: _reorder,
                itemBuilder: (context, index) {
                  final step = steps[index];
                  return ListTile(
                    key: ValueKey(step.id),
                    leading: _NumberBadge(index + 1),
                    title: Text(step.label),
                    subtitle: Text(
                      index == 0 && step.days == 0
                          ? l10n.workflowStepWhenYouStart
                          : l10n.workflowStepDaysAfter(step.days),
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      enabled: !moving,
                      child: const Icon(Icons.drag_handle_rounded),
                    ),
                    onTap: () => widget.onOpenStep(index),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroup(
          children: [
            SwitchListTile(
              value: workflow.isDefault,
              title: Text(l10n.workflowDefaultFor(workflow.stage.name)),
              onChanged: _busy.contains(_Control.isDefault)
                  ? null
                  : (on) => unawaited(
                      _run(_Control.isDefault, () => widget.onDefault(on)),
                    ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.workflowFooter,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.workflowDelete),
              textColor: error,
              iconColor: error,
              onTap: _busy.contains(_Control.delete)
                  ? null
                  : () => unawaited(_run(_Control.delete, widget.onDelete)),
            ),
          ],
        ),
      ],
    );
  }
}

/// A step's number, in a small circle.
class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final folo = FoloColors.of(context);
    return Container(
      width: AppSpacing.xl,
      height: AppSpacing.xl,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: folo.primaryMuted,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: AppTypography.label.copyWith(color: folo.primaryText),
      ),
    );
  }
}
