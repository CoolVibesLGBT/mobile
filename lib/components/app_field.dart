import 'app_resize.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../design/app_design.dart';
import 'glass_surface.dart';
import 'app_section.dart';
import 'app_pressable.dart';
import 'app_button.dart';
import '../l10n/l10n.dart';

class AppField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? placeholder;
  final bool obscureText, autofocus, enabled, autocorrect;
  final bool labelAbove;
  final bool outlined;
  final AutovalidateMode autovalidateMode;
  final bool showLabel;
  final String? prefix;
  final FocusNode? focusNode;
  final int minLines, maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted, onChanged;
  const AppField({
    super.key,
    required this.controller,
    required this.label,
    this.placeholder,
    this.obscureText = false,
    this.labelAbove = false,
    this.outlined = false,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.showLabel = true,
    this.prefix,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.autocorrect = true,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.onChanged,
  });
  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  String? error;
  bool revealed = false;
  FocusNode? _ownedFocus;
  FocusNode get focus => widget.focusNode ?? (_ownedFocus ??= FocusNode());
  @override
  void initState() {
    super.initState();
    focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(AppField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocus)?.removeListener(_focusChanged);
      focus.addListener(_focusChanged);
    }
    if (oldWidget.obscureText != widget.obscureText) revealed = false;
  }

  @override
  void dispose() {
    focus.removeListener(_focusChanged);
    _ownedFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppField(
      :controller,
      :label,
      :placeholder,
      :obscureText,
      :autofocus,
      :enabled,
      :autocorrect,
      :minLines,
      :maxLines,
      :keyboardType,
      :textInputAction,
      :autofillHints,
      :validator,
      :onSubmitted,
      :onChanged,
    ) = widget;
    final palette = AppPalette.of(context);
    final scale = MediaQuery.textScalerOf(context);
    // Source NativeField / NativeInputRow: the error is drawn under the field,
    // never inside the input decoration.
    final input = TextFormField(
      focusNode: focus,
      controller: controller,
      obscureText: obscureText && !revealed,
      autofocus: autofocus,
      enabled: enabled,
      autocorrect: autocorrect,
      enableSuggestions: !obscureText && autocorrect,
      keyboardAppearance: Theme.of(context).brightness,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autovalidateMode: widget.autovalidateMode,
      errorBuilder: widget.outlined ? (_, _) => const SizedBox.shrink() : null,
      validator: (value) {
        final message = validator?.call(value);
        if (message != error) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => error = message);
          });
        }
        return message;
      },
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      cursorColor: palette.accent,
      style: AppDesign.font(AppDesign.bodySize, color: palette.text),
      decoration: widget.outlined
          ? InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(color: palette.secondaryLabel),
              filled: false,
              suffixIcon: obscureText
                  ? AppIconButton(
                      embedded: true,
                      tooltip: revealed
                          ? context.l10n.hidePassword
                          : context.l10n.showPassword,
                      icon: Icon(
                        revealed
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                      ),
                      onPressed: enabled
                          ? () => setState(() => revealed = !revealed)
                          : null,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDesign.authControlRadius,
                ),
                borderSide: BorderSide(color: palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDesign.authControlRadius,
                ),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDesign.authControlRadius,
                ),
                borderSide: BorderSide(color: palette.accent),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDesign.authControlRadius,
                ),
                borderSide: BorderSide(color: palette.destructive),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDesign.authControlRadius,
                ),
                borderSide: BorderSide(color: palette.destructive),
              ),
              errorStyle: const TextStyle(fontSize: 0, height: 0),
            )
          : InputDecoration(
              hintText: placeholder,
              prefixText: widget.prefix,
              hintStyle: AppDesign.font(
                AppDesign.bodySize,
                color: palette.secondaryLabel,
              ),
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorStyle: const TextStyle(fontSize: 0, height: 0),
              contentPadding: EdgeInsets.symmetric(
                vertical: widget.labelAbove ? 13 : 11,
              ),
            ),
    );
    final message = error == null
        ? null
        : Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: widget.outlined
                  ? Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: palette.destructive,
                    )
                  : AppDesign.font(13, color: palette.destructive),
            ),
          );
    if (widget.outlined) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedDefaultTextStyle(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppDesign.buttonRelease,
            style: AppDesign.font(
              15,
              weight: FontWeight.w500,
              color: error != null
                  ? palette.destructive
                  : focus.hasFocus
                  ? palette.accent
                  : palette.secondaryLabel,
            ),
            child: Text(label),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: label,
            child: AppPressable(
              label: '',
              style: AppPressStyle.glass,
              observeOnly: true,
              enabled: enabled,
              child: GlassSurface(
                role: GlassSurfaceRole.input,
                interactive: enabled,
                radius: AppDesign.authControlRadius,
                child: input,
              ),
            ),
          ),
          AppResize(
            child: message == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: message,
                  ),
          ),
        ],
      );
    }
    if (widget.labelAbove) {
      // NativeField: 15pt medium label, 7pt gap, 50pt field with 12pt corners.
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: AppDesign.font(
                15,
                weight: FontWeight.w500,
                color: palette.secondaryLabel,
              ),
            ),
            const SizedBox(height: 7),
            Semantics(
              label: label,
              child: GlassSurface(
                role: GlassSurfaceRole.input,
                radius: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      width: 1 / MediaQuery.devicePixelRatioOf(context),
                      color: error == null
                          ? palette.border
                          : palette.destructive,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 50),
                      child: Center(child: input),
                    ),
                  ),
                ),
              ),
            ),
            if (message != null) ...[const SizedBox(height: 6), message],
          ],
        ),
      );
    }
    // NativeInputRow: label leads a 44pt row; large text stacks them.
    final stacked = minLines > 1 || scale.scale(17) > 17 * 1.35;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: !widget.showLabel
          ? input
          : stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Text(
                    label,
                    style: AppDesign.font(17, color: palette.text),
                  ),
                ),
                input,
              ],
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppDesign.rowHeight),
              child: Row(
                children: [
                  Flexible(
                    flex: 4,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: scale.scale(118)),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: Text(
                          label,
                          style: AppDesign.font(17, color: palette.text),
                        ),
                      ),
                    ),
                  ),
                  Expanded(flex: 7, child: input),
                ],
              ),
            ),
    );
    final section = AppSection.position(context);
    if (section != null) {
      return Semantics(
        label: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: section
                ? null
                : Border(
                    bottom: BorderSide(
                      color: palette.border,
                      width: 1 / MediaQuery.devicePixelRatioOf(context),
                    ),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row,
              if (message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: message,
                ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      label: label,
      child: GlassSurface(
        role: GlassSurfaceRole.input,
        radius: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            if (message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: message,
              ),
          ],
        ),
      ),
    );
  }
}

