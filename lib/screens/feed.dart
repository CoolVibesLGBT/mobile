import '../components/article_content.dart';
import '../l10n/l10n.dart';
// Actions is the API-action-name registry; Flutter's own Actions
// (intent/shortcuts) widget isn't used in this file.
import 'package:flutter/material.dart' hide Actions;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../core/actions.dart';
import '../core/constants.dart';
import '../core/mobile_spring.dart';
import '../design/app_design.dart';
import '../components/brand_mark.dart';
import '../components/glass_surface.dart';
import '../components/illustrated_icon.dart';
import '../components/post_report_sheet.dart';
import '../components/post_tip_sheet.dart';
import 'discover.dart';
import 'settings.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../components/components.dart';
import '../components/workspace_menu.dart';
import 'profile.dart';
import 'composer.dart';
import 'media.dart';
import '../components/emoticon_view.dart';

const _postActionIconSize = 28.0;

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final listKey = GlobalKey<RecordListState>();
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(
      leading: const WorkspaceMenuButton(),
      title: const BrandMark(),
      actions: [
        AppIconButton(
          tooltip: context.l10n.search,
          icon: const Icon(Icons.search),
          onPressed: () => open(context, const SearchScreen()),
        ),
        AppIconButton(
          tooltip: context.l10n.activity,
          icon: const Icon(Icons.notifications_none),
          onPressed: () => open(context, const ActivityScreen()),
        ),
        AppIconButton(
          tooltip: context.l10n.createPost,
          icon: const Icon(Icons.add),
          onPressed: () async {
            final result = await sheet<bool>(context, const ComposerScreen());
            if (result == true) listKey.currentState?.reload();
          },
        ),
      ],
    ),
    body: RecordList(
      key: listKey,
      action: 'post.timeline',
      header: const StoryStrip(),
      itemBuilder: (context, post, reload) =>
          PostTile(post: post, reload: reload),
    ),
  );
}

