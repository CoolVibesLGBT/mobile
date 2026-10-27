import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../design/app_design.dart';
import '../vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;
import 'record_list.dart';

/// Every page shares one continuous backdrop beneath its transparent header.
class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body, bottomNavigationBar, floatingActionButton;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset, extendBody;

  /// Every bar is transparent (NativeTabStack: `headerTransparent`). Bodies
  /// that scroll under it set this and read the inset from MediaQuery
  /// (ListView, RecordList); others start below the bar automatically.
  final bool extendBodyBehindAppBar;
  final Widget? bottomOverlay;
  final ValueListenable<double>? backgroundProgress;
  final double bottomOverlayHeight;
  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
    this.bottomOverlay,
    this.backgroundProgress,
    this.bottomOverlayHeight = 0,
  });
  @override
  Widget build(BuildContext context) {
    // The modal owns its backdrop. A page's opaque background would hide it.
    final inSheet = liquid.GlassModalSheetStateProvider.of(context) != null;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final snackSafeBottom =
        resizeToAvoidBottomInset && media.viewInsets.bottom > 0
        ? 0.0
        : media.viewPadding.bottom;
    final snackInsets =
        theme.snackBarTheme.insetPadding ??
        const EdgeInsets.fromLTRB(15, 5, 15, 10);
    final page = Theme(
      data: bottomOverlay == null
          ? theme
          : theme.copyWith(
              snackBarTheme: theme.snackBarTheme.copyWith(
                behavior: SnackBarBehavior.floating,
                insetPadding: snackInsets.copyWith(
                  bottom:
                      snackInsets.bottom +
                      (bottomOverlayHeight - snackSafeBottom).clamp(
                        0,
                        double.infinity,
                      ),
                ),
              ),
            ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: inSheet
                    ? Colors.transparent
                    : backgroundColor ??
                          Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            extendBody: extendBody,
            // The bar is always laid over the body so it stays transparent.
            extendBodyBehindAppBar: appBar != null,
            appBar: appBar,
            body:
                appBar == null ||
                    extendBodyBehindAppBar ||
                    body == null ||
                    body is ScrollView ||
                    body is RecordList
                ? body
                : Builder(
                    builder: (context) => Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.paddingOf(context).top,
                      ),
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        child: body!,
                      ),
                    ),
                  ),
            bottomNavigationBar: bottomNavigationBar,
            floatingActionButton: floatingActionButton,
          ),
        ],
      ),
    );
    if (bottomOverlay == null && backgroundProgress == null) return page;
    return ValueListenableBuilder<double>(
      valueListenable: backgroundProgress ?? const AlwaysStoppedAnimation(0),
      child: page,
      builder: (context, value, child) {
        final media = MediaQuery.of(context);
        final progress = value.clamp(0.0, 1.0);
        final inset = AppDesign.mediaBackdropInset * progress;
        final scale = 1 - inset * 2 / media.size.width;
        final keyboard = resizeToAvoidBottomInset
            ? media.viewInsets.bottom
            : 0.0;
        return ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform(
                key: const ValueKey('app.presentation.background'),
                transform: Matrix4.identity()
                  ..translateByDouble(
                    inset,
                    media.viewPadding.top * progress,
                    0,
                    1,
                  )
                  ..scaleByDouble(scale, scale, 1, 1),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppDesign.sheetCorner * progress,
                  ),
                  child: ExcludeSemantics(
                    excluding: progress > 0,
                    child: IgnorePointer(
                      ignoring: progress > 0,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          child!,
                          Positioned.fill(
                            bottom: bottomOverlayHeight + keyboard,
                            child: IgnorePointer(
                              child: ColoredBox(
                                color: Colors.black.withValues(
                                  alpha: AppDesign.mediaBackdropDim * progress,
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
              if (bottomOverlay != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: keyboard,
                  child: Material(
                    type: MaterialType.transparency,
                    child: bottomOverlay!,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
