import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/core/ui/section_header.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/settings/presentation/widgets/settings_group.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Settings → Workflows, on the signed-in account's workflows.
class WorkflowsSettings extends ConsumerWidget {
  const WorkflowsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflows = workflowsProvider(ref.watch(accountProvider)?.email);
    final state = ref.watch(workflows);
    final list = state.value;
    if (list == null) {
      return state.hasError
          ? WorkflowsLoadError(onRetry: () => ref.invalidate(workflows))
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            );
    }
    return WorkflowsView(
      workflows: list,
      onOpen: (workflow) => openWorkflow(context, workflow.id),
      onNew: () => unawaited(showNewWorkflow(context)),
    );
  }
}

/// The list, fed its data: one group per stage that has workflows, the
/// default first. Also what the preview shows.
class WorkflowsView extends StatelessWidget {
  const WorkflowsView({
    required this.workflows,
    required this.onOpen,
    required this.onNew,
    super.key,
  });

  final List<Workflow> workflows;
  final ValueChanged<Workflow> onOpen;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.workflowsIntro,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final stage in Stage.values)
          if (forStage(workflows, stage) case final group
              when group.isNotEmpty) ...[
            SectionHeader(title: _stageHeader(l10n, stage)),
            SettingsGroup(
              children: [
                for (final workflow in group)
                  ListTile(
                    title: Text(workflow.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.sm,
                      children: [
                        Text(_steps(l10n, workflow)),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: () => onOpen(workflow),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        FilledButton.tonalIcon(
          onPressed: onNew,
          style: AppTheme.tonal(context),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.workflowsNew),
        ),
      ],
    );
  }

  static String _stageHeader(AppLocalizations l10n, Stage stage) =>
      switch (stage) {
        Stage.prospect => l10n.contactsFilterProspects,
        Stage.customer => l10n.contactsFilterCustomers,
        Stage.team => l10n.contactsFilterTeam,
      };

  static String _steps(AppLocalizations l10n, Workflow workflow) {
    final steps = l10n.followWithSteps(workflow.steps.length);
    return workflow.isDefault ? l10n.workflowsDefaultSteps(steps) : steps;
  }
}

/// The workflows did not load. Existing copy: Next step says the same.
class WorkflowsLoadError extends StatelessWidget {
  const WorkflowsLoadError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l10n.nextStepLoadFailed,
        body: l10n.contactsLoadErrorBody,
        actionLabel: l10n.contactsRetry,
        onAction: onRetry,
      ),
    );
  }
}

/// In the pane in place of the list on desktop; elsewhere pushed, so back
/// returns to the list.
void openWorkflow(BuildContext context, String id) {
  final location = Routes.settingsWorkflowLocation(id);
  if (context.screenSize.isDesktop) {
    context.go(location);
  } else {
    context.push(location);
  }
}

/// Name and stage. Create writes, then opens the editor on the new workflow.
Future<void> showNewWorkflow(BuildContext context) async {
  final created = await FoloDialog.show<Workflow>(
    context,
    (_) => const _NewWorkflowForm(),
  );
  if (created != null && context.mounted) openWorkflow(context, created.id);
}

class _NewWorkflowForm extends ConsumerStatefulWidget {
  const _NewWorkflowForm();

  @override
  ConsumerState<_NewWorkflowForm> createState() => _NewWorkflowFormState();
}

class _NewWorkflowFormState extends ConsumerState<_NewWorkflowForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  Stage _stage = Stage.prospect;
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // A second tap can land before the frame that disables Create.
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final created = await editWorkflows(
        ref,
        (workflows) => workflows.create(_stage, _name.text.trim()),
      );
      if (mounted) Navigator.pop(context, created);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;

    return Form(
      key: _form,
      child: FoloDialog(
        title: l10n.workflowsNew,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.workflowsCreate),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.workflowNameRequired
                  : null,
              decoration: InputDecoration(labelText: l10n.workflowName),
            ),
            SectionHeader(title: l10n.workflowsNewStage),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final stage in Stage.values)
                  ChoiceChip(
                    label: Text(stageLabel(l10n, stage)),
                    selected: _stage == stage,
                    onSelected: (_) => setState(() => _stage = stage),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
