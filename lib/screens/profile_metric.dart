import 'package:flutter/material.dart';
import '../components/components.dart';
import '../components/profile_stats.dart';
import '../core/api.dart';
import '../core/chat_data.dart';
import 'profile.dart';

class ProfileMetricScreen extends StatelessWidget {
  final Json user;
  final ProfileMetric metric;
  const ProfileMetricScreen({
    super.key,
    required this.user,
    required this.metric,
  });
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(title: Text(metric.label)),
    body: RecordList(
      action: 'user.fetch_engagements',
      params: {'user_id': recordId(user), 'engagement_type': metric.kind},
      itemBuilder: (context, item, _) {
        final candidates = [
          item['user'],
          item['engager'],
          item['engagee'],
          item['actor'],
          item['target'],
          item,
        ];
        final person =
            candidates
                .map(object)
                .where(
                  (p) =>
                      p.isNotEmpty &&
                      userIdentities(p).isNotEmpty &&
                      userIdentities(
                        p,
                      ).intersection(userIdentities(user)).isEmpty,
                )
                .firstOrNull ??
            object(item['user'] ?? item);
        return PersonTile(
          person: person,
          onTap: () => open(context, ProfileScreen(user: person)),
        );
      },
    ),
  );
}
