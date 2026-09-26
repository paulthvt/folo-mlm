import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/settings/presentation/settings_action.dart';
import 'package:folo/features/settings/presentation/widgets/settings_group.dart';
import 'package:folo/l10n/app_localizations.dart';

/// The languages the app can be shown in, as a list rather than a dropdown so
/// it grows with them.
///
/// ponytail: no search field yet; the design adds one past about 10 languages.
class LanguageSettings extends ConsumerStatefulWidget {
  const LanguageSettings({super.key});

  @override
  ConsumerState<LanguageSettings> createState() => _LanguageSettingsState();
}

class _LanguageSettingsState extends ConsumerState<LanguageSettings>
    with SettingsAction {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chosen = ref.watch(accountProvider)?.locale;
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
            _LanguageOption(
              label: l10n.settingsLanguageSystem,
              selected: chosen == null,
              onTap: busy ? null : () => run((a) => a.updateLocale(null)),
            ),
            for (final locale in AppLocalizations.supportedLocales)
              _LanguageOption(
                key: ValueKey('language-${locale.languageCode}'),
                // Each language in its own name, so it can be found by someone
                // who cannot read the current one; its name in the current one
                // under it.
                label: lookupAppLocalizations(locale).languageName,
                translation: l10n.settingsLanguageNameIn(locale.languageCode),
                selected: chosen == locale.languageCode,
                onTap: busy
                    ? null
                    : () => run((a) => a.updateLocale(locale.languageCode)),
              ),
          ],
        ),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.translation = '',
    super.key,
  });

  final String label;

  /// Hidden when empty or the same as [label].
  final String translation;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final showTranslation = translation.isNotEmpty && translation != label;
    return Semantics(
      selected: selected,
      child: ListTile(
        title: Text(label),
        subtitle: showTranslation ? Text(translation) : null,
        trailing: selected ? const Icon(Icons.check_rounded) : null,
        onTap: onTap,
      ),
    );
  }
}
