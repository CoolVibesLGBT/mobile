import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_design.dart';
import 'glass_surface.dart';
import 'app_pressable.dart';

/// The text editor used by chat, posts, replies, check-ins and stories.
class MessageField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final int minLines;
  final int? maxLines;
  final double? maxHeight;
  final ValueChanged<String>? onChanged;
  final bool enabled, story, expanded, autofocus, plain;
  final TextStyle? textStyle;
  final Widget? trailing, helper;
  final FocusNode? focusNode;
  final VoidCallback? onTap, onSubmit;
  const MessageField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.minLines = 1,
    this.maxLines,
    this.maxHeight = 160,
    this.onChanged,
    this.enabled = true,
    this.story = false,
    this.expanded = false,
    this.autofocus = false,
    this.plain = false,
    this.textStyle,
    this.trailing,
    this.helper,
    this.focusNode,
    this.onTap,
    this.onSubmit,
  });

  bool get composing =>
      controller.value.composing.isValid &&
      !controller.value.composing.isCollapsed;

  void submit() {
    if (enabled && !composing) onSubmit?.call();
  }

  KeyEventResult handleKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (composing) return KeyEventResult.skipRemainingHandlers;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent && enabled) {
      if (keyboard.isShiftPressed) {
        final value = controller.value;
        final selection = value.selection;
        final start = selection.isValid ? selection.start : value.text.length;
        final end = selection.isValid ? selection.end : start;
        controller.value = TextEditingValue(
          text: value.text.replaceRange(start, end, '\n'),
          selection: TextSelection.collapsed(offset: start + 1),
        );
        onChanged?.call(controller.text);
      } else {
        submit();
      }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final inputRow = Row(
      crossAxisAlignment: expanded
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.end,
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: expanded
                  ? double.infinity
                  : maxHeight ?? double.infinity,
            ),
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: onSubmit == null ? null : handleKey,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onTap: onTap,
                minLines: expanded ? null : minLines,
                maxLines: expanded ? null : maxLines,
                expands: expanded,
                autofocus: autofocus,
                readOnly: !enabled,
                textAlign: story ? TextAlign.center : TextAlign.start,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: onSubmit == null
                    ? TextInputAction.newline
                    : TextInputAction.send,
                // Sending keeps the editor and software keyboard focused.
                onEditingComplete: onSubmit == null ? null : () {},
                onSubmitted: onSubmit == null ? null : (_) => submit(),
                keyboardType: TextInputType.multiline,
                keyboardAppearance: Theme.of(context).brightness,
                scrollPadding: const EdgeInsets.all(24),
                cursorColor: AppPalette.of(context).accent,
                style:
                    textStyle ??
                    AppDesign.font(
                      story ? 30 : AppDesign.bodySize,
                      height: story
                          ? null
                          : AppDesign.messageLineHeight / AppDesign.bodySize,
                      weight: story ? FontWeight.w600 : FontWeight.w400,
                      color: story ? Colors.white : AppPalette.of(context).text,
                    ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: AppDesign.font(
                    story ? 30 : AppDesign.bodySize,
                    height: story
                        ? null
                        : AppDesign.messageLineHeight / AppDesign.bodySize,
                    color: story
                        ? Colors.white70
                        : AppPalette.of(context).secondaryLabel,
                  ),
                  isDense: true,
                  filled: false,
                  contentPadding: plain
                      ? EdgeInsets.zero
                      : expanded
                      ? const EdgeInsets.fromLTRB(0, 4, 0, 10)
                      : AppDesign.composerFieldInsets,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        if (trailing != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: trailing!,
          ),
      ],
    );
    final content = Column(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        ?helper,
        if (expanded) Expanded(child: inputRow) else inputRow,
      ],
    );
    return expanded || plain
        ? content
        : AppPressable(
            label: '',
            style: AppPressStyle.glass,
            observeOnly: true,
            enabled: enabled,
            child: GlassSurface(
              role: GlassSurfaceRole.input,
              interactive: enabled,
              radius: AppDesign.messageCorner,
              child: content,
            ),
          );
  }
}
