/// Every route path and name in the app. Widgets never write a path literal.
abstract final class Routes {
  static const String today = '/';
  static const String todayName = 'today';

  static const String welcome = '/welcome';
  static const String welcomeName = 'welcome';

  static const String login = '/login';
  static const String loginName = 'login';

  static const String register = '/register';
  static const String registerName = 'register';

  static const String forgotPassword = '/forgot-password';
  static const String forgotPasswordName = 'forgotPassword';

  static const String checkInbox = '/check-inbox';
  static const String checkInboxName = 'checkInbox';

  static const String resetPassword = '/reset-password';
  static const String resetPasswordName = 'resetPassword';

  /// Reachable without a session. `/reset-password` is not in this set: it is
  /// reached by a deep link that has already signed the user in.
  static const Set<String> authPaths = {
    welcome,
    login,
    register,
    forgotPassword,
    checkInbox,
  };

  /// `/check-inbox` carries its copy in the query string rather than a router
  /// `extra`, so reloading the page on web does not land on an empty screen.
  static String checkInboxLocation({
    required String reason,
    required String email,
  }) => Uri(
    path: checkInbox,
    queryParameters: {'reason': reason, 'email': email},
  ).toString();
}
