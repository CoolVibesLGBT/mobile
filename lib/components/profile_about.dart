import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/profile_preferences.dart';
import '../core/session.dart';
import '../design/app_design.dart';
import 'app_section.dart';
import 'app_row.dart';
import 'screen_status.dart';
import 'illustrated_icon.dart';
import '../core/profile_data.dart';

export '../core/profile_preferences.dart';

/// The profile About tab (source FullProfileView renderAboutTab): attributes
/// with a filled/total count, then fantasies and interests as chips grouped by
/// category, all decoded from `preferences_flags` against initial_sync.
class ProfileAbout extends StatelessWidget {
  final Json user;
  final bool includeIdentity;
  const ProfileAbout({
    super.key,
    required this.user,
    this.includeIdentity = true,
  });

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final palette = AppPalette.of(context);
    final language = session.locale.languageCode;
    String localized(dynamic value, [String fallback = '']) {
      if (value == null) return fallback;
      if (value is String) return value;
      if (value is num) return '$value';
      final map = object(value);
      final text = map[language] ?? map['en'] ?? map.values.firstOrNull;
      return text == null ? fallback : string(text);
    }

    String nameOf(dynamic entity) {
      if (entity == null) return '';
      if (entity is String || entity is num) return '$entity';
      final map = object(entity);
      if (map['name'] != null) return localized(map['name']);
      if (map['title'] != null) return localized(map['title']);
      return '';
    }

    final flags = preferenceFlagsOf(user);
    final system = session.system;
    final preferences = object(
      object(system['data'])['preferences'] ?? system['preferences'],
    );
    final legacy = object(system['data'] ?? system);
    final options = <String, List<(String, int?)>>{};
    final multiple = <String, bool>{};
    final labels = <String, String>{};
    int order(dynamic item) =>
        (object(item)['display_order'] as num?)?.toInt() ?? 0;
    if (preferences['attributes'] is List) {
      for (final raw in preferences['attributes'] as List) {
        final attr = object(raw);
        final tag = string(attr['tag'] ?? attr['slug']);
        multiple[tag] = preferenceAllowsMultiple({
          ...attr,
          '_kind': 'attributes',
        });
        labels[tag] = preferenceGroupTitle({
          ...attr,
          '_kind': 'attributes',
        }, language);
        if (attr['items'] is List) {
          final items = [...(attr['items'] as List)]
            ..sort((a, b) => order(a) - order(b));
          options[tag] = [
            for (final item in items)
              (
                localized(object(item)['title']).isNotEmpty
                    ? localized(object(item)['title'])
                    : string(object(item)['slug']),
                (object(item)['bit_index'] as num?)?.toInt(),
              ),
          ];
        }
      }
    } else {
      for (final raw
          in legacy['attributes'] is List
              ? legacy['attributes'] as List
              : const []) {
        final group = object(raw);
        final attrs = [
          ...(group['attributes'] is List
              ? group['attributes'] as List
              : const []),
        ]..sort((a, b) => order(a) - order(b));
        options[string(group['category'])] = [
          for (final a in attrs) (localized(object(a)['name']), null),
        ];
      }
      for (final (key, field) in [
        ('gender_identities', 'gender_identity'),
        ('sexual_orientations', 'sexual_orientation'),
        ('sexual_roles', 'sex_role'),
      ]) {
        if (legacy[key] is List) {
          final items = [...(legacy[key] as List)]
            ..sort((a, b) => order(a) - order(b));
          options[field] = [
            for (final i in items) (localized(object(i)['name']), null),
          ];
        }
      }
    }

    List<String> valueOf(String field) {
      final fieldOptions = options[field] ?? const [];
      final allowMultiple = multiple[field] ?? false;
      if (fieldOptions.any((o) => o.$2 != null)) {
        final selected = [
          for (final o in fieldOptions)
            if (o.$2 != null && isBitSet(flags, o.$2!) && o.$1.isNotEmpty) o.$1,
        ];
        return allowMultiple ? selected : selected.take(1).toList();
      }
      List<String> names(dynamic source) =>
          (source is List
                  ? source
                  : source == null
                  ? const []
                  : [source])
              .map(nameOf)
              .where((n) => n.isNotEmpty)
              .toList();
      final identities = object(user['sexual_identities']);
      if (field == 'gender_identity') {
        final list = names(
          user['gender_identities'] ?? identities['gender_identities'],
        );
        if (list.isNotEmpty) return allowMultiple ? list : [list.first];
        final single = nameOf(user['gender_identity']);
        if (single.isNotEmpty) return [single];
      }
      if (field == 'sexual_orientation') {
        final list = names(
          user['sexual_orientations'] ?? identities['sexual_orientations'],
        );
        if (list.isNotEmpty) return allowMultiple ? list : [list.first];
        final single = nameOf(user['sexual_orientation']);
        if (single.isNotEmpty) return [single];
      }
      if (field == 'sex_role') {
        final role = nameOf(
          user['sexual_role'] ?? user['sex_role'] ?? identities['sex_role'],
        );
        if (role.isNotEmpty) return [role];
      }
      final top = nameOf(user[field]);
      if (top.isNotEmpty) return [top];
      if (user['user_attributes'] is List) {
        final match = (user['user_attributes'] as List)
            .map(object)
            .where((a) => a['category_type'] == field)
            .firstOrNull;
        final name = localized(object(match?['attribute'])['name']);
        if (name.isNotEmpty) return [name];
      }
      return const [];
    }

