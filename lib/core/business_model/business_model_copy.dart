import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/l10n/app_localizations.dart';

String businessModelLabel(AppLocalizations l10n, BusinessModel model) =>
    switch (model) {
      BusinessModel.doterra => l10n.businessModelDoterra,
      BusinessModel.other => l10n.businessModelOther,
    };
