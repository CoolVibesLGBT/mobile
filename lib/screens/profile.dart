import '../components/profile_photo_editor.dart';
import 'package:dio/dio.dart';
import '../l10n/l10n.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:intl/intl.dart';
import '../core/profile_data.dart';
import '../design/app_design.dart';
import '../core/realtime.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../components/components.dart';
import 'app_forms.dart';
import 'feed.dart';
import 'chat.dart';
import 'media.dart';

import '../core/chat_data.dart';
import '../components/profile_header.dart';
import '../components/profile_about.dart';
import '../components/profile_stats.dart';
import 'profile_metric.dart';
import 'settings.dart';
import 'profile_album.dart';
export 'profile_album.dart';

class ProfileScreen extends StatefulWidget {
  final Json? user;
  final String initialTab;
  const ProfileScreen({super.key, this.user, this.initialTab = 'about'});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const panes = ['about', 'posts', 'media', 'likes'];
  Json? profile;
  StreamSubscription<RealtimeEvent>? liveEvents;
  Timer? refreshTimer;
  CancelToken? requestToken;
  int loadGeneration = 0;
  String? error;
  bool loading = true;
  final pending = <String>{};
  final outerScroll = ScrollController();
  late final TabController tabs;
  final postKey = GlobalKey<RecordListState>();
  final likesKey = GlobalKey<RecordListState>();
  final albumKey = GlobalKey<AlbumScreenState>();

  bool get own =>
      widget.user == null ||
      profileBelongsTo(widget.user!, AppScope.of(context).user);
  Json get user => own
      ? profileUser(AppScope.of(context).user)
      : profile ?? profileUser(widget.user);

  @override
  void initState() {
    super.initState();
    tabs =
        TabController(
          length: panes.length,
          vsync: this,
          initialIndex: math.max(0, panes.indexOf(widget.initialTab)),
        )..addListener(() {
          if (mounted) setState(() {});
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      liveEvents = AppScope.of(context).realtime.events.listen((event) {
        if (!event.affects('user.fetch_profile')) return;
        refreshTimer?.cancel();
        refreshTimer = Timer(const Duration(milliseconds: 180), () {
          if (mounted) load();
        });
      });
      load();
    });
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user &&
        !profileBelongsTo(
          profileUser(oldWidget.user),
          profileUser(widget.user),
        )) {
      profile = null;
      loadGeneration++;
      error = null;
      loading = true;
      requestToken?.cancel();
      tabs.index = math.max(0, panes.indexOf(widget.initialTab));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  Future<void> load() async {
    if (!mounted) return;
    final request = ++loadGeneration;
    requestToken?.cancel();
    final token = requestToken = CancelToken();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final session = AppScope.of(context);
      Json fetched;
      if (own) {
        await session.refreshUser();
        fetched = profileUser(session.user);
      } else {
        final name = profileUsername(profileUser(widget.user));
        if (name.isEmpty) {
          throw ApiException(context.l10n.profileUsernameIsMissing);
        }
        final response = await session.api.call(
          'user.fetch_profile',
          body: {'nickname': name},
          cancelToken: token,
        );
        fetched = profileUser(response['data'] ?? response);
      }
      if (!mounted || request != loadGeneration) return;
      if (fetched.isEmpty) throw ApiException(context.l10n.profileUnavailable);
      if (mounted && request == loadGeneration) {
        setState(() => profile = fetched);
      }
    } catch (e) {
      if (mounted &&
          request == loadGeneration &&
          !(e is DioException && CancelToken.isCancel(e))) {
        setState(() {
          error = '$e';
          if (e is ApiException && [400, 401, 403, 404].contains(e.status)) {
            profile = null;
          }
        });
      }
    } finally {
      if (mounted && request == loadGeneration) setState(() => loading = false);
    }
  }

  Future<void> refresh() async {
    await Future.wait([
      load(),
      if (postKey.currentState != null) postKey.currentState!.reload(),
      if (likesKey.currentState != null) likesKey.currentState!.reload(),
      if (albumKey.currentState != null) albumKey.currentState!.reload(),
    ]);
  }

