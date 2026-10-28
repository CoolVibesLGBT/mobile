import 'package:flutter/material.dart';
import '../components/components.dart';
import '../core/api.dart';
import '../core/localized_content.dart';
import '../core/notification_data.dart';
import '../design/app_design.dart';
import '../l10n/l10n.dart';
import 'chat.dart';
import 'discover.dart';
import 'feed.dart';
import 'profile.dart';
import 'settings.dart' show ActivityScreen;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool unread = false;
  String category = 'all';
  void show(Json item) {
    final target = notificationTarget(item), sender = notificationSender(item);
    final type = string(item['type']);
    Widget? destination;
    if (type == 'private_photo_access_request') {
      destination = const ActivityScreen(accessRequests: true);
    } else if (notificationCategory(item) == 'messages') {
      destination = string(target['chat_id']).isEmpty
          ? const ChatsScreen()
          : ChatScreen(chat: {'id': target['chat_id']});
    } else if (string(target['post_id']).isNotEmpty) {
      destination = PostDetailScreen(post: {'public_id': target['post_id']});
    } else if (notificationCategory(item) == 'matches') {
      destination = const MatchesScreen();
    } else if (recordId(sender).isNotEmpty ||
        string(sender['username']).isNotEmpty) {
      destination = ProfileScreen(user: sender);
    }
    if (destination != null) {
      open(context, destination);
      return;
    }
    final language = Localizations.localeOf(context).toLanguageTag();
    final title = localizedText(
      item['title'] ?? notificationPayload(item)['title'],
      language: language,
    );
    showInfoSheet(
      context,
      Builder(
        builder: (context) => AppInfoSheet(
          id: 'notification.details',
          title: title.isEmpty ? context.l10n.notificationTitle : title,
          message: notificationText(item, language),
          actions: AppButton.filled(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final segmentHeight = AppSegments.heightFor(context);
    final headerBottomHeight = segmentHeight + 20;
    final categories = {
      'all': l.all,
      'messages': l.messages,
      'matches': l.matches,
      'reactions': l.notificationReactions,
      'people': l.notificationPeople,
      'gifts': l.notificationGifts,
      'other': l.notificationOther,
    };
    return AppScaffold(
      appBar: AppHeader(
        title: Text(l.notificationTitle),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(headerBottomHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: AppSegments<bool>(
              values: {false: Text(l.all), true: Text(l.notificationUnread)},
              selected: unread,
              onChanged: (value) => setState(() => unread = value),
            ),
          ),
        ),
        actions: [
          AppContextMenu(
            pressTrigger: true,
            label: l.notificationFilter,
            items: [
              for (final entry in categories.entries)
                AppMenuItem(
                  title: entry.value,
                  onPressed: () => setState(() => category = entry.key),
                ),
            ],
            child: const SizedBox.square(
              dimension: 44,
              child: Center(
                child: AppSymbol(
                  'line.3.horizontal.decrease',
                  fallback: Icons.filter_list,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RecordList(
        header: category == 'all'
            ? null
            : Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppButton.text(
                  leadingIcon: Icons.close,
                  onPressed: () => setState(() => category = 'all'),
                  child: Text(categories[category]!),
                ),
              ),
        action: 'user.fetch.notifications',
        filter: !unread && category == 'all'
            ? null
            : (item) =>
                  (!unread || notificationUnread(item)) &&
                  (category == 'all' || notificationCategory(item) == category),
        empty: ScreenStatus(
          title: l.notificationEmpty,
          message: l.notificationEmptyBody,
          animation: 'messages',
        ),
        itemBuilder: (context, item, _) => NotificationRow(
          key: ValueKey('notification.${recordId(item)}'),
          item: item,
          onTap: () => show(item),
        ),
      ),
    );
  }
}

class NotificationRow extends StatelessWidget {
  final Json item;
  final VoidCallback onTap;
  const NotificationRow({super.key, required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context), l = context.l10n;
    final sender = notificationSender(item), unread = notificationUnread(item);
    final language = Localizations.localeOf(context).toLanguageTag();
    final name = personName(sender), body = notificationText(item, language);
    final title = localizedText(
      item['title'] ?? notificationPayload(item)['title'],
      language: language,
    );
    final (symbol, icon, color) = switch (notificationCategory(item)) {
      'messages' => ('bubble.left.fill', Icons.chat_bubble, p.accent),
      'matches' ||
      'reactions' => ('heart.fill', Icons.favorite, AppDesign.premiumColors[3]),
      'people' => (
        'person.badge.plus',
        Icons.person_add,
        AppDesign.premiumColors[0],
      ),
      'gifts' => ('gift.fill', Icons.card_giftcard, AppDesign.premiumColors[2]),
      _ => ('bell.fill', Icons.notifications, p.accent),
    };
    return ColoredBox(
      color: unread ? p.accent.withValues(alpha: .045) : Colors.transparent,
      child: AppRow(
        disclosure: false,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        leading: SizedBox.square(
          dimension: 52,
          child: Stack(
            children: [
              if (sender.isNotEmpty)
                Avatar(sender, radius: 24)
              else
                Center(
                  child: AppSettingIcon(icon, color: color, symbol: symbol),
                ),
              if (sender.isNotEmpty)
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.row, width: 2),
                    ),
                    child: AppSymbol(
                      symbol,
                      fallback: icon,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name.isNotEmpty
                    ? name
                    : title.isNotEmpty
                    ? title
                    : l.notificationTitle,
                style: AppDesign.font(
                  17,
                  weight: unread ? FontWeight.w600 : FontWeight.w500,
                  color: p.text,
                ),
              ),
            ),
            if (unread)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Semantics(
                  label: l.notificationUnread,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty)
              Text(
                body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppDesign.font(15, color: p.text, height: 1.3),
              ),
            const SizedBox(height: 5),
            Text(
              relativeTime(context, item['created_at']),
              style: AppDesign.font(13, color: p.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