    Map<String, (String, List<(String, String?)>)> categorized(String key) {
      final result = <String, (String, List<(String, String?)>)>{};
      if (preferences[key] is List) {
        for (final raw in preferences[key] as List) {
          final category = object(raw);
          final items = <(String, String?)>[
            for (final item
                in category['items'] is List
                    ? category['items'] as List
                    : const [])
              if (object(item)['bit_index'] is num &&
                  isBitSet(flags, (object(item)['bit_index'] as num).toInt()))
                (
                  localized(
                    object(item)['title'],
                    string(object(item)['slug']),
                  ),
                  string(object(item)['id'] ?? object(item)['slug']),
                ),
          ];
          if (items.isNotEmpty) {
            result[string(category['id'])] = (
              localized(category['title'], string(category['id'])),
              items,
            );
          }
        }
      }
      if (preferences[key] is List) return result;
      // Older profiles carry the selections inline.
      for (final raw in user[key] is List ? user[key] as List : const []) {
        if (raw is String) {
          result.putIfAbsent('other', () => ('Other', [])).$2.add((raw, null));
          continue;
        }
        final entry = object(raw);
        final item = object(
          entry['interest_item'] ?? entry['fantasy'] ?? entry['fantasy_item'],
        );
        if (item.isEmpty) continue;
        final categoryId = string(
          item['interest_id'] ??
              object(item['interest'])['id'] ??
              item['category_id'] ??
              object(item['category'])['id'] ??
              'other',
        );
        final title = localized(
          object(item['interest'])['name'] ??
              object(item['category'])['title'] ??
              item['category'],
          categoryId,
        );
        result.putIfAbsent(categoryId, () => (title, [])).$2.add((
          localized(
            item['title'] ?? item['name'] ?? item['label'],
            string(item['slug'] ?? item['id']),
          ),
          string(item['id'] ?? item['slug']),
        ));
      }
      return result;
    }

    final rows = [
      for (final (field, fallback) in userAttributes)
        (labels[field] ?? fallback, valueOf(field), field),
    ];
    final filled = rows.where((r) => r.$2.isNotEmpty).length;
    final fantasies = categorized('fantasies');
    final interests = categorized('interests');
    int count(Map<String, (String, List<(String, String?)>)> groups) =>
        groups.values.fold(0, (sum, group) => sum + group.$2.length);
    Widget chips(Map<String, (String, List<(String, String?)>)> groups) =>
        Column(
          children: [
            for (final group in groups.values)
              AppSection(
                title: group.$1,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (name, icon) in group.$2)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: palette.accent.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IllustratedIcon(
                                  icon ?? 'system-sparkles',
                                  size: 28,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    name,
                                    style: AppDesign.font(
                                      15,
                                      color: palette.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        );
    // groupTitle: 20pt semibold, 31pt in, 4pt above and 10pt below.
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(31, 4, 31, 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: AppDesign.font(
              20,
              weight: FontWeight.w600,
              color: palette.text,
            ),
          ),
        ),
      ),
    );
    final bio = profileBioText(user['bio']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeIdentity && bio.isNotEmpty)
          AppSection(children: [AppRow(title: Text(bio))]),
        heading(
          '${context.l10n.attributes} · $filled/${userAttributes.length}',
        ),
        AppSection(
          margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
          children: [
            for (final (label, values, field) in rows)
              AppRow(
                leading: IllustratedIcon('attribute-$field'),
                title: Text(label),
                value: values.isEmpty ? '—' : values.join(', '),
              ),
          ],
        ),
        heading(
          '${context.l10n.fantasies}${count(fantasies) > 0 ? ' · ${count(fantasies)}' : ''}',
        ),
        if (count(fantasies) > 0)
          chips(fantasies)
        else
          ScreenStatus(
            compact: false,
            title: context.l10n.noFantasiesAddedYet,
            animation: 'duck_fantasies',
          ),
        heading(
          '${context.l10n.interests}${count(interests) > 0 ? ' · ${count(interests)}' : ''}',
        ),
        if (count(interests) > 0)
          chips(interests)
        else
          ScreenStatus(
            title: context.l10n.noInterestsAddedYet,
            animation: 'duck_interests',
          ),
      ],
    );
  }
}
