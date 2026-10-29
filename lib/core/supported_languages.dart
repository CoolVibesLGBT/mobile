/// Languages currently shipped by the app and their matching flag artwork.
/// Keep menus and settings rows backed by this single list.
final class SupportedLanguage {
  final String code;
  final String name;
  final String flagAsset;

  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.flagAsset,
  });
}

abstract final class SupportedLanguages {
  static const all = <SupportedLanguage>[
    SupportedLanguage(
      code: 'tr',
      name: 'Türkçe',
      flagAsset: 'assets/flags/flutter/tr.svg',
    ),
    SupportedLanguage(
      code: 'en',
      name: 'English',
      flagAsset: 'assets/flags/flutter/en.svg',
    ),
    SupportedLanguage(
      code: 'ar',
      name: 'العربية',
      flagAsset: 'assets/flags/flutter/ar.svg',
    ),
  ];
}
