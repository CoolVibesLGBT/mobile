import '../l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_design.dart';
import '../components/components.dart';
import '../core/session.dart';
import '../core/constants.dart';
import '../core/app_failure.dart';
import '../components/brand_mark.dart';
import 'captcha.dart';

enum _AuthStage { choice, login, register }

Widget _withoutAuthScrollbar(BuildContext context, Widget child) =>
    ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: child,
    );

class AuthScreen extends StatefulWidget {
  final bool initialRegister, showChoices;
  const AuthScreen({
    super.key,
    this.initialRegister = false,
    this.showChoices = true,
  });
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  final languageMenu = GlobalKey<AppContextMenuState>();
  final nickname = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController(),
      referral = TextEditingController();
  final passwordFocus = FocusNode(), confirmationFocus = FocusNode();
  late _AuthStage stage = widget.initialRegister
      ? _AuthStage.register
      : widget.showChoices
      ? _AuthStage.choice
      : _AuthStage.login;
  _AuthStage? selected;
  bool busy = false, accepted = false, errorPresented = false;
  String? error;
  bool get register => stage == _AuthStage.register;
  bool get choosing => stage == _AuthStage.choice;

  @override
  void dispose() {
    scroll.dispose();
    passwordFocus.dispose();
    confirmationFocus.dispose();
    for (final c in [nickname, password, confirmation, referral]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get canProceed =>
      !busy &&
      !errorPresented &&
      (choosing
          ? selected != null
          : nickname.text.trim().isNotEmpty &&
                password.text.isNotEmpty &&
                (!register ||
                    (nicknameError(nickname.text) == null &&
                        confirmation.text == password.text)));

  String? nicknameError(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return context.l10n.required;
    if (!register) return null;
    if (text.length < 3) return context.l10n.authNicknameTooShort;
    if (text.length > 30 || !RegExp(r'^[a-z0-9_]+$').hasMatch(text)) {
      return context.l10n.authNicknameInvalid;
    }
    return null;
  }

  void back() {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      selected = stage;
      stage = _AuthStage.choice;
      error = null;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> submit() async {
    if (busy || errorPresented) return;
    if (choosing) {
      if (selected != null) {
        setState(() {
          stage = selected!;
          error = null;
        });
        if (scroll.hasClients) scroll.jumpTo(0);
      }
      return;
    }
    if (!canProceed || !form.currentState!.validate()) return;
    if (register && !accepted) {
      setState(() => error = context.l10n.acceptTheTermsToContinue);
      return;
    }
    final session = AppScope.of(context);
    final credentials = <String, dynamic>{
      'nickname': nickname.text.trim().toLowerCase(),
      'password': password.text,
      if (register) ...{
        'name': nickname.text.trim(),
        'domain': AppConstants.registrationDomain,
        if (referral.text.trim().isNotEmpty)
          'referralCode': referral.text.trim(),
      },
    };
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    ErrorSheetResult? recovery;
    try {
      if (register) {
        if (AppConstants.registrationCaptchaEnabled) {
          final captcha = await sheet<String>(context, const CaptchaScreen());
          if (!mounted || captcha == null || captcha.trim().isEmpty) return;
          credentials['recaptchaToken'] = captcha.trim();
        } else {
          credentials['captcha'] = AppConstants.mobileRegistrationCaptcha;
        }
      }
      await session.authenticate(credentials, register: register);
      TextInput.finishAutofillContext();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          errorPresented = true;
        });
        recovery = await showErrorSheet(
          context,
          AppFailure.from(e, action: register ? 'auth.register' : 'auth.login'),
          registration: register,
          allowRetry: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          errorPresented = false;
        });
      }
    }
    if (!mounted) return;
    if (recovery == ErrorSheetResult.signIn) {
      setState(() => stage = _AuthStage.login);
    } else if (recovery == ErrorSheetResult.retry) {
      await submit();
    }
  }

  Widget illustration(bool signup, double size) => ExcludeSemantics(
    child: AppImage(
      source: AssetImage(
        'assets/images/auth/${signup ? 'register' : 'login'}-bear.png',
      ),
      width: size,
      height: size,
      fit: BoxFit.contain,
    ),
  );

  Widget choice(_AuthStage value, bool compact) {
    final l = context.l10n, p = AppPalette.of(context);
    final signup = value == _AuthStage.register, active = selected == value;
    final title = signup ? l.authRegisterTitle : l.authLoginTitle;
    final copy = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          signup ? l.authRegisterChoiceSubtitle : l.authLoginSubtitle,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5, color: p.secondaryLabel),
        ),
      ],
    );
    return AppPressable(
      key: ValueKey('auth.choice.${value.name}'),
      label: title,
      selected: active,
      style: AppPressStyle.button,
      onPressed: () => setState(() => selected = value),
      child: Container(
        decoration: BoxDecoration(
          color: active
              ? Color.alphaBlend(p.accent.withValues(alpha: .08), p.row)
              : p.row,
          borderRadius: BorderRadius.circular(AppDesign.authControlRadius),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(compact ? 12 : 16),
              child: compact
                  ? Row(
                      children: [
                        illustration(
                          signup,
                          AppDesign.authCompactChoiceImageSize,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: copy),
                      ],
                    )
                  : Column(
                      children: [
                        illustration(signup, AppDesign.authChoiceImageSize),
                        const SizedBox(height: 10),
                        copy,
                      ],
                    ),
            ),
            if (active)
              PositionedDirectional(
                top: compact ? 6 : 12,
                end: compact ? 6 : 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.accent,
                  ),
                  child: const SizedBox.square(
                    dimension: 20,
                    child: Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget fields() {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField(
          key: const ValueKey('auth.nickname'),
          controller: nickname,
          outlined: true,
          label: l.authNickname,
          placeholder: l.authNicknamePlaceholder,
          enabled: !busy,
          autocorrect: false,
          keyboardType: register
              ? TextInputType.text
              : TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
          validator: nicknameError,
          autovalidateMode: register
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          onChanged: (value) {
            final lower = value.toLowerCase();
            if (lower != value) {
              nickname.value = nickname.value.copyWith(text: lower);
            }
          },
          onSubmitted: (_) => passwordFocus.requestFocus(),
        ),
        if (register)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.authNicknameHint,
              style: TextStyle(
                fontSize: 13,
                color: AppPalette.of(context).secondaryLabel,
              ),
            ),
          ),
        const SizedBox(height: 20),
        AppField(
          key: const ValueKey('auth.password'),
          controller: password,
          focusNode: passwordFocus,
          outlined: true,
          label: l.password,
          placeholder: l.authPasswordPlaceholder,
          obscureText: true,
          enabled: !busy,
          validator: (v) => v == null || v.isEmpty ? l.required : null,
          autofillHints: [
            register ? AutofillHints.newPassword : AutofillHints.password,
          ],
          textInputAction: register
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted: (_) {
            if (register) {
              confirmationFocus.requestFocus();
            } else {
              submit();
            }
          },
        ),
        if (register) ...[
          const SizedBox(height: 20),
          AppField(
            key: const ValueKey('auth.confirmation'),
            controller: confirmation,
            focusNode: confirmationFocus,
            outlined: true,
            label: l.confirmPassword,
            placeholder: l.authConfirmPasswordPlaceholder,
            obscureText: true,
            enabled: !busy,
            validator: (v) => v != password.text ? l.passwordsDoNotMatch : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 20),
          AppField(
            key: const ValueKey('auth.referral'),
            controller: referral,
            outlined: true,
            label: l.referralCodeOptional,
            placeholder: l.authReferralPlaceholder,
            autocorrect: false,
            enabled: !busy,
          ),
          const SizedBox(height: 16),
          AppChoiceRow(
            value: accepted,
            onChanged: busy
                ? null
                : (value) => setState(() => accepted = value ?? false),
            title: Text(l.iAm18OrOlderAnd),
          ),
        ],
      ],
    );
  }

  Widget actions() {
    final l = context.l10n;
    final previous = AppButton.text(
      key: const ValueKey('auth.back'),
      leadingIcon: Icons.arrow_back,
      onPressed: busy ? null : back,
      child: Text(l.authBack),
    );
    final next = ListenableBuilder(
      listenable: Listenable.merge([nickname, password, confirmation]),
      builder: (context, _) => AppButton.filled(
        key: const ValueKey('auth.submit'),
        trailingIcon: Icons.arrow_forward,
        variant: AppButtonVariant.accent,
        onPressed: canProceed ? submit : null,
        loading: busy,
        child: Text(choosing || register ? l.authContinue : l.authLoginTitle),
      ),
    );
    if (!choosing && MediaQuery.textScalerOf(context).scale(1) > 1.4) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          next,
          const SizedBox(height: 8),
          Center(child: previous),
        ],
      );
    }
    return Row(
      children: [
        if (!choosing) ...[previous, const SizedBox(width: 12)],
        Expanded(child: next),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context),
        l = context.l10n,
        session = AppScope.of(context);
    final title = choosing
        ? l.authWelcomeTitle
        : register
        ? l.authRegisterTitle
        : l.authLoginTitle;
    final subtitle = choosing
        ? l.authWelcomeSubtitle
        : register
        ? l.authRegisterSubtitle
        : l.authLoginSubtitle;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: AppDesign.authFontFamily),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: AppDesign.authFontFamily,
          fontSize: 16,
          color: p.text,
        ),
        child: PopScope(
          canPop: !busy && choosing,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !busy && !choosing) back();
          },
          child: AppScaffold(
            backgroundColor: p.row,
            appBar: AppHeader(
              automaticallyImplyLeading: false,
              leading: const SizedBox(
                width: 260,
                child: BrandMark(compact: true),
              ),
              actions: [
                AppContextMenu(
                  key: languageMenu,
                  pressTrigger: true,
                  liftContent: false,
                  enabled: !busy,
                  align: AppMenuAlign.right,
                  label: l.language,
                  items: [
                    for (final (code, name, flag) in [
                      ('tr', 'Türkçe', 'assets/flags/flutter/tr.svg'),
                      ('en', 'English', 'assets/flags/flutter/en.svg'),
                      ('ar', 'العربية', 'assets/flags/flutter/ar.svg'),
                    ])
                      AppMenuItem(
                        title: name,
                        iconAsset: flag,
                        checked: session.locale.languageCode == code,
                        onPressed: () => session.language(Locale(code)),
                      ),
                  ],
                  child: AppIconButton(
                    tooltip:
                        '${l.language} · ${session.locale.languageCode.toUpperCase()}',
                    dimension: 44,
                    glass: true,
                    onPressed: busy
                        ? null
                        : () => languageMenu.currentState?.open(),
                    icon: const Icon(Icons.language),
                  ),
                ),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDesign.authMaxWidth,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Form(
                        key: form,
                        child: AutofillGroup(
                          child: _withoutAuthScrollbar(
                            context,
                            ListView(
                              key: const ValueKey('auth.scroll'),
                              controller: scroll,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                16,
                              ),
                              children: [
                                if (!choosing) ...[
                                  Center(
                                    child: illustration(
                                      register,
                                      AppDesign.authHeadingImageSize,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Semantics(
                                  header: true,
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                      letterSpacing: -.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: p.secondaryLabel,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                if (!choosing) ...[
                                  Row(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < (register ? 3 : 2);
                                        i++
                                      )
                                        Expanded(
                                          child: Container(
                                            margin: EdgeInsetsDirectional.only(
                                              end: i == (register ? 2 : 1)
                                                  ? 0
                                                  : 6,
                                            ),
                                            height: 3,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              color: i <= 1
                                                  ? p.accent
                                                  : p.border,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  fields(),
                                ] else ...[
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final stacked =
                                          MediaQuery.sizeOf(context).width <
                                              479 ||
                                          MediaQuery.textScalerOf(
                                                context,
                                              ).scale(1) >
                                              1.4;
                                      final compact =
                                          MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1) <=
                                          1.4;
                                      return stacked
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                choice(
                                                  _AuthStage.login,
                                                  compact,
                                                ),
                                                const SizedBox(height: 12),
                                                choice(
                                                  _AuthStage.register,
                                                  compact,
                                                ),
                                              ],
                                            )
                                          : Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: choice(
                                                    _AuthStage.login,
                                                    false,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: choice(
                                                    _AuthStage.register,
                                                    false,
                                                  ),
                                                ),
                                              ],
                                            );
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    l.authAccountNote,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: p.secondaryLabel,
                                    ),
                                  ),
                                ],
                                if (kDebugMode)
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: AppIconButton(
                                      tooltip: 'Ekran kataloğu',
                                      icon: const Icon(Icons.developer_mode),
                                      onPressed: busy
                                          ? null
                                          : () => Navigator.of(
                                              context,
                                            ).pushNamed('/debug'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: p.destructive.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(
                                AppDesign.authControlRadius,
                              ),
                            ),
                            child: Text(
                              error!,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: p.destructive,
                              ),
                            ),
                          ),
                        ),
                      ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: actions(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
