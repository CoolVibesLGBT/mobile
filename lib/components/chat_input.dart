import '../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../core/attachments.dart';
import '../core/api.dart';
import '../screens/emoticons.dart';
import 'app_button.dart';
import 'app_pressable.dart';
import 'app_context_menu.dart';
import 'glass_surface.dart';
import '../design/app_design.dart';
import 'message_field.dart';
import 'attachment_controls.dart';
import 'navigation.dart';

/// Source ChatInput: 44pt paperclip, 6pt gap, 22pt field, internal emoji,
/// and a separate accent send circle only when there is content.
class ChatInput extends StatefulWidget {
  final FocusNode? focusNode;
  final TextEditingController controller;
  final AttachmentController attachments;
  final bool sending, editing, expanded, hasExtraContent;
  final String? placeholder;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final ValueChanged<Json>? onSendEmoticon;
  final ValueChanged<double>? onPanelExpansionChanged;
  final Widget? helper;

  /// Telegram ChatSendMessageContextScreen: long-pressing send offers these
  /// (schedule, self-destruct timer).
  final List<AppMenuItem> sendOptions;

  /// Accessory inside the field before the emoji key (scheduled messages).
  final Widget? accessory;
  const ChatInput({
    super.key,
    required this.controller,
    required this.attachments,
    required this.sending,
    required this.onSend,
    required this.onChanged,
    this.onSendEmoticon,
    this.onPanelExpansionChanged,
    this.expanded = false,
    this.hasExtraContent = false,
    this.placeholder,
    this.helper,
    this.sendOptions = const [],
    this.accessory,
    this.editing = false,
    this.focusNode,
  });
  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final internalFocus = FocusNode();
  FocusNode get focus => widget.focusNode ?? internalFocus;
  bool panel = false, searching = false, panelExpanded = false;
  bool recordingBusy = false, voiceHolding = false, voiceLocked = true;
  bool voiceFinishing = false;
  Future<void>? voiceStart;
  final fieldKey = GlobalKey();
  double fieldHeight = 44;
  double keyboardHeight = 300;
  late final AnimationController expansion;

  bool get hasSendContent =>
      widget.controller.text.trim().isNotEmpty ||
      (!widget.editing &&
          (widget.attachments.hasContent || widget.hasExtraContent));

  bool get canSubmit =>
      hasSendContent &&
      !widget.sending &&
      !widget.attachments.recording &&
      !recordingBusy &&
      !voiceFinishing;

  void submit() {
    if (canSubmit) widget.onSend();
  }

  @override
  void initState() {
    super.initState();
    expansion = AnimationController(
      vsync: this,
      duration: AppDesign.mediaExpansionDuration,
    )..addListener(() => widget.onPanelExpansionChanged?.call(expansion.value));
    WidgetsBinding.instance.addObserver(this);
    focus.addListener(focusChanged);
  }

