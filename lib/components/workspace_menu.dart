import '../l10n/l10n.dart';
import 'app_button.dart';
import 'avatar.dart';
import '../design/app_design.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import '../screens/settings.dart';
import 'navigation.dart';

class WorkspaceMenuButton extends StatelessWidget {
  const WorkspaceMenuButton({super.key});
  @override
  // TabHeaderRow: a 36pt avatar inside a 44pt interactive glass circle; the
  // avatar is the glass button's content, so it swells with the glass.
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 44,
    child: GlassButton(
      child: Avatar(AppScope.of(context).user, radius: 18),
      label: context.l10n.menu,
      color: AppPalette.of(context).text,
      onPressed: () => open(context, const MenuScreen()),
    ),
  );
}
