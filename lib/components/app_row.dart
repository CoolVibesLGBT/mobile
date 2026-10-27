import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_design.dart';
import 'app_button.dart';
import 'app_pressable.dart';
import 'app_section.dart';

/// The one list row (source NativeRow, Telegram ItemListUI): 44pt minimum,
/// 16pt sides, 11pt vertical padding, 14pt gaps, 17pt title, 13pt subtitle,
/// 15pt value, a 14pt disclosure chevron and the itemHighlighted fill.
class AppRow extends StatelessWidget {
  final Widget? leading, title, subtitle, trailing;
  final String? value;
  final double leadingGap;
  final double? minHeight;
  final VoidCallback? onTap, onLongPress;
  final EdgeInsetsGeometry? contentPadding;
  final bool dense, destructive, disclosure;
  final bool? selected;
  const AppRow({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.value,
    this.leadingGap = 14,
    this.minHeight,
    this.onTap,
    this.onLongPress,
    this.contentPadding,
    this.dense = false,
    this.disclosure = true,
    this.destructive = false,
    this.selected,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final stacked = scale > 1.35;
    final section = AppSection.position(context);
    final actionable =
        disclosure && onTap != null && trailing == null && selected == null;
    final row = Container(
      constraints: BoxConstraints(
        minHeight: minHeight ?? (dense ? 36 : AppDesign.rowHeight),
      ),
      padding:
          contentPadding ??
          EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 6 : 11),
      child: Row(
        children: [
          if (leading != null) ...[
            // Icon tiles occupy 29pt; avatars keep their own size.
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 29),
              child: Center(widthFactor: 1, child: leading),
            ),
            SizedBox(width: leadingGap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  DefaultTextStyle.merge(
                    style: AppDesign.font(
                      17,
                      color: destructive ? palette.destructive : palette.text,
                    ),
                    child: title!,
                  ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: DefaultTextStyle.merge(
                      style: AppDesign.font(13, color: palette.secondaryLabel),
                      child: subtitle!,
                    ),
                  ),
                if (value != null && stacked)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      value!,
                      style: AppDesign.font(15, color: palette.secondaryLabel),
                    ),
                  ),
              ],
            ),
          ),
          if (value != null && !stacked)
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .4,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesign.font(15, color: palette.secondaryLabel),
                  ),
                ),
              ),
            ),
          if (trailing != null) ...[
            SizedBox(width: leadingGap),
            trailing!,
          ] else if (selected != null) ...[
            SizedBox(width: leadingGap),
            SizedBox(
              width: 20,
              child: selected!
                  ? Icon(Icons.check, size: 20, color: palette.accent)
                  : null,
            ),
          ] else if (actionable && !destructive) ...[
            SizedBox(width: leadingGap),
            AppSymbol.icon(
              rtl ? 'chevron.left' : 'chevron.right',
              size: 14,
              color: palette.disclosure,
              fallback: rtl ? Icons.chevron_left : Icons.chevron_right,
            ),
          ],
        ],
      ),
    );
    final separated = Stack(
      children: [
        row,
        if (section != null && !section)
          PositionedDirectional(
            start: leading != null ? 59 : 16,
            end: 0,
            bottom: 0,
            child: Container(
              height: 1 / MediaQuery.devicePixelRatioOf(context),
              color: palette.border,
            ),
          ),
      ],
    );
    final body = ColoredBox(
      color: section == null ? palette.row : Colors.transparent,
      child: separated,
    );
    return onTap == null && onLongPress == null
        ? body
        : AppPressable(
            label: '',
            style: AppPressStyle.row,
            onPressed: onTap,
            onLongPress: onLongPress,
            selected: false,
            child: body,
          );
  }
}

/// Shared switch row for boolean form values and preferences.
class AppChoiceRow extends StatelessWidget {
  final Widget title;
  final Widget? secondary, subtitle;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final EdgeInsetsGeometry? contentPadding;
  final Color? tileColor;
  const AppChoiceRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.secondary,
    this.subtitle,
    this.contentPadding,
    this.tileColor,
  });
  @override
  Widget build(BuildContext context) {
    void change(bool next) {
      HapticFeedback.selectionClick();
      onChanged?.call(next);
    }

    return MergeSemantics(
      child: AppRow(
        leading: secondary,
        title: title,
        subtitle: subtitle,
        contentPadding: contentPadding,
        onTap: onChanged == null ? null : () => change(!(value ?? false)),
        trailing: AppSwitch(
          value: value ?? false,
          onChanged: onChanged == null ? null : change,
        ),
      ),
    );
  }
}

class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const AppSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 51, minHeight: 44),
    child: CupertinoSwitch(
      value: value,
      activeTrackColor: AppPalette.of(context).accent,
      onChanged: onChanged,
    ),
  );
}
