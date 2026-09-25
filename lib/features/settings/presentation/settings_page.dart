import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/back.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/folo_avatar.dart';
import 'package:folo/core/ui/folo_top_bar.dart';
import 'package:folo/core/ui/section_header.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/l10n/app_localizations.dart';

/// Account, language, sign out, delete account.
///
/// Signing out or deleting needs no navigation here: the session ends, and the
/// router's redirect takes the user to /welcome.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;
  AuthFailure? _failure;

  Future<void> _run(Future<void> Function(AuthRepository) action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await action(ref.read(authRepositoryProvider));
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // ponytail: a dialog on every size; the design wants a bottom sheet on
    // mobile once there is a sheet component.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsDeleteTitle),
        content: Text(l10n.settingsDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) await _run((auth) => auth.deleteAccount());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final account = ref.watch(accountProvider);
    final size = context.screenSize;
    final failure = _failure;

    return Scaffold(
      // Mobile reaches Settings by push from a top bar; elsewhere it is a
      // sidebar destination and there is nothing to go back to.
      appBar: size.usesSideNavigation
          ? null
          : AppBar(
              leading: BackButton(
                onPressed: () => backOr(context, Routes.today),
              ),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: size.isDesktop
                  ? const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.xl,
                    )
                  : const EdgeInsets.all(AppSpacing.md),
              children: [
                FoloTopBar(title: l10n.settingsTitle, large: size.isDesktop),
                if (account != null) ...[
                  SectionHeader(title: l10n.settingsSectionAccount),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: FoloAvatar(
                      name: account.displayName,
                      size: AvatarSize.row,
                    ),
                    title: Text(account.displayName),
                    subtitle: account.firstName.isEmpty
                        ? null
                        : Text(account.email),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                SectionHeader(title: l10n.settingsSectionLanguage),
                _LanguageOption(
                  label: l10n.settingsLanguageSystem,
                  selected: account?.locale == null,
                  onTap: _busy
                      ? null
                      : () => _run((auth) => auth.updateLocale(null)),
                ),
                for (final locale in AppLocalizations.supportedLocales)
                  _LanguageOption(
                    key: ValueKey('language-${locale.languageCode}'),
                    // Each language in its own name, so it can be found by
                    // someone who cannot read the current one.
                    label: lookupAppLocalizations(locale).languageName,
                    selected: account?.locale == locale.languageCode,
                    onTap: _busy
                        ? null
                        : () => _run(
                            (auth) => auth.updateLocale(locale.languageCode),
                          ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (failure != null) ...[
                  FormError(authFailureCopy(l10n, failure)),
                  const SizedBox(height: AppSpacing.md),
                ],
                OutlinedButton(
                  onPressed: _busy ? null : () => _run((a) => a.signOut()),
                  child: Text(l10n.settingsSignOut),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  onPressed: _busy ? null : _confirmDelete,
                  child: Text(l10n.settingsDeleteAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    super.key,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: selected ? const Icon(Icons.check_rounded) : null,
        onTap: onTap,
      ),
    );
  }
}
