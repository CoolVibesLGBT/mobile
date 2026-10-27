import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import 'avatar.dart';
import 'app_button.dart';
import '../design/app_design.dart';
import 'navigation.dart';

class ComposerAuthor extends StatelessWidget {
  final Json user;
  const ComposerAuthor({super.key, required this.user});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(
      children: [
        Avatar(user, radius: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                personName(user).isEmpty ? 'CoolVibes' : personName(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppDesign.font(
                  16,
                  weight: FontWeight.w600,
                  color: AppPalette.of(context).text,
                ),
              ),
              const SizedBox(height: 4),
              // Audience chip on surface3Solid, 10pt corners.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xff393939)
                      : const Color(0xfff2f2f2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSymbol.icon(
                        'globe',
                        size: 12,
                        color: AppPalette.of(context).secondaryLabel,
                        fallback: Icons.public,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          context.l10n.publicPost,
                          style: AppDesign.font(
                            13,
                            color: AppPalette.of(context).secondaryLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
