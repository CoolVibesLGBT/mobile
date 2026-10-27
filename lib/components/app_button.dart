import 'glass_surface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_pressable.dart';
import '../vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;
import '../design/app_design.dart';

/// Every glass button is the vendored Liquid Glass button: it owns the press
/// (stretch, glow, scale, disabled state) and the material, the same on every
/// platform. [radius] null draws a capsule/circle.
Widget _liquidButton({
  required Widget child,
  required VoidCallback? onPressed,
  required String label,
  double? width,
  double? height,
  double? radius,
  Color? tint,
  GlassSurfaceRole? surfaceRole,
  double disabledOpacity = .5,
}) => PlatformBackdrop.listen((context, overPlatformView) {
  final role = surfaceRole ?? AppBarScope.surfaceRoleOf(context);
  return PlatformBackdropUnderlay(
    shape: radius == null
        ? const StadiumBorder()
        : RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
    child: liquid.GlassButton.custom(
      platformViewBackdrop: overPlatformView,
      label: label,
      onTap: onPressed ?? () {},
      enabled: onPressed != null,
      disabledOpacity: disabledOpacity,
      width: width,
      height: height,
      shape: radius == null
          ? const liquid.LiquidOval()
          : liquid.LiquidRoundedSuperellipse(borderRadius: radius),
      quality: role.quality,
      // These controls stay in a fixed lane. Keep the same live blur as their
      // input surface while retaining the button's press animation.
      isStationary: role != GlassSurfaceRole.control,
      style: liquid.GlassButtonStyle.filled,
      settings: appGlassSettings(
        context,
        tint: tint,
        role: role,
        platformViewBackdrop: overPlatformView,
      ),
      child: child,
    ),
  );
});

/// Source components/ui/Button.tsx vocabulary.
/// [accent] follows the chosen chat theme (Telegram action buttons).
enum AppButtonVariant { normal, accent, branded, critical, warning }

enum AppButtonEmphasis { primary, secondary, tertiary, text }

enum AppButtonSize { xsmall, small, medium, large }

/// Marks controls that sit in the navigation bar. Bar controls are iOS glass
/// items drawn in the label colour (NativeWorkspace HeaderTextButton/BarButton);
/// content controls are the source's solid Button.
class AppBarScope extends InheritedWidget {
  final GlassSurfaceRole surfaceRole;
  const AppBarScope({
    super.key,
    required super.child,
    this.surfaceRole = GlassSurfaceRole.control,
  });
  static GlassSurfaceRole surfaceRoleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppBarScope>()?.surfaceRole ??
      GlassSurfaceRole.control;
  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppBarScope>() != null;
  @override
  bool updateShouldNotify(AppBarScope oldWidget) =>
      surfaceRole != oldWidget.surfaceRole;
}

class AppButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonEmphasis emphasis;
  final AppButtonSize size;
  final bool loading, expand;
  final bool solid;
  final IconData? leadingIcon, trailingIcon;
  const AppButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.variant = AppButtonVariant.normal,
    this.emphasis = AppButtonEmphasis.primary,
    this.size = AppButtonSize.medium,
    this.loading = false,
    this.expand = false,
    this.solid = false,
    this.leadingIcon,
    this.trailingIcon,
  });
  const AppButton.text({
    super.key,
    required this.child,
    required this.onPressed,
    this.variant = AppButtonVariant.normal,
    this.size = AppButtonSize.medium,
    this.loading = false,
    this.solid = false,
    this.leadingIcon,
    this.trailingIcon,
  }) : emphasis = AppButtonEmphasis.text,
       expand = false;
  const AppButton.filled({
    super.key,
    required this.child,
    required this.onPressed,
    this.variant = AppButtonVariant.normal,
    this.size = AppButtonSize.medium,
    this.loading = false,
    this.expand = true,
    this.solid = false,
    this.leadingIcon,
    this.trailingIcon,
  }) : emphasis = AppButtonEmphasis.primary;
  const AppButton.outlined({
    super.key,
    required this.child,
    required this.onPressed,
    this.variant = AppButtonVariant.normal,
    this.size = AppButtonSize.medium,
    this.loading = false,
    this.expand = false,
    this.solid = false,
    this.leadingIcon,
    this.trailingIcon,
  }) : emphasis = AppButtonEmphasis.tertiary;

  // ButtonSizes in constants/theme.ts.
  static const _metrics = {
    AppButtonSize.xsmall: (12.0, 8.0, 44.0, 22.0, 13.0),
    AppButtonSize.small: (12.0, 8.0, 44.0, 22.0, 15.0),
    AppButtonSize.medium: (16.0, 12.0, 48.0, 24.0, 17.0),
    AppButtonSize.large: (20.0, 16.0, 56.0, 28.0, 17.0),
  };

  /// resolveColors() in Button.tsx, over the source Colors.ts brand palette.
  static (Color, Color, Color?) colors(
    BuildContext context,
    AppButtonVariant variant,
    AppButtonEmphasis emphasis,
    bool disabled,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xff131313);
    final background = dark ? const Color(0xff131313) : Colors.white;
    final surface3 = dark ? const Color(0x1fffffff) : const Color(0x14131313);
    const none = Colors.transparent;
    if (disabled) {
      return (
        emphasis == AppButtonEmphasis.tertiary ||
                emphasis == AppButtonEmphasis.text
            ? none
            : (dark ? const Color(0xff1f1f1f) : const Color(0xfff9f9f9)),
        dark ? const Color(0x61ffffff) : const Color(0x59131313),
        emphasis == AppButtonEmphasis.tertiary ? surface3 : null,
      );
    }
    final (primaryBg, primaryFg, softBg, softFg) = switch (variant) {
      AppButtonVariant.branded => (
        const Color(0xffa80080),
        Colors.white,
        const Color(0x14ff37c7),
        dark ? const Color(0xffff77dc) : const Color(0xffa80080),
      ),
      AppButtonVariant.critical => (
        dark ? const Color(0xffff593c) : const Color(0xffe10f0f),
        Colors.white,
        dark ? const Color(0x1fff593c) : const Color(0x0dff0000),
        dark ? const Color(0xffff593c) : const Color(0xffe10f0f),
      ),
      AppButtonVariant.warning => (
        dark ? const Color(0xffffbf17) : const Color(0xff996f01),
        Colors.white,
        dark ? const Color(0x14ffbf17) : const Color(0x1affbf17),
        dark ? const Color(0xffffbf17) : const Color(0xff996f01),
      ),
      AppButtonVariant.normal => (text, background, surface3, text),
      AppButtonVariant.accent => (
        AppPalette.of(context).accent,
        Colors.white,
        AppPalette.of(context).accent.withValues(alpha: .12),
        AppPalette.of(context).accent,
      ),
    };
    return switch (emphasis) {
      AppButtonEmphasis.primary => (primaryBg, primaryFg, null),
      AppButtonEmphasis.secondary => (softBg, softFg, null),
      AppButtonEmphasis.tertiary => (none, softFg, softBg),
      AppButtonEmphasis.text => (
        none,
        variant == AppButtonVariant.normal
            ? (dark ? const Color(0xffff77dc) : const Color(0xffa80080))
            : softFg,
        null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (AppBarScope.contains(context) && !solid) {
      return AppBarTextButton(
        onPressed: loading ? null : onPressed,
        loading: loading,
        child: child,
      );
    }
    final disabled = onPressed == null || loading;
    final (bg, baseForeground, border) = colors(
      context,
      variant,
      emphasis,
      disabled,
    );
    final fg =
        solid &&
            emphasis == AppButtonEmphasis.text &&
            variant == AppButtonVariant.normal
        ? AppPalette.of(context).secondaryLabel
        : baseForeground;
    final (padH, padV, minHeight, radius, fontSize) = _metrics[size]!;
    final scale = MediaQuery.textScalerOf(context);
    final content = loading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          )
        : DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            style: solid
                ? TextStyle(
                    fontFamily: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.fontFamily,
                    fontSize: scale.scale(16),
                    fontWeight: FontWeight.w500,
                    color: disabled
                        ? AppPalette.of(context).secondaryLabel
                        : fg,
                  )
                : AppDesign.font(
                    scale.scale(fontSize),
                    weight: FontWeight.w600,
                    color: fg,
                  ),
            child: IconTheme.merge(
              data: IconThemeData(color: fg, size: 20),
              child: MediaQuery.withNoTextScaling(child: child),
            ),
          );
    final contents = loading || (leadingIcon == null && trailingIcon == null)
        ? content
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(child: content),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 18, color: fg),
              ],
            ],
          );
    if (solid) {
      return Semantics(
        liveRegion: loading,
        child: AppPressable(
          label: child is Text ? (child as Text).data ?? '' : '',
          onPressed: disabled ? null : onPressed,
          style: AppPressStyle.button,
          disabledOpacity: disabled ? .65 : 1,
          child: Container(
            width: expand ? double.infinity : null,
            constraints: const BoxConstraints(minHeight: 48, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: disabled && emphasis == AppButtonEmphasis.primary
                  ? AppPalette.of(context).background
                  : bg,
              borderRadius: BorderRadius.circular(AppDesign.authControlRadius),
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Flexible(child: contents)],
            ),
          ),
        ),
      );
    }
    return _liquidButton(
      label: child is Text ? (child as Text).data ?? '' : '',
      onPressed: disabled ? null : onPressed,
      width: expand ? double.infinity : null,
      radius: radius,
      tint: emphasis == AppButtonEmphasis.primary ? bg : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Flexible(child: contents)],
          ),
        ),
      ),
    );
  }
}

