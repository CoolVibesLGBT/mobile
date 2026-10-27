import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/geo.dart';
import '../design/app_design.dart';
import 'game_map.dart';
import 'app_pressable.dart';
import 'navigation.dart';

/// helpers/chatLocation.ts locationHasVenue: these reserved strings name a
/// plain coordinate (older composers and the picker's own labels), never a
/// venue, so the bubble shows no text for them.
bool locationHasVenue(Json location) {
  final address = string(location['address']).trim().toLowerCase();
  return address.isNotEmpty &&
      !const [
        'location',
        'current location',
        'selected location',
        'live location',
        'konum',
        'mevcut konum',
        'seçilen konum',
        'الموقع',
        'الموقع الحالي',
        'الموقع المحدد',
      ].contains(address);
}

/// The picker stores a venue as "Name, address" in `location[address]`;
/// Telegram shows the title (medium 14) over the address (regular 14).
(String, String) venueTitle(Json location) {
  final value = string(location['address']).trim();
  final comma = value.indexOf(', ');
  return comma < 0
      ? (value, '')
      : (value.substring(0, comma), value.substring(comma + 2));
}

/// ChatMessageMapBubbleContentNode: a 2:1 map snapshot as wide as the image
/// constraint allows (≤300pt), Telegram's 62x74 pin over its centre and,
/// for a venue, the title and address 7pt in under the map. A plain
/// coordinate has no text; its date/status capsule sits on the map
/// ([status]). The bubble owns the 2pt frame, corners and footer status.
class LocationAttachment extends StatelessWidget {
  final Json location;
  final double? width;
  final double radius;
  final Widget? status;
  final Color? foreground, secondary;

  /// Venue footer: reserves the bubble's date/status on the last line.
  final Widget? meta;
  final VoidCallback? onPressed;
  const LocationAttachment({
    super.key,
    required this.location,
    this.width,
    this.radius = 14,
    this.status,
    this.foreground,
    this.secondary,
    this.meta,
    this.onPressed,
  });

  static double widthFor(double constrained) =>
      constrained.clamp(170.0, AppDesign.mapBubbleMaxWidth);

  @override
  Widget build(BuildContext context) {
    final point = coordinatesOf(location);
    if (point == null) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    final venue = locationHasVenue(location);
    final (title, address) = venueTitle(location);
    return LayoutBuilder(
      builder: (context, box) {
        final w = width ?? widthFor(box.maxWidth);
        final h = (w * .5).floorToDouble();
        return AppPressable(
          label: [
            context.l10n.openLocationInMaps,
            if (venue) string(location['address']),
          ].join(', '),
          style: AppPressStyle.opacity,
          onPressed:
              onPressed ??
              () => perform(context, () async {
                final uri = Uri.https('maps.apple.com', '/', {
                  'll': '${point['latitude']},${point['longitude']}',
                });
                if (!await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                )) {
                  throw ApiException('Could not open Maps');
                }
              }),
          child: SizedBox(
            width: w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: GameMap(
                                key: ValueKey(
                                  '${point['latitude']}:${point['longitude']}',
                                ),
                                latitude: point['latitude'],
                                longitude: point['longitude'],
                                zoom: 15,
                                pitch: 0,
                                bearing: 0,
                                preview: true,
                                snapshotOnly: true,
                                interactive: false,
                                controls: false,
                                hostsGlass: false,
                              ),
                            ),
                          ),
                        ),
                        // pinNode: x centred, y = h * 0.5 − 10 − 74 / 2.
                        Positioned(
                          left: ((w - 62) / 2).floorToDouble(),
                          top: (h * .5 - 10 - 37).floorToDouble(),
                          child: MapBubblePin(color: palette.accent),
                        ),
                        if (status != null)
                          PositionedDirectional(
                            end: 6,
                            bottom: 6,
                            child: status!,
                          ),
                      ],
                    ),
                  ),
                ),
                if (venue)
                  SizedBox(
                    width: w,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(7, 6, 7, 4),
                      child: Stack(
                        fit: StackFit.passthrough,
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppDesign.font(
                                  14,
                                  weight: FontWeight.w500,
                                  color: foreground ?? palette.text,
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: address.isEmpty ? ' ' : address,
                                    ),
                                    // Reserves the date/status footprint on
                                    // the last line (ChatMessageDateAndStatusNode).
                                    if (meta != null)
                                      WidgetSpan(
                                        child: Padding(
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                start: 6,
                                              ),
                                          child: Opacity(
                                            opacity: 0,
                                            child: meta,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppDesign.font(
                                  14,
                                  color: secondary ?? palette.secondaryLabel,
                                ),
                              ),
                            ],
                          ),
                          if (meta != null)
                            PositionedDirectional(
                              end: 0,
                              bottom: 0,
                              child: meta!,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ChatMessageLiveLocationPositionNode `.location`: LocationPinShadow under
/// LocationPinBackground tinted with the venue colour (accent without a
/// venue type), and the white LocationPinForeground fitted into the 44pt
/// icon box at (9, 14) with 4pt insets.
class MapBubblePin extends StatelessWidget {
  final Color color;
  const MapBubblePin({super.key, required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 62,
    height: 74,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Image.asset(
            'assets/chat/location/pin_shadow.png',
            width: 62.5,
            height: 65.5,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: Image.asset(
            'assets/chat/location/pin_background.png',
            width: 62.5,
            height: 65.5,
            color: color,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
        // 32x25 glyph aspect-fitted into 36x36: 36 x 28.125, centred.
        Positioned(
          left: 9 + 4,
          top: 14 + ((44 - 28.125) / 2).floorToDouble(),
          child: Image.asset(
            'assets/chat/location/pin_icon.png',
            width: 36,
            height: 28.125,
            color: Colors.white,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
      ],
    ),
  );
}
