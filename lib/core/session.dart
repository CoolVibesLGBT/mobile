import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'appearance.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api.dart';
import 'app_failure.dart';
import 'upload_queue.dart';
import 'realtime.dart';

class Session extends ChangeNotifier with WidgetsBindingObserver {
  final Api api;
  final bool persistPreferences;
  late final UploadQueue uploads = UploadQueue(api);
  Json user = {};
  final recentEmoji = <String>[];
  int emojiSkinTone = 0;
  final recentStickers = <Json>[];
  void _clearRecents() {
    recentEmoji.clear();
    emojiSkinTone = 0;
    recentStickers.clear();
  }

  Json system = {};
  bool updatingPreferences = false;
  bool _disposed = false;
  int mediaRevision = 0;
  bool ready = false;
  String? startupError;
  ThemeMode themeMode = ThemeMode.system;

  /// The web/RN Appearance model (base theme, presets, wallpaper, text size).
  Appearance appearanceModel = const Appearance();
  String? wallpaperImage;
  static const appearanceKey = 'coolvibes.appearance.v2';
  Locale locale = const Locale('tr');
  final AppRealtime realtime;
  StreamSubscription<RealtimeEvent>? _liveEvents;
  bool _observingLifecycle = false;
  io.Socket? get socket => realtime.socket;

  void _connectionChanged() => notifyListeners();