  void selectTab(String next) {
    final index = panes.indexOf(next);
    if (index < 0 || index == tabs.index) return;
    tabs.animateTo(
      index,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDesign.mediaExpansionDuration,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> action(String name, Future<void> Function() work) async {
    if (pending.contains(name)) return;
    setState(() => pending.add(name));
    try {
      await perform(context, work);
    } finally {
      if (mounted) setState(() => pending.remove(name));
    }
  }

  Future<void> edit(Json user) => action('edit', () async {
    await open(context, AppForms.profile(context, user));
    if (mounted) await load();
  });

  Future<void> message(Json user) => action('message', () async {
    final chat = await createConversation(AppScope.of(context).api, [
      string(user['id'] ?? user['public_id']),
    ]);
    if (mounted) await open(context, ChatScreen(chat: {...chat, 'peer': user}));
  });

  Future<void> follow(Json user) => action('follow', () async {
    final response = await AppScope.of(
      context,
    ).api.call('user.follow.toggle', body: {'followee_id': recordId(user)});
    final status = object(response['data'])['status'];
    if (!mounted) return;
    if (status is bool) {
      setState(() => profile = {...user, 'is_following': status});
    }
    await load();
  });

  Future<void> block(Json user) => action('block', () async {
    final blocked = profileBlocked(user);
    if (!await confirmAction(
      context,
      action: blocked ? context.l10n.profileUnblock : context.l10n.block,
      title: blocked ? context.l10n.profileUnblock : context.l10n.block,
      message: personName(user),
    )) {
      return;
    }
    if (!mounted) return;
    await AppScope.of(
      context,
    ).api.call('user.block.toggle', body: {'blocked_id': recordId(user)});
    if (!mounted) return;
    AppScope.of(context).invalidateMedia();
    if (blocked) {
      await load();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        profile = null;
        error = context.l10n.profileUnavailable;
      });
    }
  });

  Future<void> uploadAvatar() => action('avatar', () async {
    final changed = await editProfilePhoto(context, ProfilePhotoKind.avatar);
    if (changed == true && mounted) await load();
  });

  ProfileAction button(
    String name,
    String label,
    String symbol,
    IconData icon,
    VoidCallback onPressed, {
    bool destructive = false,
  }) => (
    label: label,
    symbol: symbol,
    icon: icon,
    destructive: destructive,
    busy: pending.contains(name),
    onPressed: pending.contains(name) ? null : onPressed,
  );

