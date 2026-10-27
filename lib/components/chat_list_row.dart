import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../design/app_design.dart';
import 'app_button.dart';
import 'app_context_menu.dart';
import 'avatar.dart';
import 'app_row.dart';

/// Telegram-iOS ChatListItem as drawn by the source chat tab: 60pt avatar,
/// 16pt semibold title, 14pt date, 15/20pt two-line preview, 20pt unread
/// badge, a hairline from 80pt, swipe-left Mute/Delete and the context menu.
class ChatListRow extends StatefulWidget {
  final Json avatar;
  final WidgetBuilder? conversationPreview;
  final String name, preview, time;
  final int unread;
  final bool group, online, muted, pinned;
  final bool? selected;
  final VoidCallback onTap;

  /// Swipe/menu actions; omitted when the row only picks a chat (forward).
  final VoidCallback? onMute, onDelete, onPin;
  const ChatListRow({
    super.key,
    required this.avatar,
    this.conversationPreview,
    required this.name,
    required this.preview,
    required this.time,
    required this.unread,
    required this.onTap,
    this.onMute,
    this.onDelete,
    this.onPin,
    this.group = false,
    this.online = false,
    this.muted = false,
    this.pinned = false,
    this.selected,
  });
  @override
  State<ChatListRow> createState() => _ChatListRowState();
}

