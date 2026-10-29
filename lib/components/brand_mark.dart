import 'package:flutter/material.dart';
import '../design/app_design.dart';

/// Brand artwork used by the auth screens and the app navigation header.
class BrandMark extends StatelessWidget {
  final bool compact, navigation;
  const BrandMark({super.key, this.compact = false, this.navigation = false});
  @override
  Widget build(BuildContext context) {
    if (navigation) {
      return Semantics(
        label: 'Coolvibes',
        image: true,
        child: ExcludeSemantics(
          child: Image.asset(
            'assets/images/wordmark-master.png',
            width: 118,
            height: 40,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
        ),
      );
    }
    return Semantics(
      label: 'Coolvibes',
      image: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            Image.asset(
              'assets/images/brand.png',
              width: compact ? 36 : 56,
              height: compact ? 36 : 56,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: 'coolvibes',
                  children: [
                    TextSpan(
                      text: '.',
                      style: TextStyle(color: AppPalette.of(context).accent),
                    ),
                  ],
                ),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontFamily: 'CupertinoSystemDisplay',
                  color: AppPalette.of(context).text,
                  fontSize: compact ? 24 : 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
