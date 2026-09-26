import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/back.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/folo_avatar.dart';
import 'package:folo/core/ui/folo_top_bar.dart';
import 'package:folo/core/ui/section_header.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/account.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/settings/presentation/account_settings.dart';
import 'package:folo/features/settings/presentation/appearance_settings.dart';
import 'package:folo/features/settings/presentation/language_settings.dart';
import 'package:folo/features/settings/presentation/settings_action.dart';
import 'package:folo/features/settings/presentation/widgets/settings_group.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

enum SettingsSection { account, language, appearance }

/// The Settings list, and one of its sections.
///
/// Desktop shows both: the list on the left, the open section — Account when
/// none is — on the right. Mobile and tablet show one at a time, each section
/// its own screen; a tablet's rail leaves too little room for two panes.
class SettingsPage extends StatelessWidget {
  const SettingsPage({this.section, super.key});

  static const double _listWidth = 400;

  final SettingsSection? section;

  /// Beside the list on desktop; elsewhere pushed, so back returns to it.
  static void open(BuildContext context, SettingsSection section) {
    final location = switch (section) {
      SettingsSection.account => Routes.settingsAccount,
      SettingsSection.language => Routes.settingsLanguage,
      SettingsSection.appearance => Routes.settingsAppearance,
    };
    if (context.screenSize.isDesktop) {
      context.go(location);
    } else {
      context.push(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = context.screenSize;
    final current = section;

    if (size.isDesktop) {
      final shown = current ?? SettingsSection.account;
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: _listWidth,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: FoloColors.of(context).borderSubtle,
                    ),
                  ),
                ),
                child: _Scroll(
                  title: l10n.settingsTitle,
                  child: _SettingsList(selected: shown),
                ),
              ),
              Expanded(child: _Section(section: shown)),
            ],
          ),
        ),
      );
    }

    // Mobile reaches the list by push from a top bar; on a tablet it is a rail
    // destination with nothing to go back to. A section always goes back.
    final canGoBack = size.isMobile || current != null;
    return Scaffold(
      appBar: canGoBack
          ? AppBar(
              leading: BackButton(
                onPressed: () => backOr(
                  context,
                  current == null ? Routes.today : Routes.settings,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: current == null
            ? _Scroll(title: l10n.settingsTitle, child: const _SettingsList())
            : _Section(section: current),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (section) {
      SettingsSection.account => _Scroll(
        title: l10n.settingsSectionAccount,
        child: const AccountSettings(),
      ),
      SettingsSection.language => _Scroll(
        title: l10n.settingsSectionLanguage,
        child: const LanguageSettings(),
      ),
      SettingsSection.appearance => _Scroll(
        title: l10n.settingsSectionAppearance,
        child: const AppearanceSettings(),
      ),
    };
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final desktop = context.screenSize.isDesktop;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: EdgeInsets.all(desktop ? AppSpacing.xl : AppSpacing.md),
          children: [
            FoloTopBar(title: title, large: desktop),
            child,
          ],
        ),
      ),
    );
  }
}

/// Profile, grouped rows, sign out. New settings are new rows in a group.
///
/// Signing out needs no navigation here: the session ends, and the router's
/// redirect takes the user to /welcome.
class _SettingsList extends ConsumerStatefulWidget {
  const _SettingsList({this.selected});

  /// The section open beside the list, on desktop.
  final SettingsSection? selected;

  @override
  ConsumerState<_SettingsList> createState() => _SettingsListState();
}

class _SettingsListState extends ConsumerState<_SettingsList>
    with SettingsAction {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountProvider);
    final selected = widget.selected;
    final error = failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (account != null) ...[
          SettingsGroup(
            children: [
              ListTile(
                selected: selected == SettingsSection.account,
                leading: FoloAvatar(
                  name: account.displayName,
                  size: AvatarSize.row,
                ),
                // One line each: this row only says whose account it is; the
                // full email is on the Account screen.
                title: Text(
                  account.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: account.firstName.isEmpty
                    ? null
                    : Text(
                        account.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    SettingsPage.open(context, SettingsSection.account),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        SectionHeader(title: l10n.settingsSectionPreferences),
        SettingsGroup(
          children: [
            ListTile(
              selected: selected == SettingsSection.language,
              leading: const Icon(Icons.translate_rounded),
              title: Text(l10n.settingsSectionLanguage),
              subtitle: Text(
                account?.locale == null
                    ? l10n.settingsLanguageSystem
                    : l10n.languageName,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => SettingsPage.open(context, SettingsSection.language),
            ),
            ListTile(
              selected: selected == SettingsSection.appearance,
              leading: const Icon(Icons.contrast_rounded),
              title: Text(l10n.settingsSectionAppearance),
              subtitle: Text(
                appearanceLabel(l10n, account?.appearance ?? Appearance.system),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () =>
                  SettingsPage.open(context, SettingsSection.appearance),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (error != null) ...[
          FormError(authFailureCopy(l10n, error)),
          const SizedBox(height: AppSpacing.md),
        ],
        SettingsGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: Text(l10n.settingsSignOut),
              onTap: busy ? null : () => run((auth) => auth.signOut()),
            ),
          ],
        ),
      ],
    );
  }
}
