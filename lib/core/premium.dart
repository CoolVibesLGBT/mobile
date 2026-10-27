import 'api.dart';

bool hasPremiumAccess(Json user) {
  if ([
    'is_premium',
    'premium',
    'premium_active',
  ].any((key) => user[key] == true)) {
    return true;
  }
  final status = string(
    object(user['subscription'])['status'] ??
        user['subscription_status'] ??
        user['plan_status'],
  ).trim().toLowerCase();
  if (['active', 'trialing', 'premium', 'pro'].contains(status)) return true;
  return ['user_role', 'plan', 'membership_tier'].any(
    (key) => string(user[key])
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .any((word) => ['premium', 'pro', 'vip'].contains(word)),
  );
}
