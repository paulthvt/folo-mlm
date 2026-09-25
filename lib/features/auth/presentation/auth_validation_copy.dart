import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/l10n/app_localizations.dart';

/// Turns what the domain found wrong into the sentence under the field.
///
/// `null` in, `null` out: a form can hand a validator's result straight to
/// these and pass the result to `TextFormField.validator` unchanged.
String? emailProblemCopy(AppLocalizations l10n, EmailProblem? problem) =>
    switch (problem) {
      null => null,
      EmailProblem.empty => l10n.authEmailRequired,
      EmailProblem.malformed => l10n.authEmailInvalid,
    };

String? passwordProblemCopy(AppLocalizations l10n, PasswordProblem? problem) =>
    switch (problem) {
      null => null,
      PasswordProblem.empty => l10n.authPasswordRequired,
      // The number comes from the constant the validator uses, not from the
      // sentence, so the two cannot drift apart.
      PasswordProblem.tooShort => l10n.authPasswordTooShort(minPasswordLength),
    };

String? firstNameProblemCopy(
  AppLocalizations l10n,
  FirstNameProblem? problem,
) => switch (problem) {
  null => null,
  FirstNameProblem.empty => l10n.authFirstNameRequired,
};

String? passwordConfirmationProblemCopy(
  AppLocalizations l10n,
  PasswordConfirmationProblem? problem,
) => switch (problem) {
  null => null,
  PasswordConfirmationProblem.empty => l10n.authPasswordConfirmationRequired,
  PasswordConfirmationProblem.mismatch => l10n.authPasswordConfirmationMismatch,
};
