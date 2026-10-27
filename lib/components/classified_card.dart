import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/classified_data.dart';
import '../core/localized_content.dart';
import '../design/app_design.dart';
import '../l10n/l10n.dart';
import '../screens/feed.dart' show relativeTime;
import '../screens/profile.dart';
import '../screens/media.dart';
import 'article_content.dart';
import 'components.dart';

class ClassifiedCard extends StatelessWidget {
  final Json post;
  final bool detail;
  final VoidCallback? onTap;
  const ClassifiedCard({
    super.key,
    required this.post,
    this.detail = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).toLanguageTag();
    final p = AppPalette.of(context), l = context.l10n;
    final title = classifiedTitle(post, language),
        author = object(post['author'] ?? post['user']);
    final metadata = classifiedMetadata(post, language);
    final content = localizedContent(
      post['content'] ?? post['text'],
      language: language,
      defaultLanguage: classifiedDefaultLanguage(post),
    );
    final seeking = classifiedKind(post) == 'job_search';
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSymbol(
                seeking
                    ? 'person.crop.circle.badge.magnifyingglass'
                    : 'briefcase.fill',
                fallback: seeking
                    ? Icons.person_search_outlined
                    : Icons.work_outline,
                size: 18,
                color: p.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  seeking ? l.seeking : l.offers,
                  style: AppDesign.font(
                    13,
                    weight: FontWeight.w600,
                    color: p.accent,
                  ),
                ),
              ),
              if (!detail)
                AppSymbol(
                  'chevron.forward',
                  fallback: Icons.chevron_right,
                  size: 14,
                  color: p.disclosure,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            header: detail,
            child: Text(
              title.isEmpty ? l.classifiedDetails : title,
              maxLines: detail ? null : 2,
              overflow: detail ? TextOverflow.visible : TextOverflow.ellipsis,
              style: AppDesign.font(
                detail ? 28 : 20,
                weight: FontWeight.w600,
                color: p.text,
                height: 1.2,
              ),
            ),
          ),
          if (contentIsPresent(content))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: detail
                  ? ArticleContent(
                      content: content,
                      style: AppDesign.font(17, color: p.text, height: 1.4),
                    )
                  : Text(
                      plainText(content).replaceAll(RegExp(r'\s+'), ' ').trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesign.font(
                        15,
                        color: p.secondaryLabel,
                        height: 1.35,
                      ),
                    ),
            ),
          if (!detail && metadata.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                metadata
                    .take(2)
                    .map((e) => '${e.label}: ${e.value}')
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppDesign.font(13, color: p.secondaryLabel),
              ),
            ),
        ],
      ),
    );
    return AppSection(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (author.isNotEmpty)
          PersonTile(
            person: author,
            subtitle: relativeTime(context, post['created_at']),
            onTap: () => open(context, ProfileScreen(user: author)),
          ),
        if (onTap != null)
          AppPressable(
            label: title,
            style: AppPressStyle.row,
            onPressed: onTap,
            child: body,
          )
        else
          body,
        if (detail) ...[
          MediaAttachments(record: post),
          for (final pair in metadata)
            AppRow(
              title: Text(pair.label),
              subtitle: Text(pair.value),
              disclosure: false,
            ),
        ],
      ],
    );
  }
}
