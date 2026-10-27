import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import 'app_pressable.dart';
import '../design/app_design.dart';

class ProfileMetric {
  final String kind, label;
  final num count;
  const ProfileMetric(this.kind, this.label, this.count);
}

/// helpers/profile-metrics.ts buildProfileMetrics: followers and following
/// always, the rest only when the service projects a count for them.
List<ProfileMetric> profileMetrics(BuildContext context, Json user) {
  final counts = object(object(user['engagements'])['counts']);
  final stats = object(user['stats']);
  return [
    for (final (kind, label, keys, always) in [
      (
        'follower',
        (AppLocalizations l) => l.metricFollowers,
        [
          'followers_count',
          'followersCount',
          's:followers_count',
          's:followers',
          'c:follower_count',
        ],
        true,
      ),
      (
        'following',
        (AppLocalizations l) => l.metricFollowing,
        [
          'following_count',
          'followingCount',
          's:following_count',
          's:following',
          'c:following_count',
        ],
        true,
      ),
      (
        'posts',
        (AppLocalizations l) => l.posts,
        [
          'posts_count',
          'postsCount',
          'post_count',
          'postCount',
          's:posts_count',
          's:posts',
          'c:post_count',
        ],
        false,
      ),
      (
        'matched',
        (AppLocalizations l) => l.matches,
        [
          'match_count',
          'matchCount',
          's:match_count',
          's:matches',
          'c:match_count',
        ],
        false,
      ),
      (
        'like_received',
        (AppLocalizations l) => l.likes,
        [
          'like_received_count',
          'likeReceivedCount',
          'likes_count',
          'likesCount',
          's:like_received_count',
          's:likes',
          'c:like_received_count',
        ],
        false,
      ),
      (
        'view_received',
        (AppLocalizations l) => l.metricViewsReceived,
        [
          'view_received_count',
          'viewReceivedCount',
          's:view_received_count',
          's:views_received',
          'c:view_received_count',
        ],
        false,
      ),
      (
        'dislike_received',
        (AppLocalizations l) => l.metricDislikesReceived,
        [
          'dislike_received_count',
          'dislikeReceivedCount',
          's:dislike_received_count',
          's:dislikes_received',
          'c:dislike_received_count',
        ],
        false,
      ),
      (
        'like_given',
        (AppLocalizations l) => l.metricLikesGiven,
        [
          'like_given_count',
          'likeGivenCount',
          's:like_given_count',
          's:likes_given',
          'c:like_given_count',
        ],
        false,
      ),
      (
        'view_given',
        (AppLocalizations l) => l.metricViewsGiven,
        [
          'view_given_count',
          'viewGivenCount',
          's:view_given_count',
          's:views_given',
          'c:view_given_count',
        ],
        false,
      ),
      (
        'dislike_given',
        (AppLocalizations l) => l.metricDislikesGiven,
        [
          'dislike_given_count',
          'dislikeGivenCount',
          's:dislike_given_count',
          's:dislikes_given',
          'c:dislike_given_count',
        ],
        false,
      ),
      (
        'blocking',
        (AppLocalizations l) => l.metricBlockedUsers,
        [
          'blocking_count',
          'blockingCount',
          's:blocking_count',
          'c:blocking_count',
        ],
        false,
      ),
    ])
      if (() {
        dynamic read(String key) => key.startsWith('s:')
            ? stats[key.substring(2)]
            : key.startsWith('c:')
            ? counts[key.substring(2)]
            : user[key];
        return always || keys.any((k) => num.tryParse(string(read(k))) != null);
      }())
        ProfileMetric(
          kind,
          label(context.l10n),
          keys
                  .map(
                    (k) => k.startsWith('s:')
                        ? stats[k.substring(2)]
                        : k.startsWith('c:')
                        ? counts[k.substring(2)]
                        : user[k],
                  )
                  .map((v) => num.tryParse(string(v)))
                  .whereType<num>()
                  .firstOrNull ??
              0,
        ),
  ];
}

/// formatCompactMetricCount: 1.2K, 12K, 1.5M.
String compactCount(num value) {
  if (value >= 1000000)
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  if (value >= 1000)
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return '${value.toInt()}';
}

/// NativeStatsOverview: one horizontally scrolling row of 64pt filled
/// circles on the row colour, the value centred, the 12pt title below.
class ProfileStats extends StatelessWidget {
  final Json user;
  final ValueChanged<ProfileMetric> onSelected;
  const ProfileStats({super.key, required this.user, required this.onSelected});
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final diameter = (64 * scale.clamp(0, 1.4)).roundToDouble();
    final metrics = profileMetrics(context, user);
    final locale = Localizations.localeOf(context).languageCode;
    final title = context.l10n.statistics;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(31, 0, 31, 7),
            child: Text(
              locale == 'tr'
                  ? title.replaceAll('i', 'İ').toUpperCase()
                  : title.toUpperCase(),
              style: AppDesign.font(13, color: palette.secondaryLabel),
            ),
          ),
          SizedBox(
            height: diameter + 6 + 15 * 2 * scale + 4,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final metric in metrics)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AppPressable(
                      label: '${metric.label}, ${metric.count}',
                      onPressed: () => onSelected(metric),
                      child: SizedBox(
                        width: diameter + 16,
                        child: Column(
                          children: [
                            Container(
                              width: diameter,
                              height: diameter,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: palette.row,
                                shape: BoxShape.circle,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  compactCount(metric.count),
                                  style:
                                      AppDesign.font(
                                        17,
                                        weight: FontWeight.w600,
                                        color: palette.text,
                                      ).copyWith(
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              metric.label,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: AppDesign.font(
                                12,
                                color: palette.secondaryLabel,
                                height: 15 / 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
