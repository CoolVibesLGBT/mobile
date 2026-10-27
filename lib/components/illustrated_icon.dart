import 'package:flutter/material.dart';
import '../design/illustrated_icon_catalog.dart';
import 'app_image.dart';

/// Original web artwork; labels belong to the containing row or control.
class IllustratedIcon extends StatelessWidget {
  final String name, fallback;
  final double size;
  const IllustratedIcon(
    this.name, {
    super.key,
    this.fallback = 'system-sparkles',
    this.size = 32,
  });

  static String keyFor(String name, {String fallback = 'system-sparkles'}) {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll('_', '-');
    return illustratedIconAliases[normalize(name)] ??
        illustratedIconAliases[normalize(fallback)] ??
        'system-sparkles';
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AppImage(
      source: AssetImage(
        'assets/images/profile_icons/${keyFor(name, fallback: fallback)}.avif',
      ),
      width: size,
      height: size,
    ),
  );
}
