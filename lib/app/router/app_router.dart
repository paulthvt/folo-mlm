import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/auth_redirect.dart';
import 'package:folo/app/router/page_transitions.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/features/auth/presentation/check_inbox_page.dart';
import 'package:folo/features/auth/presentation/forgot_password_page.dart';
import 'package:folo/features/auth/presentation/login_page.dart';
import 'package:folo/features/auth/presentation/register_page.dart';
import 'package:folo/features/auth/presentation/reset_password_page.dart';
import 'package:folo/features/auth/presentation/welcome_page.dart';
import 'package:folo/features/today/presentation/today_page.dart';
import 'package:go_router/go_router.dart';

/// The app router lives in a provider so that it can watch session state and
/// `redirect` unauthenticated users.
///
/// Still to come: a `StatefulShellRoute` wrapping the authenticated branches, so
/// the shell can render bottom navigation on mobile and a sidebar on desktop
/// (see `ScreenSize.usesSideNavigation`).
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
      GoRoute(
        path: Routes.today,
        name: Routes.todayName,
        pageBuilder: (context, state) =>
            foloPage(context, state, const TodayPage()),
      ),
      GoRoute(
        path: Routes.welcome,
        name: Routes.welcomeName,
        pageBuilder: (context, state) =>
            foloPage(context, state, const WelcomePage(), sharedAxis: true),
      ),
      GoRoute(
        path: Routes.login,
        name: Routes.loginName,
        pageBuilder: (context, state) =>
            foloPage(context, state, const LoginPage(), sharedAxis: true),
      ),
      GoRoute(
        path: Routes.register,
        name: Routes.registerName,
        pageBuilder: (context, state) =>
            foloPage(context, state, const RegisterPage(), sharedAxis: true),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        name: Routes.forgotPasswordName,
        pageBuilder: (context, state) => foloPage(
          context,
          state,
          const ForgotPasswordPage(),
          sharedAxis: true,
        ),
      ),
      GoRoute(
        path: Routes.checkInbox,
        name: Routes.checkInboxName,
        pageBuilder: (context, state) => foloPage(
          context,
          state,
          CheckInboxPage(
            reason:
                state.uri.queryParameters['reason'] ??
                CheckInboxPage.confirmReason,
            email: state.uri.queryParameters['email'] ?? '',
          ),
          sharedAxis: true,
        ),
      ),
      GoRoute(
        path: Routes.resetPassword,
        name: Routes.resetPasswordName,
        pageBuilder: (context, state) => foloPage(
          context,
          state,
          const ResetPasswordPage(),
          sharedAxis: true,
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