  Widget profileContent(Json user) {
    final username = profileUsername(user);
    final bio = plainText(
      user['bio'],
      language: Localizations.localeOf(context).languageCode,
    ).replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final joined = DateTime.tryParse(string(user['created_at']));
    final following = profileFollowing(user), blocked = profileBlocked(user);
    final avatar = user['avatar'] ?? user['avatar_url'];
    return Column(
      children: [
        ProfileHeader(
          key: const ValueKey('profile.identity'),
          user: user,
          coverTopInset: MediaQuery.viewPaddingOf(context).top,
          onAvatarPressed: assetUrl(avatar).isEmpty
              ? null
              : () => MediaScreen.show(context, {
                  'media': [
                    avatar is Map ? avatar : {'url': avatar},
                  ],
                }),
          actions: own
              ? [
                  button(
                    'edit',
                    context.l10n.edit,
                    'pencil',
                    Icons.edit_outlined,
                    () => edit(user),
                  ),
                  button(
                    'premium',
                    'Premium',
                    'star.fill',
                    Icons.star,
                    () => open(context, const PremiumScreen()),
                  ),
                ]
              : [
                  button(
                    'message',
                    context.l10n.message,
                    'bubble.left.fill',
                    Icons.chat_bubble,
                    () => message(user),
                  ),
                  button(
                    'follow',
                    following
                        ? context.l10n.profileFollowing
                        : context.l10n.profileFollow,
                    following ? 'person.fill.checkmark' : 'person.badge.plus',
                    following ? Icons.person : Icons.person_add_outlined,
                    () => follow(user),
                  ),
                  button(
                    'block',
                    blocked ? context.l10n.profileUnblock : context.l10n.block,
                    blocked ? 'hand.raised.slash.fill' : 'hand.raised.fill',
                    Icons.back_hand,
                    () => block(user),
                    destructive: !blocked,
                  ),
                ],
        ),
        if (username.isNotEmpty || bio.isNotEmpty || joined != null)
          AppSection(
            children: [
              if (username.isNotEmpty)
                ProfileInfoRow(
                  label: context.l10n.username,
                  value: '@$username',
                  accent: true,
                ),
              if (bio.isNotEmpty)
                ProfileInfoRow(label: context.l10n.bio, value: bio),
              if (joined != null)
                ProfileInfoRow(
                  label: context.l10n.profileJoined,
                  value: DateFormat.yMMMM(
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(joined),
                ),
            ],
          ),
        ProfileStats(
          user: user,
          onSelected: (metric) {
            if (metric.kind == 'posts') {
              selectTab('posts');
            } else {
              open(context, ProfileMetricScreen(user: user, metric: metric));
            }
          },
        ),
        if (error != null)
          ScreenStatus(error: error, retry: () => load(), compact: true),
      ],
    );
  }

  Widget pane(String pane, Json user) {
    if (pane == 'about') {
      return CustomScrollView(
        primary: true,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: ProfileAbout(user: user, includeIdentity: false),
          ),
          if (own)
            SliverToBoxAdapter(
              child: AppSection(
                children: [
                  AppRow(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text(context.l10n.changeAvatar),
                    onTap: pending.contains('avatar') ? null : uploadAvatar,
                  ),
                ],
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
          ),
        ],
      );
    }
    if (pane == 'media') {
      return AlbumScreen(
        key: albumKey,
        ownerId: own ? null : recordId(user),
        embedded: true,
        includePublic: true,
        primary: true,
      );
    }
    if (!canViewProfileActivity(
      user,
      own: own,
      authenticated: AppScope.of(context).api.token != null,
    )) {
      return CustomScrollView(
        primary: true,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ScreenStatus(
              title: context.l10n.profileActivityPrivate,
              animation: 'error',
            ),
          ),
        ],
      );
    }
    return RecordList(
      key: pane == 'posts' ? postKey : likesKey,
      primary: true,
      action: pane == 'likes' ? 'user.fetch.posts.likes' : 'user.fetch.posts',
      params: {'user_id': recordId(user)},
      clearOnError: true,
      itemBuilder: (_, post, reload) => PostTile(post: post, reload: reload),
    );
  }

  @override
  void dispose() {
    requestToken?.cancel();
    tabs.dispose();
    outerScroll.dispose();
    liveEvents?.cancel();
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileUser = user;
    final showContent =
        profile != null || (own && error == null && profileUser.isNotEmpty);
    final hasCover = showContent && profileCover(profileUser) != null;
    final pinnedTop =
        AppDesign.headerHeight +
        (hasCover ? MediaQuery.viewPaddingOf(context).top : 0.0);
    return AppScaffold(
      extendBodyBehindAppBar: true,
      appBar: ProfileHeader.navigationBar(
        controller: outerScroll,
        hasCover: hasCover,
        collapseTitle: showContent,
        title: Text(
          own ? context.l10n.profile : personName(profileUser),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: !showContent
          ? Center(
              child: ScreenStatus(loading: loading, error: error, retry: load),
            )
          : MediaQuery(
              data: MediaQuery.of(context),
              child: SafeArea(
                top: !hasCover,
                bottom: false,
                child: NestedScrollView(
                  key: ValueKey('profile.${recordId(profileUser)}'),
                  controller: outerScroll,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  headerSliverBuilder: (context, innerScrolled) => [
                    CupertinoSliverRefreshControl(onRefresh: refresh),
                    SliverToBoxAdapter(child: profileContent(profileUser)),
                  ],
                  body: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: ListenableBuilder(
                      listenable: outerScroll,
                      builder: (context, _) {
                        final remaining =
                            outerScroll.hasClients &&
                                outerScroll.position.hasContentDimensions
                            ? outerScroll.position.maxScrollExtent -
                                  outerScroll.offset
                            : double.infinity;
                        final top = (pinnedTop - remaining).clamp(
                          0.0,
                          pinnedTop,
                        );
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            // A nested body can have zero height while its header
                            // is outside the viewport, including during overscroll.
                            final minimum =
                                top +
                                14 +
                                AppDesign.mediaTabsHeight +
                                MediaQuery.textScalerOf(context).scale(15) -
                                15;
                            final height = math.max(
                              minimum,
                              constraints.maxHeight,
                            );
                            return ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                minHeight: height,
                                maxHeight: height,
                                child: Padding(
                                  padding: EdgeInsets.only(top: top),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          2,
                                          12,
                                          8,
                                        ),
                                        child: AppSegments<String>(
                                          key: const ValueKey('profile.tabs'),
                                          contentSized: true,
                                          fontSize: 15,
                                          values: {
                                            'about': Text(context.l10n.about),
                                            'posts': Text(context.l10n.posts),
                                            'media': Text(context.l10n.media),
                                            'likes': Text(context.l10n.likes),
                                          },
                                          selected: panes[tabs.index],
                                          onChanged: selectTab,
                                        ),
                                      ),
                                      Expanded(
                                        child: TabBarView(
                                          controller: tabs,
                                          children: [
                                            for (
                                              var i = 0;
                                              i < panes.length;
                                              i++
                                            )
                                              _ProfilePane(
                                                key: ValueKey(panes[i]),
                                                child: TickerMode(
                                                  enabled: tabs.index == i,
                                                  child: pane(
                                                    panes[i],
                                                    profileUser,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProfilePane extends StatefulWidget {
  final Widget child;
  const _ProfilePane({super.key, required this.child});
  @override
  State<_ProfilePane> createState() => _ProfilePaneState();
}

class _ProfilePaneState extends State<_ProfilePane>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
