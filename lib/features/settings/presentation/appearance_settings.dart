import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/auth/presentation/auth_failure_copy.dart';
import 'package:loomia/features/settings/presentation/settings_action.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_option.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

String appearanceLabel(AppLocalizations l10n, Appearance appearance) =>
    switch (appearance) {
      Appearance.system => l10n.settingsAppearanceSystem,
      Appearance.light => l10n.settingsAppearanceLight,
      Appearance.dark => l10n.settingsAppearanceDark,
    };

/// Light, dark, or whatever the device uses. The app switches as soon as the
/// choice is saved.
class AppearanceSettings extends ConsumerStatefulWidget {
  const AppearanceSettings({super.key});

  @override
  ConsumerState<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends ConsumerState<AppearanceSettings>
    with SettingsAction {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chosen = ref.watch(accountProvider)?.appearance ?? Appearance.system;
    final error = failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          FormError(authFailureCopy(l10n, error)),
          const SizedBox(height: AppSpacing.md),
        ],
        SettingsGroup(
          children: [
            for (final appearance in Appearance.values)
              SettingsOption(
                key: ValueKey('appearance-${appearance.name}'),
                label: appearanceLabel(l10n, appearance),
                selected: chosen == appearance,
                onTap: busy
                    ? null
                    : () => run((a) => a.updateAppearance(appearance)),
              ),
          ],
        ),
      ],
    );
  }
}
