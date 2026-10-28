import '../l10n/l10n.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../components/components.dart';
import '../components/emoticon_view.dart';
import '../components/glass_surface.dart';
import '../components/app_lottie.dart';
import '../vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;
import '../core/api.dart';
import '../core/session.dart';
import '../design/app_design.dart';

class EmoticonPicker extends StatefulWidget {
  final bool embedded, allowEmoji, emojiOnly;
  final String initialTab;
  final ValueChanged<Json>? onSelected;
  final ValueChanged<bool>? onSearchFocusChanged;

  /// Telegram media input: dragging the grid up expands the panel to the
  /// full screen; pulling down at the top collapses it again.
  final ValueChanged<bool>? onExpandChanged;
  final bool expanded;
  final VoidCallback? onKeyboard, onErase;
  final bool canErase;

  const EmoticonPicker({
    this.onKeyboard,
    this.onErase,
    this.canErase = true,
    super.key,
    this.embedded = false,
    this.allowEmoji = true,
    this.emojiOnly = false,
    this.initialTab = 'stickers',
    this.onSelected,
    this.onSearchFocusChanged,
    this.onExpandChanged,
    this.expanded = false,
  });
  static Future<Json?> show(
    BuildContext context, {
    String initialTab = 'stickers',
  }) => sheet<Json>(
    context,
    EmoticonPicker(initialTab: initialTab),
    tint: AppDesign.inputMediaPanelColor(context),
  );
  @override
  State<EmoticonPicker> createState() => _EmoticonPickerState();
}

class _EmoticonPickerState extends State<EmoticonPicker> {
  bool expansionHandled = false;
  final all = <Json>[], gifs = <Json>[], emojis = <Json>[];
  final packTitles = <String, String>{};
  String query = '', pack = '', offset = '';

