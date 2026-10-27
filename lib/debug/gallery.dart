import '../screens/profile_metric.dart';
import '../components/profile_stats.dart';
import '../components/profile_photo_editor.dart';
import '../screens/emoticons.dart';
import '../screens/appearance.dart';
import '../screens/location_picker.dart';
import '../screens/drawing.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../components/app_lottie.dart';
import '../components/glass_surface.dart';
import '../components/components.dart';
import '../core/session.dart';
import '../core/app_failure.dart';
import '../core/api.dart';
import '../l10n/l10n.dart';
import '../screens/auth.dart';
import '../screens/app_forms.dart';
import '../screens/preferences.dart';
import '../screens/radar.dart';
import '../screens/uploads.dart';
import '../screens/feed.dart';
import '../screens/discover.dart';
import '../screens/chat.dart';
import '../screens/profile.dart';
import '../screens/composer.dart';
import '../screens/settings.dart';
import '../screens/places.dart';
import '../screens/classifieds.dart';
import '../screens/media.dart';
import '../screens/shell.dart';
import 'preview_api.dart';

class DebugDestination {
  final String id, group, title;
  final WidgetBuilder build;
  const DebugDestination(this.id, this.group, this.title, this.build);
}

// Screens and sheets use the production widget constructors. No preview copies.
final debugDestinations = <DebugDestination>[
  for (final delete in [false, true])
    DebugDestination(
      delete ? 'confirmation.deleteAccount' : 'confirmation.logout',
      'Bileşenler',
      delete ? 'Hesap silme onayı' : 'Çıkış onayı',
      (context) => _SheetLauncher(
        page: AppConfirmationSheet(
          title: delete
              ? context.l10n.deleteAccountTitle
              : context.l10n.logOut2,
          message: delete
              ? context.l10n.deleteAccountConfirmation
              : context.l10n.areYouSureYouWantTo,
          actions: [
            AppConfirmationAction(
              label: delete ? context.l10n.deleteAccount : context.l10n.logOut,
              result: true,
              destructive: delete,
            ),
          ],
        ),
      ),
    ),
  for (final (id, failure) in [
    ('offline', AppFailure.from(ApiException.connection('Preview'))),
    ('http', AppFailure.from(ApiException('Preview', 503))),
    (
      'register',
      AppFailure.from(
        ApiException('username already exists', 401, 'USER_EXISTS'),
      ),
    ),
    (
      'keychain',
      const AppFailure(
        FailureKind.storage,
        code: 'KEYCHAIN_ENTITLEMENT (-34018)',
      ),
    ),
  ])
    DebugDestination(
      'error.$id',
      'Bileşenler',
      'Hata paneli / $id',
      (_) => _SheetLauncher(
        page: AppErrorSheet(failure: failure, registration: id == 'register'),
      ),
    ),
  DebugDestination(
    'profile.followers',
    'Profil',
    'Profil / takipçiler',
    (_) => ProfileMetricScreen(
      user: previewSelf,
      metric: const ProfileMetric('follower', 'Takipçiler', 0),
    ),
  ),
  DebugDestination(
    'attachment.emoticons',
    'İçerik',
    'Çıkartma ve GIF seçici',
    (_) => const EmoticonPicker(),
  ),
  DebugDestination(
    'attachment.location.teleport',
    'İçerik',
    'Konum değiştir',
    (_) => const LocationPickerScreen(teleport: true),
  ),
  DebugDestination(
    'checkins.list',
    'Keşfet',
    'Check-in / liste',
    (_) => const CheckInsScreen(initialView: 'list'),
  ),
  DebugDestination(
    'attachment.location',
    'İçerik',
    'Konum seçici',
    (_) => const LocationPickerScreen(),
  ),
  // The chat presents the picker as a glass sheet (attachment_controls).
  DebugDestination(
    'attachment.location.sheet',
    'İçerik',
    'Konum seçici / sheet',
    (_) => const _SheetLauncher(page: LocationPickerScreen()),
  ),
  DebugDestination(
    'attachment.drawing',
    'İçerik',
    'Çizim editörü',
    (_) => const DrawingScreen(),
  ),
  for (final tab in ['posts', 'media', 'likes'])
    DebugDestination(
      'profile.$tab',
      'Profil',
      'Profil / $tab',
      (_) => ProfileScreen(initialTab: tab),
    ),
  for (final mode in ['list', 'map'])
    DebugDestination(
      'nearby.$mode',
      'Ana ekranlar',
      'Yakındakiler / $mode',
      (_) => NearbyScreen(initialView: mode),
    ),
  for (final columns in [3, 4])
    DebugDestination(
      'nearby.grid$columns',
      'Ana ekranlar',
      'Yakındakiler / $columns sütun',
      (_) => NearbyScreen(initialColumns: columns),
    ),

  DebugDestination(
    'uploads',
    'İçerik',
    'Yüklemeler ve yeniden deneme',
    (context) => const UploadsScreen(),
  ),
  DebugDestination(
    'components.motion',
    'Bileşenler',
    'Lottie / basılma / Liquid Glass',
    (context) => const MotionPreview(),
  ),
  DebugDestination(
    'profile.preferences',
    'Profil',
    'Profil tercihleri',
    (context) => const PreferencesScreen(),
  ),
  DebugDestination(
    'matches',
    'Keşif',
    'Eşleşmeler / beğenilenler / geçilenler',
    (context) => const MatchesScreen(),
  ),
  DebugDestination(
    'auth.welcome',
    'Hesap',
    'Giriş ve kayıt seçenekleri',
    (context) => const AuthScreen(),
  ),
  DebugDestination(
    'auth.login',
    'Hesap',
    'Giriş',
    (context) => const AuthScreen(showChoices: false),
  ),
  DebugDestination(
    'auth.register',
    'Hesap',
    'Kayıt',
    (context) => const AuthScreen(initialRegister: true),
  ),
  DebugDestination(
    'shell',
    'Ana ekranlar',
    'Sekmeler ve gezinme',
    (context) => const Shell(initialTab: int.fromEnvironment('DEBUG_TAB')),
  ),
  DebugDestination(
    'feed',
    'Ana ekranlar',
    'Ana akış / Vibes',
    (context) => const FeedScreen(),
  ),
  DebugDestination(
    'nearby',
    'Ana ekranlar',
    'Yakındakiler',
    (context) => const NearbyScreen(),
  ),
  DebugDestination(
    'radar',
    'Ana ekranlar',
    'Radar',
    (context) => const RadarScreen(),
  ),
  DebugDestination(
    'checkins',
    'Ana ekranlar',
    'Check-in akışı',
    (context) => const CheckInsScreen(),
  ),
  DebugDestination(
    'chats',
    'Mesajlaşma',
    'Sohbet listesi',
    (context) => const ChatsScreen(),
  ),
  DebugDestination(
    'appearance',
    'Hesap',
    'Görünüm',
    (_) => const AppearanceScreen(),
  ),
  DebugDestination(
    'appearance.background',
    'Hesap',
    'Sohbet arka planı',
    (_) => const ChatBackgroundScreen(),
  ),
  DebugDestination(
    'chat.private',
    'Mesajlaşma',
    'Özel sohbet',
    (context) => ChatScreen(chat: previewChat),
  ),
  DebugDestination(
    'chat.group',
    'Mesajlaşma',
    'Grup sohbeti',
    (context) => ChatScreen(chat: previewGroup),
  ),
  DebugDestination(
    'chat.forward',
    'Mesajlaşma',
    'İlet / sohbet seç',
    (context) => const ForwardScreen(
      draft: ChatForward(
        sourceChatId: 'c1',
        messages: [
          {'id': 'preview-forward-message'},
        ],
      ),
    ),
  ),
  DebugDestination(
    'chat.schedule',
    'Mesajlaşma',
    'Mesajı zamanla',
    (context) => const ScheduleMessageSheet(),
  ),
  DebugDestination(
    'chat.scheduled',
    'Mesajlaşma',
    'Zamanlanmış mesajlar',
    (context) => ScheduledMessagesScreen(chat: previewChat),
  ),
  DebugDestination(
    'chat.create',
    'Mesajlaşma',
    'Yeni sohbet / grup',
    (context) => const NewChatScreen(),
  ),
  DebugDestination(
    'chat.details',
    'Mesajlaşma',
    'Grup bilgileri',
    (context) => GroupScreen(chat: previewGroup),
  ),
  DebugDestination(
    'chat.edit',
    'Mesajlaşma',
    'Grup düzenleme',
    (context) => AppForms.group(context, previewGroup),
  ),
  DebugDestination(
    'profile.self',
    'Profil',
    'Kendi profilim',
    (context) => const ProfileScreen(),
  ),
  DebugDestination(
    'profile.peer',
    'Profil',
    'Kullanıcı profili',
    (context) => ProfileScreen(user: previewPeer),
  ),
  DebugDestination(
    'profile.edit',
    'Profil',
    'Profili düzenle',
    (context) => AppForms.profile(context, previewSelf),
  ),
  for (final kind in ProfilePhotoKind.values)
    DebugDestination(
      'profile.photo.${kind.name}',
      'Profil',
      kind == ProfilePhotoKind.avatar
          ? 'Profil fotoğrafını düzenle'
          : 'Kapak fotoğrafını düzenle',
      (_) => ProfilePhotoEditor(kind: kind),
    ),
  DebugDestination(
    'album.self',
    'Profil',
    'Özel albümüm',
    (context) => const AlbumScreen(),
  ),
  DebugDestination(
    'album.peer',
    'Profil',
    'Başkasının özel albümü',
    (context) => const AlbumScreen(ownerId: '1002'),
  ),
  DebugDestination(
    'album.requests',
    'Profil',
    'Albüm erişim istekleri',
    (context) => const ActivityScreen(accessRequests: true),
  ),
  DebugDestination(
    'friends',
    'Profil',
    'Arkadaşlar',
    (context) => const FriendsScreen(),
  ),
  DebugDestination(
    'post.detail',
    'İçerik',
    'Gönderi ve yanıtlar',
    (context) => PostDetailScreen(post: previewPost),
  ),
  DebugDestination(
    'post.create',
    'İçerik',
    'Gönderi oluştur',
    (context) => const ComposerScreen(),
  ),
  DebugDestination(
    'story.create',
    'İçerik',
    'Hikâye oluştur',
    (context) => const ComposerScreen(story: true),
  ),
  DebugDestination(
    'checkin.create',
    'İçerik',
    'Check-in oluştur',
    (context) => const ComposerScreen(checkIn: true),
  ),
  DebugDestination(
    'media.viewer',
    'İçerik',
    'Medya görüntüleyici',
    (context) => const MediaScreen(
      record: {
        'media': [
          {'localAsset': 'assets/images/brand.png'},
        ],
      },
    ),
  ),
  DebugDestination(
    'search',
    'Keşif',
    'Kullanıcı arama',
    (context) => const SearchScreen(),
  ),
  DebugDestination(
    'places',
    'Keşif',
    'Mekân listesi',
    (context) => const PlacesScreen(),
  ),
  DebugDestination(
    'place.detail',
    'Keşif',
    'Mekân detayı',
    (context) => PlaceScreen(place: previewPlace),
  ),
  DebugDestination(
    'place.comment',
    'Keşif',
    'Mekân yorumu',
    (context) => AppForms.comment(context, previewPlace),
  ),
  DebugDestination(
    'classifieds',
    'İlanlar',
    'İlan listesi',
    (context) => const ClassifiedsScreen(),
  ),
  DebugDestination(
    'classified.detail',
    'İlanlar',
    'İlan detayı',
    (context) => ClassifiedScreen(post: previewClassified),
  ),
  DebugDestination(
    'classified.create',
    'İlanlar',
    'İlan oluştur',
    (context) => AppForms.classified(context, offers: true),
  ),
  DebugDestination('menu', 'Ayarlar', 'Menü', (context) => const MenuScreen()),
  DebugDestination(
    'activity',
    'Ayarlar',
    'Bildirimler',
    (context) => const ActivityScreen(),
  ),
  DebugDestination(
    'settings',
    'Ayarlar',
    'Ayarlar / dil / tema',
    (context) => const SettingsScreen(),
  ),
  DebugDestination(
    'password',
    'Ayarlar',
    'Şifre değiştir',
    (context) => AppForms.password(context),
  ),
  DebugDestination(
    'premium',
    'Ayarlar',
    'Premium',
    (context) => const PremiumScreen(),
  ),
  DebugDestination(
    'legal',
    'Ayarlar',
    'Yasal dokümanlar',
    (context) => const LegalScreen(),
  ),
  for (final id in [
    'privacy',
    'cookies',
    'terms',
    'guidelines',
    'accessibility',
    'about',
    'help',
    'conduct',
  ])
    DebugDestination(
      'legal.$id',
      'Ayarlar',
      'Yasal / $id',
      (context) => LegalDetail(documentId: id),
    ),
];

