import '../l10n/l10n.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/api.dart';
import '../core/chat_data.dart';
import '../design/app_design.dart';
import '../screens/media.dart';
import 'app_button.dart';
import 'app_context_menu.dart';
import 'emoticon_view.dart';
import 'message_preview.dart';
import 'location_attachment.dart';
import 'spoiler_overlay.dart';
import '../core/geo.dart';

/// Telegram's peer name colours (ChatMessageRow PEER_NAME_COLORS).
const _peerColors = [
  Color(0xffe3463e),
  Color(0xffe07b1c),
  Color(0xff9a5cdb),
  Color(0xff3baa4c),
  Color(0xff1aa59a),
  Color(0xff2a8bdb),
  Color(0xffd94e8a),
];
Color peerNameColor(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit).toSigned(32);
  }
  return _peerColors[hash.abs() % _peerColors.length];
}

final _emojiOnly = RegExp(
  r'^(?:\p{Extended_Pictographic}|\p{Emoji_Modifier}|\p{Regional_Indicator}|‍|️|⃣|\s)+$',
  unicode: true,
);

/// Telegram enlarges messages of up to three emoji and drops the bubble.
int largeEmojiCount(String text) {
  final value = text.trim();
  if (value.isEmpty || value.length > 40 || !_emojiOnly.hasMatch(value)) {
    return 0;
  }
  final count = value.replaceAll(RegExp(r'\s'), '').characters.length;
  return count <= 3 ? count : 0;
}

/// One message cell for private chats and groups (source ChatMessageRow +
/// ChatBubble, Telegram-iOS ChatMessageBubbleItemNode geometry): 16pt radius,
/// 8pt on the merged side, a tail on the group's last bubble, 17pt text with an
/// inline 11pt date and status, swipe to reply and the context menu.
class ChatBubble extends StatefulWidget {
  final Json message;
  final bool mine, first, last, group;
  final List<AppMenuItem> actions;
  final VoidCallback onReply;
  final VoidCallback? onRetry, onSelectionChanged;
  final bool? selected;

  /// Flash after jumping to the message (Telegram pinned/reply navigation).
  final bool highlighted;

