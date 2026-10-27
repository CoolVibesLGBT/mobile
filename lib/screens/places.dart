import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/l10n.dart';
import '../core/geo.dart';
import '../core/api.dart';
import '../core/app_failure.dart';
import '../core/session.dart';
import '../core/place_data.dart';
import '../core/localized_content.dart';
import '../components/components.dart';
import '../components/article_content.dart';
import '../components/place_row.dart';
import '../design/app_design.dart';
import 'app_forms.dart';
import 'feed.dart';
import 'profile.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});
  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  Json params = {};
  bool locating = false;
  Future<void> nearby() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      final point = await currentPosition();
      if (mounted) {
        setState(
          () => params = {
            'latitude': point.latitude,
            'longitude': point.longitude,
          },
        );
      }
    } catch (error) {
      if (mounted) await showErrorSheet(context, AppFailure.from(error));
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(
      title: Text(context.l10n.places2),
      actions: [
        AppIconButton(
          tooltip: context.l10n.nearbyPlaces2,
          icon: locating
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          onPressed: locating ? null : nearby,
        ),
      ],
    ),
    body: RecordList(
      action: 'place.fetch',
      params: params,
      edgeInset: 16,
      empty: ScreenStatus(title: context.l10n.noPlacesFound),
      itemBuilder: (context, place, _) => PlaceRow(
        key: ValueKey('place.${recordId(place)}'),
        place: place,
        onTap: () => open(context, PlaceScreen(place: place)),
      ),
    ),
  );
}

class PlaceScreen extends StatelessWidget {
  final Json place;
  const PlaceScreen({super.key, required this.place});
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(title: Text(context.l10n.placeDetails)),
    body: recordId(place).isEmpty
        ? ScreenStatus(error: context.l10n.placeDetailsUnavailable)
        : RemoteContent(
            action: 'post.fetch',
            params: {'post_id': recordId(place)},
            builder: (context, response, reload) {
              final item = placeFromResponse(response, recordId(place));
              if (item == null) {
                return ScreenStatus(
                  error: context.l10n.placeDetailsUnavailable,
                  retry: reload,
                );
              }
              return _PlaceDetails(place: item, reload: reload);
            },
          ),
  );
}

class _PlaceDetails extends StatefulWidget {
  final Json place;
  final VoidCallback reload;
  const _PlaceDetails({required this.place, required this.reload});
  @override
  State<_PlaceDetails> createState() => _PlaceDetailsState();
}