class _ChatListRowState extends State<ChatListRow>
    with SingleTickerProviderStateMixin {
  static const actionWidth = 74.0;
  late final reveal = AnimationController(
    vsync: this,
    upperBound: actionWidth * 2,
  );
  bool pressed = false;
  Offset origin = Offset.zero;

  @override
  void dispose() {
    reveal.dispose();
    super.dispose();
  }

  void settle() {
    // rightThreshold 40, friction 2.
    final open = reveal.value > 40;
    reveal.animateTo(
      open ? actionWidth * 2 : 0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void close() => reveal.animateTo(
    0,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    Widget swipeAction(
      String title,
      String symbol,
      IconData icon,
      Color color,
      VoidCallback onTap,
    ) => Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: () {
          close();
          onTap();
        },
        child: Container(
          width: actionWidth,
          color: color,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppSymbol.icon(
                symbol,
                size: 24,
                color: Colors.white,
                fallback: icon,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppDesign.font(
                  13,
                  weight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final muteTitle = widget.muted ? context.l10n.unmute : context.l10n.mute;
    final deleteTitle = context.l10n.deleteLabel;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 14, 8),
      // Chat palette accent wash of the chosen theme (palette.ts highlight).
      color: pressed
          ? palette.chatHighlight
          : widget.pinned
          ? palette.pinned
          : palette.row,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 60,
            child: Stack(
              children: [
                Avatar(widget.avatar, radius: 30),
                if (widget.online)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: const Color(0xff34c759),
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.row, width: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (widget.group)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 4),
                              child: Icon(
                                Icons.people,
                                size: 16,
                                color: palette.text,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              widget.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppDesign.font(
                                16,
                                weight: FontWeight.w600,
                                color: palette.text,
                              ),
                            ),
                          ),
                          if (widget.muted)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 4,
                              ),
                              child: AppSymbol.icon(
                                'speaker.slash.fill',
                                size: 13,
                                color: palette.secondaryLabel,
                                fallback: Icons.volume_off,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.time.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: Text(
                          widget.time,
                          style: AppDesign.font(
                            14,
                            color: palette.secondaryLabel,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppDesign.font(
                          15,
                          color: palette.secondaryLabel,
                          height: 20 / 15,
                        ),
                      ),
                    ),
                    if (widget.unread > 0)
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        margin: const EdgeInsetsDirectional.only(
                          start: 8,
                          top: 1,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.muted
                              ? palette.secondaryLabel
                              : palette.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.unread > 999 ? '999+' : '${widget.unread}',
                          style:
                              AppDesign.font(
                                12,
                                weight: FontWeight.w600,
                                color: palette.accentText,
                              ).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      )
                    else if (widget.pinned)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 8,
                          top: 2,
                        ),
                        child: Transform.rotate(
                          angle: .785,
                          child: AppSymbol.icon(
                            'pin.fill',
                            size: 15,
                            color: palette.secondaryLabel,
                            fallback: Icons.push_pin,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.selected != null) ...[
            const SizedBox(width: 8),
            AppSwitch(
              value: widget.selected!,
              onChanged: (_) => widget.onTap(),
            ),
          ],
        ],
      ),
    );
    final actions =
        widget.onMute != null &&
        widget.onDelete != null &&
        widget.onPin != null;
    return Semantics(
      selected: widget.selected,
      customSemanticsActions: actions
          ? {
              CustomSemanticsAction(label: muteTitle): widget.onMute!,
              CustomSemanticsAction(label: deleteTitle): widget.onDelete!,
            }
          : null,
      child: ClipRect(
        child: Stack(
          children: [
            // Swipe actions behind the row (trailing edge).
            if (actions)
              AnimatedBuilder(
                animation: reveal,
                builder: (context, child) => PositionedDirectional(
                  end: 0,
                  top: 0,
                  bottom: 0,
                  width: reveal.value,
                  child: ClipRect(
                    child: IgnorePointer(
                      ignoring: reveal.value < 1,
                      child: ExcludeSemantics(
                        excluding: reveal.value < 1,
                        child: OverflowBox(
                          alignment: AlignmentDirectional.centerEnd,
                          minWidth: actionWidth * 2,
                          maxWidth: actionWidth * 2,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    swipeAction(
                      muteTitle,
                      widget.muted ? 'chat.action.unmute' : 'chat.action.mute',
                      widget.muted
                          ? Icons.notifications_none
                          : Icons.notifications_off_outlined,
                      const Color(0xffff9500),
                      widget.onMute!,
                    ),
                    swipeAction(
                      deleteTitle,
                      'chat.action.delete',
                      Icons.delete_outline,
                      const Color(0xffff3b30),
                      widget.onDelete!,
                    ),
                  ],
                ),
              ),
            GestureDetector(
              onHorizontalDragUpdate: !actions
                  ? null
                  : (details) {
                      final delta = rtl ? details.delta.dx : -details.delta.dx;
                      reveal.value =
                          (reveal.value +
                                  delta /
                                      (reveal.value > actionWidth * 2 ? 2 : 1))
                              .clamp(0, actionWidth * 2);
                    },
              onHorizontalDragEnd: actions ? (_) => settle() : null,
              onHorizontalDragCancel: actions ? settle : null,
              child: AnimatedBuilder(
                animation: reveal,
                builder: (context, child) => Transform.translate(
                  offset: Offset(rtl ? reveal.value : -reveal.value, 0),
                  child: child,
                ),
                child: AppContextMenu(
                  previewBuilder: widget.conversationPreview,
                  label: widget.unread > 0
                      ? context.l10n.unreadMessages(widget.name, widget.unread)
                      : widget.name,
                  previewRadius: 14,
                  onPressed: () {
                    if (reveal.value > 0) {
                      close();
                    } else {
                      widget.onTap();
                    }
                  },
                  enabled: actions,
                  items: !actions
                      ? const []
                      : [
                          AppMenuItem(
                            title: widget.pinned
                                ? context.l10n.unpin
                                : context.l10n.pin,
                            symbol: widget.pinned
                                ? 'chat.action.unpin'
                                : 'chat.action.pin',
                            fallback: Icons.push_pin_outlined,
                            onPressed: widget.onPin!,
                          ),
                          AppMenuItem(
                            title: muteTitle,
                            symbol: widget.muted
                                ? 'chat.action.unmute'
                                : 'chat.action.mute',
                            fallback: Icons.notifications_off_outlined,
                            onPressed: widget.onMute!,
                          ),
                          AppMenuItem(
                            title: deleteTitle,
                            symbol: 'chat.action.delete',
                            fallback: Icons.delete_outline,
                            destructive: true,
                            onPressed: widget.onDelete!,
                          ),
                        ],
                  child: Listener(
                    onPointerDown: (event) {
                      origin = event.position;
                      if (reveal.value == 0) setState(() => pressed = true);
                    },
                    onPointerMove: (event) {
                      if (pressed && (event.position - origin).distance > 10) {
                        setState(() => pressed = false);
                      }
                    },
                    onPointerUp: (_) => setState(() => pressed = false),
                    onPointerCancel: (_) => setState(() => pressed = false),
                    child: content,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 80,
              end: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(height: hairline, color: palette.border),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// formatChatDate(): time today, otherwise a short month and day.
String chatListDate(BuildContext context, dynamic value) {
  final date = DateTime.tryParse(string(value))?.toLocal();
  if (date == null) return '';
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  return MaterialLocalizations.of(context).formatShortMonthDay(date);
}

void chatListHaptic() => HapticFeedback.mediumImpact();
