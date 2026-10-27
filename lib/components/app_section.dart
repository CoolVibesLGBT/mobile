import 'package:flutter/material.dart';
import '../design/app_design.dart';
import 'app_button.dart';

/// The one inset group (source NativeSection): 16pt margins, 24pt below, a
/// 13pt uppercase header 15pt in, 26pt corners on the row colour, a footer.
class AppSection extends StatelessWidget {
  /// Null outside a section; otherwise whether the row is the last one.
  static bool? position(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SectionSurface>()?.last;
  static bool contains(BuildContext context) => position(context) != null;
  final List<Widget> children;
  final String? title, footer;
  final double separatorInset;
  final EdgeInsetsGeometry margin;
  const AppSection({
    super.key,
    required this.children,
    this.title,
    this.footer,
    this.separatorInset = 16,
    this.margin = const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(15, 0, 15, 7),
              child: Semantics(
                header: true,
                child: Text(
                  locale.startsWith('tr')
                      ? title!.replaceAll('i', 'İ').toUpperCase()
                      : title!.toUpperCase(),
                  style: AppDesign.font(13, color: palette.secondaryLabel),
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesign.groupCorner),
            child: ColoredBox(
              color: palette.row,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++)
                    _SectionSurface(
                      last: i == children.length - 1,
                      child: children[i],
                    ),
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(15, 7, 15, 0),
              child: Text(
                footer!,
                style: AppDesign.font(
                  13,
                  color: palette.secondaryLabel,
                  height: 17 / 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionSurface extends InheritedWidget {
  final bool last;
  const _SectionSurface({required this.last, required super.child});
  @override
  bool updateShouldNotify(_SectionSurface oldWidget) => last != oldWidget.last;
}

/// Telegram settings tile: a white symbol on a 29pt rounded colour square.
class AppSettingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? symbol;
  const AppSettingIcon(
    this.icon, {
    super.key,
    required this.color,
    this.symbol,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: 29,
    height: 29,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(7),
    ),
    child: symbol == null
        ? Icon(icon, size: 18, color: Colors.white)
        : AppSymbol.icon(
            symbol!,
            size: 18,
            color: Colors.white,
            fallback: icon,
          ),
  );
}
