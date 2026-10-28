import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_design.dart';
import '../vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;
import 'app_button.dart';
import 'app_context_menu.dart';
import 'app_scaffold.dart';
import 'glass_surface.dart';

/// Edge preference retained for existing callers. All navigation headers use
/// the shared Flutter glass material; media can explicitly opt out with [none].
enum AppHeaderEdge { hard, soft, opaque, none }

/// One navigation bar for pages, sheets and the debug catalogue.
/// NativeTabStack / NativeWorkspace metrics: 44pt row under the status bar,
/// 16pt edges, 44pt glass controls 8pt apart, centred 17pt semibold title.
class AppHeader extends StatefulWidget implements PreferredSizeWidget {
  final Widget? title, leading;
  final double? titleWidth;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? foregroundColor;
  final Color? edgeTint;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final GlassSurfaceRole surfaceRole;

  /// Edge fade behind the floating controls; [AppHeaderEdge.none] leaves the
  /// wallpaper visible between the controls.
  final AppHeaderEdge? edge;
  final bool automaticallyImplyLeading;
  const AppHeader({
    super.key,
    this.title,
    this.titleWidth,
    this.leading,
    this.actions,
    this.bottom,
    this.foregroundColor,
    this.edgeTint,
    this.systemOverlayStyle,
    this.surfaceRole = GlassSurfaceRole.control,
    this.edge,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(
    AppDesign.headerHeight +
        AppDesign.headerTitlebarGap +
        (bottom?.preferredSize.height ?? 0),
  );

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = widget.foregroundColor ?? palette.text;
    final top = MediaQuery.paddingOf(context).top;
    final route = ModalRoute.of(context);
    final canPop = route?.canPop ?? false;
    final close =
        route is CupertinoSheetRoute ||
        (route is PageRoute ? route.fullscreenDialog : route is PopupRoute);
    final navigation =
        widget.leading ??
        // ChatInterfaceStateNavigationButtons: a previewing screen has no
        // leading button; its route is the menu, not a page to go back from.
        (widget.automaticallyImplyLeading &&
                canPop &&
                !AppPreviewScope.contains(context)
            ? AppIconButton(
                tooltip: close
                    ? MaterialLocalizations.of(context).closeButtonTooltip
                    : MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icon(close ? Icons.close : Icons.chevron_left),
                color: color,
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null);
    // NativeTabStack: with more than two actions the first one sits on the
    // leading side, 8pt after the navigation control.
    final all = widget.actions ?? const <Widget>[];
    final moved = all.length > 2 && navigation != null ? all.first : null;
    final actions = moved == null ? all : all.sublist(1);
    // Reserve only the occupied control lanes. A fixed 104pt inset truncated
    // simple titles and squeezed the nearby view selector on compact phones.
    final leadingCount = (navigation == null ? 0 : 1) + (moved == null ? 0 : 1);
    final laneCount = leadingCount > actions.length
        ? leadingCount
        : actions.length;
    final titleInset =
        16.0 + (laneCount == 0 ? 0 : laneCount * 44 + (laneCount - 1) * 8 + 8);
    final row = SizedBox(
      height: AppDesign.headerHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.title is Text)
            // The title stays centred on the bar, clear of up to two controls.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: titleInset),
              child: DefaultTextStyle(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppDesign.font(
                  17,
                  weight: FontWeight.w600,
                  color: color,
                ),
                child: Semantics(header: true, child: widget.title!),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ?navigation,
                if (moved != null) ...[const SizedBox(width: 8), moved],
                if (widget.title != null && widget.title is! Text)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final spare =
                              ((box.maxWidth -
                                          (widget.titleWidth ?? box.maxWidth)) /
                                      2)
                                  .clamp(0.0, double.infinity);
                          final desired =
                              (actions.length - leadingCount) * 26.0;
                          final shift =
                              desired.clamp(-spare, spare) *
                              (Directionality.of(context) == TextDirection.rtl
                                  ? -1
                                  : 1);
                          return Transform.translate(
                            offset: Offset(shift, 0),
                            child: Center(
                              child: DefaultTextStyle(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppDesign.font(
                                  17,
                                  weight: FontWeight.w600,
                                  color: color,
                                ),
                                child: Semantics(
                                  header: true,
                                  child: widget.title!,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  const Spacer(),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0 &&
                      actions[i] is! SizedBox &&
                      actions[i - 1] is! SizedBox)
                    const SizedBox(width: 8),
                  actions[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final edgeColor =
        widget.edgeTint ??
        context.findAncestorWidgetOfExactType<AppScaffold>()?.backgroundColor ??
        Theme.of(context).scaffoldBackgroundColor;
    final reduceTransparency = liquid.GlassAccessibilityData.of(
      context,
    ).reduceTransparency;
    final bar = AppBarScope(
      surfaceRole: widget.surfaceRole,
      child: IconTheme.merge(
        data: IconThemeData(color: color),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final requestedGap = AppDesign.headerTitlebarGap;
            final requiredHeight =
                top +
                AppDesign.headerHeight +
                requestedGap +
                (widget.bottom?.preferredSize.height ?? 0);
            final gap =
                !constraints.hasBoundedHeight ||
                    constraints.maxHeight >= requiredHeight
                ? requestedGap
                : 0.0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: top + gap),
                row,
                ?widget.bottom,
              ],
            );
          },
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          widget.systemOverlayStyle ??
          (color.computeLuminance() > .5
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
      child: widget.edge == AppHeaderEdge.none
          ? bar
          : Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      key: const ValueKey('app.header.backdrop'),
                      fit: StackFit.expand,
                      children: [
                        if (!reduceTransparency)
                          const liquid.ProgressiveBlur(
                            maxSigma: AppDesign.headerBlurSigma,
                            falloff: AppDesign.headerBlurFalloff,
                          ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: reduceTransparency
                                ? edgeColor.withValues(alpha: 1)
                                : null,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                for (final a in const [.75, .72, .55, .25, 0.0])
                                  edgeColor.withValues(alpha: edgeColor.a * a),
                              ],
                              stops: const [0, .45, .7, .88, 1],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                bar,
              ],
            ),
    );
  }
}
