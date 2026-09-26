import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/auth_redirect.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/shell/app_shell.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/features/auth/presentation/check_inbox_page.dart';
import 'package:folo/features/auth/presentation/forgot_password_page.dart';
import 'package:folo/features/auth/presentation/login_page.dart';
import 'package:folo/features/auth/presentation/register_page.dart';
import 'package:folo/features/auth/presentation/reset_password_page.dart';
import 'package:folo/features/auth/presentation/welcome_page.dart';
import 'package:folo/features/settings/presentation/settings_page.dart';
import 'package:folo/features/today/presentation/today_page.dart';
import 'package:go_router/go_router.dart';

/// The app router lives in a provider so that it can watch session state and
/// `redirect` unauthenticated users.
///
/// Signed-in screens sit inside a `ShellRoute` so [AppShell] draws the sidebar
/// around them. A plain `ShellRoute` is enough while Today is the only
/// destination; a `StatefulShellRoute` (one stack per tab) comes with the second.
final routerProvider = Provider<GoRouter>((ref) {
  final status = ref.watch(authStatusProvider);

  final router = GoRouter(
    initialLocation: Routes.today,
    // `Supabase.initialize` has already restored any stored session, so the
    // first redirect knows the answer and no auth screen flashes on launch.
    refreshListenable: status,
    redirect: (context, state) => authRedirect(
      hasSession: status.hasSession,
      recoveringPassword: status.recoveringPassword,
      location: state.matchedLocation,
    ),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.today,
            name: Routes.todayName,
            pageBuilder: (context, state) => _page(state, const TodayPage()),
          ),
          GoRoute(
            path: Routes.settings,
            name: Routes.settingsName,
            pageBuilder: (context, state) => _page(state, const SettingsPage()),
            routes: [
              GoRoute(
                path: Routes.settingsAccountSegment,
                name: Routes.settingsAccountName,
                pageBuilder: (context, state) =>
                    _settingsPage(context, state, SettingsSection.account),
              ),
              GoRoute(
                path: Routes.settingsLanguageSegment,
                name: Routes.settingsLanguageName,
                pageBuilder: (context, state) =>
                    _settingsPage(context, state, SettingsSection.language),
              ),
              GoRoute(
                path: Routes.settingsAppearanceSegment,
                name: Routes.settingsAppearanceName,
                pageBuilder: (context, state) =>
                    _settingsPage(context, state, SettingsSection.appearance),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.welcome,
        name: Routes.welcomeName,
        pageBuilder: (context, state) => _page(state, const WelcomePage()),
      ),
      GoRoute(
        path: Routes.login,
        name: Routes.loginName,
        pageBuilder: (context, state) => _page(state, const LoginPage()),
      ),
      GoRoute(
        path: Routes.register,
        name: Routes.registerName,
        pageBuilder: (context, state) => _page(state, const RegisterPage()),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        name: Routes.forgotPasswordName,
        pageBuilder: (context, state) =>
            _page(state, const ForgotPasswordPage()),
      ),
      GoRoute(
        path: Routes.checkInbox,
        name: Routes.checkInboxName,
        pageBuilder: (context, state) => _page(
          state,
          CheckInboxPage(
            reason:
                state.uri.queryParameters['reason'] ??
                CheckInboxPage.confirmReason,
            email: state.uri.queryParameters['email'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: Routes.resetPassword,
        name: Routes.resetPasswordName,
        pageBuilder: (context, state) =>
            _page(state, const ResetPasswordPage()),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Every route names its page instead of letting go_router pick one.
///
/// go_router decides between `MaterialPage`, `CupertinoPage` and
/// `NoTransitionPage` by looking for a `MaterialApp` ancestor — but the one it
/// looks for comes from `package:material_ui`, a different class from the
/// `flutter/material` one this app builds. The check therefore always fails and
/// every route silently loses its transition. Naming `MaterialPage` restores the
/// platform's own transition: the Cupertino slide and edge swipe on iOS, the
/// zoom on Android (`docs/design/design-system.md` §7.2).
MaterialPage<void> _page(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, name: state.name, child: child);

/// On desktop a section only swaps the right-hand pane beside a list that stays
/// put; the platform transition would slide the whole screen in instead.
Page<void> _settingsPage(
  BuildContext context,
  GoRouterState state,
  SettingsSection section,
) {
  final child = SettingsPage(section: section);
  return context.screenSize.isDesktop
      ? NoTransitionPage<void>(
          key: state.pageKey,
          name: state.name,
          child: child,
        )
      : _page(state, child);
}