/// Presents [page] through the production `sheet()` once, and again from
/// its button, so sheet-only layout (submerged corners, keyboard) is seen.
class _SheetLauncher extends StatefulWidget {
  final Widget page;
  const _SheetLauncher({required this.page});
  @override
  State<_SheetLauncher> createState() => _SheetLauncherState();
}

class _SheetLauncherState extends State<_SheetLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => present());
  }

  void present() {
    if (mounted) sheet<Object?>(context, widget.page);
  }

  @override
  Widget build(BuildContext context) => Center(
    child: AppButton(onPressed: present, child: const Text('Sheet')),
  );
}

class DebugGallery extends StatefulWidget {
  const DebugGallery({super.key});
  @override
  State<DebugGallery> createState() => _DebugGalleryState();
}

class _DebugGalleryState extends State<DebugGallery> {
  String query = '';
  PreviewState state = PreviewState.populated;
  @override
  void initState() {
    super.initState();
    const initial = String.fromEnvironment('DEBUG_SCREEN');
    final destination = debugDestinations
        .where((d) => d.id == initial)
        .firstOrNull;
    if (destination != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          open(context, DebugPreview(destination: destination, state: state));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = debugDestinations
        .where(
          (d) => '${d.group} ${d.title} ${d.id}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return AppScaffold(
      appBar: AppHeader(
        title: Text('Ekran kataloğu (${debugDestinations.length})'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Ekran ara',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<PreviewState>(
              initialValue: state,
              decoration: const InputDecoration(labelText: 'Veri durumu'),
              items: [
                for (final s in PreviewState.values)
                  DropdownMenuItem(value: s, child: Text(s.name)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => state = v);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Gerçek ekran bileşenleri • İzole test verileri • Sunucuya işlem gönderilmez',
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: destinations.length,
              itemBuilder: (context, i) {
                final destination = destinations[i];
                return AppRow(
                  title: Text(destination.title),
                  subtitle: Text('${destination.group} · ${destination.id}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(
                    context,
                    DebugPreview(destination: destination, state: state),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DebugPreview extends StatefulWidget {
  final DebugDestination destination;
  final PreviewState state;
  const DebugPreview({
    super.key,
    required this.destination,
    required this.state,
  });
  @override
  State<DebugPreview> createState() => _DebugPreviewState();
}

class _DebugPreviewState extends State<DebugPreview> {
  late final api = PreviewApi(widget.state);
  late final session = Session(api, persistPreferences: false)
    ..ready = true
    ..user = previewSelf
    ..system = previewSystem;
  ThemeMode theme = ThemeMode.light;
  Locale locale = const Locale('tr');
  double textScale = 1;
  bool grid = false;
  int revision = 0;
  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (const bool.fromEnvironment('DEBUG_FULLSCREEN')) {
      return CoolvibesApp(
        session: session,
        home: Builder(builder: widget.destination.build),
      );
    }
    session.themeMode = theme;
    session.locale = locale;
    return AppScaffold(
      appBar: AppHeader(
        title: Text(widget.destination.title),
        actions: [
          AppIconButton(
            tooltip: '8pt ızgara',
            icon: const Icon(Icons.grid_4x4),
            onPressed: () => setState(() => grid = !grid),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 8),
                DropdownButton<PreviewState>(
                  value: api.state,
                  items: [
                    for (final s in PreviewState.values)
                      DropdownMenuItem(value: s, child: Text(s.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        api.state = v;
                        revision++;
                      });
                    }
                  },
                ),
                AppIconButton(
                  tooltip: 'Tema',
                  icon: Icon(
                    theme == ThemeMode.dark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                  ),
                  onPressed: () => setState(
                    () => theme = theme == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  ),
                ),
                DropdownButton<Locale>(
                  value: locale,
                  items: const [
                    DropdownMenuItem(value: Locale('tr'), child: Text('TR')),
                    DropdownMenuItem(value: Locale('en'), child: Text('EN')),
                    DropdownMenuItem(
                      value: Locale('ar'),
                      child: Text('AR / RTL'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => locale = v);
                  },
                ),
                DropdownButton<double>(
                  value: textScale,
                  items: [
                    for (final scale in [1.0, 1.3, 2.0])
                      DropdownMenuItem(value: scale, child: Text('${scale}x')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => textScale = v);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: CoolvibesApp(
                      key: ValueKey(revision),
                      session: session,
                      home: Builder(builder: widget.destination.build),
                    ),
                  ),
                ),
                if (grid)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: GridPaper(
                        color: Color(0x339000ff),
                        interval: 8,
                        divisions: 1,
                        subdivisions: 1,
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
}

class MotionPreview extends StatelessWidget {
  const MotionPreview({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(title: const Text('Hareket ve materyal')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassSurface(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AppPressable(
              label: 'Basılma tepkisi',
              onPressed: () {},
              child: const Center(child: Text('Basılı tut ve bırak')),
            ),
          ),
        ),
        for (final asset in [
          'empty',
          'chat',
          'search',
          'restricted',
          'success',
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(asset),
                AppLottie(asset: 'assets/animations/$asset.json', size: 160),
              ],
            ),
          ),
      ],
    ),
  );
}