  /// Selected EmojiSearchSearchBarComponent group, or -1.
  int group = -1;
  late String mode = widget.emojiOnly ? 'emoji' : widget.initialTab;
  bool get gif => mode == 'gif';
  bool get emoji => mode == 'emoji';
  bool loading = false, loadingAssets = true;
  String? assetError;
  String? error;
  int generation = 0;
  final searchFocus = FocusNode();
  final searchInput = TextEditingController();
  Timer? searchDebounce;
  final gifClient = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  CancelToken? gifRequest;
  void focusChanged() =>
      widget.onSearchFocusChanged?.call(searchFocus.hasFocus);
  @override
  void dispose() {
    searchDebounce?.cancel();
    searchInput.dispose();
    gifRequest?.cancel();
    gifClient.close(force: true);
    scroll.dispose();
    searchFocus.removeListener(focusChanged);
    searchFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EmoticonPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.emojiOnly && !oldWidget.emojiOnly) {
      gifRequest?.cancel();
      generation++;
      mode = 'emoji';
      searchInput.clear();
      query = '';
      loading = false;
      error = null;
    }
  }

  bool assetsRequested = false;
  @override
  void initState() {
    super.initState();
    searchFocus.addListener(focusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (assetsRequested) return;
    assetsRequested = true;
    final bundle = DefaultAssetBundle.of(context);
    loadAssets(bundle);
    if (gif) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && gif) searchGifs();
      });
    }
  }

  Future<void> loadAssets(AssetBundle bundle) async {
    if (mounted) {
      setState(() {
        loadingAssets = true;
        assetError = null;
      });
    }
    try {
      final sources = await Future.wait([
        bundle.loadString('assets/data/sticker-packs.json'),
        if (widget.allowEmoji)
          bundle.loadString('assets/data/telegram-emoji.json'),
      ]);
      if (!mounted) return;
      setState(() {
        all.clear();
        emojis.clear();
        for (final raw in jsonDecode(sources[0]) as List) {
          final pack = object(raw);
          packTitles[string(pack['id'])] = string(pack['title']);
          all.addAll((pack['documents'] as List).map(object));
        }
        if (widget.allowEmoji) {
          emojis.addAll(
            (object(jsonDecode(sources[1]))['entries'] as List).map(object),
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => assetError = context.l10n.couldNotLoadStickers);
      }
    } finally {
      if (mounted) setState(() => loadingAssets = false);
    }
  }

  Future<void> searchGifs({bool next = false}) async {
    gifRequest?.cancel();
    final cancelToken = gifRequest = CancelToken();
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
      if (!next) {
        gifs.clear();
        offset = '';
      }
    });
    final api = AppScope.of(context).api;
    try {
      // Keep parity with the public Tenor client key used by web's GifPicker;
      // still allow release/build environments to override it.
      const key = String.fromEnvironment(
        'TENOR_API_KEY',
        defaultValue: 'AIzaSyBjmmwmtWOaK-SVlBEuUwmn0hox-9SDjcs',
      );
      Json data;
      if (key.isEmpty) {
        final response = await api.call(
          'chat.media.gifs',
          body: {'query': query, 'offset': offset},
          cancelToken: cancelToken,
        );
        data = object(response['data'] ?? response);
      } else {
        final response = await gifClient.get<Json>(
          'https://tenor.googleapis.com/v2/${query.isEmpty ? 'featured' : 'search'}',
          cancelToken: cancelToken,
          queryParameters: {
            'key': key,
            'client_key': 'bifrostapp-web',
            'q': query,
            'pos': offset,
            'limit': 32,
            'contentfilter': 'medium',
            'media_filter': 'gif,tinygif,nanogif',
          },
        );
        final raw = response.data ?? {};
        data = {
          'documents': [
            for (final item in raw['results'] as List? ?? [])
              if (object(object(item['media_formats'])['gif'])['url'] != null ||
                  object(object(item['media_formats'])['tinygif'])['url'] !=
                      null)
                {
                  'kind': 'gif',
                  'id': item['id'],
                  'url':
                      object(object(item['media_formats'])['gif'])['url'] ??
                      object(object(item['media_formats'])['tinygif'])['url'],
                  'width':
                      ((object(object(item['media_formats'])['gif'])['dims'] ??
                              object(
                                object(item['media_formats'])['tinygif'],
                              )['dims'])
                          as List?)?[0] ??
                      320,
                  'height':
                      ((object(object(item['media_formats'])['gif'])['dims'] ??
                              object(
                                object(item['media_formats'])['tinygif'],
                              )['dims'])
                          as List?)?[1] ??
                      240,
                },
          ],
          'nextOffset': raw['next'],
        };
      }
      if (!mounted || request != generation) return;
      setState(() {
        gifs.addAll((data['documents'] as List? ?? []).map(object));
        offset = string(data['nextOffset']);
      });
    } catch (e) {
      if (mounted && request == generation && !cancelToken.isCancelled) {
        setState(() => error = context.l10n.couldNotLoadGifsTryAgain);
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  static final _categories = [
    ((AppLocalizations l) => l.emojiCategorySmileysPeople, 'face.smiling'),
    ((AppLocalizations l) => l.emojiCategoryAnimalsNature, 'pawprint'),
    ((AppLocalizations l) => l.emojiCategoryFoodDrink, 'fork.knife'),
    ((AppLocalizations l) => l.emojiCategoryTravelPlaces, 'car'),
    ((AppLocalizations l) => l.emojiCategoryActivities, 'soccerball'),
    ((AppLocalizations l) => l.emojiCategoryObjectsSymbols, 'lightbulb'),
    ((AppLocalizations l) => l.emojiCategoryFlags, 'flag'),
  ];

  /// Telegram emoji search categories (EmojiSearchCategories groups): the
  /// faded glyphs inside the search bar. Each filters emoji and stickers by
  /// these characters and searches GIFs by its term.
  static const searchGroups =
      <(String icon, String term, String members, String asset)>[
        ('❤️', 'love', '❤️🧡💛💚💙💜🖤🤍🤎💕💞💓💗💖💘💝😍🥰😘😻💋🫶', 'love'),
        ('👍', 'like', '👍👌🤝👏🙌💪✅💯🫡', 'like'),
        ('👎', 'dislike', '👎🙅❌🚫💔😒🙄', 'dislike'),
        ('🎉', 'party', '🎉🎊🥳🎈🎁🪅🎂🥂🍻🍺🍷🍾', 'party'),
        ('😄', 'laugh', '😂🤣😆😹😄😁😅', 'laugh'),
        ('😦', 'wow', '😦😮😲😯😱🤯😳🙀', 'surprised'),
        ('😔', 'sad', '😢😭😿😞😔🥺😥😓', 'sad'),
        ('😡', 'angry', '😡😠🤬👿💢😤', 'angry'),
        ('😐', 'neutral', '😐😑😶🫤😕', 'neutral'),
        ('🤔', 'thinking', '🤔🧐🤨🫣', 'thinking'),
        ('🤪', 'playful', '🤪😜😝😛🙃😋', 'playful'),
      ];

  bool inGroup(String emoji, int index) {
    if (emoji.isEmpty) return false;
    final members = searchGroups[index].$3;
    final bare = emoji.replaceAll('\u{FE0F}', '');
    return members.contains(emoji) || members.contains(bare);
  }

  List<String> get recentEmoji => AppScope.of(context).recentEmoji;
  List<Json> get recentStickers => AppScope.of(context).recentStickers;
  final scroll = ScrollController();
  final sectionKeys = <String, GlobalKey>{};
  String activeSection = '';
  bool searching = false;
  int get skinTone => AppScope.of(context).emojiSkinTone;

  Json displayedEmoji(Json item) {
    final tones = item['tones'];
    return skinTone > 0 && tones is List && tones.length >= skinTone
        ? {...item, 'emoji': tones[skinTone - 1]}
        : item;
  }

  Future<void> chooseTone(Json item) async {
    final entry = item['tones'] is List
        ? item
        : emojis.firstWhere(
            (e) =>
                e['emoji'] == item['emoji'] ||
                (e['tones'] is List &&
                    (e['tones'] as List).contains(item['emoji'])),
            orElse: () => item,
          );
    final tones = entry['tones'];
    if (tones is! List || tones.isEmpty) return;
    final variants = [string(entry['emoji']), ...tones.map(string)];
    final character = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: GlassSurface(
          role: GlassSurfaceRole.sheet,
          radius: 30,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  for (final variant in variants)
                    SizedBox.square(
                      dimension: 50,
                      child: AppPressable(
                        label: variant,
                        selected:
                            variant ==
                            variants[skinTone.clamp(0, variants.length - 1)],
                        style: AppPressStyle.emoji,
                        onPressed: () => Navigator.pop(dialogContext, variant),
                        child: Center(
                          child: Text(
                            variant,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: 'Apple Color Emoji',
                              fontSize: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted || character == null) return;
    setState(() {
      // Five standard tones are shared across emoji. Mixed pairs are specific
      // to their base emoji and must not become another emoji's tone index.
      final tone = variants.indexOf(character);
      AppScope.of(context).emojiSkinTone = tone <= 5 ? tone : 0;
    });
    select({...entry, 'emoji': character});
  }

  /// EmojiPagerContentComponent.ItemLayout / GifPagerContentComponent.
  ({int perRow, double item, double spacing, double inset, double vertical})
  layout(double width) {
    if (gif) {
      final perRow = (width / 120).floor().clamp(3, 99);
      return (
        perRow: perRow,
        item: ((width - (perRow - 1)) / perRow).floorToDouble(),
        spacing: 1.0,
        inset: 0.0,
        vertical: 1.0,
      );
    }
    // Telegram's native emoji keyboard uses roughly 48pt emoji cells. The
    // previous 40pt target packed too many small glyphs into wide macOS
    // windows, making the Apple Color Emoji artwork look noticeably weaker.
    final native = emoji ? 48.0 : 70.0;
    final minPerRow = emoji ? 8 : 5;
    final inset = emoji ? (width >= 420 ? 5.0 : 7.0) : 10.0;
    final minSpacing = emoji ? (width >= 420 ? 2.0 : 9.0) : 12.0;
    final space = width - inset * 2;
    final perRow = ((space + minSpacing) / (native + minSpacing)).floor().clamp(
      minPerRow,
      99,
    );
    final item = native.clamp(
      0.0,
      ((space - minSpacing * (perRow - 1)) / perRow).floorToDouble(),
    );
    final spacing = ((space - item * perRow) / (perRow - 1).clamp(1, 99))
        .floorToDouble();
    return (
      perRow: perRow,
      item: item,
      spacing: spacing,
      inset: ((width - (item * perRow + spacing * (perRow - 1))) / 2)
          .floorToDouble(),
      vertical: emoji ? 9.0 : 2.0,
    );
  }

  // Original RN helpers/emoticons/emojiCatalog.ts search vocabulary.
  static const searchAliases = <String, List<String>>{
    'gül': ['smile', 'laugh'],
    'mutlu': ['smile', 'happy'],
    'aşk': ['love', 'heart'],
    'kalp': ['heart'],
    'öpücük': ['kiss'],
    'üzgün': ['sad', 'cry'],
    'ağla': ['cry'],
    'kedi': ['cat'],
    'köpek': ['dog'],
    'teşekkür': ['pray', 'thank'],
    'el': ['hand'],
    'حب': ['love', 'heart'],
    'قلب': ['heart'],
    'سعيد': ['smile', 'happy'],
    'ضحك': ['laugh'],
    'حزين': ['sad', 'cry'],
    'قطة': ['cat'],
    'كلب': ['dog'],
    'يد': ['hand'],
  };

  List<(String id, String title, List<Json> cells)> sections() {
    final q = query.toLowerCase();
    final terms = searchAliases[q] ?? [q];
    if (group >= 0 && !gif) {
      return [
        (
          'search',
          '',
          emoji
              ? emojis.where((d) => inGroup(string(d['emoji']), group)).toList()
              : all.where((d) => inGroup(string(d['emoji']), group)).toList(),
        ),
      ];
    }
    if (emoji) {
      if (q.isNotEmpty) {
        return [
          (
            'search',
            '',
            emojis
                .where(
                  (d) => terms.any(
                    (term) => '${d['name']} ${d['keywords']} ${d['emoji']}'
                        .toLowerCase()
                        .contains(term),
                  ),
                )
                .toList(),
          ),
        ];
      }
      return [
        if (recentEmoji.isNotEmpty)
          (
            'recent',
            context.l10n.recent,
            [
              for (final e in recentEmoji) {'emoji': e},
            ],
          ),
        for (var i = 0; i < _categories.length; i++)
          (
            'category-$i',
            _categories[i].$1(context.l10n),
            emojis.where((d) => d['category'] == i).toList(),
          ),
      ];
    }
    if (gif) return [('gif', '', gifs)];
    if (q.isNotEmpty || pack.isNotEmpty) {
      return [
        (
          'search',
          '',
          all
              .where(
                (d) =>
                    (pack.isEmpty || d['pack'] == pack) &&
                    '${d['pack']} ${d['emoji']}'.toLowerCase().contains(q),
              )
              .toList(),
        ),
      ];
    }
    final packs = <String, List<Json>>{};
    for (final d in all) {
      (packs[string(d['pack'])] ??= []).add(d);
    }
    return [
      if (recentStickers.isNotEmpty)
        ('recent', context.l10n.recent, recentStickers),
      for (final entry in packs.entries)
        (entry.key, packTitles[entry.key] ?? entry.key, entry.value),
    ];
  }

  void select(Json item) {
    final selected = emoji ? <String, dynamic>{...item, 'kind': 'emoji'} : item;
    if (emoji) {
      recentEmoji
        ..remove(string(item['emoji']))
        ..insert(0, string(item['emoji']));
      if (recentEmoji.length > 32) recentEmoji.removeLast();
    } else if (!gif) {
      recentStickers
        ..removeWhere((d) => d['id'] == item['id'])
        ..insert(0, item);
      if (recentStickers.length > 20) recentStickers.removeLast();
    }
    if (widget.onSelected != null) {
      setState(() {});
      widget.onSelected!(selected);
    } else {
      Navigator.pop(context, selected);
    }
  }

  void switchTab(String next) {
    if (next == mode) return;
    searchDebounce?.cancel();
    searchInput.clear();
    gifRequest?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      mode = next;
      loading = false;
      error = null;
      generation++;
      query = '';
      pack = '';
      group = -1;
      activeSection = '';
    });
    if (scroll.hasClients) scroll.jumpTo(0);
    if (gif) searchGifs();
  }

  void jumpTo(String id) {
    setState(() => activeSection = id);
    final target = sectionKeys[id]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sectionColor = dark
        ? const Color(0xff7b7b7b)
        : const Color(0xff9099a2);
    final iconActive = dark ? const Color(0xffd4d4d4) : const Color(0xff4d5561);
    final bottomInset = MediaQuery.paddingOf(
      context,
    ).bottom.clamp(8.0, double.infinity);
    final controlHeight = AppSegments.heightFor(context);
    final list = sections();
    final placeholder = gif
        ? context.l10n.searchGifs
        : emoji
        ? context.l10n.searchEmoji
        : context.l10n.searchStickers;
    Widget glassCircle(
      String symbol,
      IconData fallback,
      String label,
      VoidCallback? onTap,
    ) => SizedBox.square(
      dimension: 44,
      child: AppIconButton(
        glass: true,
        symbolSize: 15,
        tooltip: label,
        color: iconActive,
        icon: Icon(fallback, size: 20),
        onPressed: onTap,
      ),
    );
    final content = LayoutBuilder(
      builder: (context, box) {
        if (box.maxHeight < 12) return const SizedBox.shrink();
        final grid = layout(box.maxWidth);
        return ColoredBox(
          color: Colors.transparent,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Listener(
                      onPointerDown: (_) => expansionHandled = false,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (note) {
                          final expand = widget.onExpandChanged;
                          if (expand == null || note.depth != 0) return false;
                          if (note is ScrollStartNotification &&
                              note.dragDetails != null) {
                            expansionHandled = false;
                          }
                          if (expansionHandled) return false;
                          if (!widget.expanded &&
                              note is ScrollUpdateNotification &&
                              note.dragDetails != null &&
                              (note.scrollDelta ?? 0) > 2) {
                            expansionHandled = true;
                            expand(true);
                          } else if (widget.expanded &&
                              note is OverscrollNotification &&
                              note.dragDetails != null &&
                              note.overscroll < -2) {
                            expansionHandled = true;
                            expand(false);
                          } else if (widget.expanded &&
                              note is ScrollUpdateNotification &&
                              note.dragDetails != null &&
                              note.metrics.pixels <
                                  note.metrics.minScrollExtent - 2 &&
                              (note.dragDetails!.primaryDelta ?? 0) > 0) {
                            expansionHandled = true;
                            expand(false);
                          }
                          return false;
                        },
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: const [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                            ],
                            stops: [
                              0,
                              ((controlHeight + bottomInset + 20) / rect.height)
                                  .clamp(0.0, 1.0),
                              1,
                            ],
                          ).createShader(rect),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            controller: scroll,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            slivers: [
                              // EmojiSearchHeaderView: a 36pt capsule 8pt below
                              // the panel top with 12pt sides, holding the faded
                              // search categories (EmojiSearchSearchBarComponent).
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    12,
                                    4,
                                  ),
                                  child: _EmojiSearchBar(
                                    controller: searchInput,
                                    focusNode: searchFocus,
                                    placeholder: placeholder,
                                    selected: group,
                                    groups: [
                                      for (final g in searchGroups) g.$1,
                                    ],
                                    assets: [
                                      for (final g in searchGroups) g.$4,
                                    ],
                                    textColor: palette.text,
                                    accent: palette.accent,
                                    onGroup: (index) {
                                      searchFocus.unfocus();
                                      setState(() => group = index);
                                      if (gif) {
                                        query = index < 0
                                            ? ''
                                            : searchGroups[index].$2;
                                        searchGifs();
                                      }
                                      if (scroll.hasClients) scroll.jumpTo(0);
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        query = value.trim();
                                        group = -1;
                                      });
                                      if (gif) {
                                        searchDebounce?.cancel();
                                        gifRequest?.cancel();
                                        generation++;
                                        setState(() {
                                          gifs.clear();
                                          loading = true;
                                          error = null;
                                        });
                                        searchDebounce = Timer(
                                          const Duration(milliseconds: 250),
                                          () {
                                            if (mounted && gif) searchGifs();
                                          },
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                              if (assetError != null || error != null)
                                SliverToBoxAdapter(
                                  child: ScreenStatus(
                                    error: assetError ?? error,
                                    compact: true,
                                    retry: assetError != null
                                        ? () => loadAssets(
                                            DefaultAssetBundle.of(context),
                                          )
                                        : searchGifs,
                                  ),
                                ),
                              if ((loading || loadingAssets) &&
                                  list.every((s) => s.$3.isEmpty))
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.all(36),
                                    child: Center(
                                      child:
                                          CircularProgressIndicator.adaptive(),
                                    ),
                                  ),
                                ),
                              if (!loading &&
                                  !loadingAssets &&
                                  error == null &&
                                  assetError == null &&
                                  list.every((s) => s.$3.isEmpty))
                                SliverToBoxAdapter(
                                  child: ScreenStatus(
                                    compact: true,
                                    title: context.l10n.noResults,
                                  ),
                                ),
                              for (final (id, title, cells) in list) ...[
                                if (title.isNotEmpty)
                                  SliverToBoxAdapter(
                                    key: sectionKeys.putIfAbsent(
                                      id,
                                      GlobalKey.new,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        10,
                                        16,
                                        6,
                                      ),
                                      child: Text(
                                        title.toUpperCase(),
                                        maxLines: 1,
                                        style: AppDesign.font(
                                          13,
                                          weight: FontWeight.w500,
                                          color: sectionColor,
                                        ).copyWith(letterSpacing: .2),
                                      ),
                                    ),
                                  ),
                                SliverPadding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: gif
                                        ? 0
                                        : (grid.inset - grid.spacing / 2).clamp(
                                            0,
                                            99,
                                          ),
                                  ),
                                  sliver: SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: grid.perRow,
                                          mainAxisSpacing: grid.vertical,
                                          crossAxisSpacing: gif
                                              ? grid.spacing
                                              : 0,
                                          mainAxisExtent: emoji
                                              ? (grid.item < 44
                                                    ? 44
                                                    : grid.item)
                                              : grid.item,
                                        ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => _KeyboardCell(
                                        item: emoji && id != 'recent'
                                            ? displayedEmoji(cells[index])
                                            : cells[index],
                                        emoji: emoji,
                                        size: grid.item,
                                        onLongPress: emoji
                                            ? () => chooseTone(cells[index])
                                            : null,
                                        onTap: () => select(
                                          emoji && id != 'recent'
                                              ? displayedEmoji(cells[index])
                                              : cells[index],
                                        ),
                                      ),
                                      childCount: cells.length,
                                    ),
                                  ),
                                ),
                              ],
                              if (gif && offset.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: Center(
                                    child: AppButton.text(
                                      size: AppButtonSize.small,
                                      onPressed: loading
                                          ? null
                                          : () => searchGifs(next: true),
                                      child: Text(context.l10n.more),
                                    ),
                                  ),
                                ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: controlHeight + bottomInset + 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // EntityKeyboardBottomPanelComponent: glass accessories around a
              // glass tab capsule, floating over the content.
              Positioned(
                left: 12,
                right: 12,
                bottom: bottomInset,
                child: Row(
                  children: [
                    if (widget.onKeyboard != null)
                      glassCircle(
                        'keyboard',
                        Icons.keyboard_outlined,
                        context.l10n.showKeyboard,
                        widget.onKeyboard,
                      )
                    else
                      const SizedBox(width: 44),
                    Expanded(
                      child: Center(
                        child: widget.emojiOnly
                            ? const SizedBox.shrink()
                            : AppSegments<String>(
                                key: const ValueKey('emoji.tabs'),
                                contentSized: true,
                                selected: mode,
                                onChanged: switchTab,
                                values: {
                                  if (widget.allowEmoji)
                                    'emoji': const Text('Emoji'),
                                  if (!widget.emojiOnly)
                                    'stickers': Text(context.l10n.stickers),
                                  if (!widget.emojiOnly)
                                    'gif': const Text('GIF'),
                                },
                              ),
                      ),
                    ),
                    if (emoji && widget.onErase != null)
                      glassCircle(
                        'delete.left',
                        Icons.backspace_outlined,
                        context.l10n.deleteLastCharacter,
                        widget.canErase ? widget.onErase : null,
                      )
                    else
                      const SizedBox(width: 44),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    return widget.embedded
        ? content
        : AppScaffold(
            appBar: AppHeader(
              edge: AppHeaderEdge.none,
              title: Text(
                emoji
                    ? 'Emoji'
                    : gif
                    ? 'GIF'
                    : context.l10n.stickers,
              ),
            ),
            body: liquid.GlassModalSheetStateProvider.of(context) != null
                ? content
                : GlassSurface(
                    role: GlassSurfaceRole.sheet,
                    radius: AppDesign.inputMediaPanelCorner,
                    tint: AppDesign.inputMediaPanelColor(context),
                    hostsScrolling: true,
                    child: content,
                  ),
          );
  }
}

/// Grid cell: the slot (item plus spacing) is the touch target; pressed .88.
class _KeyboardCell extends StatelessWidget {
  final Json item;
  final bool emoji;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _KeyboardCell({
    required this.item,
    required this.emoji,
    required this.size,
    required this.onTap,
    this.onLongPress,
  });
  @override
  Widget build(BuildContext context) => AppPressable(
    label: string(item['name'] ?? item['emoji'] ?? item['kind']),
    style: AppPressStyle.emoji,
    onPressed: onTap,
    onLongPress: onLongPress,
    child: Center(
      child: emoji
          ? Text(
              string(item['emoji']),
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Apple Color Emoji',
                fontSize: (size * .8).roundToDouble(),
                height: 1.2,
              ),
            )
          : SizedBox.square(
              dimension: size,
              child: EmoticonView(document: item, size: size),
            ),
    ),
  );
}

class _EmojiSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final List<String> groups, assets;
  final int selected;
  final Color textColor, accent;
  final ValueChanged<int> onGroup;
  final ValueChanged<String> onChanged;
  const _EmojiSearchBar({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.groups,
    required this.assets,
    required this.selected,
    required this.textColor,
    required this.accent,
    required this.onGroup,
    required this.onChanged,
  });
  @override
  State<_EmojiSearchBar> createState() => _EmojiSearchBarState();
}

class _EmojiSearchBarState extends State<_EmojiSearchBar> {
  final strip = ScrollController();
  int statusVersion = 0;

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(changed);
    widget.controller.addListener(changed);
  }

  @override
  void didUpdateWidget(_EmojiSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(changed);
      widget.focusNode.addListener(changed);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(changed);
      widget.controller.addListener(changed);
    }
    if ((oldWidget.selected < 0) != (widget.selected < 0)) statusVersion++;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(changed);
    widget.controller.removeListener(changed);
    strip.dispose();
    super.dispose();
  }

  void choose(int index, double leading, double viewport) {
    final next = index == widget.selected ? -1 : index;
    widget.onGroup(next);
    if (!strip.hasClients) return;
    final start =
        leading +
        index * (AppDesign.emojiSearchIconSize + AppDesign.emojiSearchSpacing);
    final end = start + AppDesign.emojiSearchIconSize;
    var target = strip.offset;
    if (next < 0) {
      target = 0;
    } else if (end - target > viewport - 44) {
      target = end - (viewport - 44);
    } else if (start - target < 44) {
      target = start - 44;
    }
    target = target.clamp(0.0, strip.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      strip.jumpTo(target);
    } else {
      strip.animateTo(
        target,
        duration: AppDesign.emojiSearchTransition,
        curve: Curves.easeInOut,
      );
    }
  }

  void clear() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppDesign.emojiSearchColors(context);
    final hasText = widget.controller.text.isNotEmpty;
    final active = widget.focusNode.hasFocus && widget.selected < 0;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            key: const ValueKey('emoji.search'),
            height: AppDesign.emojiSearchHeight,
            decoration: BoxDecoration(
              color: colors.fill,
              borderRadius: BorderRadius.circular(
                AppDesign.emojiSearchHeight / 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                PositionedDirectional(
                  start: 8,
                  top: 0,
                  bottom: 0,
                  width: 28,
                  child: AppPressable(
                    key: const ValueKey('emoji.search.status'),
                    label: widget.selected >= 0
                        ? MaterialLocalizations.of(context).backButtonTooltip
                        : widget.placeholder,
                    onPressed: widget.selected >= 0
                        ? () {
                            widget.onGroup(-1);
                            if (strip.hasClients) strip.jumpTo(0);
                          }
                        : widget.focusNode.requestFocus,
                    child: Center(
                      child: AppLottie(
                        key: ValueKey('emoji.status.$statusVersion'),
                        asset:
                            'assets/animations/emoji_search/${widget.selected >= 0 ? 'emoji_search_to_arrow' : 'emoji_arrow_to_search'}.json',
                        size: AppDesign.emojiSearchIconSize,
                        color: colors.overlay,
                        autoplay: statusVersion > 0,
                        loop: false,
                        staticProgress: 1,
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 40,
                  end: hasText ? 32 : 8,
                  top: 0,
                  bottom: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    autocorrect: false,
                    textInputAction: TextInputAction.search,
                    cursorColor: widget.accent,
                    style: AppDesign.font(17, color: widget.textColor),
                    decoration: InputDecoration(
                      hintText: active ? widget.placeholder : null,
                      hintStyle: AppDesign.font(17, color: colors.overlay),
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: widget.onChanged,
                  ),
                ),
                if (hasText)
                  PositionedDirectional(
                    end: 0,
                    top: 0,
                    bottom: 0,
                    width: 32,
                    child: AppPressable(
                      key: const ValueKey('emoji.search.clear'),
                      label: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      onPressed: clear,
                      child: Center(
                        child: AppSymbol.icon(
                          'xmark.circle.fill',
                          size: 17,
                          color: colors.overlay,
                          fallback: Icons.cancel,
                        ),
                      ),
                    ),
                  )
                else if (!active)
                  PositionedDirectional(
                    start: 34,
                    end: 0,
                    top: 0,
                    bottom: 0,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final painter = TextPainter(
                          text: TextSpan(
                            text: widget.placeholder,
                            style: AppDesign.font(17),
                          ),
                          textScaler: MediaQuery.textScalerOf(context),
                          textDirection: Directionality.of(context),
                          maxLines: 1,
                        )..layout();
                        final textWidth = painter.width;
                        painter.dispose();
                        final items =
                            widget.groups.length *
                                AppDesign.emojiSearchIconSize +
                            (widget.groups.length - 1) *
                                AppDesign.emojiSearchSpacing;
                        final lead = math.max(
                          8 + textWidth + AppDesign.emojiSearchSpacing,
                          box.maxWidth - 8 - items,
                        );
                        return SingleChildScrollView(
                          controller: strip,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              AppPressable(
                                key: const ValueKey('emoji.search.activate'),
                                label: widget.placeholder,
                                onPressed: widget.focusNode.requestFocus,
                                child: SizedBox(
                                  width: lead,
                                  height: AppDesign.emojiSearchHeight,
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      start: 8,
                                    ),
                                    child: Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: Text(
                                        widget.placeholder,
                                        maxLines: 1,
                                        style: AppDesign.font(
                                          17,
                                          color: colors.overlay,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              for (
                                var i = 0;
                                i < widget.groups.length;
                                i++
                              ) ...[
                                if (i > 0)
                                  const SizedBox(
                                    width: AppDesign.emojiSearchSpacing,
                                  ),
                                AppPressable(
                                  key: ValueKey(
                                    'emoji.group.${widget.assets[i]}',
                                  ),
                                  label: widget.groups[i],
                                  selected: i == widget.selected,
                                  haptic: i != widget.selected,
                                  style: AppPressStyle.emoji,
                                  pressedScale: .8,
                                  onPressed: () =>
                                      choose(i, lead, box.maxWidth),
                                  child: SizedBox(
                                    width: AppDesign.emojiSearchIconSize,
                                    height: AppDesign.emojiSearchHeight,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.none,
                                      children: [
                                        AnimatedOpacity(
                                          opacity: i == widget.selected ? 1 : 0,
                                          duration: reduced
                                              ? Duration.zero
                                              : AppDesign.emojiSearchTransition,
                                          child: Container(
                                            width: AppDesign
                                                .emojiSearchSelectionSize,
                                            height: AppDesign
                                                .emojiSearchSelectionSize,
                                            decoration: BoxDecoration(
                                              color: colors.highlight,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        AppLottie(
                                          asset:
                                              'assets/animations/emoji_search/${widget.assets[i]}.json',
                                          size: AppDesign.emojiSearchIconSize,
                                          color: i == widget.selected
                                              ? colors.selected
                                              : colors.overlay,
                                          loop: false,
                                          staticProgress: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (active)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: AppPressable(
              key: const ValueKey('emoji.search.cancel'),
              label: context.l10n.cancel,
              onPressed: () {
                clear();
                widget.focusNode.unfocus();
              },
              child: SizedBox(
                height: AppDesign.emojiSearchHeight,
                child: Center(
                  child: Text(
                    context.l10n.cancel,
                    style: AppDesign.font(17, color: colors.overlay),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
