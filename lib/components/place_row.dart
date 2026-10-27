import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/place_data.dart';
import '../design/app_design.dart';
import '../l10n/l10n.dart';
import 'components.dart';

class PlaceRow extends StatelessWidget {
  final Json place;
  final VoidCallback onTap;
  const PlaceRow({super.key, required this.place, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).toLanguageTag();
    final title = placeTitle(place, language),
        region = placeRegion(place, language);
    final address = placeAddress(place, language), image = placeImage(place);
    final summary = plainText(
      placeContent(place, language),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDesign.groupCorner),
        child: AppRow(
          contentPadding: const EdgeInsets.all(AppDesign.placeRowInset),
          leading: image != null || place['localAsset'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppImage(
                    source: place['localAsset'] == null
                        ? image
                        : AssetImage(string(place['localAsset'])),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                )
              : SizedBox.square(
                  dimension: AppDesign.placeIconSize,
                  child: AppSymbol(
                    'mappin.circle.fill',
                    fallback: Icons.place,
                    size: AppDesign.placeIconSize,
                    color: palette.accent,
                  ),
                ),
          title: Text(
            title.isEmpty ? context.l10n.placeDetails : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppDesign.font(
              17,
              weight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (region.isNotEmpty || address.isNotEmpty)
                Text(
                  region.isNotEmpty ? region : address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppDesign.font(15, color: palette.secondaryLabel),
                ),
              if (summary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesign.font(13, color: palette.secondaryLabel),
                  ),
                ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
