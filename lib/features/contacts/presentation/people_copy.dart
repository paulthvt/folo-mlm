import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/l10n/app_localizations.dart';

/// User-facing words for the contacts domain. Copy, so it lives in
/// presentation.
String stageLabel(AppLocalizations l10n, Stage stage) => switch (stage) {
  Stage.prospect => l10n.stageProspect,
  Stage.customer => l10n.stageCustomer,
  Stage.team => l10n.stageTeam,
};

String statusLabel(AppLocalizations l10n, ProspectStatus status) =>
    switch (status) {
      ProspectStatus.interested => l10n.statusInterested,
      ProspectStatus.thinking => l10n.statusThinking,
      ProspectStatus.notNow => l10n.statusNotNow,
      ProspectStatus.noReply => l10n.statusNoReply,
    };

String peopleFailureCopy(AppLocalizations l10n, PeopleFailure failure) =>
    switch (failure) {
      PeopleFailure.network => l10n.peopleFailureNetwork,
      PeopleFailure.unknown => l10n.peopleFailureUnknown,
    };

/// The second line of a person's row: what they do, else what they need.
String? contactSubtitle(Person person) => person.profession ?? person.needs;
