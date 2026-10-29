import 'package:flutter/material.dart';
import '../design/app_design.dart';
import 'spoiler_overlay.dart';

/// View-once media uses the same blurred image and moving dust cover as a
/// Telegram photo spoiler. The image passed here is only a tiny preview.
class ViewOnceDust extends StatelessWidget {
  final String label;
  final Color tint;
  final Widget? preview;

  const ViewOnceDust({
    super.key,
    required this.label,
    required this.tint,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 252,
          height: 216,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SpoilerOverlay(
                hidden: true,
                revealOnTap: false,
                // A transparent fallback lets the cover blur the actual chat
                // wallpaper beneath older messages that have no safe preview.
                child: preview ?? const ColoredBox(color: Colors.transparent),
              ),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .28),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .2),
                      width: 1,
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 54,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.visibility_outlined, color: tint, size: 29),
                        PositionedDirectional(
                          end: -3,
                          bottom: -2,
                          child: Container(
                            width: 19,
                            height: 19,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '1',
                              style: AppDesign.font(
                                11,
                                weight: FontWeight.w700,
                                color: palette.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