  /// Opens unopened disappearing content (`chat.message.open`).
  final VoidCallback? onOpen;
  const ChatBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.actions,
    required this.onReply,
    this.first = true,
    this.last = true,
    this.group = false,
    this.onRetry,
    this.selected,
    this.onSelectionChanged,
    this.highlighted = false,
    this.onOpen,
  });
  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> with TickerProviderStateMixin {
  late final swipe = AnimationController(
    vsync: this,
    lowerBound: 0,
    upperBound: 96,
  );

  /// ChatMessageSelectionNode slide: 0.2s ease-out over 42pt.
  late final selection = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: widget.selected == null ? 0 : 1,
  );
  bool armed = false;

  @override
  void didUpdateWidget(ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.selected == null) != (widget.selected == null)) {
      if (MediaQuery.disableAnimationsOf(context)) {
        selection.value = widget.selected == null ? 0 : 1;
      } else if (widget.selected == null) {
        selection.reverse();
      } else {
        selection.forward();
      }
    }
  }

  @override
  void dispose() {
    swipe.dispose();
    selection.dispose();
    super.dispose();
  }

  void dragUpdate(DragUpdateDetails details, bool rtl) {
    final delta = rtl ? -details.delta.dx : details.delta.dx;
    swipe.value = (swipe.value + delta * (swipe.value > 48 ? .4 : 1)).clamp(
      0,
      96,
    );
    final next = swipe.value >= 48;
    if (next != armed) {
      armed = next;
      if (armed) HapticFeedback.selectionClick();
    }
  }

  void dragEnd() {
    if (armed) widget.onReply();
    armed = false;
    swipe.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final me = widget.mine;
    final right = rtl ? !me : me;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final width = MediaQuery.sizeOf(context).width;
    final maxBubble = (width - 52).clamp(0.0, 560.0);
    final foreground = me ? palette.outgoingText : palette.text;
    final secondary = me ? palette.outgoingMeta : palette.secondaryLabel;
    final link = me ? palette.outgoingPrimary : palette.accent;
    final date = DateTime.tryParse(string(message['created_at']))?.toLocal();
    final time = date == null
        ? ''
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final rawText = messageContentText(
      message,
      language: Localizations.localeOf(context).languageCode,
    );
    final emoticon = messageEmoticon(message);
    final forwarded = messageForwardOrigin(message);
    final spoiler = [
      true,
      1,
      '1',
      'true',
    ].contains(messageExtras(message)['spoiler'] ?? message['spoiler']);
    final gif = emoticon != null && string(emoticon['kind']) == 'gif';
    final hasMedia =
        message['attachments'] is List &&
            (message['attachments'] as List).isNotEmpty ||
        message['media'] is List && (message['media'] as List).isNotEmpty;
    final mediaItems = hasMedia ? mediaOf(message) : const <Json>[];
    // A lone audio attachment is a voice message (file node, not media).
    final voice = mediaItems.length == 1 && audioMedia(mediaItems.single);
    final reply = message['reply_to'] is Map
        ? object(message['reply_to'])
        : message['parent'] is Map
        ? object(message['parent'])
        : null;
    final location = message['location'] is Map
        ? object(message['location'])
        : null;
    final hidden = [true, 1, '1', 'true'].contains(message['content_hidden']);
    final disappearing =
        [true, 1, '1', 'true'].contains(message['is_disappearing']) ||
        [true, 1, '1', 'true'].contains(message['view_once']);
    final locked = hidden && disappearing && !widget.mine;
    final expiresAt = DateTime.tryParse(string(message['expires_at']));
    final text = locked
        ? '🔥 ${context.l10n.tapToView}'
        : locationMessageText(rawText, location);
    final emojiCount =
        emoticon == null &&
            !hasMedia &&
            reply == null &&
            location == null &&
            forwarded == null
        ? largeEmojiCount(text)
        : 0;
    final sticker = emoticon != null && !gif || emojiCount > 0;
    final gifWidth = (maxBubble - 4).clamp(170.0, 300.0);
    final gifRatio = gif
        ? (double.tryParse(string(emoticon['height'])) ?? 0) /
              (double.tryParse(string(emoticon['width'])) ?? 0)
        : 0.0;
    final gifHeight = gifRatio.isFinite && gifRatio > 0
        ? (gifWidth * gifRatio).clamp(0.0, 320.0)
        : gifWidth * .75;
    final framed = hasMedia || emoticon != null || location != null;
    final status = string(message['status']);
    final statusIcon = status == 'failed'
        ? Icons.error_outline
        : ['queued', 'sending'].contains(status)
        ? Icons.schedule
        : status == 'read'
        ? Icons.done_all
        : Icons.done;
    Widget meta(Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      children: [
        if (message['pinned'] == true) ...[
          Icon(Icons.push_pin_outlined, size: 10, color: color),
          const SizedBox(width: 3),
        ],
        if (expiresAt != null) ...[
          _Countdown(until: expiresAt, color: color, scale: scale),
          const SizedBox(width: 4),
        ] else if (disappearing && widget.mine) ...[
          Icon(Icons.timer_outlined, size: 11, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          time,
          style: AppDesign.font(
            11 * scale,
            color: color,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          textScaler: TextScaler.noScaling,
        ),
        if (me) ...[
          const SizedBox(width: 3),
          Icon(statusIcon, size: 13, color: color),
        ],
      ],
    );
    final capsule = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x59000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: meta(Colors.white),
    );
    final author = message['user'] is Map
        ? object(message['user'])
        : message['sender'] is Map
        ? object(message['sender'])
        : <String, dynamic>{};
    final authorName = string(
      author['displayname'] ?? author['name'] ?? author['username'],
    );
    Widget quote({bool card = false}) => Container(
      constraints: const BoxConstraints(minWidth: 120),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: card ? palette.incoming : link.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
        border: BorderDirectional(start: BorderSide(color: link, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            string(
                  object(reply!['user'])['displayname'] ??
                      object(reply['user'])['username'] ??
                      reply['author_name'],
                ).isEmpty
                ? context.l10n.reply
                : string(
                    object(reply['user'])['displayname'] ??
                        object(reply['user'])['username'] ??
                        reply['author_name'],
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppDesign.font(14, weight: FontWeight.w600, color: link),
          ),
          Text(
            messagePreview(context, reply),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppDesign.font(14, color: card ? palette.text : foreground),
          ),
        ],
      ),
    );
    // Appearance text size (web default 16) maps to Telegram's 17pt base.
    final textSize = palette.textSize * 17 / 16 * scale;
    Widget body;
    if (sticker) {
      body = Column(
        crossAxisAlignment: right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reply != null) quote(card: true),
          if (emojiCount > 0)
            Text(
              text.trim(),
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize:
                    (emojiCount == 1
                        ? 64
                        : emojiCount == 2
                        ? 52
                        : 44) *
                    scale.clamp(0, 1.2),
                height: emojiCount == 1
                    ? 76 / 64
                    : emojiCount == 2
                    ? 62 / 52
                    : 54 / 44,
              ),
            )
          else
            EmoticonView(document: emoticon!, size: 176),
          const SizedBox(height: 2),
          capsule,
        ],
      );
    } else {
      final children = <Widget>[
        if (widget.group && !me && widget.first && authorName.isNotEmpty)
          Padding(
            padding: framed
                ? const EdgeInsets.fromLTRB(9, 4, 9, 0)
                : EdgeInsets.zero,
            child: Text(
              authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppDesign.font(
                14 * scale,
                weight: FontWeight.w600,
                color: peerNameColor(
                  string(author['public_id'] ?? author['id']),
                ),
              ),
              textScaler: TextScaler.noScaling,
            ),
          ),
        if (forwarded != null)
          Padding(
            padding: framed
                ? const EdgeInsets.fromLTRB(9, 4, 9, 2)
                : const EdgeInsets.only(bottom: 2),
            // ChatMessageForwardInfoNode: 14/17 of the base size, regular
            // prefix and medium name in the bubble's accent.
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${context.l10n.forwardedFrom}\n'),
                  TextSpan(
                    text: string(forwarded['name']),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
              style: AppDesign.font(
                palette.textSize * 14 / 16 * scale,
                color: link,
                height: 1.2,
              ),
            ),
          ),
        if (reply != null)
          Padding(
            padding: framed
                ? const EdgeInsets.fromLTRB(9, 4, 9, 0)
                : EdgeInsets.zero,
            child: quote(),
          ),
        if (gif)
          Stack(
            children: [
              EmoticonView(
                document: emoticon,
                width: gifWidth,
                height: gifHeight,
                radius: 14,
              ),
              if (text.isEmpty) Positioned(right: 6, bottom: 6, child: capsule),
            ],
          ),
        if (voice)
          AudioMediaPlayer(
            item: mediaItems.single,
            voice: VoiceBubbleStyle(
              active: link,
              inactive: me
                  ? link.withValues(alpha: .5)
                  : dark
                  ? link.withValues(alpha: .4)
                  : const Color(0xffcacaca),
              glyph: me ? palette.outgoingStops.first : palette.incoming,
              duration: secondary,
              maxWidth: maxBubble - 21,
              meta: text.isEmpty ? meta(secondary) : null,
            ),
          )
        else if (hasMedia)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SpoilerOverlay(
                  hidden: spoiler,
                  child: MediaAttachments(
                    record: message,
                    width: (maxBubble - 4).clamp(170.0, 300.0),
                    aspect: .8,
                  ),
                ),
              ),
              if (text.isEmpty) Positioned(right: 6, bottom: 6, child: capsule),
            ],
          ),
        if (location != null)
          LocationAttachment(
            location: location,
            width: LocationAttachment.widthFor(maxBubble - 4),
            foreground: foreground,
            secondary: secondary,
            // A plain coordinate carries the capsule on the map; a venue
            // keeps the bubble status after its address.
            status: text.isEmpty && !locationHasVenue(location)
                ? capsule
                : null,
            meta: text.isEmpty && locationHasVenue(location)
                ? meta(secondary)
                : null,
          ),
        if (text.isNotEmpty)
          Padding(
            padding: framed
                ? const EdgeInsets.fromLTRB(9, 5, 9, 4)
                : EdgeInsets.zero,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: text),
                      // Reserves the date/status footprint on the last line
                      // (ChatMessageDateAndStatusNode).
                      TextSpan(
                        text:
                            ' ${message['pinned'] == true ? '  ' : ''}${expiresAt != null
                                ? '        '
                                : disappearing && me
                                ? '  '
                                : ''}$time${me ? '  ' : ''}',
                        style: AppDesign.font(
                          11 * scale,
                          color: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                  textScaler: TextScaler.noScaling,
                  style: AppDesign.font(
                    textSize,
                    color: foreground,
                    height: 1.29,
                  ),
                ),
                PositionedDirectional(
                  end: 0,
                  bottom: -1,
                  child: meta(secondary),
                ),
              ],
            ),
          )
        else if (!hasMedia && !gif && location == null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: meta(secondary),
          ),
      ];
      body = _Bubble(
        outgoing: me,
        right: right,
        first: widget.first,
        last: widget.last,
        framed: framed,
        fill: me ? palette.outgoingStops.first : palette.incoming,
        gradient:
            me && palette.outgoingStops.first != palette.outgoingStops.last
            ? palette.outgoingStops
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
    }
    final semantics = [
      me ? context.l10n.you : context.l10n.message,
      text,
      time,
    ].where((part) => part.isNotEmpty).join(', ');
    final plainRow = Padding(
      padding: EdgeInsets.only(
        top: widget.first ? 6 : 1,
        bottom: 1,
        left: right ? 8 : 12,
        right: right ? 12 : 8,
      ),
      child: Row(
        mainAxisAlignment: me ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubble),
              child: AppContextMenu(
                label: semantics,
                enabled: widget.selected == null,
                items: widget.actions,
                align: right ? AppMenuAlign.right : AppMenuAlign.left,
                child: body,
              ),
            ),
          ),
          if (status == 'failed' && widget.onRetry != null)
            Semantics(
              button: true,
              label: context.l10n.messageNotSentTapToRetry,
              child: GestureDetector(
                onTap: widget.onRetry,
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    Icons.error,
                    size: 24,
                    color: dark
                        ? const Color(0xffff6961)
                        : const Color(0xffe53935),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final row = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      color: widget.highlighted
          ? palette.accent.withValues(alpha: .18)
          : palette.accent.withValues(alpha: 0),
      child: locked && widget.onOpen != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpen,
              child: plainRow,
            )
          : plainRow,
    );
    // Selection (ChatMessageBubbleItemNode): a 28pt check 6pt from the
    // leading edge slides in over 42pt; incoming bubbles move aside, and the
    // whole row toggles.
    final selecting = widget.selected != null;
    final selectable = AnimatedBuilder(
      animation: selection,
      builder: (context, child) {
        final t = Curves.easeOut.transform(selection.value);
        if (t == 0) return child!;
        return Stack(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(start: me ? 0 : 42 * t),
              child: child,
            ),
            PositionedDirectional(
              start: 6 - 42 * (1 - t),
              top: 0,
              bottom: 0,
              child: Center(
                child: ChatSelectionCheck(selected: widget.selected == true),
              ),
            ),
          ],
        );
      },
      child: IgnorePointer(ignoring: selecting, child: row),
    );
    if (selecting) {
      return Semantics(
        selected: widget.selected,
        button: true,
        label: semantics,
        onTap: widget.onSelectionChanged,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSelectionChanged,
          child: ExcludeSemantics(child: selectable),
        ),
      );
    }
    if (selection.value > 0) return selectable;
    if (MediaQuery.disableAnimationsOf(context)) return row;
    // ReanimatedSwipeable: pull the row to reveal the reply hint; 48pt arms it.
    return GestureDetector(
      onHorizontalDragUpdate: (details) => dragUpdate(details, rtl),
      onHorizontalDragEnd: (_) => dragEnd(),
      onHorizontalDragCancel: () {
        armed = false;
        dragEnd();
      },
      child: AnimatedBuilder(
        animation: swipe,
        builder: (context, child) => Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 48,
              child: Opacity(
                opacity: (swipe.value / 48).clamp(0, 1),
                child: Center(
                  child: AppSymbol.icon(
                    'arrowshape.turn.up.left',
                    size: 22,
                    color: palette.accent,
                    fallback: Icons.reply,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(rtl ? -swipe.value : swipe.value, 0),
              child: child,
            ),
          ],
        ),
        child: row,
      ),
    );
  }
}