  void focusChanged() {
    if (focus.hasFocus && panel) hidePanel();
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? internalFocus).removeListener(focusChanged);
      focus.addListener(focusChanged);
    }
  }

  void setExpanded(bool value) {
    if (!mounted || widget.expanded || value == panelExpanded) return;
    HapticFeedback.selectionClick();
    setState(() => panelExpanded = value);
    if (MediaQuery.disableAnimationsOf(context)) {
      expansion.value = value ? 1 : 0;
    } else {
      expansion.animateWith(
        SpringSimulation(
          AppDesign.mediaExpansionSpring,
          expansion.value,
          value ? 1 : 0,
          expansion.velocity,
          snapToEnd: true,
        ),
      );
    }
  }

  void hidePanel({bool keyboard = false}) {
    setExpanded(false);
    setState(() {
      panel = false;
      searching = false;
    });
    if (keyboard) focus.requestFocus();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    focus.removeListener(focusChanged);
    expansion.dispose();
    final notify = widget.onPanelExpansionChanged;
    WidgetsBinding.instance.addPostFrameCallback((_) => notify?.call(0));
    internalFocus.dispose();
    super.dispose();
  }

  Future<void> startVoice({bool locked = true}) async {
    if (recordingBusy ||
        voiceFinishing ||
        widget.attachments.recording ||
        widget.sending ||
        widget.editing) {
      return;
    }
    focus.unfocus();
    if (panel) hidePanel();
    setState(() {
      recordingBusy = true;
      voiceLocked = locked;
      voiceHolding = !locked;
      panel = false;
    });
    final operation = voiceStart = widget.attachments.startRecording();
    await perform(context, () => operation);
    if (mounted) setState(() => recordingBusy = false);
  }

  Future<void> finishVoice({bool cancel = false, bool send = false}) async {
    if (voiceFinishing) return;
    voiceHolding = false;
    setState(() => voiceFinishing = true);
    try {
      try {
        await voiceStart;
      } catch (_) {
        return;
      }
      if (!mounted || !widget.attachments.recording) return;
      await perform(context, () async {
        await widget.attachments.stopRecording(cancel: cancel);
        if (mounted && send && !cancel && widget.attachments.hasContent) {
          widget.onSend();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          voiceFinishing = false;
          voiceLocked = true;
        });
      }
    }
  }

  void toggleRecording() =>
      widget.attachments.recording ? finishVoice() : startVoice();

  void moveVoice(LongPressMoveUpdateDetails details) {
    if (!voiceHolding || voiceLocked) return;
    final dx =
        details.offsetFromOrigin.dx *
        (Directionality.of(context) == TextDirection.rtl ? -1 : 1);
    if (dx < -80) {
      HapticFeedback.selectionClick();
      finishVoice(cancel: true);
    } else if (details.offsetFromOrigin.dy < -60) {
      HapticFeedback.selectionClick();
      setState(() => voiceLocked = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && widget.attachments.recording) {
      finishVoice();
    }
  }

  void togglePanel() {
    if (panel) {
      hidePanel(keyboard: true);
    } else {
      final inset =
          View.of(context).viewInsets.bottom /
          View.of(context).devicePixelRatio;
      if (inset > 0) keyboardHeight = inset;
      focus.unfocus();
      setState(() {
        panel = true;
        searching = false;
      });
    }
  }

  /// eraseBeforeSelection(): removes the grapheme before the caret.
  void erase() {
    final old = widget.controller.value;
    final selection = old.selection;
    final end = selection.isValid ? selection.end : old.text.length;
    final start = selection.isValid && !selection.isCollapsed
        ? selection.start
        : end;
    if (start != end) {
      widget.controller.value = TextEditingValue(
        text: old.text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
      );
    } else if (end > 0) {
      final before = old.text.substring(0, end).characters;
      final trimmed = before.skipLast(1).toString();
      widget.controller.value = TextEditingValue(
        text: trimmed + old.text.substring(end),
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    widget.onChanged(widget.controller.text);
  }

  void select(Json value) {
    if (value['kind'] == 'emoji') {
      final old = widget.controller.value;
      final selection = old.selection;
      final start = selection.isValid ? selection.start : old.text.length;
      final end = selection.isValid ? selection.end : start;
      final emoji = string(value['emoji']);
      widget.controller.value = TextEditingValue(
        text: old.text.replaceRange(start, end, emoji),
        selection: TextSelection.collapsed(offset: start + emoji.length),
      );
      widget.onChanged(widget.controller.text);
    } else if (!widget.expanded && widget.onSendEmoticon != null) {
      widget.onSendEmoticon!(value);
    } else {
      widget.attachments.emoticon = value;
      widget.attachments.changed();
    }
  }

  Widget buildPanel(BuildContext context) => Builder(
    builder: (context) {
      final media = MediaQuery.of(context);
      final inset = media.viewInsets.bottom;
      final maximum =
          (media.size.height -
                  inset -
                  media.viewPadding.top -
                  AppDesign.mediaExpandedTopInset -
                  fieldHeight -
                  12)
              .clamp(0.0, double.infinity);
      final standard = (keyboardHeight + (searching ? 118 : 0))
          .clamp(160.0, 478.0)
          .clamp(0.0, maximum);
      final collapsed = searching
          ? standard
          : (standard - inset).clamp(0.0, standard);
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: collapsed),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppDesign.mediaExpansionDuration,
        curve: Curves.easeOutCubic,
        builder: (context, baseHeight, _) {
          final height = baseHeight + (maximum - baseHeight) * expansion.value;
          return SizedBox(
            height: height,
            child: EmoticonPicker(
              embedded: true,
              allowEmoji: true,
              emojiOnly: widget.editing,
              initialTab: 'emoji',
              onKeyboard: togglePanel,
              onErase: erase,
              canErase: widget.controller.text.isNotEmpty,
              onSelected: select,
              onSearchFocusChanged: (value) {
                if (mounted) setState(() => searching = value);
              },
              expanded: panelExpanded,
              onExpandChanged: widget.expanded ? null : setExpanded,
            ),
          );
        },
      );
    },
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.attachments,
      expansion,
    ]),
    builder: (context, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.expanded) return;
        final box = fieldKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null &&
            box.hasSize &&
            (fieldHeight - box.size.height).abs() > .5) {
          setState(() => fieldHeight = box.size.height);
        }
      });
      final canSend = hasSendContent;
      if (widget.expanded) {
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MessageField(
                  controller: widget.controller,
                  focusNode: focus,
                  expanded: true,
                  autofocus: true,
                  enabled: !widget.sending,
                  placeholder:
                      widget.placeholder ??
                      context.l10n.shareAThoughtWinQuestionOr,
                  onChanged: widget.onChanged,
                  onTap: () {
                    if (panel) {
                      hidePanel();
                    }
                  },
                ),
              ),
            ),
            AttachmentPreview(controller: widget.attachments),
            // Expanded composer toolbar: a hairline, then tool glyphs in the
            // label colour (attach, voice) and the emoji key on the trailing side.
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppPalette.of(context).border,
                    width: 1 / MediaQuery.devicePixelRatioOf(context),
                  ),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                panel || MediaQuery.viewInsetsOf(context).bottom > 0
                    ? 0
                    : MediaQuery.viewPaddingOf(
                        context,
                      ).bottom.clamp(12.0, double.infinity),
              ),
              child: Row(
                children: [
                  _ToolbarGlyph(
                    label: context.l10n.attachments,
                    symbol: 'paperclip',
                    fallback: Icons.attach_file,
                    size: 24,
                    onTap: widget.sending
                        ? null
                        : () => chooseAttachment(context, widget.attachments),
                  ),
                  _ToolbarGlyph(
                    label: widget.attachments.recording
                        ? context.l10n.stopRecording2
                        : context.l10n.voiceMessage,
                    symbol: widget.attachments.recording ? 'stop.fill' : 'mic',
                    fallback: widget.attachments.recording
                        ? Icons.stop
                        : Icons.mic_none,
                    size: 24,
                    color: widget.attachments.recording
                        ? const Color(0xffff593c)
                        : null,
                    onTap: widget.sending || recordingBusy
                        ? null
                        : toggleRecording,
                  ),
                  const Spacer(),
                  _ToolbarGlyph(
                    label: context.l10n.emojiStickersAndGifs,
                    symbol: panel ? 'keyboard' : 'sticker',
                    fallback: panel
                        ? Icons.keyboard_outlined
                        : Icons.emoji_emotions_outlined,
                    size: 25,
                    onTap: widget.sending ? null : togglePanel,
                  ),
                ],
              ),
            ),
            if (panel) buildPanel(context),
          ],
        );
      }
      // ChatInput (kind chat): footer 8pt sides, 6pt top, bottom inset
      // max(safe area, 12) without a keyboard and 0 above it.
      final palette = AppPalette.of(context);
      final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
      final bottom = panel || keyboard
          ? 0.0
          : MediaQuery.viewPaddingOf(
              context,
            ).bottom.clamp(12.0, double.infinity);
      final footer = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.attachments.recording && voiceHolding)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      voiceLocked
                          ? context.l10n.voiceRecordingLocked
                          : context.l10n.voiceSlideToCancel,
                      style: AppDesign.font(13, color: palette.secondaryLabel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    voiceLocked ? Icons.lock : Icons.lock_open,
                    size: 20,
                    color: palette.secondaryLabel,
                  ),
                ],
              ),
            ),
          Padding(
            key: const ValueKey('chat-composer-row'),
            padding: EdgeInsets.fromLTRB(
              AppDesign.composerSideInset,
              6,
              AppDesign.composerSideInset,
              panel || keyboard ? 6 : bottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Telegram ChatTextInputPanelNode: interactive glass circle
                // with a 24pt paperclip in the secondary label colour.
                if (widget.attachments.recording)
                  const SizedBox(width: AppDesign.composerControl)
                else
                  AppIconButton(
                    glass: true,
                    surfaceRole: GlassSurfaceRole.input,
                    symbolSize: 17,
                    tooltip: context.l10n.attachments,
                    icon: const Icon(Icons.attach_file, size: 24),
                    color: palette.text,
                    onPressed:
                        widget.sending ||
                            widget.editing ||
                            widget.attachments.recording ||
                            recordingBusy
                        ? null
                        : () => chooseAttachment(
                            context,
                            widget.attachments,
                            sendNow: () async => widget.onSend(),
                          ),
                  ),
                const SizedBox(width: AppDesign.composerGap),
                Expanded(
                  child: widget.attachments.recording
                      ? VoiceRecordingBar(
                          controller: widget.attachments,
                          busy: voiceFinishing,
                          onCancel: () => finishVoice(cancel: true),
                          onSend: voiceLocked
                              ? () => finishVoice(send: true)
                              : null,
                        )
                      : MessageField(
                          key: fieldKey,
                          onSubmit: submit,
                          enabled:
                              !widget.sending && !widget.attachments.recording,
                          controller: widget.controller,
                          focusNode: focus,
                          onTap: () {
                            if (panel) {
                              hidePanel();
                            }
                          },
                          helper: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.helper != null) widget.helper!,
                              if (!widget.editing)
                                AttachmentPreview(
                                  controller: widget.attachments,
                                ),
                            ],
                          ),
                          placeholder:
                              widget.placeholder ?? context.l10n.typeAMessage,
                          onChanged: widget.onChanged,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ?widget.accessory,
                              AppPressable(
                                label: panel
                                    ? context.l10n.showKeyboard
                                    : context.l10n.emojiStickersAndGifs,
                                style: AppPressStyle.touchable,
                                onPressed: widget.sending ? null : togglePanel,
                                child: SizedBox.square(
                                  dimension: 44,
                                  child: Center(
                                    child: AppSymbol.icon(
                                      panel ? 'keyboard' : 'sticker',
                                      size: 25,
                                      color: panel
                                          ? palette.accent
                                          : palette.secondaryLabel,
                                      fallback: panel
                                          ? Icons.keyboard_outlined
                                          : Icons.emoji_emotions_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              if (canSend || widget.sending || widget.editing)
                                AppContextMenu(
                                  items: widget.editing || widget.sending
                                      ? const []
                                      : widget.sendOptions,
                                  enabled:
                                      !widget.editing &&
                                      widget.sendOptions.isNotEmpty,
                                  align: AppMenuAlign.right,
                                  label: (widget.editing
                                      ? context.l10n.save
                                      : context.l10n.send),
                                  child: AppIconButton(
                                    tooltip: (widget.editing
                                        ? context.l10n.save
                                        : context.l10n.send),
                                    glass: false,
                                    embedded: true,
                                    prominent: true,
                                    color: palette.accentText,
                                    onPressed: canSubmit ? submit : null,
                                    icon: widget.sending
                                        ? SizedBox.square(
                                            dimension: 20,
                                            child:
                                                CircularProgressIndicator.adaptive(
                                                  valueColor:
                                                      AlwaysStoppedAnimation(
                                                        palette.accentText,
                                                      ),
                                                ),
                                          )
                                        : Icon(
                                            widget.editing
                                                ? Icons.check
                                                : Icons.arrow_upward,
                                            size: 22,
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
                if (panel ||
                    widget.attachments.recording ||
                    (!canSend && !widget.sending && !widget.editing)) ...[
                  const SizedBox(width: AppDesign.composerGap),
                  if (panel)
                    AppIconButton(
                      key: const ValueKey('chat.media.expand'),
                      tooltip: panelExpanded
                          ? context.l10n.collapseEmojiPanel
                          : context.l10n.expandEmojiPanel,
                      glass: true,
                      surfaceRole: GlassSurfaceRole.input,
                      onPressed: widget.sending
                          ? null
                          : () => setExpanded(!panelExpanded),
                      icon: Transform(
                        key: const ValueKey('chat.media.expand.arrow'),
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(
                          1,
                          expansion.value * 2 - 1,
                          1,
                        ),
                        child: const AppSymbol.native('chat.media.expand'),
                      ),
                    )
                  else
                    AppIconButton(
                      tooltip: widget.attachments.recording
                          ? context.l10n.stopRecording2
                          : context.l10n.voiceMessage,
                      glass: true,
                      surfaceRole: GlassSurfaceRole.input,
                      color: widget.attachments.recording
                          ? palette.destructive
                          : palette.text,
                      icon: recordingBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator.adaptive(),
                            )
                          : Icon(
                              widget.attachments.recording
                                  ? Icons.stop
                                  : Icons.mic_none,
                              size: 24,
                            ),
                      onPressed: recordingBusy || voiceFinishing
                          ? null
                          : toggleRecording,
                      onLongPressStart: (_) => startVoice(locked: false),
                      onLongPressMoveUpdate: moveVoice,
                      onLongPressEnd: (_) {
                        if (voiceHolding && !voiceLocked) {
                          finishVoice(send: true);
                        }
                      },
                      onLongPressCancel: () {
                        if (voiceHolding && !voiceLocked) {
                          finishVoice(cancel: true);
                        }
                      },
                    ),
                ],
              ],
            ),
          ),
          if (panel)
            // ChatEntityKeyboardInputNode: blur tinted with
            // inputMediaPanel.backgroundColor under 30pt corners.
            GlassSurface(
              role: GlassSurfaceRole.sheet,
              radius: AppDesign.inputMediaPanelCorner,
              topOnly: true,
              useOwnLayer: true,
              tint: AppDesign.inputMediaPanelColor(context),
              hostsScrolling: true,
              child: buildPanel(context),
            ),
        ],
      );
      return footer;
    },
  );
}

/// A bare 44pt tool button with a SystemIcon glyph (expanded composer).
class _ToolbarGlyph extends StatelessWidget {
  final String label, symbol;
  final IconData fallback;
  final double size;
  final Color? color;
  final VoidCallback? onTap;
  const _ToolbarGlyph({
    required this.label,
    required this.symbol,
    required this.fallback,
    required this.size,
    this.color,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => AppPressable(
    label: label,
    style: AppPressStyle.touchable,
    onPressed: onTap,
    child: SizedBox.square(
      dimension: 44,
      child: Center(
        child: AppSymbol.icon(
          symbol,
          size: size,
          color: color ?? AppPalette.of(context).text,
          fallback: fallback,
        ),
      ),
    ),
  );
}
