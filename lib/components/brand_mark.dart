import 'package:flutter/material.dart';

/// Brand wordmark used by the auth screens and the app navigation header.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
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
