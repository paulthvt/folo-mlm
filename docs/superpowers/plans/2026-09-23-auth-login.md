# Auth — Supabase, sign-in and registration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the app's first feature — Supabase-backed sign-in, registration,
email confirmation, password reset, session persistence, a route guard and sign
out.

**Architecture:** One new dependency (`supabase_flutter`), initialised in
`main()` before `runApp`. A single `AuthRepository` in
`features/auth/data/` is the only file that imports `supabase_flutter`; it
translates every error into a `domain/AuthFailure` so no Supabase type reaches
`presentation`. Six stateless-by-default screens own their own submit state in
`setState`; shared session state lives in an `AuthStatus` `ChangeNotifier` that
the router uses as `refreshListenable` plus a pure `authRedirect` function.

**Tech Stack:** Flutter, Dart, `flutter_riverpod`, `go_router`,
`supabase_flutter` 2.17.2. No codegen.

**Spec:** [docs/superpowers/specs/2026-09-23-auth-login-design.md](../specs/2026-09-23-auth-login-design.md)

## Global Constraints

- **Adding a dependency requires a reason stated in the pubspec comment next to
  it.** Exactly one dependency is added by this plan: `supabase_flutter`.
- No codegen. No `--dart-define-from-file`. No `.env`.
- Client key is the publishable key `sb_publishable_bsLrMyEAUZDcUjDeLj_xNA_D_TzK2NY`,
  committed in `lib/core/supabase/supabase_config.dart`. **The service-role key
  never enters the repo, the client, or any config file.**
- Project URL: `https://cskjeqspecsyqioietrj.supabase.co`. Deep-link redirect:
  `io.supabase.folo://login-callback/`.
- Imports are always `package:folo/...` (`always_use_package_imports`).
- Layering `presentation → domain ← data`. `presentation` must never import from
  `data` except the repository provider.
- Never hard-code a colour, radius, font size or spacing value in a widget. Use
  `Theme.of(context).colorScheme`, `FoloColors.of(context)`, `AppSpacing.*`,
  `AppRadii.*`, `Theme.of(context).textTheme` / `AppTypography.*`.
- Branch on `context.screenSize`, never on raw pixel widths.
- Add the path to `lib/app/router/routes.dart` before the `GoRoute`. No path
  literals in widgets.
- No MLM language anywhere in copy or naming. No "recruit", no ranks, no
  leaderboards.
- A failed sign-in never says which field was wrong and never reveals whether an
  account exists: `Email or password is incorrect.`
- `/forgot-password` always confirms identically — *"If an account exists for
  that address, we sent a link."* — success or failure.
- Tests never hit the live project. Every widget test uses a fake
  `AuthRepository` injected with `authRepositoryProvider.overrideWithValue`.
- `dart format .`, `flutter analyze` ("No issues found!") and `flutter test`
  pass before the PR.
- Conventional Commits. Branch `feature/21-auth-login`. PR closes #21.

## Review Focus

1. **Email typed with leading/trailing space or capitals** — `" Pauline@Example.COM "`
   must sign in the same account as `pauline@example.com`. Test in Task 3
   (`normalizeEmail`) and Task 7 (login page passes the normalized value).
2. **Submit tapped twice before the first request returns** — the second tap
   must not fire a second request. Test in Task 5 (`SubmitButton` is disabled
   while `busy`).
3. **Request outlives the screen** — the user taps back while the sign-in
   request is in flight; `setState` after dispose must not throw. Test in
   Task 7 (pump a completer, pop the route, complete it).
4. **Recovery deep link opened while already signed in as someone else** — the
   `passwordRecovery` event must win over the "session, so leave the auth
   routes" rule. Test in Task 11 (`authRedirect` with
   `hasSession: true, recoveringPassword: true`).
5. **Resend tapped repeatedly on `/check-inbox`** — the rate-limit failure must
   render as `Too many attempts. Try again in a few minutes.` and not as
   `Something went wrong.` Test in Task 9 (fake throws `AuthFailure.rateLimited`).

---

## File Structure

```
pubspec.yaml                                      modify: + supabase_flutter
lib/main.dart                                     modify: async, Supabase.initialize
lib/core/supabase/supabase_config.dart            create: URL, publishable key, redirect URL
lib/core/supabase/supabase_provider.dart          create: Provider<SupabaseClient>
lib/features/auth/domain/auth_failure.dart         create: enum AuthFailure
lib/features/auth/domain/auth_validation.dart      create: pure validators + normalizeEmail
lib/features/auth/data/auth_failure_mapping.dart   create: Object -> AuthFailure
lib/features/auth/data/auth_repository.dart        create: the only supabase_flutter importer
lib/features/auth/presentation/auth_failure_copy.dart      create: AuthFailure -> copy
lib/features/auth/presentation/widgets/auth_scaffold.dart  create
lib/features/auth/presentation/widgets/form_error.dart     create
lib/features/auth/presentation/widgets/submit_button.dart  create
lib/features/auth/presentation/widgets/password_field.dart create
lib/features/auth/presentation/welcome_page.dart           create
lib/features/auth/presentation/login_page.dart             create
lib/features/auth/presentation/register_page.dart          create
lib/features/auth/presentation/forgot_password_page.dart   create
lib/features/auth/presentation/check_inbox_page.dart       create
lib/features/auth/presentation/reset_password_page.dart    create
lib/app/router/auth_redirect.dart                  create: pure redirect + AuthStatus
lib/app/router/routes.dart                         modify: 6 paths + names
lib/app/router/app_router.dart                     modify: routes, redirect, refreshListenable
lib/features/dashboard/presentation/dashboard_page.dart    modify: sign out action
android/app/src/main/AndroidManifest.xml           modify: intent filter
ios/Runner/Info.plist                              modify: CFBundleURLTypes
docs/architecture.md, README.md                    modify: the new dependency and folder
```

Tests mirror `lib/` under `test/`, one file per unit above that has behaviour.

---

### Task 1: Supabase dependency and bootstrap

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/supabase/supabase_config.dart`
- Create: `lib/core/supabase/supabase_provider.dart`
- Modify: `lib/main.dart`
- Test: `test/core/supabase/supabase_config_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `SupabaseConfig.url`, `SupabaseConfig.publishableKey`,
  `SupabaseConfig.redirectUrl` (all `static const String`);
  `supabaseClientProvider` (`Provider<SupabaseClient>`).

- [ ] **Step 1: Write the failing test**

`test/core/supabase/supabase_config_test.dart` — this test exists to keep a
secret out of the repo, which is why it asserts on the shape of the key:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/core/supabase/supabase_config.dart';