/// NativeWorkspace HeaderTextButton: 17pt semibold label colour, secondary
/// label when disabled, inside the system bar-item glass capsule on iOS 26.
class AppBarTextButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool loading;
  const AppBarTextButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final enabled = onPressed != null && !loading;
    final label = child is Text ? (child as Text).data ?? '' : '';
    final style = AppDesign.font(
      MediaQuery.textScalerOf(context).scale(17),
      weight: FontWeight.w600,
      color: enabled ? palette.text : palette.secondaryLabel,
    );
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final width = (painter.width + 32).clamp(44.0, 220.0);
    return _liquidButton(
      label: label,
      onPressed: enabled ? onPressed : null,
      width: width,
      height: 44,
      radius: 22,
      child: Center(
        child: loading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation(palette.text),
                ),
              )
            : MediaQuery.withNoTextScaling(
                child: Text(label, maxLines: 1, style: style),
              ),
      ),
    );
  }
}

/// One SF Symbol control. In the navigation bar (or with [glass]) it is the
/// source's 44pt round glass bar item with a 14pt medium, large-scale symbol in
/// the label colour (SystemIcon `bar`); elsewhere it is a bare 44pt target.
class AppIconButton extends StatelessWidget {
  final Widget icon;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double dimension;
  final bool embedded, prominent;
  final bool? glass;
  final bool badge;
  final double symbolSize;
  final GlassSurfaceRole? surfaceRole;
  final Color? backgroundColor;
  const AppIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    this.onLongPressCancel,
    required this.onPressed,
    this.color,
    this.padding = const EdgeInsets.all(10),
    this.dimension = 44,
    this.embedded = false,
    this.prominent = false,
    this.glass,
    this.badge = false,
    this.symbolSize = 14,
    this.surfaceRole,
    this.backgroundColor,
  });
  static final symbols = <int, String>{
    Icons.add.codePoint: 'plus',
    Icons.attach_file.codePoint: 'paperclip',
    Icons.emoji_emotions_outlined.codePoint: 'face.smiling',
    Icons.mic_none.codePoint: 'mic',
    Icons.stop.codePoint: 'stop.fill',
    Icons.star_outline.codePoint: 'star',
    Icons.person_add_outlined.codePoint: 'person.badge.plus',
    Icons.block.codePoint: 'hand.raised',
    Icons.close.codePoint: 'xmark',
    Icons.chevron_left.codePoint: 'chevron.backward',
    Icons.menu.codePoint: 'line.3.horizontal',
    Icons.search.codePoint: 'magnifyingglass',
    Icons.travel_explore.codePoint: 'location.magnifyingglass',
    Icons.forward.codePoint: 'arrowshape.turn.up.right',
    Icons.edit.codePoint: 'pencil',
    Icons.edit_outlined.codePoint: 'pencil',
    Icons.edit_square.codePoint: 'square.and.pencil',
    Icons.favorite.codePoint: 'heart.fill',
    Icons.favorite_border.codePoint: 'heart',
    Icons.bookmark_border.codePoint: 'bookmark',
    Icons.bookmark.codePoint: 'bookmark.fill',
    Icons.chat_bubble_outline.codePoint: 'bubble.left',
    Icons.send.codePoint: 'arrow.up',
    Icons.arrow_upward.codePoint: 'arrow.up',
    Icons.photo_outlined.codePoint: 'photo',
    Icons.videocam_outlined.codePoint: 'video',
    Icons.location_on_outlined.codePoint: 'mappin.and.ellipse',
    Icons.my_location.codePoint: 'location.fill',
    Icons.map_outlined.codePoint: 'map',
    Icons.list.codePoint: 'list.bullet',
    Icons.info_outline.codePoint: 'info.circle',
    Icons.reply.codePoint: 'arrowshape.turn.up.left',
    Icons.check.codePoint: 'checkmark',
    Icons.refresh.codePoint: 'arrow.clockwise',
    Icons.person_remove_outlined.codePoint: 'person.badge.minus',
    Icons.notifications_none.codePoint: 'bell',
    Icons.developer_mode.codePoint: 'hammer',
    Icons.grid_4x4.codePoint: 'grid',
    Icons.grid_view.codePoint: 'square.grid.2x2',
    Icons.grid_view_outlined.codePoint: 'square.grid.2x2',
    Icons.light_mode.codePoint: 'sun.max',
    Icons.dark_mode.codePoint: 'moon',
    Icons.add_location_alt_outlined.codePoint: 'mappin.badge.plus',
    Icons.thumb_up_outlined.codePoint: 'hand.thumbsup',
    Icons.thumb_down_outlined.codePoint: 'hand.thumbsdown',
    Icons.add_comment_outlined.codePoint: 'bubble.left.and.bubble.right',
    Icons.play_arrow.codePoint: 'play.fill',
    Icons.pause.codePoint: 'pause.fill',
    Icons.more_horiz.codePoint: 'ellipsis',
    Icons.share_outlined.codePoint: 'square.and.arrow.up',
    Icons.keyboard_outlined.codePoint: 'keyboard',
    Icons.settings_outlined.codePoint: 'gearshape',
  };

  /// NativeWorkspace BadgeDot: 8pt destructive dot, 8pt from the top.
  static Widget _withBadge(Widget child, AppPalette palette) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      PositionedDirectional(
        top: 8,
        end: 7,
        child: IgnorePointer(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: palette.destructive,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final onGlass = !embedded && (glass ?? true);
    final tint = color ?? (onGlass ? palette.text : palette.secondaryLabel);
    final symbol = icon is Icon
        ? symbols[(icon as Icon).icon?.codePoint]
        : null;
    Widget glyph = IconTheme.merge(
      data: IconThemeData(
        color: color ?? (prominent ? palette.accentText : tint),
        size:
            (icon is Icon ? (icon as Icon).size : null) ??
            (onGlass ? symbolSize * 1.3 : 22),
      ),
      // One icon source on every platform: the SF-style Cupertino glyph.
      child: symbol != null && AppSymbol.icons.containsKey(symbol)
          ? Icon(AppSymbol.icons[symbol])
          : icon,
    );
    final face = SizedBox.square(
      dimension: dimension,
      child: Center(
        child: embedded && prominent
            ? Container(
                width: AppDesign.composerSendSize,
                height: AppDesign.composerSendSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onPressed == null
                      ? palette.accent.withValues(alpha: .4)
                      : palette.accent,
                ),
                child: Center(child: glyph),
              )
            : glyph,
      ),
    );
    Widget control = onLongPressStart != null
        ? AppPressable(
            label: tooltip ?? '',
            style: AppPressStyle.glass,
            onPressed: onPressed,
            onLongPressStart: onLongPressStart,
            onLongPressMoveUpdate: onLongPressMoveUpdate,
            onLongPressEnd: onLongPressEnd,
            onLongPressCancel: onLongPressCancel,
            child: GlassSurface(
              role: surfaceRole ?? AppBarScope.surfaceRoleOf(context),
              circular: true,
              radius: dimension / 2,
              child: face,
            ),
          )
        : onGlass
        ? _liquidButton(
            label: tooltip ?? '',
            onPressed: onPressed,
            width: dimension,
            height: dimension,
            tint: backgroundColor ?? (prominent ? palette.accent : null),
            disabledOpacity: backgroundColor != null ? 1 : .5,
            surfaceRole: surfaceRole,
            child: face,
          )
        : AppPressable(
            label: tooltip ?? '',
            style: AppPressStyle.opacity,
            onPressed: onPressed,
            child: face,
          );
    if (badge) control = _withBadge(control, palette);
    return SizedBox(
      width: dimension,
      height: dimension < 44 ? 44 : dimension,
      child: Center(child: control),
    );
  }
}

