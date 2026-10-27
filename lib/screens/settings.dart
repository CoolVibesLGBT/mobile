import '../l10n/l10n.dart';
import 'premium.dart';
import 'notifications.dart';
import 'legal.dart';
export 'legal.dart' show LegalScreen, LegalDetail;
export 'premium.dart' show PremiumScreen;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../design/app_design.dart';
import '../core/session.dart';
import '../core/app_failure.dart';
import '../components/components.dart';
import 'app_forms.dart';
import 'appearance.dart';
import '../core/appearance.dart';
import 'discover.dart';
import 'profile.dart';
import 'places.dart';
import 'classifieds.dart';
import 'uploads.dart';
import '../components/profile_header.dart';
import '../core/profile_data.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> edit(BuildContext context) =>
      open(context, AppForms.profile(context, AppScope.of(context).user));
  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    final username = profileUsername(user);
    final hasCover = profileCover(user) != null;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return AppScaffold(
      extendBodyBehindAppBar: true,
      appBar: ProfileHeader.navigationBar(
        controller: scrollController,
        hasCover: hasCover,
        actions: [
          AppButton.text(
            onPressed: () => edit(context),
            child: Text(context.l10n.edit),
          ),
        ],
      ),
      body: ListView(
        controller: scrollController,
        padding: EdgeInsets.only(
          top: hasCover ? 0 : topInset + AppDesign.headerHeight,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          AppPressable(
            label: '${personName(user)}, @$username',
            onPressed: () => open(context, const ProfileScreen()),
            child: IgnorePointer(
              child: ProfileHeader(
                user: user,
                coverTopInset: topInset,
                actions: const [],
                subtitle: username.isEmpty ? '' : '@$username',
                topInset: 8,
                bottomInset: 24,
              ),
            ),
          ),
          AppSection(
            children: [
              row(
                context,
                Icons.account_circle,
                context.l10n.viewProfile,
                const ProfileScreen(),
                color: const Color(0xffff3b30),
                symbol: 'person.crop.circle.fill',
              ),
              row(
                context,
                Icons.star,
                'Premium',
                const PremiumScreen(),
                color: const Color(0xffaf52de),
                symbol: 'star.fill',
              ),
            ],
          ),
          AppSection(
            title: context.l10n.menuCommunity,
            children: [
              row(
                context,
                Icons.place,
                context.l10n.places2,
                const PlacesScreen(),
                color: const Color(0xff34c759),
                symbol: 'mappin.and.ellipse',
              ),
              row(
                context,
                Icons.work,
                context.l10n.classifieds,
                const ClassifiedsScreen(),
                color: const Color(0xffff9500),
                symbol: 'briefcase.fill',
              ),
              row(
                context,
                Icons.people,
                context.l10n.friends,
                const FriendsScreen(),
                color: const Color(0xff007aff),
                symbol: 'person.2.fill',
              ),
              row(
                context,
                Icons.favorite,
                context.l10n.matches,
                const MatchesScreen(),
                color: const Color(0xffff2d55),
                symbol: 'heart.fill',
              ),
            ],
          ),
          AppSection(
            title: context.l10n.menuAccount,
            children: [
              row(
                context,
                Icons.cloud_upload,
                context.l10n.uploads,
                const UploadsScreen(),
                color: const Color(0xff007aff),
                symbol: 'arrow.up.circle.fill',
              ),
              row(
                context,
                Icons.lock,
                context.l10n.photoAccessRequests,
                const ActivityScreen(accessRequests: true),
                color: const Color(0xff34c759),
                symbol: 'lock.fill',
              ),
              row(
                context,
                Icons.settings,
                context.l10n.settings,
                const SettingsScreen(),
                color: const Color(0xff8e8e93),
                symbol: 'gearshape.fill',
              ),
              row(
                context,
                Icons.back_hand,
                context.l10n.legal,
                const LegalScreen(),
                color: const Color(0xff5856d6),
                symbol: 'hand.raised.fill',
              ),
            ],
          ),
          if (kDebugMode)
            AppSection(
              children: [
                AppRow(
                  leading: const AppSettingIcon(
                    Icons.developer_mode,
                    color: Color(0xff8e8e93),
                  ),
                  title: const Text('Ekran kataloğu'),
                  onTap: () => Navigator.of(context).pushNamed('/debug'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget row(
    BuildContext context,
    IconData icon,
    String title,
    Widget page, {
    required Color color,
    required String symbol,
  }) => AppRow(
    leading: AppSettingIcon(icon, color: color, symbol: symbol),
    title: Text(title),
    onTap: () => open(context, page),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final languageMenu = GlobalKey<AppContextMenuState>();
  String? accountAction;
  bool submitting = false;

  Future<void> endAccountSession({required bool delete}) async {
    if (accountAction != null) return;
    final session = AppScope.of(context), l = context.l10n;
    setState(() => accountAction = delete ? 'delete' : 'logout');
    try {
      final confirmed = await confirmAction(
        context,
        title: delete ? l.deleteAccountTitle : l.logOut2,
        message: delete ? l.deleteAccountConfirmation : l.areYouSureYouWantTo,
        action: delete ? l.deleteAccount : l.logOut,
        destructive: delete,
      );
      if (!confirmed || !mounted) return;
      setState(() => submitting = true);
      if (delete) {
        await session.deleteAccount();
      } else {
        await session.logout();
      }
      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      }
    } catch (error) {
      if (mounted) {
        setState(() => submitting = false);
        await showErrorSheet(context, AppFailure.from(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          accountAction = null;
          submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return AppScaffold(
      appBar: AppHeader(title: Text(context.l10n.settings)),
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + AppDesign.headerHeight + 24,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          AppSection(
            children: [
              AppRow(
                leading: const AppSettingIcon(
                  Icons.palette,
                  color: Color(0xff2aa9f0),
                  symbol: 'paintbrush.fill',
                ),
                title: Text(context.l10n.appearance),
                value: themeLabels[session.appearanceModel.base]!(context.l10n),
                onTap: () => open(context, const AppearanceScreen()),
              ),
              AppContextMenu(
                key: languageMenu,
                pressTrigger: true,
                liftContent: false,
                align: AppMenuAlign.right,
                label: context.l10n.language,
                items: [
                  for (final (code, name) in [
                    ('tr', 'Türkçe'),
                    ('en', 'English'),
                    ('ar', 'العربية'),
                  ])
                    AppMenuItem(
                      title: name,
                      checked: session.locale.languageCode == code,
                      onPressed: () => session.language(Locale(code)),
                    ),
                ],
                child: AppRow(
                  leading: const AppSettingIcon(
                    Icons.language,
                    color: Color(0xffaf52de),
                    symbol: 'globe',
                  ),
                  title: Text(context.l10n.language),
                  value: const {
                    'tr': 'Türkçe',
                    'en': 'English',
                    'ar': 'العربية',
                  }[session.locale.languageCode],
                  onTap: () => languageMenu.currentState?.open(),
                ),
              ),
            ],
          ),
          AppSection(
            children: [
              AppRow(
                leading: const AppSettingIcon(
                  Icons.lock,
                  color: Color(0xff8e8e93),
                  symbol: 'lock.fill',
                ),
                title: Text(context.l10n.changePassword),
                onTap: () => sheet(context, AppForms.password(context)),
              ),
            ],
          ),
          AppSection(
            children: [
              AppRow(
                leading: const AppSettingIcon(
                  Icons.logout,
                  color: Color(0xffff9500),
                  symbol: 'rectangle.portrait.and.arrow.right',
                ),
                key: const ValueKey('settings.logout'),
                title: Text(context.l10n.logOut),
                destructive: true,
                disclosure: false,
                trailing: submitting && accountAction == 'logout'
                    ? const CircularProgressIndicator.adaptive()
                    : null,
                onTap: accountAction != null
                    ? null
                    : () => endAccountSession(delete: false),
              ),
              AppRow(
                key: const ValueKey('settings.deleteAccount'),
                leading: const AppSettingIcon(
                  Icons.person_remove_outlined,
                  color: Color(0xffff3b30),
                  symbol: 'person.crop.circle.badge.minus',
                ),
                title: Text(context.l10n.deleteAccount),
                destructive: true,
                disclosure: false,
                trailing: submitting && accountAction == 'delete'
                    ? const CircularProgressIndicator.adaptive()
                    : null,
                onTap: accountAction != null
                    ? null
                    : () => endAccountSession(delete: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ActivityScreen extends StatelessWidget {
  final bool accessRequests;
  const ActivityScreen({super.key, this.accessRequests = false});
  @override
  Widget build(BuildContext context) => !accessRequests
      ? const NotificationsScreen()
      : AppScaffold(
          appBar: AppHeader(title: Text(context.l10n.accessRequests)),
          body: RecordList(
            action: 'user.private_photos.access.requests',
            itemBuilder: (context, item, reload) => _PhotoAccessRow(
              key: ValueKey(item['request_id'] ?? recordId(item)),
              request: item,
              reload: reload,
            ),
          ),
        );
}

class _PhotoAccessRow extends StatefulWidget {
  final Json request;
  final VoidCallback reload;
  const _PhotoAccessRow({
    super.key,
    required this.request,
    required this.reload,
  });
  @override
  State<_PhotoAccessRow> createState() => _PhotoAccessRowState();
}

class _PhotoAccessRowState extends State<_PhotoAccessRow> {
  bool busy = false;
  Json get viewer => object(
    widget.request['viewer'] ??
        widget.request['requester'] ??
        widget.request['user'],
  );

  Future<void> decide(String decision) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await perform(context, () async {
        final session = AppScope.of(context);
        final revoke = decision == 'revoke';
        if (revoke &&
            !await confirmAction(
              context,
              title: context.l10n.profileRevokeAccess,
              message: personName(viewer),
              action: context.l10n.profileRevokeAccess,
            )) {
          return;
        }
        if (!mounted) return;
        await session.api.call(
          revoke
              ? 'user.private_photos.access.revoke'
              : 'user.private_photos.access.respond',
          body: revoke
              ? {'viewer_id': widget.request['viewer_id'] ?? recordId(viewer)}
              : {
                  'request_id':
                      widget.request['request_id'] ?? recordId(widget.request),
                  'decision': decision,
                },
        );
        if (!mounted) return;
        session.invalidateMedia();
        widget.reload();
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.request['status'];
    final approved = status == 'approved' || status == 'granted';
    return AppRow(
      leading: Avatar(viewer),
      title: Text(personName(viewer)),
      subtitle: Text(
        approved
            ? context.l10n.profileAccessApproved
            : status == 'pending'
            ? context.l10n.profileAccessPending
            : context.l10n.profileAccessDenied,
      ),
      onTap: () => open(context, ProfileScreen(user: viewer)),
      disclosure: false,
      trailing: busy
          ? const SizedBox.square(
              dimension: 44,
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'pending') ...[
                  AppIconButton(
                    tooltip: context.l10n.approve,
                    icon: const Icon(Icons.check),
                    onPressed: () => decide('approved'),
                  ),
                  AppIconButton(
                    tooltip: context.l10n.deny,
                    icon: const Icon(Icons.close),
                    onPressed: () => decide('denied'),
                  ),
                ],
                if (approved)
                  AppIconButton(
                    tooltip: context.l10n.profileRevokeAccess,
                    icon: const Icon(Icons.lock_outline),
                    onPressed: () => decide('revoke'),
                  ),
              ],
            ),
    );
  }
}

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(title: Text(context.l10n.friends)),
    body: RecordList(
      action: 'user.friend.fetch',
      params: const {'scope': 'friends'},
      itemBuilder: (context, user, _) => PersonTile(
        person: user,
        onTap: () => open(context, ProfileScreen(user: user)),
      ),
    ),
  );
}
