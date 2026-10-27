import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/profile_data.dart';
import '../design/app_design.dart';
import 'components.dart';

/// A peer header action: SF Symbol on a 56pt interactive glass circle.
typedef ProfileAction = ({
  String label,
  String symbol,
  IconData icon,
  VoidCallback? onPressed,
  bool destructive,
  bool busy,
});

/// FullProfileView peer header (Telegram PeerInfoHeaderNode): centred 100pt
/// avatar, 28pt medium title, 17pt status, and 56pt glass actions with a
/// 12pt label, 24pt apart.
class ProfileHeader extends StatelessWidget {
  final Json user;
  final List<ProfileAction> actions;
  final VoidCallback? onAvatarPressed;
  final String? subtitle;
  final bool showName, avatarBusy;
  final Widget? avatarFooter;
  final double topInset, bottomInset, coverTopInset;
  const ProfileHeader({
    super.key,
    required this.user,
    required this.actions,
    this.onAvatarPressed,
    this.subtitle,
    this.showName = true,
    this.avatarBusy = false,
    this.avatarFooter,
    this.topInset = AppDesign.profileTopInset,
    this.bottomInset = 16,
    this.coverTopInset = 0,
  });

  static PreferredSizeWidget navigationBar({
    required ScrollController controller,
    required bool hasCover,
    Widget? title,
    List<Widget>? actions,
    bool collapseTitle = true,
  }) => PreferredSize(
    preferredSize: const Size.fromHeight(AppDesign.headerHeight),
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final offset = controller.hasClients ? controller.offset : 0.0;
        final coverAmount = hasCover
            ? ((AppDesign.profileCoverHeight - offset) / AppDesign.headerHeight)
                  .clamp(0.0, 1.0)
            : 0.0;
        final titleStart = hasCover
            ? AppDesign.profileCoverHeight -
                  AppDesign.profileCoverOverlap +
                  AppDesign.profileAvatarDiameter +
                  AppDesign.profileIdentityGap -
                  AppDesign.headerHeight
            : AppDesign.profileAvatarDiameter;
        final opacity = !collapseTitle
            ? 1.0
            : ((offset - titleStart) /
                      (AppDesign.profileTitleSize + AppDesign.profileTopInset))
                  .clamp(0.0, 1.0);
        return AppHeader(
          edgeTint: hasCover
              ? Color.lerp(
                  Theme.of(context).scaffoldBackgroundColor,
                  AppDesign.profileCoverShade,
                  coverAmount,
                )
              : null,
          systemOverlayStyle: coverAmount > .5
              ? SystemUiOverlayStyle.light
              : null,
          title: title == null
              ? null
              : Opacity(
                  opacity: opacity,
                  child: ExcludeSemantics(
                    excluding: opacity < .5,
                    child: title,
                  ),
                ),
          actions: actions,
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final cover = profileCover(user);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final location = user['location'] is String
        ? string(user['location']).trim()
        : string(object(user['location'])['display']).trim();
    final online = [
      true,
      1,
      '1',
      'true',
    ].contains(user['is_online'] ?? user['online']);
    final status =
        subtitle ??
        [
          if (online) context.l10n.online2,
          if (location.isNotEmpty) location,
        ].join(' · ');
    final avatar = Container(
      key: const ValueKey('profile.avatar.surface'),
      decoration: BoxDecoration(shape: BoxShape.circle, color: palette.row),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: cover == null
            ? null
            : Border.all(
                color: palette.background,
                width: AppDesign.profileAvatarBorder,
              ),
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Avatar(user, radius: AppDesign.profileAvatarDiameter / 2),
            if (avatarBusy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x59000000),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              ),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        if (cover != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: AppDesign.profileCoverHeight + coverTopInset,
            child: AppImage(
              key: const ValueKey('profile.cover'),
              source: cover,
              fit: BoxFit.cover,
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            cover == null
                ? topInset
                : AppDesign.profileCoverHeight +
                      coverTopInset -
                      AppDesign.profileCoverOverlap,
            16,
            bottomInset,
          ),
          child: Column(
            children: [
              if (onAvatarPressed == null)
                Semantics(image: true, label: context.l10n.photo, child: avatar)
              else
                AppPressable(
                  label: context.l10n.photo,
                  onPressed: onAvatarPressed,
                  child: avatar,
                ),
              ?avatarFooter,
              if (showName) ...[
                const SizedBox(height: AppDesign.profileIdentityGap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        personName(user),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: AppDesign.font(
                          AppDesign.profileTitleSize,
                          weight: FontWeight.w500,
                          color: palette.text,
                        ),
                      ),
                    ),
                    if (profileFlag(user['is_verified'])) ...[
                      const SizedBox(width: 6),
                      AppSymbol.icon(
                        'checkmark.seal.fill',
                        size: 22,
                        color: palette.accent,
                        fallback: Icons.verified,
                      ),
                    ],
                  ],
                ),
              ],
              if (status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    status,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesign.font(
                      17,
                      color: online ? palette.accent : palette.secondaryLabel,
                    ),
                  ),
                ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppDesign.profileActionSpacing,
                  runSpacing: 16,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 64),
                        child: Column(
                          children: [
                            SizedBox.square(
                              dimension: AppDesign.profileActionDiameter,
                              child: AppIconButton(
                                glass: true,
                                dimension: AppDesign.profileActionDiameter,
                                symbolSize: 17,
                                tooltip: actions[i].label,
                                icon: actions[i].busy
                                    ? const SizedBox.square(
                                        dimension: 22,
                                        child:
                                            CircularProgressIndicator.adaptive(),
                                      )
                                    : AppSymbol.icon(
                                        actions[i].symbol,
                                        size: 24,
                                        fallback: actions[i].icon,
                                      ),
                                color: actions[i].destructive
                                    ? palette.destructive
                                    : palette.accent,
                                onPressed: actions[i].busy
                                    ? null
                                    : actions[i].onPressed,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              actions[i].label,
                              maxLines: 1,
                              style: AppDesign.font(
                                12 * scale,
                                color: actions[i].destructive
                                    ? palette.destructive
                                    : palette.text,
                              ),
                              textScaler: TextScaler.noScaling,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  final String label, value;
  final bool accent;
  const ProfileInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.accent = false,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final last = AppSection.position(context) ?? true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: palette.border,
                  width: 1 / MediaQuery.devicePixelRatioOf(context),
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppDesign.font(14, color: palette.secondaryLabel)),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: AppDesign.font(
              17,
              color: accent ? palette.accent : palette.text,
              height: 22 / 17,
            ),
          ),
        ],
      ),
    );
  }
}
