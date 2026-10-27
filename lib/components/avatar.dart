import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/session.dart';
import 'app_image.dart';
import 'glass_surface.dart';

class Avatar extends StatelessWidget {
  final Json user;
  final double radius;
  final bool glass, rounded;
  const Avatar(
    this.user, {
    super.key,
    this.radius = 23,
    this.glass = false,
    this.rounded = false,
  });

  dynamic _source(BuildContext context) {
    final raw = user['avatar'] ?? user['avatar_url'] ?? user['imageUrl'];
    final resolved = assetUrl(raw, variant: radius > 35 ? 'large' : 'small');
    final id = user['public_id'] ?? user['id'] ?? user['username'] ?? 'guest';
    final preview =
        context
            .dependOnInheritedWidgetOfExactType<AppScope>()
            ?.notifier
            ?.api
            .isPreview ??
        false;
    return user['localAsset'] != null
        ? AssetImage('${user['localAsset']}')
        : preview
        ? const AssetImage('assets/avatars/guest.svg')
        : resolved.isNotEmpty
        ? resolved
        : 'https://api.dicebear.com/9.x/toon-head/svg?seed=${Uri.encodeComponent('$id')}';
  }

  @override
  Widget build(BuildContext context) {
    final source = _source(context);
    final image = SizedBox.square(
      dimension: radius * 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rounded ? 12 : radius),
        child: AppImage(
          profile: true,
          source: source,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
        ),
      ),
    );
    return glass
        ? GlassSurface(radius: radius, clear: true, child: image)
        : image;
  }
}