/// The round or capsule glass bar item (NativeWorkspace BarButton): a
/// symbol, a title or arbitrary [child] (the header avatar) on interactive
/// glass that swells under the finger. Drawn by Flutter on every platform.
class GlassButton extends StatelessWidget {
  final String? symbol, title;
  final Widget? child;
  final double symbolSize, fontSize;
  final bool prominent;
  final Color color;
  final Color? tint, disabledColor;
  final bool loading;
  final bool expand;
  final VoidCallback? onPressed;
  final String label;
  const GlassButton({
    super.key,
    this.symbol,
    this.title,
    this.child,
    this.symbolSize = 14,
    this.fontSize = 17,
    this.prominent = false,
    required this.color,
    this.tint,
    this.disabledColor,
    this.loading = false,
    this.expand = true,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled
        ? color
        : disabledColor ?? AppPalette.of(context).secondaryLabel;
    final Widget content = loading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation(foreground),
            ),
          )
        : child ??
              (symbol != null
                  ? AppSymbol(
                      symbol!,
                      size: symbolSize,
                      box: symbolSize * 1.6,
                      color: foreground,
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppDesign.font(
                          MediaQuery.textScalerOf(context).scale(fontSize),
                          weight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ));
    return LayoutBuilder(
      builder: (context, box) => _liquidButton(
        label: label,
        onPressed: loading ? null : onPressed,
        width: expand && box.hasBoundedWidth ? box.maxWidth : null,
        height: box.hasBoundedHeight ? box.maxHeight : null,
        // A capsule unless the button is square (then a circle).
        radius:
            box.hasBoundedWidth &&
                box.hasBoundedHeight &&
                box.maxWidth != box.maxHeight
            ? box.maxHeight / 2
            : null,
        tint: prominent ? tint : null,
        child: Center(widthFactor: expand ? null : 1, child: content),
      ),
    );
  }
}

