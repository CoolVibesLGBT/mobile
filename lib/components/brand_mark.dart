import 'package:flutter/material.dart';
import '../design/app_design.dart';

/// Same horizontal artwork and typography as the source mobile BrandMark.
class BrandMark extends StatelessWidget {
  final bool compact, navigation;
  const BrandMark({super.key, this.compact = false, this.navigation = false});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Coolvibes',
    image: true,
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(navigation ? 6 : 0),
            child: Image.asset(
              'assets/images/brand.png',
              width: navigation
                  ? 24
                  : compact
                  ? 36
                  : 56,
              height: navigation
                  ? 24
                  : compact
                  ? 36
                  : 56,
            ),
          ),
          SizedBox(width: navigation ? 7 : 12),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: navigation ? 'CoolVibes' : 'coolvibes',
                children: [
                  if (!navigation)
                    TextSpan(
                      text: '.',
                      style: TextStyle(color: AppPalette.of(context).accent),
                    ),
                ],
              ),
              textDirection: TextDirection.ltr,
              maxLines: navigation ? 1 : null,
              overflow: navigation ? TextOverflow.ellipsis : TextOverflow.clip,
              style: TextStyle(
                fontFamily: navigation
                    ? 'CupertinoSystemText'
                    : 'CupertinoSystemDisplay',
                color: AppPalette.of(context).text,
                fontSize: navigation
                    ? 17
                    : compact
                    ? 24
                    : 32,
                fontWeight: navigation ? FontWeight.w600 : FontWeight.w700,
                letterSpacing: navigation ? -.3 : -1.2,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
