import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// The one entry point for UI strings: `context.l10n.someKey`.
/// Messages live in lib/l10n/app_{en,tr,ar}.arb (English is the template;
/// Turkish and Arabic follow the source app's mobileStrings).
extension AppL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