/// An SF Symbol name drawn with the matching Cupertino glyph, so iOS and
/// Android show the same icon (SF Symbols themselves are Apple-only).
class AppSymbol extends StatelessWidget {
  final String name;
  final double size;
  final String weight;
  final Color? color;
  final IconData? fallback;
  final double box;

  /// SystemIcon without `bar`: the glyph scaled to fit a [box] square.
  final bool fit;
  final bool nativeSize;
  const AppSymbol(
    this.name, {
    super.key,
    this.size = 17,
    this.weight = 'regular',
    this.color,
    this.fallback,
    this.box = 30,
    this.fit = false,
    this.nativeSize = false,
  });

  /// `<SystemIcon name size>`: the glyph scaled to fit a [size] square.
  const AppSymbol.icon(
    this.name, {
    super.key,
    required double size,
    this.weight = 'regular',
    this.color,
    this.fallback,
  }) : size = 14,
       box = size,
       fit = true,
       nativeSize = false;

  const AppSymbol.native(this.name, {super.key, this.color})
    : size = 24,
      weight = 'regular',
      fallback = null,
      box = 30,
      fit = false,
      nativeSize = true;

  static const assets = <String, (String, double)>{
    'chat.action.pin': ('assets/images/chat_action_pin.svg', 24.0),
    'chat.action.unpin': ('assets/images/chat_action_unpin.svg', 24.0),
    'chat.action.mute': ('assets/images/chat_action_muted.svg', 24.0),
    'chat.action.unmute': ('assets/images/chat_action_unmute.svg', 24.0),
    'chat.action.delete': ('assets/images/chat_action_delete.svg', 24.0),
    'chat.media.expand': ('assets/images/chat_media_expand.png', 26.0),
    'article.add': ('assets/images/article/add.svg', 24.0),
    'article.list': ('assets/images/article/list.svg', 30.0),
    'article.table': ('assets/images/article/table.svg', 30.0),
    'article.attach': ('assets/images/article/attach.svg', 30.0),
    'article.emoji': ('assets/images/article/emoji.svg', 30.0),
    'article.bold': ('assets/images/article/bold.svg', 30.0),
    'article.italic': ('assets/images/article/italic.svg', 30.0),
    'article.strike': ('assets/images/article/strike.svg', 30.0),
    'article.underline': ('assets/images/article/underline.svg', 30.0),
    'article.spoiler': ('assets/images/article/spoiler.svg', 30.0),
    'article.link': ('assets/images/article/link.svg', 30.0),
    'article.quote': ('assets/images/article/quote.svg', 30.0),
    'article.send': ('assets/images/article/send.svg', 30.0),
    'article.close': ('assets/images/article/close.svg', 30.0),
    'article.undo': ('assets/images/article/undo.svg', 30.0),
    'article.redo': ('assets/images/article/redo.svg', 30.0),
    'article.keyboard': ('assets/images/article/keyboard.svg', 40.0),
    'article.heading': ('assets/images/article/heading.svg', 24.0),
    'article.h1': ('assets/images/article/h1.svg', 24.0),
    'article.h2': ('assets/images/article/h2.svg', 24.0),
    'article.h3': ('assets/images/article/h3.svg', 24.0),
    'article.h4': ('assets/images/article/h4.svg', 24.0),
    'article.h5': ('assets/images/article/h5.svg', 24.0),
    'article.h6': ('assets/images/article/h6.svg', 24.0),
    'article.text': ('assets/images/article/text.svg', 24.0),
    'article.bullet': ('assets/images/article/bullet.svg', 24.0),
    'article.number': ('assets/images/article/number.svg', 24.0),
    'article.checklist': ('assets/images/article/checklist.svg', 24.0),
    'article.blockquote': ('assets/images/article/blockquote.svg', 24.0),
    'article.code': ('assets/images/article/code.svg', 24.0),
    'textformat.heading': ('assets/images/article/heading.svg', 24.0),
    'textformat.h1': ('assets/images/article/h1.svg', 24.0),
    'textformat.h2': ('assets/images/article/h2.svg', 24.0),
    'textformat.h3': ('assets/images/article/h3.svg', 24.0),
    'textformat.h4': ('assets/images/article/h4.svg', 24.0),
    'textformat.h5': ('assets/images/article/h5.svg', 24.0),
    'textformat.h6': ('assets/images/article/h6.svg', 24.0),
    'textformat.paragraph': ('assets/images/article/text.svg', 24.0),
    'text.quote': ('assets/images/article/blockquote.svg', 24.0),
    'list.number': ('assets/images/article/number.svg', 24.0),
    'checklist': ('assets/images/article/checklist.svg', 24.0),
    'chevron.left.forwardslash.chevron.right': (
      'assets/images/article/code.svg',
      24.0,
    ),
  };