  void invalidateMedia() {
    mediaRevision++;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && api.token != null) {
      realtime.resume();
    }
  }

  Session(this.api, {this.persistPreferences = true, AppRealtime? realtime})
    : realtime = realtime ?? AppRealtime() {
    this.realtime.addListener(_connectionChanged);
    _liveEvents = this.realtime.events.listen((event) {
      if (event.name == 'private_photo_changed' || event.name == 'sync') {
        invalidateMedia();
      }
    });
    api.onUnauthorized = (expired) async {
      if (await api.invalidate(expired)) {
        await uploads.attach('');
        this.realtime.disconnect();
        user = {};
        _clearRecents();
        mediaRevision++;
        notifyListeners();
      }
    };
  }
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString('language');
      if (language != null) locale = Locale(language);
      await AppearanceCatalog.load();
      final saved = prefs.getString(appearanceKey);
      if (saved != null) {
        final data = object(jsonDecode(saved));
        appearanceModel = readAppearance(jsonEncode(data['appearance']));
        final image = data['wallpaperImage'];
        wallpaperImage = image is String && File(image).existsSync()
            ? image
            : null;
      } else {
        // Previous Flutter builds stored only a light/dark mode.
        final legacy = prefs.getString('theme');
        appearanceModel = Appearance(
          base: legacy == 'dark'
              ? 'night'
              : legacy == 'light'
              ? 'day'
              : 'system',
        );
      }
      themeMode = _modeFor(appearanceModel);
      await api.restore();
      if (api.token != null) {
        try {
          await refreshUser();
          connect();
        } on ApiException catch (e) {
          if (e.status == 401) {
            await api.clearToken();
          } else {
            startupError = e.message;
          }
        }
      }
    } catch (e) {
      startupError = '$e';
    }
    ready = true;
    notifyListeners();
    syncSystem();
  }

  Future<void> retryStartup() async {
    if (!ready) return;
    ready = false;
    startupError = null;
    notifyListeners();
    try {
      await refreshUser();
      connect();
    } catch (e) {
      startupError = '$e';
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  Future<void> syncSystem({bool throwOnError = false}) async {
    try {
      final response = await api.call('system.initial_sync', get: true);
      if (_disposed) return;
      system = object(response['data'] ?? response);
      notifyListeners();
    } catch (_) {
      if (throwOnError) rethrow;
    }
  }

  Future<void> updatePreference(Json group, Json item, bool enabled) async {
    if (updatingPreferences || _disposed) return;
    updatingPreferences = true;
    final requestToken = api.token;
    notifyListeners();
    try {
      final tag = string(group['tag'] ?? group['slug']);
      final kind = group['_kind'];
      final identity = {
        'gender_identity': 'gender_identity_id',
        'sexual_orientation': 'sexual_orientation_id',
        'sex_role': 'sexual_role_id',
      }[tag];
      final modern = item['bit_index'] is num;
      final result = await api.call(
        modern
            ? 'user.update_preferences'
            : identity != null
            ? 'user.update_identify'
            : kind == 'interests'
            ? 'user.update_interest'
            : kind == 'fantasies'
            ? 'user.update_fantasy'
            : 'user.update_attribute',
        body: modern
            ? {
                'id': item['id'],
                'bit_index': item['bit_index'],
                'enabled': enabled,
              }
            : {
                identity ??
                        (kind == 'interests'
                            ? 'interest_id'
                            : kind == 'fantasies'
                            ? 'fantasy_id'
                            : 'attribute_id'):
                    item['id'],
              },
      );
      if (_disposed || requestToken != api.token) return;
      final updated = object(object(result['data'])['user'] ?? result['user']);
      if (updated.isEmpty) {
        await refreshUser();
      } else {
        user = {...user, ...updated};
        // A partial legacy projection must not leave old set-bit indices
        // overriding the new flags returned by the server.
        if (updated['preferences_flags'] != null &&
            updated['selected_preference_bits'] == null) {
          user.remove('selected_preference_bits');
        }
      }
    } finally {
      updatingPreferences = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    final requestToken = api.token;
    final result = await api.call('auth.user_info');
    if (_disposed || requestToken != api.token) return;
    final data = object(result['data']);
    final restored = object(data['user'] ?? result['user'] ?? result['data']);
    if (restored.isEmpty) throw ApiException('Invalid user response');
    user = restored;
    final owner = string(user['public_id'] ?? user['id']);
    if (owner != uploads.owner) await uploads.attach(owner);
    notifyListeners();
  }

  Future<void> authenticate(Json fields, {bool register = false}) async {
    final response = await api.call(
      register ? 'auth.register' : 'auth.login',
      body: fields,
    );
    final data = object(response['data']);
    final token = string(data['token']);
    if (token.isEmpty) throw ApiException('Invalid authentication response');
    try {
      await api.saveToken(token);
    } catch (error) {
      throw AuthenticationCompletionException(error, accountCreated: register);
    }
    _clearRecents();
    user = object(data['user']);
    if (string(user['public_id'] ?? user['id']).isEmpty) {
      try {
        await refreshUser();
      } catch (_) {
        await api.clearToken();
        user = {};
        rethrow;
      }
    }
    await uploads.attach(string(user['public_id'] ?? user['id']));
    startupError = null;
    connect();
    notifyListeners();
  }

  void connect() {
    if (api.isPreview || api.token == null) return;
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
    realtime.connect(url: Api.socketUrl, token: api.token!);
  }

  Future<void> logout() async {
    try {
      await api.call('auth.logout');
    } catch (_) {}
    await _clearSession();
  }

  Future<void> deleteAccount() async {
    await api.call('user.delete_profile');
    await _clearSession();
  }

  Future<void> _clearSession() async {
    realtime.disconnect();
    await uploads.attach('');
    await api.clearToken();
    user = {};
    _clearRecents();
    mediaRevision++;
    notifyListeners();
  }

  static ThemeMode _modeFor(Appearance value) => value.base == 'system'
      ? ThemeMode.system
      : value.base == 'night' || value.base == 'tinted'
      ? ThemeMode.dark
      : ThemeMode.light;

  /// The base theme the UI currently shows.
  BaseTheme currentBase(BuildContext context) => resolvedBase(
    appearanceModel,
    MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  );

  void updateAppearance(
    Appearance next, {
    String? image,
    bool clearImage = false,
  }) {
    appearanceModel = next;
    if (image != null) wallpaperImage = image;
    if (clearImage) wallpaperImage = null;
    themeMode = _modeFor(next);
    if (persistPreferences) {
      final value = jsonEncode({
        'fontSize': 'medium',
        'appearance': jsonDecode(next.encode()),
        'wallpaperImage': wallpaperImage,
      });
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(appearanceKey, value),
      );
    }
    notifyListeners();
  }

  /// Kept for callers that only switch light/dark.
  void appearance(ThemeMode mode) => updateAppearance(
    appearanceModel.copyWith(
      base: mode == ThemeMode.dark
          ? 'night'
          : mode == ThemeMode.light
          ? 'day'
          : 'system',
    ),
  );

  void language(Locale value) {
    locale = value;
    if (persistPreferences) {
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString('language', value.languageCode),
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    api.onUnauthorized = null;
    if (_observingLifecycle) WidgetsBinding.instance.removeObserver(this);
    _liveEvents?.cancel();
    realtime.removeListener(_connectionChanged);
    realtime.dispose();
    uploads.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<Session> {
  const AppScope({super.key, required Session session, required super.child})
    : super(notifier: session);
  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
