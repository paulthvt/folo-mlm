import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/l10n/app_localizations.dart';

/// Localized copy for a validation problem. Shaped for
/// `TextFormField.validator`, so a page passes
/// `validator: (value) => emailFieldError(l10n, value)`.
///
/// The switches are exhaustive over the problem enums: a new problem is a
/// compile error here, which a nullable `String` never gave us.
String? emailFieldError(AppLocalizations l10n, String? value) =>
    switch (validateEmail(value)) {
      null => null,
      EmailProblem.empty => l10n.authEmailRequired,
      EmailProblem.malformed => l10n.authEmailInvalid,
    };

String? passwordFieldError(AppLocalizations l10n, String? value) =>
    switch (validatePassword(value)) {
      null => null,
      PasswordProblem.empty => l10n.authPasswordRequired,
      PasswordProblem.tooShort => l10n.authPasswordTooShort(minPasswordLength),
    };

String? firstNameFieldError(AppLocalizations l10n, String? value) =>
    switch (validateFirstName(value)) {
      null => null,
      FirstNameProblem.empty => l10n.authFirstNameRequired,
    };

String? passwordConfirmationFieldError(
  AppLocalizations l10n,
  String? value,
  String password,
) => switch (validatePasswordConfirmation(value, password)) {
  null => null,
  PasswordConfirmationProblem.empty => l10n.authPasswordConfirmationRequired,
  PasswordConfirmationProblem.mismatch => l10n.authPasswordConfirmationMismatch,
};