/// Discover stories row: 66pt rings, 58pt thumbnails, 72pt items 16pt apart.
class StoryStrip extends StatelessWidget {
  const StoryStrip({super.key});
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget item({
      required Widget ring,
      required String name,
      required VoidCallback onTap,
    }) => AppPressable(
      label: name,
      style: AppPressStyle.touchable,
      onPressed: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            ring,
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppDesign.font(
                12,
                weight: FontWeight.w600,
                color: palette.text,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: dark ? const Color(0xff1a1a1a) : const Color(0xfff0f0f0),
            width: 1 / MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      height: 66 + 8 + MediaQuery.textScalerOf(context).scale(12) * 1.4 + 34,
      child: RemoteContent(
        action: 'user.fetch.stories',
        compact: true,
        builder: (context, response, reload) {
          final stories = RecordPage.parse(response).records;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              if (index == 0) {
                return item(
                  name: context.l10n.addStory,
                  onTap: () =>
                      sheet(context, const ComposerScreen(story: true)),
                  ring: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark
                          ? const Color(0xff1a1a1a)
                          : const Color(0xfff5f5f5),
                      border: Border.all(color: const Color(0x0d000000)),
                    ),
                    child: Icon(Icons.add, size: 24, color: palette.text),
                  ),
                );
              }
              final story = stories[index - 1];
              final user = object(story['user'] ?? story['author'] ?? story);
              final active =
                  story['is_viewed'] != true && story['viewed'] != true;
              return item(
                name: personName(user),
                onTap: () => MediaScreen.show(context, story),
                ring: Container(
                  width: 66,
                  height: 66,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 2,
                      color: active
                          ? palette.text
                          : (dark
                                ? const Color(0xff333333)
                                : const Color(0xffeeeeee)),
                    ),
                  ),
                  child: Avatar(user, radius: 29),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// The one post card (source components/PostCard.tsx).
class PostTile extends StatefulWidget {
  final Json post;
  final VoidCallback reload;
  final bool detail;
  // Purely behavioral, not a second renderer: a reply still gets the full
  // card (see the PostDetailScreen builder below), this only tells delete
  // whether to pop the thread (its own root was removed) or just reload
  // the list (one reply among others was removed).
  final bool isReply;
  const PostTile({
    super.key,
    required this.post,
    required this.reload,
    this.detail = false,
    this.isReply = false,
  });
  @override
  State<PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<PostTile> with TickerProviderStateMixin {
  // Post (web/src/features/post/Post.tsx updateEngagementStates): the only
  // source for the viewer's own like/dislike/banana/bookmark state is
  // engagements.engagement_details, each row an {engager_id, kind} the
  // viewer must filter for themselves — there's no top-level `liked` flag
  // on the post. Mirroring that read is what makes a post you've already
  // liked show as liked.
  late Json _counts = object(object(widget.post['engagements'])['counts']);
  late List _engagementDetails =
      object(widget.post['engagements'])['engagement_details'] is List
      ? object(widget.post['engagements'])['engagement_details'] as List
      : const [];
  late final Set<String> _selfIds = {
    string(AppScope.of(context).user['id']),
    string(AppScope.of(context).user['public_id']),
  }..removeWhere((id) => id.isEmpty);

  bool _engaged(Set<String> kinds) => _engagementDetails.any((raw) {
    final detail = object(raw);
    return _selfIds.contains(string(detail['engager_id'])) &&
        kinds.contains(string(detail['kind']));
  });

  late bool liked = _engaged(const {'like_given', 'like_received'});
  late int likes = _count(_counts, ['like_received_count']);
  late bool disliked = _engaged(const {'dislike_given', 'dislike_received'});
  late int dislikes = _count(_counts, ['dislike_received_count']);
  late bool bananaed = _engaged(const {'banana'});
  late int bananas = _count(_counts, ['banana_count', 'banana_received_count']);
  late bool bookmarked = _engaged(const {'bookmark'});
  late int bookmarks = _count(_counts, ['bookmark_count']);
  late int tips = _count(_counts, ['tip_count']);
  late int views = _count(_counts, ['view_count']);
  bool _viewCounted = false;
  late final AnimationController pop, dislikePop, bananaPop, bookmarkPop;
  @override
  void initState() {
    super.initState();
    pop = AnimationController.unbounded(vsync: this, value: 1);
    dislikePop = AnimationController.unbounded(vsync: this, value: 1);
    bananaPop = AnimationController.unbounded(vsync: this, value: 1);
    bookmarkPop = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void didUpdateWidget(covariant PostTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.post, widget.post)) return;
    if (recordId(oldWidget.post) != recordId(widget.post)) {
      _viewCounted = false;
    }
    final engagements = object(widget.post['engagements']);
    _counts = object(engagements['counts']);
    _engagementDetails = engagements['engagement_details'] is List
        ? engagements['engagement_details'] as List
        : const [];
    liked = _engaged(const {'like_given', 'like_received'});
    likes = _count(_counts, ['like_received_count']);
    disliked = _engaged(const {'dislike_given', 'dislike_received'});
    dislikes = _count(_counts, ['dislike_received_count']);
    bananaed = _engaged(const {'banana'});
    bananas = _count(_counts, ['banana_count', 'banana_received_count']);
    bookmarked = _engaged(const {'bookmark'});
    bookmarks = _count(_counts, ['bookmark_count']);
    tips = _count(_counts, ['tip_count']);
    views = _count(_counts, ['view_count']);
  }

  @override
  void dispose() {
    pop.dispose();
    dislikePop.dispose();
    bananaPop.dispose();
    bookmarkPop.dispose();
    super.dispose();
  }

  /// handleLike/handleDislike/handleBanana share this one bounce (spring
  /// 1.4 d4 k200, spring back to 1) — Telegram's reaction tap pop, applied
  /// to whichever control was actually pressed.
  Future<void> _bounce(AnimationController controller) async {
    if (MediaQuery.disableAnimationsOf(context)) return;
    await controller
        .animateWith(
          MobileSpring(controller.value, 1.4, 0, stiffness: 200, damping: 4),
        )
        .orCancel
        .catchError((_) {});
    if (mounted) {
      controller.animateWith(
        MobileSpring(controller.value, 1, controller.velocity),
      );
    }
  }

  static int _count(Json counts, List<String> keys) {
    for (final key in keys) {
      final value = num.tryParse(string(counts[key]));
      if (value != null) return value.toInt();
    }
    return 0;
  }

  void openDetail() {
    if (!widget.detail) open(context, PostDetailScreen(post: widget.post));
  }

  List<Json> _engagers(Set<String> kinds, {bool includeSelf = false}) {
    final people = <Json>[];
    final seen = <String>{};
    for (final raw in _engagementDetails) {
      final detail = object(raw);
      if (!kinds.contains(string(detail['kind']).toLowerCase())) continue;
      final person = object(
        detail['engager'] ?? detail['user'] ?? detail['initiator'],
      );
      final name = personName(person);
      if (name.isEmpty) continue;
      final id = string(
        person['public_id'] ?? person['id'] ?? detail['engager_id'],
      );
      final key = id.isEmpty ? name.toLowerCase() : id;
      if (_selfIds.contains(id) || !seen.add(key)) continue;
      people.add(person);
    }
    if (includeSelf) {
      final self = AppScope.of(context).user;
      final name = personName(self);
      final id = string(self['public_id'] ?? self['id']);
      final key = id.isEmpty ? name.toLowerCase() : id;
      if (name.isNotEmpty && seen.add(key)) {
        people.insert(0, Map<String, dynamic>.from(self));
      }
    }
    return people;
  }

  Future<void> _openEngagers(
    String title,
    Set<String> kinds, {
    bool includeSelf = false,
  }) async {
    await sheet(
      context,
      PostEngagementSheet(
        title: title,
        people: _engagers(kinds, includeSelf: includeSelf),
        onSelectUser: (user) {
          Navigator.of(context, rootNavigator: true).maybePop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) open(context, ProfileScreen(user: user));
          });
        },
      ),
    );
  }

