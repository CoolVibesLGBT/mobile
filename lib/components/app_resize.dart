import 'package:flutter/material.dart';
import '../design/app_design.dart';

class AppResize extends StatelessWidget {
  final Widget child;
  const AppResize({super.key, required this.child});

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: AppDesign.buttonRelease,
          alignment: Alignment.topCenter,
          child: child,
        );
}
