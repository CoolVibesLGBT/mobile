import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
export '../core/api.dart' show recordId;
import '../design/app_design.dart';
import 'glass_surface.dart';
import 'screen_status.dart';
import '../vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;

/// Workspace pages push on the root stack above the tabs (NativeWorkspace
/// Stack), so the tab bar leaves with the iOS push transition — the same
/// transition and edge-swipe back on every platform.
Future<T?> open<T>(BuildContext context, Widget page) => Navigator.of(
  context,
  rootNavigator: true,
).push<T>(CupertinoPageRoute<T>(builder: (_) => page));

/// `presentation: 'modal'` / page sheets on the vendored Liquid Glass modal
/// sheet: it opens full height, drags down to half and away, and rounds its
/// corners at Telegram's 38pt glass-modal radius on every platform.
Future<T?> sheet<T>(
  BuildContext context,
  Widget page, {
  double halfSize = .45,
  double? fullSize,
  liquid.GlassSheetState initialState = liquid.GlassSheetState.full,
  Color barrierColor = liquid.GlassDefaults.barrierColor,
  Color? tint,
}) => liquid.GlassModalSheet.show<T>(
  context: context,
  useRootNavigator: true,
  halfSize: halfSize,
  fullSize: fullSize,
  barrierColor: barrierColor,
  settings: sheetGlass(context, tint: tint),
  fullSettings: sheetGlass(context, tint: tint),
  fullStateContentSettings: sheetGlass(context, tint: tint),
  quality: liquid.GlassQuality.minimal,
  expandedColor: tint ?? AppDesign.glassSheetLight,
  expandedDarkColor: tint ?? AppDesign.glassFrostedDark,
  initialState: initialState,
  topBorderRadius: AppDesign.sheetCorner,
  fullTopBorderRadius: AppDesign.sheetCorner,
  builder: (context) => _SheetViewport(child: page),
);

/// At the full detent the glass sheet sinks `safe area + corner radius`
/// below the screen to hide its bottom corners (Telegram's modal does the
/// same). The page is laid out on the visible part only, so anything it pins
/// to its bottom edge (send buttons, search inputs, keyboard insets) stays
/// on screen, and it still receives the home-indicator inset itself.
class _SheetViewport extends StatelessWidget {
  final Widget child;
  const _SheetViewport({required this.child});
  @override
  Widget build(BuildContext context) {
    final submerged =
        liquid.GlassModalSheetStateProvider.of(context)?.submergedBottom ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: submerged),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: MediaQuery.paddingOf(
            context,
          ).copyWith(top: AppDesign.sheetHeaderInset),
          viewPadding: MediaQuery.viewPaddingOf(context).copyWith(top: 0),
        ),
        child: child,
      ),
    );
  }
}

Future<void> perform(BuildContext context, Future<void> Function() task) async {
  try {
    await task();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

String personName(Json user) => string(
  user['displayname'] ?? user['name'] ?? user['nickname'] ?? user['username'],
);

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = true,
}) async =>
    await showInfoSheet<bool>(
      context,
      AppConfirmationSheet(
        title: title,
        message: message,
        actions: [
          AppConfirmationAction(
            label: action,
            result: true,
            destructive: destructive,
          ),
        ],
      ),
    ) ??
    false;