void main() {
  test('url points at the Folo project', () {
    expect(SupabaseConfig.url, 'https://cskjeqspecsyqioietrj.supabase.co');
  });

  test('the committed key is a publishable key, never a secret', () {
    expect(SupabaseConfig.publishableKey, startsWith('sb_publishable_'));
    // A service-role or legacy anon key is a JWT: three dot-separated parts.
    expect(SupabaseConfig.publishableKey.split('.').length, 1);
    expect(SupabaseConfig.publishableKey, isNot(contains('service_role')));
  });

  test('the redirect url matches the registered deep link', () {
    expect(SupabaseConfig.redirectUrl, 'io.supabase.folo://login-callback/');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/supabase/supabase_config_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'folo' … supabase_config.dart` (file does not exist).

- [ ] **Step 3: Add the dependency**

In `pubspec.yaml`, under `dependencies:` after `go_router`:

```yaml
  # Auth, session persistence and email/OAuth deep links in one package, so
  # this feature needs no app_links, shared_preferences or provider SDKs.
  supabase_flutter: ^2.17.2
```

Run: `flutter pub get`

- [ ] **Step 4: Write the config and the provider**

`lib/core/supabase/supabase_config.dart`:

```dart
/// Supabase project coordinates for the client.
///
/// These are deliberately committed. The publishable key is designed to be
/// public and ships inside every binary anyway; Row Level Security is the
/// actual boundary. The service-role key never appears here, in the client, or
/// in any config file.
abstract final class SupabaseConfig {
  static const String url = 'https://cskjeqspecsyqioietrj.supabase.co';

  /// Modern publishable key, not the legacy anon JWT — those stop working at
  /// the end of 2026. `Supabase.initialize` still calls the parameter
  /// `anonKey`; the name is historical, the key type is not.
  static const String publishableKey =
      'sb_publishable_bsLrMyEAUZDcUjDeLj_xNA_D_TzK2NY';

  /// Where email confirmation, password recovery and OAuth come back to.
  /// Registered in the project's allowed redirect URLs, in the Android intent
  /// filter and in `Info.plist`.
  static const String redirectUrl = 'io.supabase.folo://login-callback/';
}
```

`lib/core/supabase/supabase_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The initialised client. `Supabase.initialize` runs in `main()`, so reading
/// this provider before that completes is a programming error, not a state to
/// handle.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
```

- [ ] **Step 5: Initialise Supabase in `main()`**

`lib/main.dart` becomes:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/app.dart';
import 'package:folo/core/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restores a stored session before the first frame, so the router's first
  // redirect already knows the answer and no auth screen flashes on launch.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
  runApp(const ProviderScope(child: FoloApp()));
}
```

- [ ] **Step 6: Run the tests and the analyzer**

Run: `dart format . && flutter analyze && flutter test`
Expected: format clean, "No issues found!", all tests pass.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/supabase lib/main.dart test/core/supabase
git commit -m "feat(auth): add supabase_flutter and initialise the client"
```

---

### Task 2: `AuthFailure` and the exception mapping

**Files:**
- Create: `lib/features/auth/domain/auth_failure.dart`
- Create: `lib/features/auth/data/auth_failure_mapping.dart`
- Test: `test/features/auth/data/auth_failure_mapping_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum AuthFailure { invalidCredentials, emailNotConfirmed,
  rateLimited, network, unknown }`; `AuthFailure authFailureFrom(Object error)`.

- [ ] **Step 1: Write the failing test**

`test/features/auth/data/auth_failure_mapping_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/auth/data/auth_failure_mapping.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('wrong password maps to invalidCredentials', () {
    final error = AuthApiException('Invalid login credentials',
        code: 'invalid_credentials', statusCode: '400');
    expect(authFailureFrom(error), AuthFailure.invalidCredentials);
  });

  test('unconfirmed email maps to emailNotConfirmed', () {
    final error = AuthApiException('Email not confirmed',
        code: 'email_not_confirmed', statusCode: '400');
    expect(authFailureFrom(error), AuthFailure.emailNotConfirmed);
  });

  test('email send limit maps to rateLimited', () {
    final error = AuthApiException('rate limit',
        code: 'over_email_send_rate_limit', statusCode: '429');
    expect(authFailureFrom(error), AuthFailure.rateLimited);
  });

  test('any 429 maps to rateLimited even without a known code', () {
    final error = AuthApiException('slow down', statusCode: '429');
    expect(authFailureFrom(error), AuthFailure.rateLimited);
  });

  test('a retryable fetch failure maps to network', () {
    expect(
      authFailureFrom(AuthRetryableFetchException(message: 'offline')),
      AuthFailure.network,
    );
  });

  test('a socket failure maps to network', () {
    expect(
      authFailureFrom(const SocketException('no route to host')),
      AuthFailure.network,
    );
  });

  test('anything unrecognised maps to unknown', () {
    expect(authFailureFrom(StateError('boom')), AuthFailure.unknown);
  });

  test('an AuthFailure passes through unchanged', () {
    expect(authFailureFrom(AuthFailure.network), AuthFailure.network);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/data/auth_failure_mapping_test.dart`
Expected: FAIL — the two files do not exist.

- [ ] **Step 3: Write the enum**

`lib/features/auth/domain/auth_failure.dart`:

```dart
/// The auth failures a screen can react to differently. Everything else is
/// [unknown] — a longer enum would be a copy list pretending to be a domain.
///
/// Thrown by `AuthRepository`; no `supabase_flutter` type crosses into
/// `presentation`.
enum AuthFailure {
  invalidCredentials,
  emailNotConfirmed,
  rateLimited,
  network,
  unknown,
}
```

- [ ] **Step 4: Write the mapping**

`lib/features/auth/data/auth_failure_mapping.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates anything thrown by `supabase_flutter` into an [AuthFailure].
///
/// Matches on `code` first — the messages are server copy and change without
/// notice.
AuthFailure authFailureFrom(Object error) {
  if (error is AuthFailure) return error;
  if (error is AuthRetryableFetchException) return AuthFailure.network;
  if (error is AuthException) {
    if (error.statusCode == '429') return AuthFailure.rateLimited;
    switch (error.code) {
      case 'invalid_credentials':
      case 'invalid_grant':
        return AuthFailure.invalidCredentials;
      case 'email_not_confirmed':
        return AuthFailure.emailNotConfirmed;
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return AuthFailure.rateLimited;
      case 'user_already_exists':
      case 'email_exists':
        // Deliberately not surfaced as its own failure: telling the user the
        // address is taken is an account-enumeration oracle.
        return AuthFailure.unknown;
    }
    return AuthFailure.unknown;
  }
  if (error is SocketException || error is TimeoutException) {
    return AuthFailure.network;
  }
  return AuthFailure.unknown;
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/auth/data/auth_failure_mapping_test.dart`
Expected: PASS. If `AuthApiException`'s constructor signature differs in
2.17.2, check it with
`grep -rn "class AuthApiException" ~/.pub-cache/hosted/pub.dev/gotrue-*/lib/src/types/auth_exception.dart`
and adjust the test's construction only — never the production switch.

- [ ] **Step 6: Commit**

```bash
git add lib/features/auth/domain/auth_failure.dart lib/features/auth/data/auth_failure_mapping.dart test/features/auth/data/auth_failure_mapping_test.dart
git commit -m "feat(auth): map Supabase auth exceptions onto AuthFailure"
```

---

### Task 3: Field validators

**Files:**
- Create: `lib/features/auth/domain/auth_validation.dart`
- Test: `test/features/auth/domain/auth_validation_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `String normalizeEmail(String value)`,
  `String? validateEmail(String? value)`,
  `String? validatePassword(String? value)`,
  `String? validateFirstName(String? value)`,
  `String? validatePasswordConfirmation(String? value, String password)`.
  All validators return `null` when valid and user-facing copy when not, so
  they drop straight into `TextFormField.validator`.

- [ ] **Step 1: Write the failing test**

`test/features/auth/domain/auth_validation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';

void main() {
  group('normalizeEmail', () {
    test('trims surrounding whitespace and lowercases', () {
      expect(normalizeEmail('  Pauline@Example.COM '), 'pauline@example.com');
    });

    test('leaves an already-normal address alone', () {
      expect(normalizeEmail('pauline@example.com'), 'pauline@example.com');
    });
  });

  group('validateEmail', () {
    test('accepts an address with surrounding whitespace', () {
      expect(validateEmail(' pauline@example.com '), isNull);
    });

    test('rejects empty', () {
      expect(validateEmail(''), 'Enter your email address.');
      expect(validateEmail(null), 'Enter your email address.');
    });

    test('rejects a string with no domain', () {
      expect(validateEmail('pauline@'), 'That address does not look right.');
      expect(validateEmail('pauline'), 'That address does not look right.');
      expect(validateEmail('a b@example.com'),
          'That address does not look right.');
    });
  });

  group('validatePassword', () {
    test('accepts eight characters', () {
      expect(validatePassword('abcdefgh'), isNull);
    });

    test('rejects seven', () {
      expect(validatePassword('abcdefg'), 'At least 8 characters.');
    });

    test('rejects empty', () {
      expect(validatePassword(''), 'Enter a password.');
    });

    test('does not trim — a space is a character in a password', () {
      expect(validatePassword(' abcdefg'), isNull);
    });
  });

  group('validateFirstName', () {
    test('accepts a name', () => expect(validateFirstName('Pauline'), isNull));

    test('rejects blank and whitespace-only', () {
      expect(validateFirstName(''), 'Enter your first name.');
      expect(validateFirstName('   '), 'Enter your first name.');
    });
  });

  group('validatePasswordConfirmation', () {
    test('accepts a match', () {
      expect(validatePasswordConfirmation('abcdefgh', 'abcdefgh'), isNull);
    });

    test('rejects a mismatch', () {
      expect(validatePasswordConfirmation('abcdefgi', 'abcdefgh'),
          'Those passwords do not match.');
    });

    test('rejects empty', () {
      expect(validatePasswordConfirmation('', 'abcdefgh'),
          'Confirm your password.');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/domain/auth_validation_test.dart`
Expected: FAIL — `auth_validation.dart` does not exist.

- [ ] **Step 3: Write the validators**

`lib/features/auth/domain/auth_validation.dart`:

```dart
/// Pure field validation, shared by every auth form. Each function returns the
/// message to show, or `null` when the value is fine, so it can be passed
/// straight to `TextFormField.validator`.
///
/// Minimum password length is 8 here *and* in the Supabase project settings —
/// the client is not the only gate.
const int minPasswordLength = 8;

/// A typed address differs from the stored one only by case and stray spaces
/// far more often than users notice. Normalise before validating and before
/// every call that carries an email.
String normalizeEmail(String value) => value.trim().toLowerCase();

// Deliberately loose: one run of non-space, an @, a dotted domain. A stricter
// pattern rejects valid addresses, and the real check is the confirmation
// email arriving.
final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String? value) {
  final email = normalizeEmail(value ?? '');
  if (email.isEmpty) return 'Enter your email address.';
  if (!_emailPattern.hasMatch(email)) return 'That address does not look right.';
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Enter a password.';
  if (password.length < minPasswordLength) return 'At least 8 characters.';
  return null;
}

String? validateFirstName(String? value) {
  if ((value ?? '').trim().isEmpty) return 'Enter your first name.';
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if ((value ?? '').isEmpty) return 'Confirm your password.';
  if (value != password) return 'Those passwords do not match.';
  return null;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/auth/domain/auth_validation_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/domain/auth_validation.dart test/features/auth/domain/auth_validation_test.dart
git commit -m "feat(auth): add pure field validators"
```

---

### Task 4: `AuthRepository`, its provider, and the fake every later test uses

**Files:**
- Create: `lib/features/auth/domain/auth_change.dart`
- Create: `lib/features/auth/data/auth_repository.dart`
- Create: `test/features/auth/fake_auth_repository.dart`
- Test: `test/features/auth/data/auth_repository_test.dart`

**Interfaces:**
- Consumes: `SupabaseConfig` and `supabaseClientProvider` (Task 1),
  `AuthFailure` and `authFailureFrom` (Task 2).
- Produces:
  - `enum AuthChange { signedIn, signedOut, passwordRecovery, userUpdated, other }`
  - `class AuthRepository` with `bool get hasSession`,
    `Stream<AuthChange> get changes`,
    `Future<void> signIn({required String email, required String password})`,
    `Future<void> signUp({required String email, required String password, required String firstName})`,
    `Future<void> signInWithGoogle()`, `Future<void> signInWithApple()`,
    `Future<void> sendPasswordReset(String email)`,
    `Future<void> resendConfirmation(String email)`,
    `Future<void> updatePassword(String password)`,
    `Future<void> signOut()`. Every method throws `AuthFailure`, never a
    `supabase_flutter` type.
  - `final authRepositoryProvider = Provider<AuthRepository>(...)`
  - `FakeAuthRepository` (test-only) with `List<String> calls`,
    `Object? failWith`, `Completer<void>? gate`, `void emit(AuthChange)`,
    `bool session`.

> Dart classes are implicitly implementable, so `FakeAuthRepository implements
> AuthRepository` needs no interface in `lib/`. Do **not** add one.

- [ ] **Step 1: Write the failing test**

`test/features/auth/fake_auth_repository.dart` — the shared test double. Written
here because it is the thing Tasks 6–12 depend on:

```dart
import 'dart:async';

import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_change.dart';

/// Records what a screen asked for, and fails or stalls on demand.
class FakeAuthRepository implements AuthRepository {
  /// One entry per call, e.g. `signIn(pauline@example.com, hunter22)`.
  final List<String> calls = <String>[];

  /// Thrown by the next call when set. Use an [AuthFailure].
  Object? failWith;

  /// When set, calls wait on it — for testing in-flight behaviour.
  Completer<void>? gate;

  bool session = false;

  final StreamController<AuthChange> _changes =
      StreamController<AuthChange>.broadcast();

  void emit(AuthChange change) => _changes.add(change);

  void dispose() => _changes.close();

  @override
  bool get hasSession => session;

  @override
  Stream<AuthChange> get changes => _changes.stream;

  Future<void> _record(String call) async {
    calls.add(call);
    if (gate != null) await gate!.future;
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _record('signIn($email, $password)');

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
  }) => _record('signUp($email, $password, $firstName)');

  @override
  Future<void> signInWithGoogle() => _record('signInWithGoogle()');

  @override
  Future<void> signInWithApple() => _record('signInWithApple()');

  @override
  Future<void> sendPasswordReset(String email) =>
      _record('sendPasswordReset($email)');

  @override
  Future<void> resendConfirmation(String email) =>
      _record('resendConfirmation($email)');

  @override
  Future<void> updatePassword(String password) =>
      _record('updatePassword($password)');

  @override
  Future<void> signOut() => _record('signOut()');
}
```

`test/features/auth/data/auth_repository_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_change.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';

import '../fake_auth_repository.dart';

void main() {
  test('the fake satisfies the whole repository surface', () {
    final AuthRepository repository = FakeAuthRepository();
    expect(repository.hasSession, isFalse);
  });

  test('a fake records calls and throws what it is told to', () async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.invalidCredentials;

    await expectLater(
      fake.signIn(email: 'pauline@example.com', password: 'hunter22'),
      throwsA(AuthFailure.invalidCredentials),
    );
    expect(fake.calls, ['signIn(pauline@example.com, hunter22)']);
  });

  test('a fake can hold a call in flight', () async {
    final fake = FakeAuthRepository()..gate = Completer<void>();
    var done = false;

    final future = fake.signOut().then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);

    fake.gate!.complete();
    await future;
    expect(done, isTrue);
  });

  test('changes is a broadcast stream of domain events', () async {
    final fake = FakeAuthRepository();
    final seen = <AuthChange>[];
    fake.changes.listen(seen.add);

    fake.emit(AuthChange.passwordRecovery);
    await Future<void>.delayed(Duration.zero);

    expect(seen, [AuthChange.passwordRecovery]);
    fake.dispose();
  });

  test('authRepositoryProvider can be overridden with a fake', () {
    final fake = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(authRepositoryProvider), same(fake));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/data/auth_repository_test.dart`
Expected: FAIL — `auth_repository.dart` and `auth_change.dart` do not exist.

- [ ] **Step 3: Write the domain event**

`lib/features/auth/domain/auth_change.dart`:

```dart
/// What just happened to the session, in the app's own vocabulary.
///
/// `supabase_flutter` has a longer list; the router only distinguishes these,
/// and mapping here is what keeps its type out of `presentation`.
enum AuthChange { signedIn, signedOut, passwordRecovery, userUpdated, other }
```

- [ ] **Step 4: Write the repository**

`lib/features/auth/data/auth_repository.dart`:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/core/supabase/supabase_config.dart';
import 'package:folo/core/supabase/supabase_provider.dart';
import 'package:folo/features/auth/data/auth_failure_mapping.dart';
import 'package:folo/features/auth/domain/auth_change.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The only file in the app that imports `supabase_flutter`.
///
/// Every method throws [AuthFailure] and nothing else, so screens never see a
/// `supabase_flutter` type. Callers pass an already-normalised email
/// (`normalizeEmail`).
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// On web the browser already knows where it came from; the custom scheme is
  /// for Android and iOS only.
  String? get _redirect => kIsWeb ? null : SupabaseConfig.redirectUrl;

  bool get hasSession => _auth.currentSession != null;

  Stream<AuthChange> get changes => _auth.onAuthStateChange.map((state) {
    final change = switch (state.event) {
      AuthChangeEvent.signedIn => AuthChange.signedIn,
      AuthChangeEvent.signedOut => AuthChange.signedOut,
      AuthChangeEvent.passwordRecovery => AuthChange.passwordRecovery,
      AuthChangeEvent.userUpdated => AuthChange.userUpdated,
      _ => AuthChange.other,
    };
    if (change == AuthChange.signedIn) _backfillFirstName(state.session?.user);
    return change;
  });

  /// Google and Apple return a name; keep it where the email flow puts it, so
  /// the greeting has one place to read from. Best effort — a failure here must
  /// never block a sign-in.
  void _backfillFirstName(User? user) {
    if (user == null) return;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final existing = (metadata['first_name'] as String?)?.trim() ?? '';
    if (existing.isNotEmpty) return;
    final full = (metadata['full_name'] as String? ??
            metadata['name'] as String? ??
            '')
        .trim();
    if (full.isEmpty) return;
    final first = full.split(' ').first;
    _auth
        .updateUser(UserAttributes(data: {'first_name': first}))
        .ignore();
  }

  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithPassword(email: email, password: password));

  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
  }) => _guard(
    () => _auth.signUp(
      email: email,
      password: password,
      data: {'first_name': firstName.trim()},
      emailRedirectTo: _redirect,
    ),
  );

  Future<void> signInWithGoogle() => _signInWith(OAuthProvider.google);

  Future<void> signInWithApple() => _signInWith(OAuthProvider.apple);

  Future<void> _signInWith(OAuthProvider provider) =>
      _guard(() => _auth.signInWithOAuth(provider, redirectTo: _redirect));

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email, redirectTo: _redirect));

  Future<void> resendConfirmation(String email) => _guard(
    () => _auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: _redirect,
    ),
  );

  Future<void> updatePassword(String password) =>
      _guard(() => _auth.updateUser(UserAttributes(password: password)));

  Future<void> signOut() => _guard(_auth.signOut);

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (error) {
      throw authFailureFrom(error);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/auth/data/auth_repository_test.dart`
Expected: PASS. `_guard` takes `Future<void> Function()` while the wrapped calls
return `AuthResponse`/`UserResponse`; if the analyzer objects, change `_guard`'s
parameter to `Future<Object?> Function()` rather than discarding the futures.

- [ ] **Step 6: Run the analyzer and the whole suite**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all green.

- [ ] **Step 7: Commit**

```bash
git add lib/features/auth test/features/auth
git commit -m "feat(auth): add AuthRepository over supabase_flutter"
```

---

### Task 5: Shared auth widgets

**Files:**
- Create: `lib/features/auth/presentation/auth_failure_copy.dart`
- Create: `lib/features/auth/presentation/widgets/form_error.dart`
- Create: `lib/features/auth/presentation/widgets/submit_button.dart`
- Create: `lib/features/auth/presentation/widgets/password_field.dart`
- Create: `lib/features/auth/presentation/widgets/auth_scaffold.dart`
- Test: `test/features/auth/presentation/widgets/auth_widgets_test.dart`

**Interfaces:**
- Consumes: `AuthFailure` (Task 2).
- Produces:
  - `String authFailureCopy(AuthFailure failure)`
  - `class FormError extends StatelessWidget` — `const FormError(this.message, {super.key})`
  - `class SubmitButton extends StatelessWidget` —
    `const SubmitButton({required String label, required VoidCallback onPressed, bool busy = false, super.key})`
  - `class PasswordField extends StatefulWidget` —
    `const PasswordField({required TextEditingController controller, required String label, String? helper, String? Function(String?)? validator, bool enabled = true, void Function(String)? onSubmitted, super.key})`
  - `class AuthScaffold extends StatelessWidget` —
    `const AuthScaffold({required List<Widget> children, bool showBack = true, super.key})`

- [ ] **Step 1: Write the failing test**

`test/features/auth/presentation/widgets/auth_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/password_field.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  group('authFailureCopy', () {
    test('never names the field that was wrong', () {
      expect(
        authFailureCopy(AuthFailure.invalidCredentials),
        'Email or password is incorrect.',
      );
    });

    test('covers every failure with its own sentence', () {
      final copies = AuthFailure.values.map(authFailureCopy).toSet();
      expect(copies.length, AuthFailure.values.length);
      expect(copies.every((copy) => copy.endsWith('.')), isTrue);
    });
  });

  testWidgets('FormError shows the message', (tester) async {
    await tester.pumpWidget(_host(const FormError('Something went wrong.')));
    expect(find.text('Something went wrong.'), findsOneWidget);
  });

  testWidgets('SubmitButton fires once when idle', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(SubmitButton(label: 'Sign in', onPressed: () => taps++)),
    );

    await tester.tap(find.text('Sign in'));
    expect(taps, 1);
  });

  testWidgets('SubmitButton swallows a second tap while busy', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(SubmitButton(label: 'Sign in', busy: true, onPressed: () => taps++)),
    );

    expect(find.text('Sign in'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(SubmitButton));
    expect(taps, 0);
  });

  testWidgets('PasswordField hides the value until the toggle is tapped',
      (tester) async {
    await tester.pumpWidget(
      _host(
        PasswordField(
          controller: TextEditingController(text: 'hunter22'),
          label: 'Password',
        ),
      ),
    );

    expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isTrue);

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isFalse);
  });

  testWidgets('AuthScaffold shows a back button only when asked',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AuthScaffold(showBack: false, children: [Text('Welcome')]),
      ),
    );
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Welcome'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/presentation/widgets/auth_widgets_test.dart`
Expected: FAIL — none of the widget files exist.

