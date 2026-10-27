import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

void registerGlassLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Roboto',
    ], await rootBundle.loadString('assets/licenses/web-roboto.txt'));
    for (final name in ['liquid_glass_widgets', 'liquid_glass_engine']) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/licenses/$name.txt'));
    }
    yield LicenseEntryWithLineBreaks(
      ['Telegram reference artwork'],
      await rootBundle.loadString(
        'assets/licenses/telegram-background-NOTICE.txt',
      ),
    );
  });
}