  /// SF Symbol -> Cupertino glyph.
  static const icons = <String, IconData>{
    'table.row.add': IconData(0xf04f3, fontFamily: 'MaterialCommunityIcons'),
    'table.column.add': IconData(0xf04ec, fontFamily: 'MaterialCommunityIcons'),
    'table.row.remove': IconData(0xf04f5, fontFamily: 'MaterialCommunityIcons'),
    'table.column.remove': IconData(
      0xf04ee,
      fontFamily: 'MaterialCommunityIcons',
    ),
    'table.remove': IconData(0xf0a76, fontFamily: 'MaterialCommunityIcons'),
    'arrow.clockwise': CupertinoIcons.arrow_clockwise,
    'arrow.up': CupertinoIcons.arrow_up,
    'arrowshape.turn.up.left': CupertinoIcons.arrowshape_turn_up_left,
    'arrowshape.turn.up.right': CupertinoIcons.arrowshape_turn_up_right,
    'bell': CupertinoIcons.bell,
    'bell.fill': CupertinoIcons.bell_fill,
    'bookmark': CupertinoIcons.bookmark,
    'bookmark.fill': CupertinoIcons.bookmark_fill,
    'bubble.left': CupertinoIcons.chat_bubble,
    'bubble.left.fill': CupertinoIcons.chat_bubble_fill,
    'bubble.left.and.bubble.right': CupertinoIcons.chat_bubble_2,
    'bubble.left.and.bubble.right.fill': CupertinoIcons.chat_bubble_2_fill,
    'calendar': CupertinoIcons.calendar,
    'camera': CupertinoIcons.camera,
    'car': CupertinoIcons.car,
    'checkmark': CupertinoIcons.checkmark,
    'checkmark.circle': CupertinoIcons.checkmark_circle,
    'chevron.backward': CupertinoIcons.chevron_back,
    'doc': CupertinoIcons.doc,
    'doc.on.doc': CupertinoIcons.doc_on_doc,
    'dot.radiowaves.left.and.right':
        CupertinoIcons.antenna_radiowaves_left_right,
    'ellipsis': CupertinoIcons.ellipsis,
    'exclamationmark.bubble': CupertinoIcons.exclamationmark_bubble,
    'face.smiling': CupertinoIcons.smiley,
    'flag': CupertinoIcons.flag,
    'fork.knife': CupertinoIcons.cart,
    'gearshape': CupertinoIcons.gear_alt,
    'globe': CupertinoIcons.globe,
    'grid': CupertinoIcons.square_grid_3x2,
    'hammer': CupertinoIcons.hammer,
    'hand.raised': CupertinoIcons.hand_raised,
    'hand.raised.fill': CupertinoIcons.hand_raised_fill,
    'hand.raised.slash.fill': CupertinoIcons.hand_raised_slash_fill,
    'hand.thumbsdown': CupertinoIcons.hand_thumbsdown,
    'hand.thumbsup': CupertinoIcons.hand_thumbsup,
    'heart': CupertinoIcons.heart,
    'heart.fill': CupertinoIcons.heart_fill,
    'house': CupertinoIcons.house,
    'house.fill': CupertinoIcons.house_fill,
    'info.circle': CupertinoIcons.info_circle,
    'keyboard': CupertinoIcons.keyboard,
    'lightbulb': CupertinoIcons.lightbulb,
    'line.3.horizontal': CupertinoIcons.line_horizontal_3,
    'list.bullet': CupertinoIcons.list_bullet,
    'location': CupertinoIcons.location,
    'location.circle': CupertinoIcons.location_circle,
    'location.circle.fill': CupertinoIcons.location_circle_fill,
    'location.fill': CupertinoIcons.location_fill,
    'location.magnifyingglass': CupertinoIcons.location,
    'lock.fill': CupertinoIcons.lock_fill,
    'magnifyingglass': CupertinoIcons.search,
    'map': CupertinoIcons.map,
    'mappin.and.ellipse': CupertinoIcons.map_pin_ellipse,
    'mappin.badge.plus': CupertinoIcons.map_pin_ellipse,
    'mappin.circle': CupertinoIcons.placemark,
    'mappin.circle.fill': CupertinoIcons.placemark_fill,
    'mic': CupertinoIcons.mic,
    'moon': CupertinoIcons.moon,
    'paintbrush.fill': CupertinoIcons.paintbrush_fill,
    'paperclip': CupertinoIcons.paperclip,
    'paperplane': CupertinoIcons.paperplane,
    'pause.fill': CupertinoIcons.pause_fill,
    'pawprint': CupertinoIcons.paw,
    'pencil': CupertinoIcons.pencil,
    'person.badge.minus': CupertinoIcons.person_badge_minus,
    'person.badge.plus': CupertinoIcons.person_badge_plus,
    'person.fill.checkmark':
        CupertinoIcons.person_crop_circle_fill_badge_checkmark,
    'person.crop.circle': CupertinoIcons.person_crop_circle,
    'photo': CupertinoIcons.photo,
    'photo.on.rectangle': CupertinoIcons.photo_on_rectangle,
    'play.fill': CupertinoIcons.play_fill,
    'plus': CupertinoIcons.plus,
    'rectangle.portrait.and.arrow.right': CupertinoIcons.square_arrow_right,
    'soccerball': CupertinoIcons.sportscourt,
    'square.and.arrow.up': CupertinoIcons.square_arrow_up,
    'square.and.pencil': CupertinoIcons.square_pencil,
    'square.grid.2x2': CupertinoIcons.square_grid_2x2,
    'star': CupertinoIcons.star,
    'star.fill': CupertinoIcons.star_fill,
    'stop.fill': CupertinoIcons.stop_fill,
    'sun.max': CupertinoIcons.sun_max,
    'timer': CupertinoIcons.timer,
    'trash': CupertinoIcons.trash,
    'video': CupertinoIcons.videocam,
    'xmark': CupertinoIcons.xmark,
  };

