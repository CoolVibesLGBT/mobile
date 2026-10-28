import '../l10n/l10n.dart';
import 'places.dart';
import '../design/app_design.dart';
import 'package:dio/dio.dart';
import '../core/geo.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/place_data.dart';
import '../core/session.dart';
import '../components/components.dart';
import '../components/workspace_menu.dart';
import 'profile.dart';
import 'composer.dart';
import 'feed.dart';
import 'radar.dart';
import 'settings.dart';
import 'chat.dart';
import '../core/chat_data.dart';
import '../components/discovery_map.dart';
import '../components/radar_profile_card.dart';

class NearbyScreen extends StatefulWidget {
  final bool radar;
  final String initialView;
  final int initialColumns;
  const NearbyScreen({
    super.key,
    this.radar = false,
    this.initialView = 'grid',
    this.initialColumns = 2,
  });
  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  Json coordinates = {...defaultDiscoveryCoordinates};
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started && TickerMode.valuesOf(context).enabled) {
      started = true;
      // Do not mount the nearby list with fallback coordinates while the first
      // location request is waiting for its post-frame callback.
      locating = !AppScope.of(context).api.isPreview;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || AppScope.of(context).api.isPreview) return;
        locating = false;
        locate();
      });
    }
  }

  late String view = widget.initialView;
  bool locating = false;
  String? locationError;
  late int columns = widget.initialColumns;
  Json? _selectedUser;
  Future<void> locate() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      final p = await currentPosition();
      if (mounted) {
        setState(() {
          coordinates = {'latitude': p.latitude, 'longitude': p.longitude};
          locationError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => locationError =
              context.l10n.yourLocationIsUnavailableCheckLocation,
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  /// NativeContextMenu on the grid segment (Nearby ViewModeSwitch): the
  /// column counts, the current one checked.
  final columnsMenu = GlobalKey<AppContextMenuState>();
  void chooseColumns() => columnsMenu.currentState?.open();

  Future<void> message(Json user) => perform(context, () async {
    final chat = await createConversation(AppScope.of(context).api, [
      recordId(user),
    ]);
    if (mounted) open(context, ChatScreen(chat: chat));
  });
  Future<void> react(Json user, String reaction, VoidCallback reload) =>
      perform(context, () async {
        await AppScope.of(context).api.call(
          'match.create',
          body: {'public_id': recordId(user), 'reaction': reaction},
        );
        if (mounted) reload();
      });
  void person(Json user) => setState(() => _selectedUser = user);
  @override
  Widget build(BuildContext context) => widget.radar
      ? const RadarScreen()
      : AppScaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: AppPalette.of(context).row,
          appBar: AppHeader(
            edge: view == 'map' ? AppHeaderEdge.none : null,
            leading: const WorkspaceMenuButton(),
            titleWidth: 156,
            title: AppContextMenu(
              key: columnsMenu,
              enabled: false,
              liftContent: false,
              align: AppMenuAlign.center,
              title: context.l10n.columns,
              items: [
                for (final count in [2, 3, 4])
                  AppMenuItem(
                    title: context.l10n.columns2(count),
                    checked: columns == count,
                    onPressed: () => setState(() {
                      columns = count;
                      view = 'grid';
                    }),
                  ),
              ],
              child: SizedBox(
                width: 156,
                height: 44,
                child: AppSegments<String>(
                  header: true,
                  values: {
                    'grid': GestureDetector(
                      onTap: view == 'grid'
                          ? chooseColumns
                          : () => setState(() => view = 'grid'),
                      child: Tooltip(
                        message: context.l10n.grid,
                        child: const Icon(Icons.grid_view_outlined, size: 22),
                      ),
                    ),
                    'list': Tooltip(
                      message: context.l10n.list,
                      child: const Icon(Icons.list, size: 22),
                    ),
                    'map': Tooltip(
                      message: context.l10n.map,
                      child: const Icon(Icons.map_outlined, size: 22),
                    ),
                  },
                  selected: view,
                  onChanged: (value) => setState(() => view = value),
                ),
              ),
            ),
            actions: [
              AppIconButton(
                tooltip: context.l10n.search,
                icon: const Icon(Icons.search),
                onPressed: () => open(context, const SearchScreen()),
              ),
              AppIconButton(
                tooltip: context.l10n.activity,
                icon: const Icon(Icons.notifications_none),
                onPressed: () => open(context, const ActivityScreen()),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Column(
                  children: [
                    if (locating && view != 'map')
                      const LinearProgressIndicator(),
                    Expanded(
                      child: view == 'map'
                          ? DiscoveryMap(
                              action: 'user.fetch.nearby.users',
                              coordinates: coordinates,
                              onCoordinatesChanged: (point) =>
                                  setState(() => coordinates = point),
                            )
                          : locationError != null
                          ? ScreenStatus(error: locationError, retry: locate)
                          : locating
                          ? const ScreenStatus(loading: true)
                          : ColoredBox(
                              color: AppPalette.of(context).row,
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  final count = view == 'list'
                                      ? 1
                                      : columns.clamp(
                                          1,
                                          (box.maxWidth /
                                                  (84 *
                                                      MediaQuery.textScalerOf(
                                                        context,
                                                      ).scale(1)))
                                              .floor()
                                              .clamp(1, 8),
                                        );
                                  return RecordList(
                                    action: 'user.fetch.nearby.users',
                                    params: coordinates,
                                    columns: count,
                                    // List rows carry their own hairline separators.
                                    gap: view == 'list' ? 0 : 8,
                                    itemBuilder: (context, raw, reload) {
                                      final user = nearbyPerson(
                                        raw,
                                        coordinates,
                                      );
                                      return PersonTile(
                                        person: user,
                                        grid: view == 'grid',
                                        subtitle:
                                            string(user['distance']).isEmpty
                                            ? null
                                            : '${user['distance']} km',
                                        onTap: () => person(user),
                                        onChat: () => message(user),
                                        onLike: () =>
                                            react(user, 'like', reload),
                                        onDislike: () =>
                                            react(user, 'dislike', reload),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
                // RadarCardHost pattern: overlay the profile card directly
                // inside the screen body so the spring morph starts from the
                // correct position and animates upward to the pinned header,
                // matching the RN RadarCardHost / NearbyScreen behaviour.
                if (_selectedUser != null)
                  Positioned.fill(
                    child: RadarProfileCard(
                      key: ValueKey(
                        _selectedUser!['public_id'] ?? _selectedUser!['id'],
                      ),
                      user: _selectedUser!,
                      topInset:
                          View.of(context).viewPadding.top /
                              View.of(context).devicePixelRatio +
                          AppDesign.headerHeight,
                      bottomInset: MediaQuery.paddingOf(context).bottom,
                      onClose: () => setState(() => _selectedUser = null),
                    ),
                  ),
              ],
            ),
          ),
        );
}

class PeopleMap extends StatelessWidget {
  final Json params;
  const PeopleMap({super.key, required this.params});
  @override
  Widget build(BuildContext context) =>
      DiscoveryMap(action: 'user.fetch.nearby.users', coordinates: params);
}

class CheckInsScreen extends StatefulWidget {
  const CheckInsScreen({super.key, this.initialView = 'map'});
  final String initialView;
  @override
  State<CheckInsScreen> createState() => _CheckInsScreenState();
}

class _CheckInsScreenState extends State<CheckInsScreen> {
  late bool map = widget.initialView != 'list';
  Json coordinates = {...defaultDiscoveryCoordinates};
  int revision = 0;
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started && TickerMode.valuesOf(context).enabled) {
      started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || AppScope.of(context).api.isPreview) return;
        try {
          final p = await currentPosition();
          if (mounted) {
            setState(
              () => coordinates = {
                'latitude': p.latitude,
                'longitude': p.longitude,
              },
            );
          }
        } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    extendBodyBehindAppBar: true,
    backgroundColor: AppPalette.of(context).row,
    appBar: AppHeader(
      edge: map ? AppHeaderEdge.none : null,
      leading: const WorkspaceMenuButton(),
      title: AppSegments<bool>(
        header: true,
        values: {
          true: Semantics(
            label: context.l10n.map2,
            child: const Icon(Icons.map_outlined, size: 22),
          ),
          false: Semantics(
            label: context.l10n.list2,
            child: const Icon(Icons.list, size: 22),
          ),
        },
        selected: map,
        onChanged: (value) => setState(() => map = value),
      ),
      actions: [
        AppIconButton(
          tooltip: context.l10n.search,
          icon: const Icon(Icons.search),
          onPressed: () => open(context, const SearchScreen()),
        ),
        AppIconButton(
          tooltip: context.l10n.activity,
          icon: const Icon(Icons.notifications_none),
          onPressed: () => open(context, const ActivityScreen()),
        ),
        AppIconButton(
          tooltip: context.l10n.checkIn,
          icon: const Icon(Icons.add),
          onPressed: () async {
            final result = await sheet<bool>(
              context,
              const ComposerScreen(checkIn: true),
            );
            if (result == true && mounted) {
              setState(() {
                revision++;
                map = false;
              });
            }
          },
        ),
      ],
    ),
    body: map
        ? DiscoveryMap(
            key: ValueKey(revision),
            action: 'user.check_in_fetch',
            limit: 50,
            coordinates: coordinates,
          )
        : ColoredBox(
            color: AppPalette.of(context).row,
            child: RecordList(
              key: ValueKey(revision),
              action: 'user.check_in_fetch',
              params: {...coordinates, 'limit': 50},
              itemBuilder: (_, post, reload) =>
                  PostTile(post: post, reload: reload),
            ),
          ),
  );
}

/// Global search (source app/search/index.tsx): `search.global` with Telegram
/// folder filters and list rows for people, events, posts and places.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final input = TextEditingController();
  String filter = 'all';
  List<(String, Json)> results = [];
  bool loading = false;
  String? error;
  int generation = 0;
  CancelToken? searchRequest;

  @override
  void dispose() {
    searchRequest?.cancel();
    input.dispose();
    super.dispose();
  }

  void changed() {
    searchRequest?.cancel();
    generation++;
    final term = input.text.trim();
    if (term.length < 2) {
      generation++;
      setState(() {
        results = [];
        loading = false;
        error = null;
      });
      return;
    }
    setState(() {
      loading = true;
      results = [];
      error = null;
    });
  }

  Future<void> search() async {
    final term = input.text.trim();
    if (term.length < 2) return;
    searchRequest?.cancel();
    setState(() {
      loading = true;
      error = null;
    });
    final request = ++generation;
    final cancelToken = searchRequest = CancelToken();
    try {
      final response = await AppScope.of(context).api.call(
        'search.global',
        cancelToken: cancelToken,
        body: {'query': term, 'scope': filter, 'limit': 20},
      );
      if (!mounted || request != generation) return;
      final data = object(response['data'] ?? response);
      List<(String, Json)> pick(String key, String type) => [
        for (final item in data[key] is List ? data[key] as List : const [])
          (type, object(item)),
      ];
      setState(
        () => results = [
          ...pick('users', 'people'),
          ...pick('events', 'events'),
          ...pick('posts', 'posts'),
          ...pick('places', 'places'),
        ],
      );
    } catch (e) {
      if (mounted && request == generation && !cancelToken.isCancelled) {
        setState(() {
          results = [];
          error = '$e';
        });
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  String readable(dynamic value) => plainText(
    value,
    language: Localizations.localeOf(context).languageCode,
  ).replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  void openResult(String type, Json data) {
    if (type == 'people') {
      open(context, ProfileScreen(user: data));
    } else if (type == 'places') {
      open(context, PlaceScreen(place: data));
    } else {
      open(context, PostDetailScreen(post: data));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final term = input.text.trim();
    final visible = results
        .where((r) => filter == 'all' || r.$1 == filter)
        .toList();
    final media = MediaQuery.of(context);
    final top = media.padding.top + AppDesign.headerInset(context);
    final inputHeight = media.textScaler.scale(17) * 1.3 + 24;
    final footerHeight = inputHeight + 16 + media.padding.bottom;
    final filters = [
      ('all', context.l10n.all),
      ('people', context.l10n.people),
      ('events', context.l10n.events),
      ('posts', context.l10n.posts),
      ('places', context.l10n.places),
    ];
    return AppScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppHeader(
        title: Text(context.l10n.search),
        edge: AppHeaderEdge.none,
      ),
      bottomOverlayHeight: footerHeight,
      bottomOverlay: SafeArea(
        top: false,
        child: AppSearchField(
          controller: input,
          floating: true,
          autofocus: true,
          placeholder: context.l10n.searchPeoplePostsAndPlaces,
          debounceDuration: const Duration(milliseconds: 280),
          onChanged: (_) => changed(),
          onSearch: (_) => search(),
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(top: top, bottom: footerHeight + 24),
        children: [
          if (term.length >= 2)
            AppFolderTabs<String>(
              items: filters,
              value: filter,
              onChanged: (value) {
                setState(() => filter = value);
                changed();
                search();
              },
            ),
          if (loading && visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (term.length < 2)
            ScreenStatus(
              title: context.l10n.searchCoolvibes,
              message: context.l10n.findPeoplePostsEventsAndPlaces,
              animation: 'search',
            )
          else if (visible.isEmpty)
            ScreenStatus(
              title: error != null
                  ? context.l10n.searchCouldNotBeCompleted
                  : context.l10n.noResults,
              animation: error != null ? 'error' : 'search',
              retry: error != null ? search : null,
            )
          else
            ColoredBox(
              color: palette.row,
              child: Column(
                children: [
                  for (var i = 0; i < visible.length; i++)
                    _SearchRow(
                      type: visible[i].$1,
                      data: visible[i].$2,
                      last: i == visible.length - 1,
                      readable: readable,
                      onTap: () => openResult(visible[i].$1, visible[i].$2),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Search result row: 60pt, 44pt avatar or symbol disc, 16pt title, 15pt
/// two-line subtitle, hairline from 70pt.
class _SearchRow extends StatelessWidget {
  final String type;
  final Json data;
  final bool last;
  final String Function(dynamic) readable;
  final VoidCallback onTap;
  const _SearchRow({
    required this.type,
    required this.data,
    required this.last,
    required this.readable,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final author = object(data['author'] ?? data['user']);
    final language = Localizations.localeOf(context).toLanguageTag();
    final title = type == 'people'
        ? string(data['displayname'] ?? data['username'])
        : type == 'places'
        ? placeTitle(data, language)
        : [
            string(author['displayname']),
            string(author['username']),
            readable(data['title']),
          ].firstWhere((v) => v.isNotEmpty, orElse: () => context.l10n.post);
    final subtitle = type == 'people'
        ? (string(data['username']).isEmpty ? '' : '@${data['username']}')
        : type == 'places'
        ? [
            placeAddress(data, language),
            placeRegion(data, language),
            plainText(placeContent(data, language)),
          ].firstWhere((v) => v.isNotEmpty, orElse: () => '')
        : [
            data['content_text'],
            data['summary'],
            data['content'],
            data['text'],
            data['description'],
            data['title'],
          ].map(readable).firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final symbol = type == 'places'
        ? ('mappin.circle.fill', Icons.place, const Color(0xff34c759))
        : type == 'events'
        ? ('calendar', Icons.event, const Color(0xffff9500))
        : null;
    return AppPressable(
      label: [title, subtitle].where((v) => v.isNotEmpty).join(', '),
      style: AppPressStyle.row,
      onPressed: onTap,
      child: Stack(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 7, 16, 7),
            child: Row(
              children: [
                if (symbol != null)
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: symbol.$3,
                      shape: BoxShape.circle,
                    ),
                    child: AppSymbol.icon(
                      symbol.$1,
                      size: 22,
                      color: Colors.white,
                      fallback: symbol.$2,
                    ),
                  )
                else
                  Avatar(type == 'people' ? data : author, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppDesign.font(
                          16,
                          weight: FontWeight.w600,
                          color: palette.text,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppDesign.font(
                            15,
                            color: palette.secondaryLabel,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!last)
            PositionedDirectional(
              start: 70,
              end: 0,
              bottom: 0,
              child: Container(
                height: 1 / MediaQuery.devicePixelRatioOf(context),
                color: palette.border,
              ),
            ),
        ],
      ),
    );
  }
}

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});
  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  String filter = 'matched';
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(title: Text(context.l10n.matches)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            initialValue: filter,
            isExpanded: true,
            items: [
              for (final key in ['matched', 'liked', 'passed'])
                DropdownMenuItem(
                  value: key,
                  child: Text(
                    {
                      'matched': context.l10n.matches,
                      'liked': context.l10n.matchFilterLiked,
                      'passed': context.l10n.matchFilterPassed,
                    }[key]!,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => filter = value);
            },
          ),
        ),
        Expanded(
          child: RecordList(
            action: 'match.fetch.$filter',
            itemBuilder: (context, item, _) {
              final user = object(item['user'] ?? item['target'] ?? item);
              return PersonTile(
                person: user,
                onTap: () => open(context, ProfileScreen(user: user)),
              );
            },
          ),
        ),
      ],
    ),
  );
}
