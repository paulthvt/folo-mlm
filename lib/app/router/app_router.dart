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
import 'package:material_ui/material_ui.dart';

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
            builder: (context, state) => const TodayPage(),
          ),
          GoRoute(
            path: Routes.settings,
            name: Routes.settingsName,
            builder: (context, state) => const SettingsPage(),
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
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: Routes.login,
        name: Routes.loginName,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.register,
        name: Routes.registerName,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        name: Routes.forgotPasswordName,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.checkInbox,
        name: Routes.checkInboxName,
        builder: (context, state) => CheckInboxPage(
          reason:
              state.uri.queryParameters['reason'] ??
              CheckInboxPage.confirmReason,
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.resetPassword,
        name: Routes.resetPasswordName,
        builder: (context, state) => const ResetPasswordPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

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
      : MaterialPage<void>(key: state.pageKey, name: state.name, child: child);
}
