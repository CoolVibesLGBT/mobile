import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../core/mobile_spring.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/chat_data.dart';
import '../core/session.dart';
import '../screens/chat.dart';
import 'components.dart';
import 'glass_surface.dart';
import 'profile_about.dart';
import '../design/app_design.dart';

/// The source RadarUserCard morph: .8 viewport circle -> 110pt profile avatar,
/// Reanimated 4 mass=4 / damping=20 / stiffness=120, 34pt name and 70/80/70pt actions.
class RadarProfileCard extends StatefulWidget {
  final Json user;
  final VoidCallback onClose;
  final ValueChanged<String>? onReaction;
  final double topInset, bottomInset;
  const RadarProfileCard({
    super.key,
    required this.user,
    required this.onClose,
    this.onReaction,
    this.topInset = 0,
    this.bottomInset = 0,
  });
  @override
  State<RadarProfileCard> createState() => _RadarProfileCardState();
}

class _RadarProfileCardState extends State<RadarProfileCard>
    with SingleTickerProviderStateMixin {
  late final progress = AnimationController.unbounded(vsync: this, value: 0);
  final scroll = ScrollController();
  bool expanded = false, pressed = false, busy = false;
  Json? profile;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final nickname = widget.user['username'] ?? widget.user['nickname'];
    if (nickname == null) return;
    try {
      final result = await AppScope.of(
        context,
      ).api.call('user.fetch_profile', body: {'nickname': nickname});
      if (mounted) {
        setState(
          () => profile = object(
            object(result['data'])['user'] ?? result['data'],
          ),
        );
      }
    } catch (_) {}
  }

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

  Future<void> action(String value) async {
    if (busy) return;
    setState(() => busy = true);
    if (value == 'like') {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    final api = AppScope.of(context).api;
    try {
      await perform(context, () async {
        if (value == 'chat') {
          final chat = await createConversation(api, [recordId(widget.user)]);
          if (!mounted) return;
          // Capture the root navigator before closing the radar overlay.
          final navigator = Navigator.of(context, rootNavigator: true);
          widget.onClose();
          navigator.push(
            MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: chat)),
          );
        } else {
          await api.call(
            'match.create',
            body: {'public_id': recordId(widget.user), 'reaction': value},
          );
          if (!mounted) return;
          HapticFeedback.lightImpact();
          widget.onReaction?.call(value);
          widget.onClose();
        }
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
        // The spring can briefly overshoot its target. Keep the layout
        // interpolation within its endpoints so a small/zero-width host can
        // never produce a negative avatar dimension.
        final t = progress.value.clamp(0.0, 1.0);
        final fontScale = MediaQuery.textScalerOf(context).scale(1);
        final dark = Theme.of(context).brightness == Brightness.dark;
        final palette = AppPalette.of(context);
        double lerp(double a, double b) => a + (b - a) * t;
        double clampT(double from, double to) =>
            ((t - from) / (to - from)).clamp(0.0, 1.0);
        final viewportHeight =
            box.maxHeight - widget.topInset - widget.bottomInset;
        // The Radar hero is sized from the available screen height, not the
        // desktop window width. Wide macOS windows otherwise create a huge
        // avatar that overwhelms the profile and bottom tab bar.
        final cardDiameter = (viewportHeight * .24)
            .clamp(150.0, 190.0)
            .clamp(0.0, box.maxWidth * .8);
        final collapsedY =
            widget.topInset + viewportHeight / 2 - cardDiameter / 2 - 60;
        final expandedY = widget.topInset + 20;
        final top = lerp(collapsedY, expandedY);
        // Keep the profile portrait at a stable, screen-centered size while
        // the surrounding identity and actions animate.
        final diameter = cardDiameter;
        final user = profile ?? widget.user;
        final dob = DateTime.tryParse(string(user['date_of_birth']));
        final now = DateTime.now();
        final age = dob == null
            ? null
            : now.year -
                  dob.year -
                  ((now.month < dob.month ||
                          (now.month == dob.month && now.day < dob.day))
                      ? 1
                      : 0);
        final distance = string(widget.user['distance']).replaceAll(' km', '');
        final blurOpacity = (t < .5 ? .8 + .2 * t : .9 + .2 * (t - .5)).clamp(
          0.0,
          1.0,
        );
        final backdropTint = dark
            ? AppDesign.glassClearDark
            : AppDesign.glassPanelLight;
        Widget action(String value) {
          final main = value == 'chat';
          final size = main ? 80.0 : 70.0;
          return AppPressable(
            label: {
              'dislike': context.l10n.radarActionDislike,
              'chat': context.l10n.chat,
              'like': context.l10n.like,
            }[value]!,
            style: AppPressStyle.touchable,
            onPressed: busy ? null : () => this.action(value),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: main
                    ? (dark ? Colors.white : Colors.black)
                    : (dark
                          ? const Color(0xff222222)
                          : const Color(0xfff5f5f5)),
                boxShadow: dark ? const [] : AppDesign.glassShadow,
              ),
              child: Icon(
                main
                    ? Icons.chat
                    : value == 'like'
                    ? Icons.favorite
                    : Icons.close,
                size: main ? 30 : 32,
                color: main
                    ? (dark ? Colors.black : Colors.white)
                    : value == 'like'
                    ? const Color(0xff34c759)
                    : const Color(0xffff3b30),
              ),
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: AppBackdropBlur(
                key: const ValueKey('radar.profile.canvas'),
                intensity: 80 * blurOpacity,
                dark: dark,
                tint: (dark ? AppDesign.glassClearDark : Colors.white)
                    .withValues(alpha: (dark ? .36 : .28) * blurOpacity),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: CustomScrollView(
                key: const ValueKey('radar.profile.scroll'),
                controller: scroll,
                physics: expanded ? null : const NeverScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: top.clamp(0.0, double.infinity),
                            bottom: 24,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                key: const ValueKey('radar.profile.avatar'),
                                dimension: diameter,
                                child: Semantics(
                                  button: true,
                                  expanded: expanded,
                                  label: personName(user),
                                  child: GestureDetector(
                                    onTapDown: (_) {
                                      HapticFeedback.lightImpact();
                                      setState(() => pressed = true);
                                    },
                                    onTapCancel: () =>
                                        setState(() => pressed = false),
                                    onTapUp: (_) =>
                                        setState(() => pressed = false),
                                    onTap: toggle,
                                    child: Opacity(
                                      opacity: pressed ? .9 : 1,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xff333333),
                                          border: Border.all(
                                            width: lerp(4, 2),
                                            color: dark
                                                ? const Color(0xff222222)
                                                : const Color(0xffeeeeee),
                                          ),
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ClipOval(
                                              child: Avatar(
                                                widget.user,
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
                              const SizedBox(height: 15),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDesign.inset,
                                ),
                                child: ConstrainedBox(
                                  key: const ValueKey('radar.profile.identity'),
                                  constraints: BoxConstraints(
                                    minHeight: 70 * fontScale,
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          '${personName(user)}${age != null ? ', $age' : ''}',
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          // Outfit-Black resolves to System 800 on iOS (NativeText).
                                          style: TextStyle(
                                            fontFamily: AppDesign.displayFamily,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 34,
                                            letterSpacing: -1.5,
                                            color: palette.text,
                                          ),
                                        ),
                                      ),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if (user['is_verified'] == true)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: dark
                                                    ? const Color(0xff333333)
                                                    : const Color(0xffeeeeee),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.verified,
                                                    size: 14,
                                                    color: Color(0xff7c4dff),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    context.l10n.verified,
                                                    style: AppDesign.font(
                                                      12,
                                                      weight: FontWeight.w700,
                                                      color: palette.text,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (distance.isNotEmpty &&
                                              distance != '-')
                                            Text(
                                              '• $distance km',
                                              style: AppDesign.font(
                                                14,
                                                weight: FontWeight.w600,
                                                color: palette.text.withValues(
                                                  alpha: .5,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                              Row(
                                key: const ValueKey('radar.profile.actions'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  action('dislike'),
                                  const SizedBox(width: 20),
                                  action('chat'),
                                  const SizedBox(width: 20),
                                  action('like'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
                              child: ProfileAbout(
                                key: const ValueKey('radar.profile.about'),
                                user: user,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
