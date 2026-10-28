import 'app_resize.dart';
import '../l10n/l10n.dart';
import 'app_button.dart';
import 'package:flutter/material.dart';
import 'app_lottie.dart';
import 'emoticon_view.dart';
import 'app_pressable.dart';
import '../design/app_design.dart';
import '../core/app_failure.dart';
import 'navigation.dart';
import 'app_row.dart';

/// All remote screens use one loading, failure and empty presentation.
class ScreenStatus extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback? retry;
  final bool compact;
  final EdgeInsetsGeometry padding;
  final Widget? details, actions;

  /// NativeScreenState title/message and animation (search, empty, error,
  /// messages). Without a title the error or the generic empty copy is used.
  final String? title, message, animation;
  const ScreenStatus({
    super.key,
    this.loading = false,
    this.error,
    this.retry,
    this.compact = false,
    this.title,
    this.message,
    this.animation,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 44),
    this.details,
    this.actions,
  });
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: loading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      error ?? title ?? context.l10n.nothingHereYet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (retry != null)
                    AppIconButton(
                      tooltip: context.l10n.retry,
                      onPressed: retry,
                      icon: const Icon(Icons.refresh),
                    ),
                  ?actions,
                ],
              ),
      );
    }
    // NativeScreenState: Telegram animated placeholder, 20pt title, 15pt
    // message and a plain accent "Try again".
    final palette = AppPalette.of(context);
    final kind = animation ?? (error != null ? 'error' : 'empty');
    final Map<String, dynamic>? duckSticker = switch (kind) {
      'duck_fantasies' => {
        'kind': 'sticker',
        'id': '4fccb7cee6ad0f05',
        'url': '/animations/telegram/packs/4fccb7cee6ad0f05.tgs',
        'emoji': '😘',
        'width': 512,
        'height': 512,
      },
      'duck_interests' => {
        'kind': 'sticker',
        'id': 'a60b07ed596c2937',
        'url': '/animations/telegram/packs/a60b07ed596c2937.tgs',
        'emoji': '🌈',
        'width': 512,
        'height': 512,
      },
      _ => null,
    };
    final asset =
        const {
          'search': 'assets/animations/search.json',
          'error': 'assets/animations/restricted.json',
          'messages': 'assets/animations/chat.json',
        }[kind] ??
        'assets/animations/empty.json';
    final heading = title ?? error ?? context.l10n.noItemsHereYet;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  height: 132,
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: duckSticker == null
                      ? AppLottie(
                          asset: asset,
                          size: 132,
                          loop: kind != 'error',
                          staticProgress: .5,
                        )
                      : EmoticonView(document: duckSticker, size: 156),
                ),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  liveRegion: error != null,
                  child: Text(
                    heading,
                    textAlign: TextAlign.center,
                    style: AppDesign.font(
                      20,
                      weight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: AppDesign.font(
                      15,
                      color: palette.secondaryLabel,
                      height: 20 / 15,
                    ),
                  ),
                ],
                if (retry != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: AppPressable(
                      label: context.l10n.tryAgain,
                      onPressed: retry,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            context.l10n.tryAgain,
                            style: AppDesign.font(17, color: palette.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (details != null) ...[const SizedBox(height: 20), details!],
                if (actions != null) ...[const SizedBox(height: 24), actions!],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum ErrorSheetResult { retry, signIn }

Future<T?> showInfoSheet<T>(BuildContext context, Widget page) {
  FocusManager.instance.primaryFocus?.unfocus();
  final media = MediaQuery.of(context);
  return sheet<T>(
    context,
    page,
    halfSize: .6,
    fullSize:
        (480 * media.textScaler.scale(1).clamp(1, 1.6) +
                media.viewPadding.bottom)
            .clamp(0, media.size.height - media.viewPadding.top - 12)
            .toDouble(),
  );
}

class AppInfoSheet extends StatelessWidget {
  final String title, message, animation;
  final Widget? details, actions;
  final bool isError;
  final String id;
  const AppInfoSheet({
    super.key,
    required this.title,
    required this.message,
    this.animation = 'error',
    this.details,
    this.actions,
    this.isError = false,
    this.id = 'info.sheet',
  });

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SafeArea(
      top: true,
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppIconButton(
              key: ValueKey('$id.close'),
              tooltip: context.l10n.close,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: ListView(
              key: ValueKey('$id.scroll'),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              children: [
                ScreenStatus(
                  title: title,
                  message: message,
                  error: isError ? message : null,
                  animation: animation,
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                  details: details,
                  actions: actions,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<ErrorSheetResult?> showErrorSheet(
  BuildContext context,
  AppFailure failure, {
  bool registration = false,
  bool allowRetry = false,
}) => showInfoSheet<ErrorSheetResult>(
  context,
  AppErrorSheet(
    failure: failure,
    registration: registration,
    allowRetry: allowRetry,
  ),
);

class AppConfirmationAction {
  final String label;
  final Object result;
  final bool destructive;
  const AppConfirmationAction({
    required this.label,
    required this.result,
    this.destructive = true,
  });
}

class AppConfirmationSheet extends StatelessWidget {
  final String title, message;
  final List<AppConfirmationAction> actions;
  const AppConfirmationSheet({
    super.key,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    void finish(Object? confirmed) {
      if (ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.of(context).pop(confirmed);
    }

    return AppInfoSheet(
      id: 'confirmation.sheet',
      title: title,
      message: message,
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            AppButton.filled(
              key: ValueKey(
                i == 0
                    ? 'confirmation.sheet.confirm'
                    : 'confirmation.sheet.action.$i',
              ),
              variant: actions[i].destructive
                  ? AppButtonVariant.critical
                  : AppButtonVariant.accent,
              onPressed: () => finish(actions[i].result),
              child: Text(actions[i].label),
            ),
            const SizedBox(height: 8),
          ],
          AppButton.text(
            key: const ValueKey('confirmation.sheet.cancel'),
            onPressed: () => finish(null),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
  }
}

class AppErrorSheet extends StatefulWidget {
  final AppFailure failure;
  final bool registration, allowRetry;
  const AppErrorSheet({
    super.key,
    required this.failure,
    this.registration = false,
    this.allowRetry = false,
  });
  @override
  State<AppErrorSheet> createState() => _AppErrorSheetState();
}

class _AppErrorSheetState extends State<AppErrorSheet> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n,
        p = AppPalette.of(context),
        failure = widget.failure;
    final message = switch (failure.kind) {
      FailureKind.connection => l.unableToReachTheServiceCheck,
      FailureKind.server => l.errorServerMessage,
      FailureKind.credentials => l.loginFailedPleaseCheckYourCredentials,
      FailureKind.usernameTaken => l.errorUsernameTaken,
      FailureKind.emailTaken => l.errorEmailTaken,
      FailureKind.referral => l.errorReferral,
      FailureKind.captcha => l.errorCaptcha,
      FailureKind.invalidInput => l.errorInvalidInput,
      FailureKind.rateLimited => l.errorRateLimited,
      FailureKind.forbidden => l.errorForbidden,
      FailureKind.notFound => l.errorNotFound,
      FailureKind.storage => l.errorStorageMessage,
      FailureKind.unknown => l.errorUnexpectedMessage,
    };
    final retryable =
        widget.allowRetry &&
        !widget.registration &&
        {
          FailureKind.connection,
          FailureKind.server,
          FailureKind.unknown,
        }.contains(failure.kind);
    return AppInfoSheet(
      id: 'error.sheet',
      isError: true,
      title: failure.accountCreated
          ? l.errorAccountCreatedTitle
          : failure.kind == FailureKind.connection
          ? l.errorConnectionTitle
          : failure.kind == FailureKind.storage
          ? l.errorStorageTitle
          : widget.registration
          ? l.errorRegistrationTitle
          : l.errorRequestTitle,
      message: failure.accountCreated
          ? '${l.errorAccountCreatedMessage}\n\n$message'
          : message,
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppRow(
            title: Text(l.errorDetails),
            trailing: Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            ),
            onTap: () => setState(() => expanded = !expanded),
          ),
          AppResize(
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      failure.diagnostic,
                      textDirection: TextDirection.ltr,
                      style: AppDesign.font(13, color: p.secondaryLabel),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
      actions: AppButton.filled(
        key: const ValueKey('error.sheet.action'),
        variant: AppButtonVariant.accent,
        onPressed: () => Navigator.of(context).pop(
          failure.accountCreated
              ? ErrorSheetResult.signIn
              : retryable
              ? ErrorSheetResult.retry
              : null,
        ),
        child: Text(
          failure.accountCreated
              ? l.authLoginTitle
              : retryable
              ? l.tryAgain
              : l.close,
        ),
      ),
    );
  }
}