  void openComments() {
    if (widget.detail) {
      sheet(context, ComposerScreen(replyTo: recordId(widget.post)));
    } else {
      openDetail();
    }
  }

  /// handleLike: optimistic toggle, withSequence(spring 1.4 d4 k200, spring 1),
  /// clearing a standing dislike the same way the web client does.
  Future<void> like() async {
    final next = !liked;
    final previousLikes = likes;
    final previousDisliked = disliked;
    final previousDislikes = dislikes;
    setState(() {
      liked = next;
      likes = (likes + (next ? 1 : -1)).clamp(0, 1 << 31);
      if (next && disliked) {
        disliked = false;
        dislikes = (dislikes - 1).clamp(0, 1 << 31);
      }
    });
    if (next) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    final api = AppScope.of(context).api;
    await _bounce(pop);
    try {
      await api.call(
        Actions.cmdPostLike,
        body: {'post_id': recordId(widget.post)},
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          liked = !next;
          likes = previousLikes;
          disliked = previousDisliked;
          dislikes = previousDislikes;
        });
      }
    }
  }

  /// handleDislike: same optimistic toggle as like(), mutually exclusive.
  Future<void> dislike() async {
    final next = !disliked;
    final previousLiked = liked;
    final previousLikes = likes;
    final previousDislikes = dislikes;
    setState(() {
      disliked = next;
      dislikes = (dislikes + (next ? 1 : -1)).clamp(0, 1 << 31);
      if (next && liked) {
        liked = false;
        likes = (likes - 1).clamp(0, 1 << 31);
      }
    });
    HapticFeedback.selectionClick();
    final dislikeApi = AppScope.of(context).api;
    await _bounce(dislikePop);
    try {
      await dislikeApi.call(
        Actions.cmdPostDislike,
        body: {'post_id': recordId(widget.post)},
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          disliked = !next;
          dislikes = previousDislikes;
          liked = previousLiked;
          likes = previousLikes;
        });
      }
    }
  }

  /// handleBanana: the third, branded reaction — same optimistic shape.
  Future<void> banana() async {
    final next = !bananaed;
    setState(() {
      bananaed = next;
      bananas = (bananas + (next ? 1 : -1)).clamp(0, 1 << 31);
    });
    HapticFeedback.selectionClick();
    final bananaApi = AppScope.of(context).api;
    await _bounce(bananaPop);
    try {
      await bananaApi.call(
        Actions.cmdPostBanana,
        body: {'post_id': recordId(widget.post)},
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          bananaed = !next;
          bananas = (bananas + (next ? -1 : 1)).clamp(0, 1 << 31);
        });
      }
    }
  }

  Future<void> bookmark() async {
    final next = !bookmarked;
    final previousCount = bookmarks;
    setState(() {
      bookmarked = next;
      bookmarks = (bookmarks + (next ? 1 : -1)).clamp(0, 1 << 31);
    });
    HapticFeedback.selectionClick();
    final bookmarkApi = AppScope.of(context).api;
    await _bounce(bookmarkPop);
    try {
      await bookmarkApi.call(
        Actions.cmdPostBookmark,
        body: {'post_id': recordId(widget.post)},
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          bookmarked = !next;
          bookmarks = previousCount;
        });
      }
    }
  }

  void share() {
    final box = context.findRenderObject() as RenderBox?;
    SharePlus.instance.share(
      ShareParams(
        uri: Uri.https(
          AppConstants.registrationDomain,
          '/status/${recordId(widget.post)}',
        ),
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> openReport() async {
    await sheet(context, PostReportSheet(post: widget.post));
  }

  /// Post (web/src/features/post/Post.tsx handleDeletePost): the author's
  /// own menu entry, gated on `user.id === post.author_id` — only ever
  /// shown and enabled for the post's own author, confirmed first since
  /// it's destructive and permanent.
  Future<void> deletePost() async {
    final confirmed = await confirmAction(
      context,
      title: context.l10n.deletePost,
      message: context.l10n.deletePostConfirmation,
      action: context.l10n.deleteLabel,
    );
    if (!confirmed || !mounted) return;
    await perform(context, () async {
      await AppScope.of(context).api.call(
        Actions.cmdPostDelete,
        body: {'post_id': recordId(widget.post)},
      );
      if (!mounted) return;
      if (widget.detail && !widget.isReply) {
        Navigator.of(context).maybePop();
      } else {
        widget.reload();
      }
    });
  }

  Future<void> openTip() async {
    await sheet(context, PostTipSheet(post: widget.post));
    if (mounted) widget.reload();
  }

  /// A dwell view, matching the web client's useDwellView: only counted once
  /// the card has actually sat mostly on screen for a moment, not on every
  /// frame it merely scrolls past.
  void onVisibilityChanged(VisibilityInfo info) {
    if (_viewCounted || info.visibleFraction < .6 || !mounted) return;
    _viewCounted = true;
    AppScope.of(context).api
        .call(Actions.cmdPostView, body: {'post_id': recordId(widget.post)})
        .then((result) {
          if (mounted && result['counted'] == true) {
            setState(() => views += 1);
          }
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final author = object(post['user'] ?? post['author']);
    final content = plainText(post['content'] ?? post['text']);
    final username = string(author['username'] ?? author['nickname']);
    final comments = _count(_counts, ['comment_count']);
    // A reply is a Post like any other (web's PostDetails renders every
    // reply through the same <Post>) — it gets the full card, including
    // working like/dislike/banana/comment actions, not a stripped preview.
    final emoticon = object(
      object(post['extras'])['emoticon'] ?? post['emoticon'],
    );
    final brand = dark ? const Color(0xffff77dc) : const Color(0xffa80080);
    final muted = dark ? const Color(0xff8e8e93) : const Color(0xff666666);
    // Like/dislike/banana are the core reactions and always ship. Only tip
    // (a money-adjacent feature) stays behind the rollout switch (Settings >
    // debug), along with the view counter, inline share and the bookmark
    // moving into this row; report is a fix to something already shipped, so
    // it's unconditional. While the switch is off, bookmark stays exactly
    // where it already was, in the overflow menu.
    final enhanced = AppScope.of(context).postEngagementActionsEnabled;
    final isOwnPost =
        _selfIds.contains(string(author['id'])) ||
        _selfIds.contains(string(author['public_id'])) ||
        _selfIds.contains(string(post['author_id']));
    final pinkActions = <AppMenuItem>[
      if (isOwnPost)
        AppMenuItem(
          title: context.l10n.deletePost,
          iconAsset:
              'assets/images/profile_icons/${IllustratedIcon.keyFor('x')}.avif',
          fallback: Icons.delete_outline,
          destructive: true,
          onPressed: deletePost,
        ),
      if (!enhanced)
        AppMenuItem(
          title: context.l10n.bookmark,
          iconAsset:
              'assets/images/profile_icons/${IllustratedIcon.keyFor('save')}.avif',
          fallback: Icons.bookmark_border,
          onPressed: bookmark,
        ),
      AppMenuItem(
        title: context.l10n.report,
        iconAsset:
            'assets/images/profile_icons/${IllustratedIcon.keyFor('report-harassment')}.avif',
        fallback: Icons.flag_outlined,
        destructive: true,
        onPressed: openReport,
      ),
    ];
    final card = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: dark ? const Color(0xff131313) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: dark ? const Color(0x1fffffff) : const Color(0x14131313),
                width: 1 / MediaQuery.devicePixelRatioOf(context),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: 40pt avatar, 17pt semibold name, 13pt @username.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => open(context, ProfileScreen(user: author)),
                      child: Avatar(author, radius: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => open(context, ProfileScreen(user: author)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    personName(author),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppDesign.font(
                                      17,
                                      weight: FontWeight.w600,
                                      color: palette.text,
                                    ).copyWith(letterSpacing: -.3),
                                  ),
                                ),
                                if (author['is_verified'] == true ||
                                    author['verified'] == true)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.verified,
                                      size: 18,
                                      color: brand,
                                    ),
                                  ),
                              ],
                            ),
                            if (username.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  '@$username',
                                  style: AppDesign.font(
                                    13,
                                    weight: FontWeight.w600,
                                    color: muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (enhanced) ...[
                      if (views > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Opacity(
                                opacity: .7,
                                child: IllustratedIcon(
                                  'eye',
                                  size: _postActionIconSize,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$views',
                                style: AppDesign.font(12, color: muted),
                              ),
                            ],
                          ),
                        ),
                      AppIconButton(
                        tooltip: context.l10n.share,
                        dimension: 44,
                        symbolSize: 18,
                        onPressed: share,
                        icon: const IllustratedIcon(
                          'report-cultural-insensitivity',
                          size: _postActionIconSize,
                        ),
                      ),
                    ],
                    AppContextMenu(
                      pressTrigger: true,
                      liftContent: false,
                      align: AppMenuAlign.right,
                      label: context.l10n.more,
                      items: pinkActions,
                      child: GlassSurface(
                        circular: true,
                        radius: 22,
                        interactive: true,
                        child: SizedBox.square(
                          dimension: 44,
                          child: Center(
                            child: IllustratedIcon(
                              'system-morehorizontal',
                              size: 42,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (content.isNotEmpty)
                GestureDetector(
                  onTap: openDetail,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ArticleContent(
                        content: post['content'] ?? post['text'],
                        style: AppDesign.font(
                          17,
                          color: palette.text,
                          height: 24 / 17,
                        ),
                      ),
                    ),
                  ),
                ),
              MediaAttachments(
                record: post,
                indicators: true,
                onTap: widget.detail ? null : openDetail,
              ),
              if (emoticon.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: EmoticonView(document: emoticon, size: 118),
                ),
              Builder(
                builder: (context) {
                  // Two full-width columns keep each action readable on phones
                  // while giving its count a separate, accessible tap target.
                  final actionTiles = <Widget>[
                    _PostActionTile(
                      label: context.l10n.like,
                      count: likes,
                      countLabel: context.l10n.postLikers,
                      icon: AnimatedBuilder(
                        animation: pop,
                        builder: (context, child) =>
                            Transform.scale(scale: pop.value, child: child),
                        child: Opacity(
                          opacity: liked ? 1 : .55,
                          child: const IllustratedIcon(
                            'thumbsup',
                            size: _postActionIconSize,
                          ),
                        ),
                      ),
                      color: brand,
                      selected: liked,
                      onPressed: like,
                      onCountPressed: () => _openEngagers(
                        context.l10n.postLikers,
                        const {'like', 'liked', 'like_given', 'like_received'},
                        includeSelf: liked,
                      ),
                    ),
                    _PostActionTile(
                      label: context.l10n.postDislikeAction,
                      count: dislikes,
                      countLabel: context.l10n.postDislikers,
                      icon: AnimatedBuilder(
                        animation: dislikePop,
                        builder: (context, child) => Transform.scale(
                          scale: dislikePop.value,
                          child: child,
                        ),
                        child: Opacity(
                          opacity: disliked ? 1 : .55,
                          child: const IllustratedIcon(
                            'thumbsdown',
                            size: _postActionIconSize,
                          ),
                        ),
                      ),
                      color: const Color(0xff8774e1),
                      selected: disliked,
                      onPressed: dislike,
                      onCountPressed: () =>
                          _openEngagers(context.l10n.postDislikers, const {
                            'dislike',
                            'disliked',
                            'dislike_given',
                            'dislike_received',
                          }, includeSelf: disliked),
                    ),
                    _PostActionTile(
                      label: context.l10n.banana,
                      count: bananas,
                      countLabel: context.l10n.postBananaReactors,
                      icon: AnimatedBuilder(
                        animation: bananaPop,
                        builder: (context, child) => Transform.scale(
                          scale: bananaPop.value,
                          child: child,
                        ),
                        child: Opacity(
                          opacity: bananaed ? 1 : .55,
                          child: const IllustratedIcon(
                            'lollipop',
                            size: _postActionIconSize,
                          ),
                        ),
                      ),
                      color: dark
                          ? const Color(0xffffbf17)
                          : const Color(0xff8a6200),
                      selected: bananaed,
                      onPressed: banana,
                      onCountPressed: () => _openEngagers(
                        context.l10n.postBananaReactors,
                        const {'banana'},
                        includeSelf: bananaed,
                      ),
                    ),
                    _PostActionTile(
                      label: context.l10n.comments,
                      count: comments,
                      countLabel: context.l10n.comments,
                      icon: const IllustratedIcon(
                        'nav-messages',
                        size: _postActionIconSize,
                      ),
                      color: palette.accent,
                      onPressed: openComments,
                      onCountPressed: openComments,
                    ),
                    if (enhanced) ...[
                      _PostActionTile(
                        label: context.l10n.tip,
                        count: tips,
                        countLabel: context.l10n.postTippers,
                        icon: const IllustratedIcon(
                          'black-lives-matter',
                          size: _postActionIconSize,
                        ),
                        color: const Color(0xffe10f0f),
                        onPressed: openTip,
                        onCountPressed: () => _openEngagers(
                          context.l10n.postTippers,
                          const {'tip', 'tip_received'},
                        ),
                      ),
                      _PostActionTile(
                        label: context.l10n.bookmark,
                        count: bookmarks,
                        countLabel: context.l10n.postBookmarkers,
                        icon: AnimatedBuilder(
                          animation: bookmarkPop,
                          builder: (context, child) => Transform.scale(
                            scale: bookmarkPop.value,
                            child: child,
                          ),
                          child: Opacity(
                            opacity: bookmarked ? 1 : .55,
                            child: const IllustratedIcon(
                              'save',
                              size: _postActionIconSize,
                            ),
                          ),
                        ),
                        color: const Color(0xffffbf17),
                        selected: bookmarked,
                        onPressed: bookmark,
                        onCountPressed: () => _openEngagers(
                          context.l10n.postBookmarkers,
                          const {'bookmark'},
                          includeSelf: bookmarked,
                        ),
                      ),
                    ],
                  ];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 8.0;
                        const columns = 2;
                        final itemWidth =
                            (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                        return Wrap(
                          alignment: WrapAlignment.center,
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (final tile in actionTiles)
                              SizedBox(width: itemWidth, child: tile),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relativeTime(context, post['created_at']),
                      style: AppDesign.font(
                        11,
                        color: dark
                            ? const Color(0xff48484a)
                            : const Color(0xff999999),
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
    if (!enhanced) return card;
    return VisibilityDetector(
      key: ValueKey('post.view.${recordId(post)}'),
      onVisibilityChanged: onVisibilityChanged,
      child: card,
    );
  }
}

/// One compact Liquid Glass action with a separate, tappable count. Tapping
/// the action changes the reaction; tapping its count opens the people list.
class _PostActionTile extends StatelessWidget {
  final String label;
  final String countLabel;
  final int count;
  final Widget icon;
  final Color color;
  final bool selected;
  final VoidCallback onPressed, onCountPressed;

  const _PostActionTile({
    required this.label,
    required this.countLabel,
    required this.count,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.onCountPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = selected ? color : palette.secondaryLabel;
    final tint = selected
        ? color.withValues(alpha: .12)
        : palette.text.withValues(alpha: dark ? .055 : .035);
    final countTint = selected
        ? color.withValues(alpha: .17)
        : palette.text.withValues(alpha: dark ? .13 : .075);
    return GlassSurface(
      radius: 18,
      tint: tint,
      interactive: true,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: AppPressable(
                label: label,
                selected: selected,
                style: AppPressStyle.glass,
                onPressed: onPressed,
                child: SizedBox.expand(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, right: 2),
                    child: Row(
                      children: [
                        IconTheme.merge(
                          data: IconThemeData(
                            color: foreground,
                            size: _postActionIconSize,
                          ),
                          child: icon,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppDesign.font(
                              13,
                              weight: FontWeight.w600,
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
              child: Semantics(
                button: true,
                label: '$count $countLabel',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCountPressed,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 3, right: 8),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: countTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count',
                          maxLines: 1,
                          softWrap: false,
                          style: AppDesign.font(
                            12,
                            weight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The post API already includes public engager profiles with each engagement
/// detail, so counts open the matching people list without another API call.
class PostEngagementSheet extends StatelessWidget {
  final String title;
  final List<Json> people;
  final ValueChanged<Json> onSelectUser;

  const PostEngagementSheet({
    super.key,
    required this.title,
    required this.people,
    required this.onSelectUser,
  });

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(title: Text(title)),
    body: people.isEmpty
        ? ScreenStatus(compact: true, title: context.l10n.noResults)
        : ListView.builder(
            padding: EdgeInsets.only(
              // Scroll views extend behind AppHeader. Scaffold consumes the
              // MediaQuery top padding here, so use the sheet's explicit
              // safe-area inset to keep the first avatar below the close
              // control.
              top: AppDesign.sheetHeaderInset + AppDesign.headerInset(context),
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: people.length,
            itemBuilder: (context, index) {
              final user = people[index];
              final name = personName(user);
              final username = string(user['username']);
              return AppPressable(
                label: name,
                style: AppPressStyle.row,
                onPressed: () => onSelectUser(user),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Avatar(user, radius: 23),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppDesign.font(
                                16,
                                weight: FontWeight.w600,
                                color: AppPalette.of(context).text,
                              ),
                            ),
                            if (username.isNotEmpty)
                              Text(
                                '@$username',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppDesign.font(
                                  13,
                                  color: AppPalette.of(context).secondaryLabel,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

/// helpers/classifieds formatRelativeTime: just now, min, hours, days, date.
String relativeTime(BuildContext context, dynamic value) {
  final date = DateTime.tryParse(string(value))?.toLocal();
  if (date == null) return '';
  final delta = DateTime.now().difference(date);
  if (delta.inMinutes < 1) return context.l10n.justNow;
  if (delta.inMinutes < 60) {
    return context.l10n.minAgo(delta.inMinutes);
  }
  if (delta.inHours < 24) {
    return context.l10n.hoursAgo(delta.inHours);
  }
  if (delta.inDays < 7) {
    return context.l10n.daysAgo(delta.inDays);
  }
  return MaterialLocalizations.of(context).formatShortDate(date);
}

class PostDetailScreen extends StatefulWidget {
  final Json post;
  const PostDetailScreen({super.key, required this.post});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final remote = GlobalKey<RemoteContentState>();
  Json get post => widget.post;
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(title: Text(context.l10n.post)),
    body: Column(
      children: [
        Expanded(
          child: RemoteContent(
            key: remote,
            action: 'post.fetch',
            params: {'post_id': recordId(post)},
            builder: (context, response, reload) {
              final data = object(response['data']);
              final record = object(data['post'] ?? data);
              final replies = data['replies'] is List
                  ? (data['replies'] as List).map(object).toList()
                  : <Json>[];
              final children = record['children'] is List
                  ? (record['children'] as List).map(object).toList()
                  : replies;
              return ListView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                // AppScaffold only gives a non-ScrollView body the bare
                // safe-area inset (and strips it from this subtree's own
                // MediaQuery), not the header's own height — without this,
                // the list started under the status bar and scrolled up
                // through the floating blurred header instead of below it.
                padding: EdgeInsets.only(
                  top: AppDesign.headerInset(context),
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: children.isEmpty ? 3 : children.length + 2,
                itemBuilder: (_, i) => i == 1
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          context.l10n.comments2(children.length),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : children.isEmpty && i == 2
                    ? ScreenStatus(
                        compact: true,
                        title: context.l10n.noCommentsYet,
                      )
                    : PostTile(
                        post: i == 0 ? record : children[i - 2],
                        detail: true,
                        isReply: i > 1,
                        reload: reload,
                      ),
              );
            },
          ),
        ),
        ComposerScreen(
          key: ValueKey('comment-${recordId(post)}'),
          replyTo: recordId(post),
          inline: true,
          onSubmitted: () => remote.currentState?.load(),
        ),
      ],
    ),
  );
}
