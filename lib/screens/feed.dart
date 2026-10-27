import '../components/article_content.dart';
import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/mobile_spring.dart';
import '../design/app_design.dart';
import '../components/brand_mark.dart';
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
      title: const BrandMark(navigation: true),
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
  final bool detail, comment;
  const PostTile({
    super.key,
    required this.post,
    required this.reload,
    this.detail = false,
    this.comment = false,
  });
  @override
  State<PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<PostTile>
    with SingleTickerProviderStateMixin {
  late bool liked =
      widget.post['liked'] == true || widget.post['is_liked'] == true;
  late int likes =
      num.tryParse(
        string(
          widget.post['like_count'] ??
              widget.post['likes_count'] ??
              widget.post['likes'],
        ),
      )?.toInt() ??
      0;
  late final AnimationController pop;
  @override
  void initState() {
    super.initState();
    pop = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void dispose() {
    pop.dispose();
    super.dispose();
  }

  void openDetail() {
    if (!widget.detail) open(context, PostDetailScreen(post: widget.post));
  }

  /// handleLike: optimistic toggle, withSequence(spring 1.4 d4 k200, spring 1).
  Future<void> like() async {
    final next = !liked;
    setState(() {
      liked = next;
      likes = (likes + (next ? 1 : -1)).clamp(0, 1 << 31);
    });
    if (next) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    final api = AppScope.of(context).api;
    if (!MediaQuery.disableAnimationsOf(context)) {
      await pop
          .animateWith(
            MobileSpring(pop.value, 1.4, 0, stiffness: 200, damping: 4),
          )
          .orCancel
          .catchError((_) {});
      if (mounted) pop.animateWith(MobileSpring(pop.value, 1, pop.velocity));
    }
    try {
      await api.call('post.like', body: {'post_id': recordId(widget.post)});
    } catch (_) {
      if (mounted) {
        setState(() {
          liked = !next;
          likes = (likes + (next ? -1 : 1)).clamp(0, 1 << 31);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final author = object(post['user'] ?? post['author']);
    final content = plainText(post['content'] ?? post['text']);
    final username = string(author['username'] ?? author['nickname']);
    final comments =
        num.tryParse(
          string(
            post['reply_count'] ??
                post['comments_count'] ??
                post['comment_count'],
          ),
        )?.toInt() ??
        0;
    if (widget.comment) {
      final emoticon = object(
        object(post['extras'])['emoticon'] ?? post['emoticon'],
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: palette.row,
          border: Border(
            bottom: BorderSide(
              width: 1 / MediaQuery.devicePixelRatioOf(context),
              color: palette.border,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(author, radius: 17),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppPressable(
                          label: personName(author),
                          style: AppPressStyle.opacity,
                          onPressed: () =>
                              open(context, ProfileScreen(user: author)),
                          child: Text(
                            personName(author),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppDesign.font(
                              13,
                              weight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          relativeTime(
                            context,
                            post['created_at'],
                          ).toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppDesign.font(
                            11,
                            weight: FontWeight.w700,
                            color: palette.secondaryLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: ArticleContent(
                        content: post['content'] ?? post['text'],
                        style: AppDesign.font(
                          14,
                          color: palette.text,
                        ).copyWith(height: 19 / 14),
                      ),
                    ),
                  if (mediaOf(post).isNotEmpty) MediaAttachments(record: post),
                  if (emoticon.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: EmoticonView(document: emoticon, size: 118),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final brand = dark ? const Color(0xffff77dc) : const Color(0xffa80080);
    final muted = dark ? const Color(0xff8e8e93) : const Color(0xff666666);
    final pinkActions = <AppMenuItem>[
      AppMenuItem(
        title: context.l10n.bookmark,
        symbol: 'bookmark',
        fallback: Icons.bookmark_border,
        onPressed: () => perform(context, () async {
          await AppScope.of(
            context,
          ).api.call('post.bookmark', body: {'post_id': recordId(post)});
        }),
      ),
      AppMenuItem(
        title: context.l10n.report,
        symbol: 'exclamationmark.bubble',
        fallback: Icons.flag_outlined,
        destructive: true,
        onPressed: () => perform(context, () async {
          await AppScope.of(
            context,
          ).api.call('post.report', body: {'post_id': recordId(post)});
        }),
      ),
    ];
    return Center(
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
                                      size: 14,
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
                    AppContextMenu(
                      pressTrigger: true,
                      liftContent: false,
                      align: AppMenuAlign.right,
                      label: context.l10n.more,
                      items: pinkActions,
                      child: SizedBox.square(
                        dimension: 44,
                        child: Center(
                          child: AppSymbol.icon(
                            'ellipsis',
                            size: 20,
                            color: palette.text,
                            fallback: Icons.more_horiz,
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
              // Actions: 28pt heart, 26pt comment, 4pt padding, 4pt gap.
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Row(
                  children: [
                    AppPressable(
                      label: context.l10n.like,
                      selected: liked,
                      style: AppPressStyle.touchable,
                      onPressed: like,
                      child: AnimatedBuilder(
                        animation: pop,
                        builder: (context, child) =>
                            Transform.scale(scale: pop.value, child: child),
                        child: Icon(
                          liked ? Icons.favorite : Icons.favorite_border,
                          size: 28,
                          color: liked ? brand : palette.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AppPressable(
                      label: context.l10n.comments,
                      style: AppPressStyle.touchable,
                      onPressed: () => widget.detail
                          ? sheet(
                              context,
                              ComposerScreen(replyTo: recordId(post)),
                            )
                          : openDetail(),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 26,
                        color: palette.text,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text.rich(
                        TextSpan(
                          text: '$likes ',
                          children: [
                            TextSpan(
                              text: 'vibes',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: palette.text.withValues(alpha: .6),
                              ),
                            ),
                          ],
                        ),
                        style: AppDesign.font(
                          15,
                          weight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                    ),
                    if (comments > 0)
                      GestureDetector(
                        onTap: openDetail,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 6),
                          child: Text(
                            context.l10n.viewAllComments(comments),
                            style: AppDesign.font(
                              14,
                              weight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ),
                      ),
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
  }
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
                        comment: i > 1,
                        detail: true,
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