- [ ] **Step 3: Write the copy map**

`lib/features/auth/presentation/auth_failure_copy.dart`:

```dart
import 'package:folo/features/auth/domain/auth_failure.dart';

/// User-facing copy for a failure. Lives in `presentation` because it is copy,
/// not logic.
///
/// [AuthFailure.invalidCredentials] deliberately does not say which field was
/// wrong and does not reveal whether the account exists.
String authFailureCopy(AuthFailure failure) => switch (failure) {
  AuthFailure.invalidCredentials => 'Email or password is incorrect.',
  AuthFailure.emailNotConfirmed =>
    'Confirm your email first. We can send the link again.',
  AuthFailure.rateLimited => 'Too many attempts. Try again in a few minutes.',
  AuthFailure.network => 'We could not reach Folo. Check your connection.',
  AuthFailure.unknown => 'Something went wrong. Try again.',
};
```

- [ ] **Step 4: Write `FormError`**

`lib/features/auth/presentation/widgets/form_error.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_spacing.dart';

/// Form-level failure: "we could not sign you in", as opposed to a field being
/// wrong (that is the text field's own error state).
///
/// This is one of only two places red appears outside a destructive action.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.ms),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Icon(Icons.error_outline_rounded, size: 20, color: scheme.error),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Write `SubmitButton`**

`lib/features/auth/presentation/widgets/submit_button.dart`:

```dart
import 'package:flutter/material.dart';

