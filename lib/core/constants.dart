abstract final class AppConstants {
  static const registrationCaptchaEnabled = bool.fromEnvironment(
    'REGISTRATION_CAPTCHA_ENABLED',
    defaultValue: false,
  );
  static const mobileRegistrationCaptcha = 'COOLVIBES';
  static const registrationDomain = 'coolvibes.lgbt';
  static const recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_SITE_KEY',
    defaultValue: '6LecaQIsAAAAAOptodMnAZCOiKSVysrvKnmsXDix',
  );
  static const recaptchaOrigin = 'https://coolvibes.lgbt/';
}