  @override
  Widget build(BuildContext context) {
    final asset = assets[name];
    final extent = nativeSize && asset != null
        ? asset.$2
        : fit
        ? box
        : size * 1.3;
    final tint = color ?? IconTheme.of(context).color ?? Colors.black;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: nativeSize && asset != null ? asset.$2 : box,
        child: Center(
          child: asset != null
              ? asset.$1.endsWith('.png')
                    ? Image.asset(
                        asset.$1,
                        width: extent,
                        height: extent,
                        color: tint,
                        colorBlendMode: BlendMode.srcIn,
                      )
                    : SvgPicture.asset(
                        asset.$1,
                        width: extent,
                        height: extent,
                        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
                      )
              : name == 'sticker'
              ? CustomPaint(
                  size: Size.square(extent),
                  painter: _StickerGlyph(tint),
                )
              : Icon(
                  icons[name] ?? fallback ?? CupertinoIcons.circle,
                  size: extent,
                  color: tint,
                ),
        ),
      ),
    );
  }
}

/// Folded circular sticker glyph used by the media-keyboard toggle.
class _StickerGlyph extends CustomPainter {
  const _StickerGlyph(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final path = Path()
      ..moveTo(12, 2)
      ..cubicTo(6.48, 2, 2, 6.48, 2, 12)
      ..cubicTo(2, 17.52, 6.48, 22, 12, 22)
      ..cubicTo(17.52, 22, 22, 17.52, 22, 12)
      ..lineTo(12, 2)
      ..cubicTo(10.8, 8.6, 15.4, 13.2, 22, 12);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StickerGlyph oldDelegate) => color != oldDelegate.color;
}