/// ChatBubble.tsx: fill, corners, 0/1/1.5 shadow and the Telegram tail.
class _Bubble extends StatelessWidget {
  final bool outgoing, right, first, last, framed;
  final Color fill;
  final List<Color>? gradient;
  final Widget child;
  const _Bubble({
    this.gradient,
    required this.outgoing,
    required this.right,
    required this.first,
    required this.last,
    required this.framed,
    required this.fill,
    required this.child,
  });
  static const _tail =
      'M-6 16h6v17c-.193-2.84-.876-5.767-2.05-8.782-.904-2.325-2.446-4.485-4.625-6.48A1 1 0 01-6 16z';
  @override
  Widget build(BuildContext context) {
    const main = Radius.circular(16), merged = Radius.circular(8);
    final radius = right
        ? BorderRadius.only(
            topLeft: main,
            bottomLeft: main,
            topRight: first ? main : merged,
            bottomRight: last ? Radius.zero : merged,
          )
        : BorderRadius.only(
            topRight: main,
            bottomRight: main,
            topLeft: first ? main : merged,
            bottomLeft: last ? Radius.zero : merged,
          );
    final tail = gradient?.last ?? fill;
    final hex = tail.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 35),
          decoration: BoxDecoration(
            color: fill,
            // Two-stop outgoing fill, top to bottom (outgoingStops).
            gradient: gradient == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradient!,
                  ),
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                offset: Offset(0, 1),
                blurRadius: 1.5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Padding(
              padding: framed
                  ? const EdgeInsets.all(2)
                  : const EdgeInsets.fromLTRB(11, 6, 11, 6),
              child: child,
            ),
          ),
        ),
        if (last)
          Positioned(
            bottom: 0,
            left: right ? null : -8.4,
            right: right ? -8.4 : null,
            child: Transform.flip(
              flipX: right,
              child: SvgPicture.string(
                '<svg width="11" height="20" viewBox="0 0 11 20" xmlns="http://www.w3.org/2000/svg">'
                '<g transform="translate(9 -14)" fill-rule="evenodd">'
                '<path d="$_tail" transform="matrix(1 0 0 -1 0 49)" fill="#$hex"/></g></svg>',
                width: 11,
                height: 20,
              ),
            ),
          ),
      ],
    );
  }
}

