import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/settings/presentation/widgets/settings_scroll.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
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
    final workflows = workflowsProvider(ref.watch(accountProvider)?.email);
    final state = ref.watch(workflows);
    final list = state.value;
    final workflow = list == null ? null : findWorkflow(list, id);

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
      ),
    );
  }
}

/// What a write in flight disables: the control that started it.
enum _Control { name }

/// The editor, fed the saved workflow and one callback per write; each
/// callback throws `PeopleFailure`. Also what the preview shows.
class WorkflowEditorView extends StatefulWidget {
  const WorkflowEditorView({
    required this.workflow,
    required this.onRename,
    super.key,
  });

  final Workflow workflow;

  /// A trimmed name, different from the saved one.
  final Future<void> Function(String name) onRename;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      ],
    );
  }
}