class _PlaceDetailsState extends State<_PlaceDetails> {
  bool reacting = false;
  Future<void> launch(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw ApiException('Could not open destination');
      }
    } catch (error) {
      if (mounted) await showErrorSheet(context, AppFailure.from(error));
    }
  }

  Future<void> comment() async {
    final sent = await sheet<bool>(
      context,
      AppForms.comment(context, widget.place),
    );
    if (sent == true && mounted) widget.reload();
  }

  Future<void> react(String action) async {
    if (reacting) return;
    setState(() => reacting = true);
    try {
      await AppScope.of(
        context,
      ).api.call('post.$action', body: {'post_id': recordId(widget.place)});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.placeReactionSaved)),
        );
        widget.reload();
      }
    } catch (error) {
      if (mounted) await showErrorSheet(context, AppFailure.from(error));
    } finally {
      if (mounted) setState(() => reacting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place,
        l = context.l10n,
        palette = AppPalette.of(context);
    final language = Localizations.localeOf(context).toLanguageTag();
    final info = placeInfo(place),
        title = placeTitle(place, language),
        address = placeAddress(place, language),
        region = placeRegion(place, language);
    final content = placeContent(place, language),
        image = placeImage(place),
        tags = placeTags(place);
    final website = placeWebsite(place),
        directions = placeDirections(place, language);
    final phone = string(info['telephone'] ?? place['phone']).trim(),
        email = string(info['email'] ?? place['email']).trim();
    final author = object(place['author']);
    final children = [
      for (final child
          in place['children'] is List ? place['children'] as List : const [])
        object(child),
    ];
    Widget action(String label, IconData icon, VoidCallback? onPressed) =>
        AppButton(
          variant: AppButtonVariant.accent,
          emphasis: AppButtonEmphasis.secondary,
          leadingIcon: icon,
          onPressed: onPressed,
          child: Text(label),
        );
    Widget contact(
      String label,
      String value,
      String symbol,
      IconData icon,
      Uri uri,
    ) => AppRow(
      leading: AppSymbol(
        symbol,
        fallback: icon,
        color: palette.accent,
        size: 24,
      ),
      title: Text(value),
      subtitle: Text(label),
      onTap: () => launch(uri),
    );
    return CustomScrollView(
      key: PageStorageKey('place.detail.${recordId(place)}'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image != null || place['localAsset'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDesign.groupCorner,
                      ),
                      child: AspectRatio(
                        aspectRatio: AppDesign.placeImageRatio,
                        child: AppImage(
                          source: place['localAsset'] == null
                              ? image
                              : AssetImage(string(place['localAsset'])),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                Semantics(
                  header: true,
                  child: Text(
                    title.isEmpty ? l.placeDetails : title,
                    style: AppDesign.font(
                      28,
                      weight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                ),
                if (region.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      region,
                      style: AppDesign.font(15, color: palette.secondaryLabel),
                    ),
                  ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (directions != null)
                      action(
                        l.placeDirections,
                        Icons.directions,
                        () => launch(directions),
                      ),
                    if (phone.isNotEmpty)
                      action(
                        l.placeCall,
                        Icons.phone_outlined,
                        () => launch(Uri(scheme: 'tel', path: phone)),
                      ),
                    action(l.comment2, Icons.chat_bubble_outline, comment),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (contentIsPresent(content))
          SliverToBoxAdapter(
            child: AppSection(
              title: l.about,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ArticleContent(
                    content: content,
                    defaultLanguage: placeDefaultLanguage(place),
                    style: AppDesign.font(17, color: palette.text, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        if (tags.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    Text(
                      '#$tag',
                      style: AppDesign.font(15, color: palette.accent),
                    ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: AppSection(
            title: l.placeContact,
            children: [
              if (phone.isNotEmpty)
                contact(
                  l.placePhone,
                  phone,
                  'phone',
                  Icons.phone_outlined,
                  Uri(scheme: 'tel', path: phone),
                ),
              if (email.isNotEmpty)
                contact(
                  l.email,
                  email,
                  'envelope',
                  Icons.mail_outline,
                  Uri(scheme: 'mailto', path: email),
                ),
              if (website != null)
                contact(
                  l.website,
                  website.host,
                  'globe',
                  Icons.language,
                  website,
                ),
              if (directions != null)
                contact(
                  l.placeDirections,
                  address.isNotEmpty
                      ? address
                      : region.isNotEmpty
                      ? region
                      : title,
                  'mappin.and.ellipse',
                  Icons.location_on_outlined,
                  directions,
                ),
              if (phone.isEmpty &&
                  email.isEmpty &&
                  website == null &&
                  directions == null)
                AppRow(title: Text(l.placeNoContact)),
            ],
          ),
        ),
        if (author.isNotEmpty)
          SliverToBoxAdapter(
            child: AppSection(
              title: l.placeAddedBy,
              children: [
                PersonTile(
                  person: author,
                  onTap: () => open(context, ProfileScreen(user: author)),
                ),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                action(
                  l.like,
                  Icons.thumb_up_outlined,
                  reacting ? null : () => react('like'),
                ),
                action(
                  l.placeDislike,
                  Icons.thumb_down_outlined,
                  reacting ? null : () => react('dislike'),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Semantics(
              header: true,
              child: Text(
                l.comments2(children.length),
                style: AppDesign.font(
                  20,
                  weight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ),
          ),
        ),
        if (children.isEmpty)
          SliverToBoxAdapter(
            child: ScreenStatus(compact: true, title: l.noCommentsYet),
          )
        else
          SliverList.builder(
            itemCount: children.length,
            itemBuilder: (context, index) => PostTile(
              post: children[index],
              comment: true,
              detail: true,
              reload: widget.reload,
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
        ),
      ],
    );
  }
}