/// Telegram date separator: 13pt semibold white on a translucent capsule.
class ChatDaySeparator extends StatelessWidget {
  final DateTime date;
  const ChatDaySeparator({super.key, required this.date});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final language = Localizations.localeOf(context).languageCode;
    final label = day == today
        ? context.l10n.today
        : day == today.subtract(const Duration(days: 1))
        ? context.l10n.yesterday
        : MaterialLocalizations.of(
            context,
          ).formatMediumDate(date).replaceAll(language == 'en' ? '' : ',', '');
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Semantics(
          header: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: dark ? const Color(0x59000000) : const Color(0x33000000),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              label,
              style: AppDesign.font(
                13,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Telegram CheckNode (overlay style on wallpapers): a 28pt circle with a
/// white rim and soft shade; selected fills with the accent and a white tick.
class ChatSelectionCheck extends StatelessWidget {
  final bool selected;
  const ChatSelectionCheck({super.key, required this.selected});
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? palette.accent : const Color(0x26000000),
        border: Border.all(
          color: selected ? palette.accent : Colors.white,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 19, color: palette.accentText)
          : null,
    );
  }
}

/// Remaining lifetime of an opened disappearing message (m:ss, h or d).
class _Countdown extends StatefulWidget {
  final DateTime until;
  final Color color;
  final double scale;
  const _Countdown({
    required this.until,
    required this.color,
    required this.scale,
  });
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.until.difference(DateTime.now());
    final seconds = left.isNegative ? 0 : left.inSeconds;
    final label = seconds >= 86400
        ? '${seconds ~/ 86400}d'
        : seconds >= 3600
        ? '${seconds ~/ 3600}h'
        : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department, size: 11, color: widget.color),
        const SizedBox(width: 2),
        Text(
          label,
          textScaler: TextScaler.noScaling,
          style: AppDesign.font(
            11 * widget.scale,
            color: widget.color,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}
