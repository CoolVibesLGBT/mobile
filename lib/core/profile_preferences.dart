import 'api.dart';
import '../design/profile_preference_labels.dart';

/// helpers/bitfield.ts: `preferences_flags` is a hex (or decimal) bitfield
/// whose bit positions are the `bit_index` values of system.initial_sync.
BigInt parsePreferencesFlags(dynamic flags) {
  final value = string(flags).trim();
  if (value.isEmpty) return BigInt.zero;
  try {
    if (value.startsWith('0x')) {
      return BigInt.parse(value.substring(2), radix: 16);
    }
    if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
      return BigInt.parse(value, radix: 16);
    }
    return BigInt.parse(value);
  } catch (_) {
    return BigInt.zero;
  }
}

/// web ProfileScreen: the service now projects `selected_preference_bits`
/// (the set bit indices); older payloads carry the hex `preferences_flags`.
BigInt preferenceFlagsOf(Json user) {
  final bits = user['selected_preference_bits'];
  if (bits is List) {
    return bits
        .whereType<num>()
        .where((b) => b >= 0 && b <= 1000000)
        .fold(BigInt.zero, (flags, bit) => setBit(flags, bit.toInt()));
  }
  return parsePreferencesFlags(user['preferences_flags']);
}

bool isBitSet(BigInt flags, int index) =>
    (flags & (BigInt.one << index)) != BigInt.zero;
BigInt setBit(BigInt flags, int index) => flags | (BigInt.one << index);
BigInt unsetBit(BigInt flags, int index) => flags & ~(BigInt.one << index);
String serializePreferencesFlags(BigInt flags) =>
    flags == BigInt.zero ? '' : flags.toRadixString(16);

/// constants/profile-data.ts USER_ATTRIBUTES, in source order.
const userAttributes = [
  ('gender_identity', 'gender identity'),
  ('sexual_orientation', 'sexual orientation'),
  ('sex_role', 'sex role'),
  ('preferred_partner_gender', 'preferred partner gender'),
  ('relationship_status', 'relationship status'),
  ('relationship_preferences', 'relationship preferences'),
  ('height', 'height'),
  ('weight', 'weight'),
  ('hair_color', 'hair color'),
  ('eye_color', 'eye color'),
  ('skin_color', 'skin color'),
  ('body_type', 'body type'),
  ('tattoos', 'tattoos'),
  ('ethnicity', 'ethnicity'),
  ('zodiac_sign', 'zodiac sign'),
  ('circumcision', 'circumcision'),
  ('physical_disability', 'physical disability'),
  ('smoking', 'smoking'),
  ('drinking', 'drinking'),
  ('religion', 'religion'),
  ('education', 'education level'),
  ('personality', 'personality'),
  ('mbti_type', 'mbti type'),
  ('cronotype', 'cronotype'),
  ('sense_of_humor', 'sense of humor'),
  ('kids_preference', 'kids'),
  ('pets', 'pets'),
  ('dietary', 'dietary'),
  ('hiv_aids_status', 'hiv aids status'),
  ('bdsm_interest', 'bdsm interest'),
  ('bdsm_plays', 'bdsm plays'),
  ('bdsm_roles', 'bdsm roles'),
];

String preferenceText(dynamic value, String language) {
  if (value is String || value is num) return string(value);
  final translations = object(value);
  return string(
    translations[language] ??
        translations['en'] ??
        translations.values.firstOrNull,
  );
}

String preferenceGroupTitle(Json group, String language) {
  final tag = string(group['tag'] ?? group['slug']);
  final label = profileAttributeLabels[language]?[tag];
  return (group['_kind'] == 'attributes' ? label : null) ??
      preferenceText(group['title'] ?? group['name'] ?? tag, language);
}

List<Json> preferenceItems(Json group) {
  final items = [
    for (final item in group['items'] as List? ?? []) object(item),
  ];
  items.sort(
    (a, b) => ((a['display_order'] as num?) ?? 0).compareTo(
      (b['display_order'] as num?) ?? 0,
    ),
  );
  return items;
}

List<Json> preferenceGroups(Json system, {String? kind}) {
  final data = object(system['data'] ?? system);
  final preferences = object(data['preferences']);
  return [
    for (final category in ['attributes', 'interests', 'fantasies'])
      if (kind == null || kind == category)
        ...(() {
          final groups = [
            for (final raw in preferences[category] as List? ?? [])
              {...object(raw), '_kind': category},
          ];
          int order(Json group) {
            if (category == 'attributes') {
              final index = userAttributes.indexWhere(
                (item) => item.$1 == group['tag'],
              );
              if (index >= 0) return index;
            }
            return (group['display_order'] as num?)?.toInt() ?? 0;
          }

          groups.sort((a, b) => order(a).compareTo(order(b)));
          return groups;
        })(),
  ];
}

bool preferenceAllowsMultiple(Json group) {
  final value = group['allow_multiple'];
  if (value is bool) return value;
  if (value is num) return value != 0;
  switch (string(value).trim().toLowerCase()) {
    case 'true':
    case '1':
      return true;
    case 'false':
    case '0':
      return false;
    default:
      return group['_kind'] != 'attributes';
  }
}

List<Json> selectedPreferenceItems(Json user, Json group) {
  final items = preferenceItems(group);
  if (user['selected_preference_bits'] is List ||
      user['preferences_flags'] != null) {
    final flags = preferenceFlagsOf(user);
    return items.where((item) {
      final bit = item['bit_index'];
      return bit is num &&
          bit >= 0 &&
          bit <= 1000000 &&
          isBitSet(flags, bit.toInt());
    }).toList();
  }
  final tag = string(group['tag'] ?? group['slug']);
  final identities = object(user['sexual_identities']);
  final raw = switch (tag) {
    'gender_identity' =>
      user['gender_identities'] ?? identities['gender_identities'] ?? user[tag],
    'sexual_orientation' =>
      user['sexual_orientations'] ??
          identities['sexual_orientations'] ??
          user[tag],
    'sex_role' => user['sexual_role'] ?? identities['sex_role'] ?? user[tag],
    _ =>
      user[group['_kind'] == 'attributes' ? 'user_attributes' : group['_kind']],
  };
  final ids = <String>{};
  for (final value in raw is List ? raw : [?raw]) {
    final row = object(value);
    final item = object(
      row['attribute'] ??
          row['interest_item'] ??
          row['fantasy_item'] ??
          row['fantasy'] ??
          row,
    );
    ids.add(
      string(
        item['id'] ??
            row['attribute_id'] ??
            row['interest_item_id'] ??
            row['fantasy_id'] ??
            value,
      ),
    );
  }
  return items.where((item) => ids.contains(string(item['id']))).toList();
}

String preferenceGroupIcon(Json group) => group['_kind'] == 'attributes'
    ? 'attribute-${group['tag'] ?? group['slug']}'
    : string(group['id'] ?? group['slug']);