/// The single primary action on an auth screen.
///
/// While [busy] the button is disabled, which is what stops a second tap from
/// firing a second request, and the label swaps for a spinner inside a box the
/// size of the label's line so the button does not resize.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
```

- [ ] **Step 6: Write `PasswordField`**

`lib/features/auth/presentation/widgets/password_field.dart`:

```dart
import 'package:flutter/material.dart';

/// A password input with a reveal toggle.
///
/// Stateful for one reason: whether the value is currently visible is local
/// widget state.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    this.helper,
    this.validator,
    this.enabled = true,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? Function(String?)? validator;
  final bool enabled;
  final void Function(String)? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: !_revealed,
      enabled: widget.enabled,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _revealed = !_revealed),
          icon: Icon(
            _revealed
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          tooltip: _revealed ? 'Hide password' : 'Show password',
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Write `AuthScaffold`**

`lib/features/auth/presentation/widgets/auth_scaffold.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';

/// The shape every auth screen shares: no navigation, one column capped at 400
/// and centred, flat on the canvas.
///
/// This is the only part of the product whose layout does not restructure
/// across size classes — a form has one column at every width. Only the
/// vertical rhythm steps up on a larger screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.children, this.showBack = true, super.key});

  static const double _columnWidth = 400;

  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final rhythm = context.screenSize == ScreenSize.mobile
        ? AppSpacing.lg
        : AppSpacing.xl;

    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _columnWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: rhythm,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

`AppBar()` with no title renders the automatic back button and nothing else,
which is exactly the spec's "Back" row; the theme already removes its shadow.

- [ ] **Step 8: Run the test to verify it passes**

Run: `flutter test test/features/auth/presentation/widgets/auth_widgets_test.dart`
Expected: PASS.

- [ ] **Step 9: Run the analyzer and the whole suite**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all green.

- [ ] **Step 10: Commit**

```bash
git add lib/features/auth/presentation test/features/auth/presentation
git commit -m "feat(auth): add the shared auth form widgets"
```

---

### Task 6: Routes and the welcome screen

**Files:**
- Modify: `lib/app/router/routes.dart`
- Create: `lib/features/auth/presentation/welcome_page.dart`
- Modify: `lib/app/router/app_router.dart`
- Test: `test/features/auth/presentation/welcome_page_test.dart`

**Interfaces:**
- Consumes: `AuthScaffold`, `FormError`, `authFailureCopy` (Task 5),
  `authRepositoryProvider` (Task 4).
- Produces: `Routes.welcome/login/register/forgotPassword/checkInbox/resetPassword`
  plus a `…Name` for each, `Routes.checkInboxLocation({required String reason,
  required String email})`, `Routes.authPaths` (a `Set<String>`);
  `class WelcomePage extends ConsumerStatefulWidget`.

- [ ] **Step 1: Write the failing test**

`test/features/auth/presentation/welcome_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/welcome_page.dart';

import '../fake_auth_repository.dart';

Widget _host(FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp(theme: AppTheme.light, home: const WelcomePage()),
);

void main() {
  testWidgets('offers the three identity paths and the register link',
      (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository()));

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Know what to do next.'), findsOneWidget);
  });

  testWidgets('Google calls the repository once', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signInWithGoogle()']);
  });

  testWidgets('a failed OAuth attempt shows a form error', (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.network;
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();

    expect(
      find.text('We could not reach Folo. Check your connection.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/presentation/welcome_page_test.dart`
Expected: FAIL — `welcome_page.dart` does not exist.

- [ ] **Step 3: Add the routes**

`lib/app/router/routes.dart` — keep the existing dashboard entries and add:

```dart
/// Every route path and name in the app. Widgets never write a path literal.
abstract final class Routes {
  static const String dashboard = '/';
  static const String dashboardName = 'dashboard';

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
  }) =>
      Uri(
        path: checkInbox,
        queryParameters: {'reason': reason, 'email': email},
      ).toString();
}
```

- [ ] **Step 4: Write the welcome screen**

`lib/features/auth/presentation/welcome_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:go_router/go_router.dart';

/// The signed-out root: the promise, and the three ways in.
///
/// The social buttons live here and nowhere else — a user who signed up with
/// Google is never shown a competing email form beside their real path.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  bool _busy = false;
  AuthFailure? _failure;

  Future<void> _continueWith(Future<void> Function() start) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await start();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(authRepositoryProvider);
    final text = Theme.of(context).textTheme;

    return AuthScaffold(
      showBack: false,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            // ponytail: the wordmark is set type until there is a real logo —
            // that is its own issue.
            Text('Folo', style: text.displaySmall),
            Text('Know what to do next.', style: text.titleLarge),
            Text(
              'Organize your relationships, know what to do next.',
              style: text.bodyMedium,
            ),
          ],
        ),
        if (_failure != null) FormError(authFailureCopy(_failure!)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            // Google and Apple each mandate their own sign-in mark; until those
            // assets are added the buttons are label-only.
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _continueWith(repository.signInWithGoogle),
              child: const Text('Continue with Google'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _continueWith(repository.signInWithApple),
              child: const Text('Continue with Apple'),
            ),
            FilledButton(
              onPressed: _busy ? null : () => context.go(Routes.login),
              child: const Text('Continue with email'),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New here?', style: text.bodySmall),
            TextButton(
              onPressed: () => context.go(Routes.register),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Register the route**

In `lib/app/router/app_router.dart`, inside `routes:`, after the dashboard route:

```dart
      GoRoute(
        path: Routes.welcome,
        name: Routes.welcomeName,
        builder: (context, state) => const WelcomePage(),
      ),
```

Add `import 'package:folo/features/auth/presentation/welcome_page.dart';`.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/auth/presentation/welcome_page_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/app/router lib/features/auth/presentation/welcome_page.dart test/features/auth/presentation/welcome_page_test.dart
git commit -m "feat(auth): add the welcome screen and the auth routes"
```

---

### Task 7: Sign-in screen

**Files:**
- Create: `lib/features/auth/presentation/login_page.dart`
- Modify: `lib/app/router/app_router.dart`
- Test: `test/features/auth/presentation/login_page_test.dart`

**Interfaces:**
- Consumes: `AuthScaffold`, `PasswordField`, `SubmitButton`, `FormError`,
  `authFailureCopy`, `validateEmail`, `validatePassword`, `normalizeEmail`,
  `authRepositoryProvider`, `Routes`.
- Produces: `class LoginPage extends ConsumerStatefulWidget`.

- [ ] **Step 1: Write the failing test**

`test/features/auth/presentation/login_page_test.dart` — the last two tests are
Review Focus 1 and 3:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/login_page.dart';

import '../fake_auth_repository.dart';

Widget _host(FakeAuthRepository fake, {GlobalKey<NavigatorState>? navigator}) =>
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        theme: AppTheme.light,
        navigatorKey: navigator,
        home: const LoginPage(),
      ),
    );

Future<void> _fill(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
}

void main() {
  testWidgets('renders the sign-in form', (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository()));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('will not call the repository with an invalid email',
      (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake));

    await _fill(tester, email: 'pauline', password: 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('That address does not look right.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('a rejected sign-in shows the neutral form error',
      (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.invalidCredentials;
    await tester.pumpWidget(_host(fake));

    await _fill(tester, email: 'pauline@example.com', password: 'wrongpass');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.textContaining('password'), findsWidgets);
    // Nothing on screen may say whether the account exists.
    expect(find.textContaining('No account'), findsNothing);
  });

  testWidgets('normalizes the email before signing in', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake));

    await _fill(tester, email: '  Pauline@Example.COM ', password: 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signIn(pauline@example.com, hunter22)']);
  });

  testWidgets('a request that outlives the screen does not throw',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final fake = FakeAuthRepository()..gate = Completer<void>();
    await tester.pumpWidget(_host(fake, navigator: navigator));

    await _fill(tester, email: 'pauline@example.com', password: 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    fake.gate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/presentation/login_page_test.dart`
Expected: FAIL — `login_page.dart` does not exist.

- [ ] **Step 3: Write the screen**

`lib/features/auth/presentation/login_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/password_field.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:go_router/go_router.dart';

/// Email + password sign-in.
///
/// The form-level error never says which field was wrong and never reveals
/// whether the account exists.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final email = normalizeEmail(_email.text);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: _password.text);
    } on AuthFailure catch (failure) {
      // The request can outlive the screen: the user may go back while it is in
      // flight.
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AuthScaffold(
      children: [
        Text('Welcome back', style: text.headlineSmall),
        if (_failure != null) FormError(authFailureCopy(_failure!)),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              TextFormField(
                controller: _email,
                enabled: !_busy,
                validator: validateEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              PasswordField(
                controller: _password,
                label: 'Password',
                enabled: !_busy,
                validator: validatePassword,
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go(Routes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              SubmitButton(label: 'Sign in', busy: _busy, onPressed: _submit),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New here?', style: text.bodySmall),
            TextButton(
              onPressed: () => context.go(Routes.register),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Register the route**

In `app_router.dart`, after the welcome route:

```dart
      GoRoute(
        path: Routes.login,
        name: Routes.loginName,
        builder: (context, state) => const LoginPage(),
      ),
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/auth/presentation/login_page_test.dart`
Expected: PASS. `SubmitButton` renders its label as a `Text`, so
`find.text('Sign in')` hits the button; if the "Sign in" finder becomes
ambiguous because the heading changes, target `find.byType(SubmitButton)`.

- [ ] **Step 6: Commit**

```bash
git add lib/app/router/app_router.dart lib/features/auth/presentation/login_page.dart test/features/auth/presentation/login_page_test.dart
git commit -m "feat(auth): add the sign-in screen"
```

---

### Task 8: Registration screen

**Files:**
- Create: `lib/features/auth/presentation/register_page.dart`
- Modify: `lib/app/router/app_router.dart`
- Test: `test/features/auth/presentation/register_page_test.dart`

**Interfaces:**
- Consumes: the same widgets and validators as Task 7, plus
  `Routes.checkInboxLocation`.
- Produces: `class RegisterPage extends ConsumerStatefulWidget`.

- [ ] **Step 1: Write the failing test**

`test/features/auth/presentation/register_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/register_page.dart';

import '../fake_auth_repository.dart';

/// A two-route router, so `context.go` works and the test can assert where
/// signup navigated to.
GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RegisterPage()),
    GoRoute(
      path: Routes.checkInbox,
      builder: (context, state) => const SizedBox.shrink(),
    ),
  ],
);

Widget _host(GoRouter router, FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
);

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Future<void> _fill(
  WidgetTester tester, {
  String firstName = 'Pauline',
  String email = 'pauline@example.com',
  String password = 'hunter22',
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), firstName);
  await tester.enterText(fields.at(1), email);
  await tester.enterText(fields.at(2), password);
}

void main() {
  testWidgets('collects first name, email and password', (tester) async {
    await tester.pumpWidget(_host(_router(), FakeAuthRepository()));

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('a blank first name blocks the request', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(_router(), fake));

    await _fill(tester, firstName: '   ');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your first name.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('a short password blocks the request', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(_router(), fake));

    await _fill(tester, password: 'hunter2');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('At least 8 characters.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('signs up with a normalized email and goes to check-inbox',
      (tester) async {
    final fake = FakeAuthRepository();
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _fill(tester, email: ' Pauline@Example.com ');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signUp(pauline@example.com, hunter22, Pauline)']);
    expect(
      _location(router),
      Routes.checkInboxLocation(
        reason: 'confirm',
        email: 'pauline@example.com',
      ),
    );
  });

  testWidgets('a failure keeps the user on the form', (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.unknown;
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _fill(tester);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(_location(router), '/');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/presentation/register_page_test.dart`
Expected: FAIL — `register_page.dart` does not exist.

- [ ] **Step 3: Write the screen**

`lib/features/auth/presentation/register_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/password_field.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:go_router/go_router.dart';

/// Registration. The first name goes into the auth user's metadata; there is no
/// profiles table yet, and nothing in the app queries another person's name.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _firstName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final email = normalizeEmail(_email.text);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).signUp(
        email: email,
        password: _password.text,
        firstName: _firstName.text.trim(),
      );
      if (!mounted) return;
      // Email confirmation is on, so there is no session yet — the next step is
      // the user's inbox.
      context.go(Routes.checkInboxLocation(reason: 'confirm', email: email));
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AuthScaffold(
      children: [
        Text('Create your account', style: text.headlineSmall),
        if (_failure != null) FormError(authFailureCopy(_failure!)),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              TextFormField(
                controller: _firstName,
                enabled: !_busy,
                validator: validateFirstName,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.givenName],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                validator: validateEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              PasswordField(
                controller: _password,
                label: 'Password',
                helper: 'At least 8 characters',
                enabled: !_busy,
                validator: validatePassword,
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              SubmitButton(
                label: 'Create account',
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        Text(
          'By creating an account you agree to the terms and the privacy '
          'policy.',
          style: text.bodySmall,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account?', style: text.bodySmall),
            TextButton(
              onPressed: () => context.go(Routes.login),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Register the route**

In `app_router.dart`:

```dart
      GoRoute(
        path: Routes.register,
        name: Routes.registerName,
        builder: (context, state) => const RegisterPage(),
      ),
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/auth/presentation/register_page_test.dart`
Expected: PASS. `import 'package:go_router/go_router.dart';` is needed in the
test for `_router`. If `routerDelegate.currentConfiguration` is not available in
go_router 18, read the location from `router.state.uri.toString()` instead.

- [ ] **Step 6: Commit**

```bash
git add lib/app/router/app_router.dart lib/features/auth/presentation/register_page.dart test/features/auth/presentation/register_page_test.dart
git commit -m "feat(auth): add the registration screen"
```

---

### Task 9: Forgot password and check inbox

**Files:**
- Create: `lib/features/auth/presentation/forgot_password_page.dart`
- Create: `lib/features/auth/presentation/check_inbox_page.dart`
- Modify: `lib/app/router/app_router.dart`
- Test: `test/features/auth/presentation/forgot_password_page_test.dart`
- Test: `test/features/auth/presentation/check_inbox_page_test.dart`

**Interfaces:**
- Consumes: the Task 5 widgets, `validateEmail`, `normalizeEmail`,
  `authRepositoryProvider`, `Routes.checkInboxLocation`.
- Produces: `class ForgotPasswordPage extends ConsumerStatefulWidget`;
  `class CheckInboxPage extends ConsumerStatefulWidget` with
  `const CheckInboxPage({required String reason, required String email, super.key})`.
  `reason` is `'confirm'` or `'reset'`; anything else is treated as `'confirm'`.

- [ ] **Step 1: Write the failing tests**

`test/features/auth/presentation/forgot_password_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/forgot_password_page.dart';
import 'package:go_router/go_router.dart';

import '../fake_auth_repository.dart';

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const ForgotPasswordPage()),
    GoRoute(
      path: Routes.checkInbox,
      builder: (context, state) => const SizedBox.shrink(),
    ),
  ],
);

Widget _host(GoRouter router, FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
);

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Future<void> _request(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextFormField), email);
  await tester.tap(find.text('Send reset link'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the request form', (tester) async {
    await tester.pumpWidget(_host(_router(), FakeAuthRepository()));

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets('sends the reset and confirms on check-inbox', (tester) async {
    final fake = FakeAuthRepository();
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _request(tester, ' Pauline@Example.com ');

    expect(fake.calls, ['sendPasswordReset(pauline@example.com)']);
    expect(
      _location(router),
      Routes.checkInboxLocation(reason: 'reset', email: 'pauline@example.com'),
    );
  });

  testWidgets(
      'an unknown address is confirmed identically — no enumeration oracle',
      (tester) async {
    // The server answers the same way for an address it does not know; if it
    // ever errors, the screen must still not say so.
    final fake = FakeAuthRepository()..failWith = AuthFailure.unknown;
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _request(tester, 'nobody@example.com');

    expect(
      _location(router),
      Routes.checkInboxLocation(reason: 'reset', email: 'nobody@example.com'),
    );
    expect(find.textContaining('went wrong'), findsNothing);
  });

  testWidgets('a connection failure is reported, not silently confirmed',
      (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.network;
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _request(tester, 'pauline@example.com');

    expect(_location(router), '/');
    expect(
      find.text('We could not reach Folo. Check your connection.'),
      findsOneWidget,
    );
  });
}
```

`test/features/auth/presentation/check_inbox_page_test.dart` — the last test is
Review Focus 5:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/check_inbox_page.dart';

import '../fake_auth_repository.dart';

Widget _host(
  FakeAuthRepository fake, {
  String reason = 'confirm',
  String email = 'pauline@example.com',
}) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp(
    theme: AppTheme.light,
    home: CheckInboxPage(reason: reason, email: email),
  ),
);

void main() {
  testWidgets('confirmation copy names the address', (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository()));

    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.textContaining('pauline@example.com'), findsOneWidget);
    expect(find.text('Resend email'), findsOneWidget);
  });

  testWidgets('reset copy never confirms that the account exists',
      (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository(), reason: 'reset'));

    expect(
      find.text('If an account exists for that address, we sent a link.'),
      findsOneWidget,
    );
  });

  testWidgets('resend on a confirmation asks for the signup email again',
      (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Resend email'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['resendConfirmation(pauline@example.com)']);
    expect(find.text('Sent. It can take a minute to arrive.'), findsOneWidget);
  });

  testWidgets('resend on a reset asks for another reset link', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake, reason: 'reset'));

    await tester.tap(find.text('Resend email'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['sendPasswordReset(pauline@example.com)']);
  });

  testWidgets('an unknown reason falls back to the confirmation copy',
      (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository(), reason: 'nonsense'));

    expect(find.text('Check your inbox'), findsOneWidget);
  });

  testWidgets('a missing address still renders and can still resend',
      (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake, email: ''));

    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Resend email'), findsNothing);
  });

  testWidgets('resend spam surfaces the rate limit, not a generic error',
      (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.rateLimited;
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Resend email'));
    await tester.pumpAndSettle();

    expect(
      find.text('Too many attempts. Try again in a few minutes.'),
      findsOneWidget,
    );
    expect(find.textContaining('went wrong'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/auth/presentation/`
Expected: FAIL — the two new page files do not exist.

- [ ] **Step 3: Write the forgot-password screen**

`lib/features/auth/presentation/forgot_password_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:go_router/go_router.dart';

/// Request a password reset link.
///
/// The outcome is deliberately the same whether or not the address has an
/// account: this screen must not be usable to find out who is registered. Only
/// failures that are about *this device* — no connection, too many attempts —
/// are shown, because they say nothing about the address.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final email = normalizeEmail(_email.text);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      if (failure == AuthFailure.network || failure == AuthFailure.rateLimited) {
        setState(() {
          _failure = failure;
          _busy = false;
        });
        return;
      }
      // Any server-side failure is swallowed on purpose — see the class doc.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    context.go(Routes.checkInboxLocation(reason: 'reset', email: email));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AuthScaffold(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            Text('Reset your password', style: text.headlineSmall),
            Text(
              'Enter the address you signed up with and we will send a link.',
              style: text.bodyMedium,
            ),
          ],
        ),
        if (_failure != null) FormError(authFailureCopy(_failure!)),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              TextFormField(
                controller: _email,
                enabled: !_busy,
                validator: validateEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              SubmitButton(
                label: 'Send reset link',
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => context.go(Routes.login),
            child: const Text('Back to sign in'),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Write the check-inbox screen**

`lib/features/auth/presentation/check_inbox_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:go_router/go_router.dart';

/// One screen for both "confirm your email" and "we sent a reset link".
///
/// [reason] and [email] arrive as query parameters rather than a router
/// `extra`, so reloading the page on web still has its content.
class CheckInboxPage extends ConsumerStatefulWidget {
  const CheckInboxPage({required this.reason, required this.email, super.key});

  static const String confirmReason = 'confirm';
  static const String resetReason = 'reset';

  final String reason;
  final String email;

  @override
  ConsumerState<CheckInboxPage> createState() => _CheckInboxPageState();
}

class _CheckInboxPageState extends ConsumerState<CheckInboxPage> {
  bool _busy = false;
  bool _sent = false;
  AuthFailure? _failure;

  bool get _isReset => widget.reason == CheckInboxPage.resetReason;

  Future<void> _resend() async {
    final repository = ref.read(authRepositoryProvider);
    setState(() {
      _busy = true;
      _failure = null;
      _sent = false;
    });
    try {
      if (_isReset) {
        await repository.sendPasswordReset(widget.email);
      } else {
        await repository.resendConfirmation(widget.email);
      }
      if (!mounted) return;
      setState(() => _sent = true);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hasEmail = widget.email.isNotEmpty;

    return AuthScaffold(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            Text(
              _isReset ? 'Check your email' : 'Check your inbox',
              style: text.titleLarge,
            ),
            Text(
              _isReset
                  // Says nothing about whether the address is registered.
                  ? 'If an account exists for that address, we sent a link.'
                  : hasEmail
                  ? 'We sent a confirmation link to ${widget.email}. Open it to '
                        'finish setting up your account.'
                  : 'We sent a confirmation link. Open it to finish setting up '
                        'your account.',
              style: text.bodyMedium,
            ),
          ],
        ),
        if (_failure != null) FormError(authFailureCopy(_failure!)),
        if (_sent)
          Text(
            'Sent. It can take a minute to arrive.',
            style: text.bodySmall?.copyWith(color: scheme.primary),
          ),
        if (hasEmail)
          SubmitButton(label: 'Resend email', busy: _busy, onPressed: _resend),
        Center(
          child: TextButton(
            onPressed: () => context.go(Routes.login),
            child: const Text('Back to sign in'),
          ),
        ),
      ],
    );
  }
}
```

The "missing address" test asserts no `FilledButton` labelled `Resend email`
exists: without an address there is nothing to resend to, so the button is not
rendered at all.

- [ ] **Step 5: Register both routes**

In `app_router.dart`:

```dart
      GoRoute(
        path: Routes.forgotPassword,
        name: Routes.forgotPasswordName,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.checkInbox,
        name: Routes.checkInboxName,
        builder: (context, state) => CheckInboxPage(
          reason: state.uri.queryParameters['reason'] ??
              CheckInboxPage.confirmReason,
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/auth/presentation/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/app/router/app_router.dart lib/features/auth/presentation test/features/auth/presentation
git commit -m "feat(auth): add password reset request and check-inbox screens"
```

---

### Task 10: Choose a new password

**Files:**
- Create: `lib/features/auth/presentation/reset_password_page.dart`
- Modify: `lib/app/router/app_router.dart`
- Test: `test/features/auth/presentation/reset_password_page_test.dart`

**Interfaces:**
- Consumes: `PasswordField`, `SubmitButton`, `FormError`, `authFailureCopy`,
  `validatePassword`, `validatePasswordConfirmation`, `authRepositoryProvider`.
- Produces: `class ResetPasswordPage extends ConsumerStatefulWidget`.

- [ ] **Step 1: Write the failing test**

`test/features/auth/presentation/reset_password_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/reset_password_page.dart';
import 'package:folo/features/auth/presentation/widgets/password_field.dart';
import 'package:go_router/go_router.dart';

import '../fake_auth_repository.dart';

GoRouter _router() => GoRouter(
  initialLocation: Routes.resetPassword,
  routes: [
    GoRoute(
      path: Routes.resetPassword,
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(
      path: Routes.dashboard,
      builder: (context, state) => const Text('Dashboard'),
    ),
  ],
);

Widget _host(GoRouter router, FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
);

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Future<void> _fill(
  WidgetTester tester, {
  required String password,
  required String confirmation,
}) async {
  final fields = find.byType(PasswordField);
  await tester.enterText(fields.at(0), password);
  await tester.enterText(fields.at(1), confirmation);
}

void main() {
  testWidgets('has no back button — a deep link has no previous screen',
      (tester) async {
    await tester.pumpWidget(_host(_router(), FakeAuthRepository()));

    expect(find.text('Choose a new password'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('a mismatch blocks the request', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(_router(), fake));

    await _fill(tester, password: 'hunter22', confirmation: 'hunter23');
    await tester.tap(find.text('Save and sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Those passwords do not match.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('a short password blocks the request', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(_router(), fake));

    await _fill(tester, password: 'hunter2', confirmation: 'hunter2');
    await tester.tap(find.text('Save and sign in'));
    await tester.pumpAndSettle();

    expect(find.text('At least 8 characters.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('saving the password lands on the dashboard', (tester) async {
    final fake = FakeAuthRepository();
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _fill(tester, password: 'hunter22', confirmation: 'hunter22');
    await tester.tap(find.text('Save and sign in'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['updatePassword(hunter22)']);
    expect(_location(router), Routes.dashboard);
  });

  testWidgets('an expired link shows a form error and stays put',
      (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.unknown;
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _fill(tester, password: 'hunter22', confirmation: 'hunter22');
    await tester.tap(find.text('Save and sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(_location(router), Routes.resetPassword);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/presentation/reset_password_page_test.dart`
Expected: FAIL — `reset_password_page.dart` does not exist.

- [ ] **Step 3: Write the screen**

`lib/features/auth/presentation/reset_password_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/password_field.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:go_router/go_router.dart';

/// Reached by the recovery deep link, which has already created a session — so
/// there is no back button and nowhere to go back to.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      context.go(Routes.dashboard);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AuthScaffold(
      showBack: false,
      children: [
        Text('Choose a new password', style: text.headlineSmall),
        if (_failure != null) FormError(authFailureCopy(_failure!)),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              PasswordField(
                controller: _password,
                label: 'New password',
                helper: 'At least 8 characters',
                enabled: !_busy,
                validator: validatePassword,
              ),
              PasswordField(
                controller: _confirmation,
                label: 'Confirm password',
                enabled: !_busy,
                validator: (value) =>
                    validatePasswordConfirmation(value, _password.text),
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              SubmitButton(
                label: 'Save and sign in',
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Register the route**

In `app_router.dart`:

```dart
      GoRoute(
        path: Routes.resetPassword,
        name: Routes.resetPasswordName,
        builder: (context, state) => const ResetPasswordPage(),
      ),
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/auth/presentation/reset_password_page_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the analyzer and the whole suite**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!". `test/app_test.dart` still passes because nothing
reads `supabaseClientProvider` yet — that changes in Task 11.

- [ ] **Step 7: Commit**

```bash
git add lib/app/router/app_router.dart lib/features/auth/presentation/reset_password_page.dart test/features/auth/presentation/reset_password_page_test.dart
git commit -m "feat(auth): add the choose-a-new-password screen"
```

---

### Task 11: Route guard and session persistence

**Files:**
- Create: `lib/app/router/auth_redirect.dart`
- Modify: `lib/app/router/app_router.dart`
- Modify: `test/app_test.dart`
- Test: `test/app/router/auth_redirect_test.dart`

**Interfaces:**
- Consumes: `AuthRepository`, `AuthChange`, `authRepositoryProvider`, `Routes`.
- Produces:
  - `String? authRedirect({required bool hasSession, required bool recoveringPassword, required String location})`
  - `class AuthStatus extends ChangeNotifier` — `AuthStatus(AuthRepository)`,
    `bool get hasSession`, `bool get recoveringPassword`
  - `final authStatusProvider = Provider<AuthStatus>(...)`

> Riverpod 3 treats `ChangeNotifierProvider` as legacy. Use a plain `Provider`
> that returns the notifier and disposes it in `ref.onDispose` — do not import
> `flutter_riverpod/legacy.dart`.

- [ ] **Step 1: Write the failing test**

`test/app/router/auth_redirect_test.dart` — the third group is Review Focus 4:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/auth_redirect.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_change.dart';

import '../../features/auth/fake_auth_repository.dart';

void main() {
  group('signed out', () {
    String? redirect(String location) => authRedirect(
      hasSession: false,
      recoveringPassword: false,
      location: location,
    );

    test('is sent to welcome from a protected route', () {
      expect(redirect(Routes.dashboard), Routes.welcome);
    });

    test('is left alone on every auth route', () {
      for (final path in Routes.authPaths) {
        expect(redirect(path), isNull, reason: path);
      }
    });

    test('cannot reach reset-password without the link having signed them in',
        () {
      expect(redirect(Routes.resetPassword), Routes.welcome);
    });
  });

  group('signed in', () {
    String? redirect(String location) => authRedirect(
      hasSession: true,
      recoveringPassword: false,
      location: location,
    );

    test('is left alone on a protected route', () {
      expect(redirect(Routes.dashboard), isNull);
    });

    test('is sent to the dashboard from an auth route', () {
      for (final path in Routes.authPaths) {
        expect(redirect(path), Routes.dashboard, reason: path);
      }
    });

    test('is never pushed off reset-password', () {
      expect(redirect(Routes.resetPassword), isNull);
    });
  });

  group('recovering a password', () {
    String? redirect(String location, {bool hasSession = true}) => authRedirect(
      hasSession: hasSession,
      recoveringPassword: true,
      location: location,
    );

    test('goes to reset-password from anywhere', () {
      expect(redirect(Routes.dashboard), Routes.resetPassword);
      expect(redirect(Routes.welcome), Routes.resetPassword);
    });

    test('recovery wins even when a session is already open', () {
      // Someone opens a recovery link while signed in as another account: the
      // link has replaced the session, so it must not be treated as "already
      // signed in, go to the dashboard".
      expect(redirect(Routes.resetPassword), isNull);
      expect(redirect(Routes.login), Routes.resetPassword);
    });
  });

  group('AuthStatus', () {
    test('starts from the restored session', () {
      final fake = FakeAuthRepository()..session = true;
      final status = AuthStatus(fake);

      expect(status.hasSession, isTrue);
      expect(status.recoveringPassword, isFalse);
      status.dispose();
    });

    test('follows sign-in, recovery and sign-out', () async {
      final fake = FakeAuthRepository();
      final status = AuthStatus(fake);
      var notifications = 0;
      status.addListener(() => notifications++);

      fake.emit(AuthChange.signedIn);
      await Future<void>.delayed(Duration.zero);
      expect(status.hasSession, isTrue);

      fake.emit(AuthChange.passwordRecovery);
      await Future<void>.delayed(Duration.zero);
      expect(status.recoveringPassword, isTrue);
      expect(status.hasSession, isTrue);

      fake.emit(AuthChange.userUpdated);
      await Future<void>.delayed(Duration.zero);
      expect(status.recoveringPassword, isFalse);

      fake.emit(AuthChange.signedOut);
      await Future<void>.delayed(Duration.zero);
      expect(status.hasSession, isFalse);
      expect(status.recoveringPassword, isFalse);

      expect(notifications, 4);
      status.dispose();
    });

    test('is exposed by authStatusProvider', () {
      final fake = FakeAuthRepository()..session = true;
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(container.read(authStatusProvider).hasSession, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app/router/auth_redirect_test.dart`
Expected: FAIL — `auth_redirect.dart` does not exist.

- [ ] **Step 3: Write the redirect and the notifier**

`lib/app/router/auth_redirect.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_change.dart';

/// The whole guard, as a pure function of three facts — which is why it is
/// testable without a router, a widget tree or a client.
String? authRedirect({
  required bool hasSession,
  required bool recoveringPassword,
  required String location,
}) {
  // Recovery outranks everything: the link signs the user in before they choose
  // the new password, so "has a session" must not send them to the dashboard.
  if (recoveringPassword) {
    return location == Routes.resetPassword ? null : Routes.resetPassword;
  }
  if (location == Routes.resetPassword) {
    return hasSession ? null : Routes.welcome;
  }
  final isAuthRoute = Routes.authPaths.contains(location);
  if (!hasSession) return isAuthRoute ? null : Routes.welcome;
  return isAuthRoute ? Routes.dashboard : null;
}

/// The two pieces of session state the router needs, as a `Listenable` so
/// `GoRouter.refreshListenable` can re-run the redirect.
class AuthStatus extends ChangeNotifier {
  AuthStatus(AuthRepository repository)
    : _hasSession = repository.hasSession {
    _subscription = repository.changes.listen(_apply);
  }

  bool _hasSession;
  bool _recoveringPassword = false;
  late final StreamSubscription<AuthChange> _subscription;

  bool get hasSession => _hasSession;
  bool get recoveringPassword => _recoveringPassword;

  void _apply(AuthChange change) {
    switch (change) {
      case AuthChange.signedIn:
        _hasSession = true;
      case AuthChange.passwordRecovery:
        _hasSession = true;
        _recoveringPassword = true;
      case AuthChange.userUpdated:
        // The new password has been saved, so recovery is over.
        _recoveringPassword = false;
      case AuthChange.signedOut:
        _hasSession = false;
        _recoveringPassword = false;
      case AuthChange.other:
        return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final authStatusProvider = Provider<AuthStatus>((ref) {
  final status = AuthStatus(ref.watch(authRepositoryProvider));
  ref.onDispose(status.dispose);
  return status;
});
```

Add `import 'dart:async';` at the top for `StreamSubscription`.

- [ ] **Step 4: Wire the router**

`lib/app/router/app_router.dart` — replace the provider body, keeping the six
`GoRoute`s added in Tasks 6–10:

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final status = ref.watch(authStatusProvider);

  final router = GoRouter(
    initialLocation: Routes.dashboard,
    // `Supabase.initialize` has already restored any stored session, so the
    // first redirect knows the answer and no auth screen flashes on launch.
    refreshListenable: status,
    redirect: (context, state) => authRedirect(
      hasSession: status.hasSession,
      recoveringPassword: status.recoveringPassword,
      location: state.matchedLocation,
    ),
    routes: [
      // ... the existing dashboard route and the six auth routes
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
```

Delete the stale extension-point comment items 1 and 2 above the provider; item 3
(the `StatefulShellRoute`) is still to come.

- [ ] **Step 5: Update the app boot test**

`test/app_test.dart` — the app now needs a repository, and a signed-out launch
lands on the welcome screen:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/app.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/features/auth/data/auth_repository.dart';

import 'features/auth/fake_auth_repository.dart';

void main() {
  testWidgets('a signed-out launch lands on the welcome screen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const FoloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets('a restored session lands on the dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository()..session = true,
          ),
        ],
        child: const FoloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Folo'), findsOneWidget);
  });

  test('breakpoints map widths to layout classes', () {
    expect(Breakpoints.of(375), ScreenSize.mobile);
    expect(Breakpoints.of(Breakpoints.tablet), ScreenSize.tablet);
    expect(Breakpoints.of(Breakpoints.desktop), ScreenSize.desktop);
    expect(ScreenSize.mobile.usesSideNavigation, isFalse);
    expect(ScreenSize.desktop.usesSideNavigation, isTrue);
  });
}
```

The welcome screen also renders the `Folo` wordmark, so the dashboard assertion
must stay distinguishable: if `find.text('Folo')` becomes ambiguous, assert on
the dashboard's own sign-out action (`find.byTooltip('Sign out')`, added in
Task 12) instead.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all green.

- [ ] **Step 7: Commit**

```bash
git add lib/app/router test/app/router test/app_test.dart
git commit -m "feat(auth): guard routes on the session and follow recovery links"
```

---

### Task 12: Sign out

**Files:**
- Modify: `lib/features/dashboard/presentation/dashboard_page.dart`
- Test: `test/features/dashboard/presentation/dashboard_page_test.dart`

**Interfaces:**
- Consumes: `authRepositoryProvider`.
- Produces: `DashboardPage` becomes a `ConsumerWidget` with a trailing
  `Sign out` action.

> The spec puts sign out in the Sidebar account block on desktop and a Today
> overflow item on mobile. Neither a Sidebar nor a Today screen exists yet, and
> the components doc has no menu component, so this is one trailing `IconButton`
> — the same single action with less machinery. It moves when a settings screen
> exists.

- [ ] **Step 1: Write the failing test**

`test/features/dashboard/presentation/dashboard_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/dashboard/presentation/dashboard_page.dart';

import '../../auth/fake_auth_repository.dart';

Widget _host(FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp(theme: AppTheme.light, home: const DashboardPage()),
);

void main() {
  testWidgets('signs out from the trailing action', (tester) async {
    final fake = FakeAuthRepository()..session = true;
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signOut()']);
  });

  testWidgets('a failed sign out does not crash the screen', (tester) async {
    final fake = FakeAuthRepository()
      ..session = true
      ..failWith = AuthFailure.network;
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Folo'), findsOneWidget);
  });
}
```

Add `import 'package:folo/features/auth/domain/auth_failure.dart';` for the
second test.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dashboard/presentation/dashboard_page_test.dart`
Expected: FAIL — `No widget with tooltip "Sign out"`.

- [ ] **Step 3: Add the action**

`lib/features/dashboard/presentation/dashboard_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';

/// Temporary entry screen. The real "What should I do today?" dashboard is
/// built in a later step; this exists so the router has a signed-in
/// destination, and so there is somewhere to sign out from.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            // The router sends the user to /welcome as soon as the session
            // goes; a failure here leaves them signed in, which is the safe
            // outcome and needs no screen state.
            onPressed: () => ref
                .read(authRepositoryProvider)
                .signOut()
                .onError<AuthFailure>((_, _) {}),
          ),
        ],
      ),
      body: Center(
        child: Text('Folo', style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dashboard/presentation/dashboard_page_test.dart`
Expected: PASS. If `onError<AuthFailure>((_, _) {})` trips the analyzer on
wildcard parameters, write `.onError<AuthFailure>((error, stack) {})`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard test/features/dashboard
git commit -m "feat(auth): add sign out to the dashboard app bar"
```

---

### Task 13: Deep links, docs and the release gate

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Modify: `docs/architecture.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: `SupabaseConfig.redirectUrl` (`io.supabase.folo://login-callback/`).
- Produces: nothing in Dart. This task makes email confirmation and password
  recovery actually come back into the app on a device.

- [ ] **Step 1: Add the Android intent filter**

In `android/app/src/main/AndroidManifest.xml`, inside the `.MainActivity`
`<activity>` element, after the existing LAUNCHER `<intent-filter>` and before
`</activity>`:

```xml
            <!-- Supabase email confirmation, password recovery and OAuth come
                 back to io.supabase.folo://login-callback/ (SupabaseConfig). -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="io.supabase.folo"
                      android:host="login-callback"/>
            </intent-filter>
```

`android:launchMode="singleTop"` is already set, which is what lets the callback
reuse the running activity instead of starting a second one.

- [ ] **Step 2: Add the iOS URL type**

In `ios/Runner/Info.plist`, inside the top-level `<dict>` (before the final
`</dict>` on the last line):

```xml
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string>io.supabase.folo</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>io.supabase.folo</string>
			</array>
		</dict>
	</array>
```

Keep the file's tab indentation — Xcode rewrites it otherwise.

- [ ] **Step 3: Verify the link opens the app**

Run, with an Android emulator or device attached and the app installed:

```bash
flutter run -d android
adb shell am start -a android.intent.action.VIEW -d "io.supabase.folo://login-callback/"
```

Expected: the running app comes to the foreground rather than a browser
error. On iOS the equivalent is
`xcrun simctl openurl booted "io.supabase.folo://login-callback/"`.

If no device is available, record in the PR that the intent filter and
`Info.plist` entry are unverified on hardware, and that the web flow was
verified instead with `flutter run -d chrome` (`http://localhost:<port>` must be
in the project's allowed redirect URLs).

- [ ] **Step 4: Update `docs/architecture.md`**

In the directory map, add under `core/`:

```
    supabase/                    # client provider + committed project config
```

and under `features/`:

```
    auth/                        # welcome, sign in, register, reset, guard
```

Replace the "Not yet present, by design" paragraph with:

```markdown
### Not yet present, by design

Firebase Cloud Messaging, a profiles table, account deletion, localisation,
local persistence beyond the Supabase session, analytics, CI. Each will be added
when the feature that needs it is built.

Supabase arrived with auth (#21): the client is a provider in
`core/supabase/`, its project URL and publishable key are committed there, and
all access sits behind `features/<x>/data/` repositories. The service-role key
is not in this repo and must never be.
```

- [ ] **Step 5: Update `README.md`**

In the setup section, add a short subsection after the install steps:

```markdown
### Auth and Supabase

The Supabase project URL and publishable key are committed in
`lib/core/supabase/supabase_config.dart` — the publishable key is public by
design and Row Level Security is the boundary. Nothing to configure locally.

Email confirmation and password recovery return to
`io.supabase.folo://login-callback/`. On web, add the origin you develop on
(`http://localhost:<port>`) to the project's allowed redirect URLs.

These project settings are managed in the Supabase dashboard, not in this repo:
email confirmations on, minimum password length 8, Google and Apple providers,
allowed redirect URLs.
```

- [ ] **Step 6: Run the release gate**

Run:

```bash
dart format .
flutter analyze
flutter test
flutter build web --release
```

Expected: format clean, "No issues found!", every test green, web build
succeeds.

- [ ] **Step 7: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist docs/architecture.md README.md
git commit -m "chore(auth): register the auth deep link and document Supabase"
```

- [ ] **Step 8: Open the PR**

```bash
git push -u origin feature/21-auth-login
gh pr create --fill
```

Fill the **Ticket** section with `Closes #21`.

---

## Known debt this ships with

- Google and Apple buttons are label-only until their official brand assets are
  added; both vendors mandate their own artwork.
- The wordmark is set type, not a logo.
- OAuth is a browser redirect, not a native sheet.
- No account deletion, no profiles table.
- Sign out sits in the dashboard app bar until a settings screen exists.
