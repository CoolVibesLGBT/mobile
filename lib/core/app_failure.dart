import 'package:flutter/services.dart';
import 'api.dart';

enum FailureKind {
  connection,
  server,
  credentials,
  usernameTaken,
  emailTaken,
  referral,
  captcha,
  invalidInput,
  rateLimited,
  forbidden,
  notFound,
  storage,
  unknown,
}

class AuthenticationCompletionException implements Exception {
  final Object cause;
  final bool accountCreated;
  const AuthenticationCompletionException(
    this.cause, {
    required this.accountCreated,
  });
}

class AppFailure {
  final FailureKind kind;
  final int? httpStatus;
  final String? code;
  final bool accountCreated;
  const AppFailure(
    this.kind, {
    this.httpStatus,
    this.code,
    this.accountCreated = false,
  });

  factory AppFailure.from(Object exception, {String? action}) {
    final accountCreated =
        exception is AuthenticationCompletionException &&
        exception.accountCreated;
    final error = exception is AuthenticationCompletionException
        ? exception.cause
        : exception;
    if (error is PlatformException &&
        (exception is AuthenticationCompletionException ||
            error.code == 'Unexpected security result code' ||
            error.code == '-34018' ||
            error.details == -34018)) {
      final missingEntitlement =
          error.details == -34018 ||
          '${error.code} ${error.message}'.contains('-34018');
      return AppFailure(
        FailureKind.storage,
        code: missingEntitlement
            ? 'KEYCHAIN_ENTITLEMENT (-34018)'
            : 'SECURE_STORAGE',
        accountCreated: accountCreated,
      );
    }
    if (error is! ApiException) {
      return AppFailure(
        FailureKind.unknown,
        code: 'UNEXPECTED_ERROR',
        accountCreated: accountCreated,
      );
    }
    final status = error.status;
    final message = error.message.trim().toLowerCase();
    final kind = error.connectionFailure
        ? FailureKind.connection
        : status == 429
        ? FailureKind.rateLimited
        : status != null && status >= 500
        ? FailureKind.server
        : switch (message) {
            'username already exists' => FailureKind.usernameTaken,
            'email already exists' => FailureKind.emailTaken,
            'invalid referral code' ||
            'referral is unavailable' => FailureKind.referral,
            'invalid captcha' || 'invalid_captcha' => FailureKind.captcha,
            _ when action == 'auth.login' && status == 401 =>
              FailureKind.credentials,
            _ when status == 403 => FailureKind.forbidden,
            _ when status == 404 => FailureKind.notFound,
            _
                when status == 400 ||
                    status == 401 ||
                    status == 409 ||
                    status == 422 =>
              FailureKind.invalidInput,
            _ => FailureKind.unknown,
          };
    // Only known service codes are safe for display; never include raw bodies,
    // request URLs, credentials or exception text in a user-facing diagnostic.
    const publicCodes = {
      'INVALID_INPUT',
      'INVALID_FORM',
      'USER_EXISTS',
      'INVALID_CAPTCHA',
      'DATABASE_ERROR',
      'UNAUTHORIZED',
      'FORBIDDEN',
      'NOT_FOUND',
    };
    return AppFailure(
      kind,
      httpStatus: status,
      code: publicCodes.contains(error.code)
          ? error.code
          : kind.name.toUpperCase(),
      accountCreated: accountCreated,
    );
  }

  String get diagnostic =>
      [if (httpStatus != null) 'HTTP $httpStatus', ?code].join(' · ');
}
