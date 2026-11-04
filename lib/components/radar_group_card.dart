import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../core/mobile_spring.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/app_failure.dart';
import '../core/chat_data.dart';
import '../core/session.dart';
import '../screens/chat.dart';
import 'components.dart';
import 'glass_surface.dart';
import 'living_background.dart';
import '../design/app_design.dart';
import '../vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;

/// The group counterpart to RadarProfileCard: same collapse/expand morph and
/// backdrop-blur shell (which now reads the radar's active-group hero photo
/// behind it, see _RadarWallpaper in radar.dart), but the single action
/// opens the chat instead of like/dislike, and the expanded content lists
/// participants instead of the about tab. Viewing or dismissing a preview is
/// read-only; joining happens only through the explicit chat action.
class RadarGroupCard extends StatefulWidget {
  final Json group;
  final RadarMotion motion;
  final VoidCallback onClose;
  final double topInset, bottomInset;
  const RadarGroupCard({
    super.key,
    required this.group,
    required this.motion,
    required this.onClose,
    this.topInset = 0,
    this.bottomInset = 0,
  });
  @override
  State<RadarGroupCard> createState() => _RadarGroupCardState();
}

class _RadarGroupCardState extends State<RadarGroupCard>
    with SingleTickerProviderStateMixin {
  late final progress = AnimationController.unbounded(vsync: this, value: 0);
  final scroll = ScrollController();
  bool expanded = false, pressed = false, busy = false;

  void toggle() {
    expanded = !expanded;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (scroll.hasClients && scroll.offset != 0) {
      if (reduceMotion) {
        scroll.jumpTo(0);
      } else {
        scroll.animateTo(
          0,
          duration: AppDesign.buttonRelease,
          curve: Curves.easeOut,
        );
      }
    }
    if (reduceMotion) {
      progress.value = expanded ? 1 : 0;
    } else {
      progress.animateWith(
        MobileSpring(
          progress.value,
          expanded ? 1 : 0,
          progress.velocity,
          stiffness: 120,
          damping: 20,
        ),
      );
    }
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  Future<void> openChat() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await perform(context, () async {
        final opened = await joinGroup(AppScope.of(context).api, widget.group);
        if (!mounted) return;
        final navigator = Navigator.of(context, rootNavigator: true);
        widget.onClose();
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: opened)),
        );
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    progress.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value.clamp(0.0, 1.0);
        final dark = Theme.of(context).brightness == Brightness.dark;
        double lerp(double a, double b) => a + (b - a) * t;
        double clampT(double from, double to) =>
            ((t - from) / (to - from)).clamp(0.0, 1.0);
        final viewportHeight =
            box.maxHeight - widget.topInset - widget.bottomInset;
        final cardDiameter = (viewportHeight * .24)
            .clamp(150.0, 190.0)
            .clamp(0.0, box.maxWidth * .8);
        final collapsedY =
            widget.topInset + viewportHeight / 2 - cardDiameter / 2 - 60;
        final expandedY = widget.topInset + 20;
        final top = lerp(collapsedY, expandedY);
        final diameter = cardDiameter;
        final group = widget.group;
        final username = string(group['public_username']);
        return Stack(
          children: [
            Positioned.fill(
              child: Stack(
                key: const ValueKey('radar.group.canvas'),
                fit: StackFit.expand,
                children: [
                  // Hero is the backdrop when the card first opens; it
                  // dissolves into the cover photo as the avatar expands.
                  // Kept sharp (no blur) — only a scrim darkens it for text.
                  Opacity(
                    opacity: (1 - clampT(0, .6)),
                    child: DriftingImage(
                      motion: widget.motion,
                      child: AppImage(
                        source: group['localHeroAsset'] != null
                            ? AssetImage('${group['localHeroAsset']}')
                            : (group['hero'] ?? group['cover']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: clampT(0, .6),
                    child: DriftingImage(
                      motion: widget.motion,
                      child: AppImage(
                        source: group['localCoverAsset'] != null
                            ? AssetImage('${group['localCoverAsset']}')
                            : (group['cover'] ?? group['hero']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: (dark ? Colors.black : Colors.white).withValues(
                        alpha: dark ? .35 : .2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: CustomScrollView(
                key: const ValueKey('radar.group.scroll'),
                controller: scroll,
                physics: expanded ? null : const NeverScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: top.clamp(0.0, double.infinity),
                        bottom: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            key: const ValueKey('radar.group.avatar'),
                            dimension: diameter,
                            child: Semantics(
                              button: true,
                              expanded: expanded,
                              label: personName(group),
                              child: GestureDetector(
                                onTapDown: (_) {
                                  HapticFeedback.lightImpact();
                                  setState(() => pressed = true);
                                },
                                onTapCancel: () =>
                                    setState(() => pressed = false),
                                onTapUp: (_) => setState(() => pressed = false),
                                onTap: toggle,
                                child: Opacity(
                                  opacity: pressed ? .9 : 1,
                                  // Not GlassSurface here: its BackdropFilter
                                  // sampling goes black while this avatar's
                                  // position is actively springing between
                                  // collapsed and expanded. This fakes the
                                  // glass rim with a sweep-gradient highlight
                                  // instead of live backdrop capture, so it
                                  // can't glitch on a fast-moving widget —
                                  // rotating it slowly off the same shared
                                  // ticker other glass-y bits use is what
                                  // gives it a "liquid", alive feel rather
                                  // than a flat static ring.
                                  child: AnimatedBuilder(
                                    animation: widget.motion,
                                    builder: (context, child) => Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: SweepGradient(
                                          transform: GradientRotation(
                                            widget.motion.angle,
                                          ),
                                          colors: const [
                                            Color(0xf2ffffff),
                                            Color(0x59ffffff),
                                            Color(0xf2ffffff),
                                            Color(0x59ffffff),
                                            Color(0xf2ffffff),
                                          ],
                                        ),
                                        boxShadow: AppDesign.glassShadow,
                                      ),
                                      child: child,
                                    ),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      padding: const EdgeInsets.all(.5),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ClipOval(
                                            child: Avatar(
                                              group,
                                              radius: diameter / 2,
                                            ),
                                          ),
                                          IgnorePointer(
                                            child: Opacity(
                                              opacity: 1 - clampT(0, .3),
                                              child: const DecoratedBox(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Color(0x0d000000),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDesign.inset,
                            ),
                            child: Column(
                              key: const ValueKey('radar.group.identity'),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    personName(group),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppDesign.displayFamily,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 34,
                                      letterSpacing: -1.5,
                                      // White + a dark shadow reads on any
                                      // photo underneath; palette.text (near
                                      // black in light mode) only worked
                                      // over the card's own scrim, not the
                                      // busy hero/cover photo behind it.
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x99000000),
                                          blurRadius: 12,
                                        ),
                                        Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (username.isNotEmpty)
                                      Text(
                                        '@$username',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xe6ffffff),
                                          shadows: [
                                            Shadow(
                                              color: Color(0x99000000),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 25),
                          Row(
                            key: const ValueKey('radar.group.actions'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // GlassSurface + AppPressable gave the glow but
                              // not the elastic stretch the header's buttons
                              // have — that physics lives specifically in
                              // GlassButton (LiquidStretch), which
                              // AppIconButton uses under the hood and a
                              // plain GlassSurface does not. clear: true on
                              // the settings keeps the same transparent
                              // material as the honeycomb bubbles/tab bar.
                              PlatformBackdrop.listen(
                                (
                                  context,
                                  overPlatformView,
                                ) => PlatformBackdropUnderlay(
                                  shape: const CircleBorder(),
                                  child: liquid.GlassButton.custom(
                                    platformViewBackdrop: overPlatformView,
                                    label: context.l10n.joinGroup,
                                    onTap: busy ? () {} : openChat,
                                    enabled: !busy,
                                    width: 80,
                                    height: 80,
                                    shape: const liquid.LiquidOval(),
                                    // Without an explicit quality this
                                    // resolves to GlassButton's own
                                    // standard default (no ancestor
                                    // InheritedLiquidGlass here), which
                                    // skips the 3D refraction shader the
                                    // clear/near-zero-blur settings below
                                    // depend on to read as glass at all.
                                    // Every other control glass button
                                    // (_liquidButton, GlassSurface, the
                                    // honeycomb bubbles) forces the same
                                    // premium tier.
                                    quality: GlassSurfaceRole.control.quality,
                                    settings: appGlassSettings(
                                      context,
                                      clear: true,
                                      platformViewBackdrop: overPlatformView,
                                    ),
                                    child: busy
                                        ? const SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.chat, size: 30),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (t > .4)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              MediaQuery.paddingOf(context).bottom +
                              widget.bottomInset +
                              24,
                        ),
                        child: IgnorePointer(
                          ignoring: !expanded,
                          child: ExcludeSemantics(
                            excluding: !expanded,
                            child: Opacity(
                              opacity: clampT(.4, 1),
                              child: _GroupParticipants(
                                key: const ValueKey('radar.group.participants'),
                                chat: widget.group,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PositionedDirectional(
              end: AppDesign.inset,
              top: widget.topInset + AppDesign.radarIdentityGap,
              child: AppIconButton(
                key: const ValueKey('radar.group.close'),
                glass: true,
                tooltip: context.l10n.close,
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: widget.onClose,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _GroupParticipants extends StatefulWidget {
  final Json? chat;
  const _GroupParticipants({super.key, required this.chat});
  @override
  State<_GroupParticipants> createState() => _GroupParticipantsState();
}

class _GroupParticipantsState extends State<_GroupParticipants> {
  List<Json>? participants;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void didUpdateWidget(_GroupParticipants old) {
    super.didUpdateWidget(old);
    if (chatEntityId(object(old.chat)) != chatEntityId(object(widget.chat))) {
      participants = null;
      error = null;
      load();
    }
  }

  Future<void> load() async {
    final chat = widget.chat;
    if (chat == null || chatEntityId(chat).isEmpty || !mounted) return;
    try {
      final result = await AppScope.of(context).api.call(
        'chat.participants.fetch',
        body: {'chat_id': chatEntityId(chat)},
      );
      final page = RecordPage.parse(result);
      if (mounted) setState(() => participants = page.records);
    } catch (e) {
      if (mounted) {
        setState(() => error = AppFailure.from(e).message(context.l10n));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ScreenStatus(error: error, retry: load),
      );
    }
    if (widget.chat == null || participants == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    // AppSection is what gives AppRow its grouped-card background/separators
    // (AppRow paints a full-bleed opaque row colour with no framing when it
    // isn't nested in one); without it every participant row was a bare
    // white rectangle floating directly on the unblurred hero photo.
    return AppSection(
      title: context.l10n.groupMembersCount(participants!.length),
      children: [
        // chat.participants.fetch rows are {user_id, user: {...}, ...}; the
        // displayable person is nested under 'user', not the row itself.
        for (final row in participants!)
          PersonTile(person: object(row['user'])),
      ],
    );
  }
}
