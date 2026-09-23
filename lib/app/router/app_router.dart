import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/features/auth/presentation/login_page.dart';
import 'package:folo/features/auth/presentation/register_page.dart';
import 'package:folo/features/auth/presentation/welcome_page.dart';
import 'package:folo/features/dashboard/presentation/dashboard_page.dart';
import 'package:go_router/go_router.dart';

/// The app router lives in a provider so that, once authentication exists, it
/// can watch session state and `redirect` unauthenticated users.
///
/// Extension points, in the order they will be needed:
///  1. `redirect:` — send signed-out users to `/sign-in` and back again.
///  2. `refreshListenable:` — re-run `redirect` when the session changes.
///  3. A `StatefulShellRoute` wrapping the authenticated branches, so the shell
///     can render bottom navigation on mobile and a sidebar on desktop
///     (see `ScreenSize.usesSideNavigation`).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.dashboard,
    routes: [
      GoRoute(
        path: Routes.dashboard,
        name: Routes.dashboardName,
        builder: (context, state) => const DashboardPage(),
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
    ],
  );
});
