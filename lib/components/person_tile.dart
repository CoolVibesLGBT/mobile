import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'app_button.dart';
import '../core/api.dart';
import 'app_row.dart';
import '../design/app_design.dart';
import 'app_context_menu.dart';
import 'avatar.dart';
import 'app_pressable.dart';
import 'glass_surface.dart';
import 'navigation.dart';

/// One person component: source NativePersonCell grid/list/selection variants.
class PersonTile extends StatelessWidget {
  final Json person;
  final VoidCallback? onTap, onChat, onLike, onDislike;
  final String? subtitle;
  final Widget? trailing;
  final bool? selected;
  final ValueChanged<bool?>? onSelected;
  final bool grid;
  const PersonTile({
    super.key,
    required this.person,
    this.onTap,
    this.onChat,
    this.onLike,
    this.onDislike,
    this.subtitle,
    this.trailing,
    this.selected,
    this.onSelected,
    this.grid = false,
  });
  @override
  Widget build(BuildContext context) {
    final user = userRecord(person);
    final online = user['online'] == true || user['is_online'] == true;
    final detail = [
      if (online)
        context.l10n.online
      else if (!grid && string(user['username']).isNotEmpty)
        '@${user['username']}',
      if (subtitle?.isNotEmpty ?? false) subtitle!,
    ].join(' · ');
    final name =
        '${personName(user)}${user['age'] is num ? ', ${user['age']}' : ''}';
    if (selected != null) {
      return AppChoiceRow(
        secondary: Avatar(user, radius: 20),
        title: Text(name),
        subtitle: detail.isEmpty ? null : Text(detail),
        value: selected,
        onChanged: onSelected,
      );
    }
    if (grid) {
      final cell = GlassSurface(
        radius: 12,
        child: AppPressable(
          label: [name, detail].join(', '),
          style: AppPressStyle.glass,
          onPressed: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, box) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Avatar(
                      user,
                      radius: box.maxWidth / 2,
                      glass: false,
                      rounded: true,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          height: 18 / 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      if (onChat == null && onLike == null && onDislike == null) return cell;
      return AppContextMenu(
        label: [name, detail].join(', '),
        previewRadius: 12,
        onPressed: onTap,
        items: _actions(context),
        child: cell,
      );
    }
    if (onLike != null || onChat != null) return _row(context, user, name);
    return AppRow(
      leading: Avatar(user, radius: 20),
      title: Text(name),
      subtitle: detail.isEmpty ? null : Text(detail),
      trailing:
          trailing ??
          ((onLike != null || onChat != null)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onLike != null)
                      AppIconButton(
                        tooltip: '${context.l10n.like}, $name',
                        icon: const Icon(Icons.favorite_border, size: 20),
                        onPressed: onLike,
                      ),
                    if (onChat != null)
                      AppIconButton(
                        tooltip: '${context.l10n.chat}, $name',
                        icon: const Icon(Icons.chat_bubble_outline, size: 20),
                        onPressed: onChat,
                      ),
                  ],
                )
              : null),
      onTap: onTap,
    );
  }

  /// NativePersonCell actions: Profile, Chat, Like, Dislike (destructive).
  List<AppMenuItem> _actions(BuildContext context) => [
    if (onTap != null)
      AppMenuItem(
        title: context.l10n.profile,
        symbol: 'person.crop.circle',
        onPressed: onTap!,
      ),
    if (onChat != null)
      AppMenuItem(
        title: context.l10n.chat,
        symbol: 'bubble.left',
        onPressed: onChat!,
      ),
    if (onLike != null)
      AppMenuItem(
        title: context.l10n.like,
        symbol: 'heart',
        onPressed: onLike!,
      ),
    if (onDislike != null)
      AppMenuItem(
        title: context.l10n.dislike,
        symbol: 'hand.thumbsdown',
        destructive: true,
        onPressed: onDislike!,
      ),
  ];

  /// NativePersonCell `list`: a 68pt row, 40pt avatar 16pt in, 17pt medium
  /// name over Online (accent) or @username and the distance at 15pt, then a
  /// grey heart and an accent chat circle (36pt in 44pt targets) and a
  /// hairline inset 68pt.
  Widget _row(BuildContext context, Json user, String name) {
    final palette = AppPalette.of(context);
    final online = user['online'] == true || user['is_online'] == true;
    final secondary = AppDesign.font(15, color: palette.secondaryLabel);
    Widget action(
      String label,
      IconData icon,
      Color fill,
      Color glyph,
      VoidCallback? onPressed,
    ) => onPressed == null
        ? const SizedBox.shrink()
        : AppPressable(
            label: '$label, ${personName(user)}',
            style: AppPressStyle.opacity,
            onPressed: onPressed,
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: glyph),
                ),
              ),
            ),
          );
    return ColoredBox(
      color: palette.row,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Row(
              children: [
                Expanded(
                  child: AppContextMenu(
                    label: name,
                    previewRadius: 12,
                    onPressed: onTap,
                    items: _actions(context),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        12,
                        0,
                        12,
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Avatar(user, radius: 20),
                              if (online)
                                PositionedDirectional(
                                  end: -1,
                                  bottom: -1,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff34c759),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: palette.row,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppDesign.font(
                                    17,
                                    weight: FontWeight.w500,
                                    color: palette.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (online)
                                      Text(
                                        context.l10n.online,
                                        style: AppDesign.font(
                                          15,
                                          color: palette.accent,
                                        ),
                                      )
                                    else if (string(
                                      user['username'],
                                    ).isNotEmpty)
                                      Text(
                                        '@${string(user['username']).replaceFirst('@', '')}',
                                        style: secondary,
                                      ),
                                    if (subtitle?.isNotEmpty ?? false)
                                      Text(subtitle!, style: secondary),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      action(
                        context.l10n.like,
                        CupertinoIcons.heart,
                        palette.input,
                        palette.secondaryLabel,
                        onLike,
                      ),
                      const SizedBox(width: 2),
                      action(
                        context.l10n.chat,
                        CupertinoIcons.chat_bubble_2_fill,
                        palette.accent,
                        Colors.white,
                        onChat,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 68),
            child: Container(
              height: 1 / MediaQuery.devicePixelRatioOf(context),
              color: palette.border,
            ),
          ),
        ],
      ),
    );
  }
}