class AppSearchField extends StatefulWidget {
  final String placeholder;
  final ValueChanged<String> onSearch;
  final ValueChanged<String>? onChanged;
  final Duration debounceDuration;
  final bool autofocus, floating;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  const AppSearchField({
    super.key,
    required this.placeholder,
    required this.onSearch,
    this.onChanged,
    this.debounceDuration = const Duration(milliseconds: 350),
    this.autofocus = false,
    this.floating = false,
    this.controller,
    this.focusNode,
  });
  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  Timer? debounce;
  String? submitted;
  void search(String value) {
    debounce?.cancel();
    final term = value.trim();
    if (submitted == term) return;
    submitted = term;
    widget.onSearch(term);
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  /// Telegram SearchBarNode (.modern): a 36pt field with 21pt corner
  /// diameter, 17pt text and the navigation search input fill.
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final radius = widget.floating ? AppDesign.messageCorner : 10.5;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AppPressable(
        label: '',
        style: AppPressStyle.glass,
        observeOnly: true,
        child: GlassSurface(
          role: GlassSurfaceRole.input,
          useOwnLayer: true,
          interactive: true,
          radius: radius,
          child: CupertinoSearchTextField(
            controller: widget.controller,
            padding: EdgeInsetsDirectional.fromSTEB(
              widget.floating ? 12 : 5.5,
              widget.floating ? 12 : 8,
              0,
              widget.floating ? 12 : 8,
            ),
            backgroundColor: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            placeholder: widget.placeholder,
            placeholderStyle: TextStyle(
              fontFamily: AppDesign.fontFamily,
              fontSize: 17,
              color: palette.secondaryLabel,
            ),
            itemColor: palette.secondaryLabel,
            cursorColor: palette.accent,
            suffixIcon: Icon(
              CupertinoIcons.xmark_circle_fill,
              semanticLabel: context.l10n.clearSearch,
            ),
            autofocus: widget.autofocus,
            autocorrect: false,
            focusNode: widget.focusNode,
            onSubmitted: search,
            onChanged: (value) {
              submitted = null;
              widget.onChanged?.call(value);
              debounce?.cancel();
              if (value.isEmpty) {
                search('');
              } else {
                debounce = Timer(widget.debounceDuration, () => search(value));
              }
            },
            style: TextStyle(
              fontFamily: AppDesign.fontFamily,
              fontSize: 17,
              color: palette.text,
            ),
          ),
        ),
      ),
    );
  }
}
