// Port of the source helpers/appearance/{telegramColors,model,palette}.ts,
// itself a port of web features/appearance (tweb themeController, GPL-3.0;
// assets/licenses). Kept line-for-line so resolved colours match exactly.
import '../l10n/l10n.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

typedef Rgb = List<int>;

// ---------------------------------------------------------------- colours

double _clamp(double value, double low, double high) =>
    math.max(low, math.min(high, value));

/// h in [0,360), s and v in [0,1].
List<double> rgbToHsv(num r0, num g0, num b0) {
  final r = r0 / 255, g = g0 / 255, b = b0 / 255;
  final v = math.max(r, math.max(g, b));
  final c = v - math.min(r, math.min(g, b));
  final double h = c == 0
      ? 0
      : (v == r)
      ? (g - b) / c
      : (v == g)
      ? 2 + (b - r) / c
      : 4 + (r - g) / c;
  return [60 * (h < 0 ? h + 6 : h), v == 0 ? 0 : c / v, v];
}

int _jsRound(double value) => (value + .5).floorToDouble().toInt();

Rgb hsvToRgb(double h, double s, double v) {
  int f(double n) {
    final k = (n + h / 60) % 6;
    return _jsRound(
      (v - v * s * math.max(math.min(k, math.min(4 - k, 1)), 0)) * 255,
    );
  }

  return [f(5), f(3), f(1)];
}

class Hsla {
  final double h, s, l, a;
  const Hsla(this.h, this.s, this.l, this.a);
}

Hsla rgbaToHsla(num r0, num g0, num b0, [double a = 1]) {
  final r = r0 / 255, g = g0 / 255, b = b0 / 255;
  final max = math.max(r, math.max(g, b)), min = math.min(r, math.min(g, b));
  double h = 0, s = 0;
  final l = (max + min) / 2;
  if (max != min) {
    final d = max - min;
    s = l > .5 ? d / (2 - max - min) : d / (max + min);
    if (max == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (max == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h /= 6;
  }
  return Hsla(h * 360, s * 100, l * 100, a);
}

List<int> hslaToRgba(double h0, double s0, double l0, double a) {
  final h = h0 / 360, s = s0 / 100, l = l0 / 100;
  double r, g, b;
  if (s == 0) {
    r = g = b = l;
  } else {
    double hue2rgb(double p, double q, double t0) {
      var t = t0;
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    final q = l < .5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }
  return [r, g, b, a].map((v) => _jsRound(v * 255)).toList();
}

Rgb hexToRgb(String hex) {
  final value = hex.startsWith('#') ? hex.substring(1) : hex;
  return [
    int.parse(value.substring(0, 2), radix: 16),
    int.parse(value.substring(2, 4), radix: 16),
    int.parse(value.substring(4, 6), radix: 16),
  ];
}

String rgbaToHexa(List<int> rgba) =>
    '#${rgba.map((v) => v.toRadixString(16).padLeft(2, '0')).map((s) => s.substring(s.length - 2)).join()}';

Rgb mixColors(Rgb color1, Rgb color2, double weight) => [
  for (var i = 0; i < 3; i++)
    (color2[i] + (color1[i] - color2[i]) * weight).floor(),
];

double computePerceivedBrightness(Rgb color) =>
    (color[0] * .2126 + color[1] * .7152 + color[2] * .0722) / 255;

Rgb getAverageColor(Rgb color1, Rgb color2) => [
  for (var i = 0; i < 3; i++) _jsRound((color1[i] + color2[i]) / 2),
];

Rgb getAccentColor(List<double> baseHsv, Rgb baseColor, Rgb elementColor) {
  final hsv3 = rgbToHsv(baseColor[0], baseColor[1], baseColor[2]);
  final hsv4 = rgbToHsv(elementColor[0], elementColor[1], elementColor[2]);
  final dist = math.min(1.5 * hsv3[1] / baseHsv[1], 1.0);
  hsv3[0] = math.min(360, hsv4[0] - hsv3[0] + baseHsv[0]);
  hsv3[1] = math.min(1, hsv4[1] * baseHsv[1] / hsv3[1]);
  hsv3[2] = math.min(1, (hsv4[2] / hsv3[2] + dist - 1) * baseHsv[2] / dist);
  if (hsv3[2] < .3) return elementColor;
  return hsvToRgb(hsv3[0], hsv3[1], hsv3[2]);
}

Rgb changeBrightness(Rgb color, double amount) => color
    .map((v) => _clamp(_jsRound(v * amount).toDouble(), 0, 255).toInt())
    .toList();

Rgb changeColorAccent(
  List<double> baseHsv,
  List<double> accentHsv,
  Rgb color,
  bool isDarkTheme,
) {
  final colorHsv = rgbToHsv(color[0], color[1], color[2]);
  final diffH = math.min(
    (colorHsv[0] - baseHsv[0]).abs(),
    (colorHsv[0] - baseHsv[0] - 360).abs(),
  );
  if (diffH > 30) return color;
  final dist = baseHsv[1] != 0
      ? math.min(1.5 * colorHsv[1] / baseHsv[1], 1.0)
      : 0.0;
  colorHsv[0] = math.min(360, colorHsv[0] + accentHsv[0] - baseHsv[0]);
  colorHsv[1] = baseHsv[1] != 0
      ? math.min(1, colorHsv[1] * accentHsv[1] / baseHsv[1])
      : 0;
  colorHsv[2] = baseHsv[2] != 0
      ? math.min(1, colorHsv[2] * (1 - dist + dist * accentHsv[2] / baseHsv[2]))
      : 0;
  var newColor = hsvToRgb(colorHsv[0], colorHsv[1], colorHsv[2]);
  final origBrightness = computePerceivedBrightness(color);
  final newBrightness = computePerceivedBrightness(newColor);
  final revert = isDarkTheme
      ? origBrightness > newBrightness
      : origBrightness < newBrightness;
  if (revert) {
    const amountOfNew = .6;
    final fallback =
        (1 - amountOfNew) * origBrightness / newBrightness + amountOfNew;
    newColor = changeBrightness(newColor, fallback);
  }
  return newColor;
}

double relativeLuminance(List<num> rgb) {
  double lin(num value) {
    final c = value / 255;
    return c <= .03928
        ? c / 12.92
        : math.pow((c + .055) / 1.055, 2.4).toDouble();
  }

  return .2126 * lin(rgb[0]) + .7152 * lin(rgb[1]) + .0722 * lin(rgb[2]);
}

String darkenToMaxLuminance(String hex, double maxL) {
  if (!RegExp(r'^#[0-9a-f]{6}$', caseSensitive: false).hasMatch(hex))
    return hex;
  final rgb = hexToRgb(hex);
  if (relativeLuminance(rgb) <= maxL) return hex;
  double lo = 0, hi = 1;
  for (var i = 0; i < 20; i++) {
    final f = (lo + hi) / 2;
    if (relativeLuminance([rgb[0] * f, rgb[1] * f, rgb[2] * f]) > maxL) {
      hi = f;
    } else {
      lo = f;
    }
  }
  String c(int v) => _jsRound(v * lo).toRadixString(16).padLeft(2, '0');
  return '#${c(rgb[0])}${c(rgb[1])}${c(rgb[2])}';
}

String ensureTextContrast(String hex, Rgb background, [double ratio = 4.9]) {
  final rgb = hexToRgb(hex);
  final fg = relativeLuminance(rgb);
  final bg = relativeLuminance(background);
  if ((math.max(fg, bg) + .05) / (math.min(fg, bg) + .05) >= ratio) return hex;
  if (bg > .179) return darkenToMaxLuminance(hex, (bg + .05) / ratio - .05);
  final target = ratio * (bg + .05) - .05;
  double low = 0, high = 1;
  for (var i = 0; i < 20; ++i) {
    final amount = (low + high) / 2;
    final mixed = rgb.map((v) => v + (255 - v) * amount).toList();
    if (relativeLuminance(mixed) < target) {
      low = amount;
    } else {
      high = amount;
    }
  }
  return rgbaToHexa(rgb.map((v) => (v + (255 - v) * high).ceil()).toList());
}

// ---------------------------------------------------------------- model

enum BaseTheme { day, night, light, tinted }

/// THEME_CHOICES: the four bases plus following the system.
const themeChoices = ['day', 'night', 'light', 'tinted', 'system'];

class Wallpaper {
  final String kind; // color | gradient | image
  final List<String> colors;
  final int rotation;
  final bool pattern, blur;
  final double intensity;
  final String? source;
  const Wallpaper({
    required this.kind,
    required this.colors,
    this.rotation = 0,
    this.pattern = false,
    this.intensity = 50,
    this.blur = false,
    this.source,
  });
  Wallpaper copyWith({
    String? kind,
    List<String>? colors,
    int? rotation,
    bool? pattern,
    double? intensity,
    bool? blur,
  }) => Wallpaper(
    kind: kind ?? this.kind,
    colors: colors ?? this.colors,
    rotation: rotation ?? this.rotation,
    pattern: pattern ?? this.pattern,
    intensity: intensity ?? this.intensity,
    blur: blur ?? this.blur,
    source: source,
  );
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'colors': colors,
    'rotation': rotation,
    'pattern': pattern,
    'intensity': intensity,
    'blur': blur,
    'source': ?source,
  };
}

class MessageColors {
  final String accent;
  final List<String> colors;
  const MessageColors(this.accent, this.colors);
  Map<String, dynamic> toJson() => {'accent': accent, 'colors': colors};
}

class ThemeSelection {
  final int? preset;
  final String? theme;
  final Wallpaper? wallpaper;
  final MessageColors? messages;
  const ThemeSelection({
    this.preset,
    this.theme,
    this.wallpaper,
    this.messages,
  });
  Map<String, dynamic> toJson() => {
    'preset': preset,
    'theme': ?theme,
    if (wallpaper != null) 'wallpaper': wallpaper!.toJson(),
    if (messages != null) 'messages': messages!.toJson(),
  };
}

class Appearance {
  final String base; // ThemeChoice
  final int textSize;
  final Map<BaseTheme, ThemeSelection> themes;
  const Appearance({
    this.base = 'system',
    this.textSize = 16,
    this.themes = const {
      BaseTheme.day: ThemeSelection(),
      BaseTheme.night: ThemeSelection(),
      BaseTheme.light: ThemeSelection(),
      BaseTheme.tinted: ThemeSelection(),
    },
  });
  Appearance copyWith({
    String? base,
    int? textSize,
    Map<BaseTheme, ThemeSelection>? themes,
  }) => Appearance(
    base: base ?? this.base,
    textSize: textSize ?? this.textSize,
    themes: themes ?? this.themes,
  );
  Appearance withSelection(BaseTheme theme, ThemeSelection selection) =>
      copyWith(themes: {...themes, theme: selection});
  String encode() => jsonEncode({
    'version': 1,
    'base': base,
    'textSize': textSize,
    'themes': {for (final e in themes.entries) e.key.name: e.value.toJson()},
  });
}

class AccentPreset {
  final int id, accentColor;
  final List<int> messageColors;
  final Map<String, dynamic>? wallpaper;
  AccentPreset(this.id, this.accentColor, this.messageColors, this.wallpaper);
}

class ChatThemeVariant {
  final int accentColor;
  final List<int> messageColors;
  final int? outboxAccentColor;
  final List<int> wallpaperColors;
  final double intensity;
  final int rotation;
  final bool pattern;
  final String? source;
  ChatThemeVariant.fromJson(Map<String, dynamic> json)
    : accentColor = json['accent_color'],
      messageColors = List<int>.from(json['message_colors']),
      outboxAccentColor = json['outbox_accent_color'],
      wallpaperColors = List<int>.from(json['wallpaper']['colors']),
      intensity = (json['wallpaper']['intensity'] as num).toDouble(),
      rotation = json['wallpaper']['rotation'] ?? 0,
      pattern = json['wallpaper']['pattern'] == true,
      source = json['wallpaper']['source'];
}

class ChatTheme {
  final String id, emoticon;
  final Map<BaseTheme, ChatThemeVariant> variants;
  ChatTheme(this.id, this.emoticon, this.variants);
}

/// Telegram presets and cloud chat themes (assets/appearance).
class AppearanceCatalog {
  static Map<BaseTheme, List<AccentPreset>> presets = {};
  static List<ChatTheme> themes = [];
  static bool get loaded => themes.isNotEmpty;
  static Future<void> load([AssetBundle? bundle]) async {
    if (loaded) return;
    final source = bundle ?? rootBundle;
    final presetJson =
        jsonDecode(
              await source.loadString(
                'assets/appearance/telegram-presets.json',
              ),
            )
            as Map<String, dynamic>;
    final themeJson =
        jsonDecode(
              await source.loadString('assets/appearance/telegram-themes.json'),
            )
            as List;
    presets = {
      for (final base in BaseTheme.values)
        base: [
          for (final p in presetJson[base.name] as List)
            AccentPreset(
              p['id'],
              p['accent_color'],
              List<int>.from(p['message_colors']),
              p['wallpaper'] == null
                  ? null
                  : Map<String, dynamic>.from(p['wallpaper']),
            ),
        ],
    };
    themes = [
      for (final t in themeJson)
        ChatTheme(t['id'], t['emoticon'], {
          for (final base in BaseTheme.values)
            base: ChatThemeVariant.fromJson(
              Map<String, dynamic>.from(t['variants'][base.name]),
            ),
        }),
    ];
  }
}

const backgroundColors = [
  '#E6EBEE',
  '#B2CEE1',
  '#008DD0',
  '#C6E7CB',
  '#C4E1A6',
  '#60B16E',
  '#CCD0AF',
  '#A6A997',
  '#7A7072',
  '#FDD7AF',
  '#FDB76E',
  '#DD8851',
];

String hexOf(int value) => '#${value.toRadixString(16).padLeft(6, '0')}';
List<int> telegramWallpaperColors(List<int> colors) => [
  for (var i = 0; i < colors.length; i++)
    if (i == 0 || colors[i] != 0) colors[i],
];
bool validColor(dynamic value) =>
    value is String &&
    RegExp(r'^#[0-9a-f]{6}$', caseSensitive: false).hasMatch(value);

Appearance readAppearance(String? raw) {
  var result = const Appearance();
  if (raw == null) return result;
  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1) return result;
    final base = themeChoices.contains(data['base'])
        ? data['base'] as String
        : 'system';
    final size = data['textSize'] is num
        ? (data['textSize'] as num).round().clamp(12, 20)
        : 16;
    final themes = <BaseTheme, ThemeSelection>{};
    for (final theme in BaseTheme.values) {
      final entry = (data['themes'] as Map?)?[theme.name] as Map?;
      String? chat =
          AppearanceCatalog.themes.any((t) => t.id == entry?['theme'])
          ? entry!['theme']
          : null;
      int? preset =
          (AppearanceCatalog.presets[theme] ?? []).any(
            (p) => p.id == entry?['preset'],
          )
          ? entry!['preset']
          : null;
      Wallpaper? wallpaper;
      final wp = entry?['wallpaper'] as Map?;
      if (wp != null &&
          ['color', 'gradient', 'image'].contains(wp['kind']) &&
          wp['colors'] is List &&
          (wp['colors'] as List).isNotEmpty &&
          (wp['colors'] as List).length <= 4 &&
          (wp['colors'] as List).every(validColor)) {
        final source = wp['source'];
        wallpaper = Wallpaper(
          kind: wp['kind'],
          colors: List<String>.from(wp['colors']),
          rotation: wp['rotation'] is num
              ? (wp['rotation'] as num).abs().toInt() % 360
              : 0,
          pattern: wp['pattern'] == true,
          intensity: wp['intensity'] is num
              ? (wp['intensity'] as num).toDouble().clamp(0, 100)
              : 50,
          blur: wp['blur'] == true,
          source:
              source is String &&
                  RegExp(r'^/images/chat/[\w-]+\.svg$').hasMatch(source)
              ? source
              : null,
        );
      }
      MessageColors? messages;
      final m = entry?['messages'] as Map?;
      if (m != null &&
          validColor(m['accent']) &&
          m['colors'] is List &&
          (m['colors'] as List).isNotEmpty &&
          (m['colors'] as List).length <= 2 &&
          (m['colors'] as List).every(validColor)) {
        messages = MessageColors(m['accent'], List<String>.from(m['colors']));
      }
      themes[theme] = ThemeSelection(
        preset: preset,
        theme: chat,
        wallpaper: wallpaper,
        messages: messages,
      );
    }
    result = Appearance(base: base, textSize: size, themes: themes);
  } catch (_) {}
  return result;
}

class _Base {
  final String accent, surface, background, text, secondary, border, incoming;
  final List<int> bubble, wallpaper;
  const _Base(
    this.accent,
    this.surface,
    this.background,
    this.text,
    this.secondary,
    this.border,
    this.incoming,
    this.bubble,
    this.wallpaper,
  );
}

_Base _baseOf(BaseTheme base) => switch (base) {
  BaseTheme.day => const _Base(
    '#3390ec',
    '#ffffff',
    '#f4f4f5',
    '#000000',
    '#707579',
    '#dfe1e5',
    '#ffffff',
    [0x5ca853],
    [0xdbddbb, 0x6ba587, 0xd5d88d, 0x88b884],
  ),
  BaseTheme.night => const _Base(
    '#8774e1',
    '#212121',
    '#181818',
    '#ffffff',
    '#aaaaaa',
    '#0f0f0f',
    '#212121',
    [0x8774e1],
    [0xfec496, 0xdd6cb9, 0x962fbf, 0x4f5bd5],
  ),
  BaseTheme.light => const _Base(
    '#2d7ed5',
    '#ffffff',
    '#f4f4f5',
    '#333333',
    '#8c8e91',
    '#dfe1e5',
    '#f0f0f0',
    [0x2d7ed5],
    [0xb1e0fa, 0x82b0d8, 0xa0d8e8, 0xe5f0f8],
  ),
  BaseTheme.tinted => _Base(
    '#0088ff',
    '#1d2733',
    '#151e27',
    '#ffffff',
    '#7d8b99',
    '#0f151b',
    '#232e3b',
    AppearanceCatalog.presets[BaseTheme.tinted]?.first.messageColors ??
        const [0x3685fa],
    [0x1e3557, 0x182036, 0x1c4352, 0x16263a],
  ),
};

/// The resolved palette (source palette.ts `adapt(resolveTheme(...))`).
class ResolvedAppearance {
  final BaseTheme base;
  final bool dark;
  final String accent, surface, background, text, secondary, border, incoming;
  final String outgoing,
      thumbnailOutgoing,
      sourceAccent,
      outgoingText,
      outgoingPrimary;
  final List<String> outgoingStops, sourceMessageColors;
  final bool outgoingGradient;
  final String outgoingMeta; // '#rrggbb' or '#rrggbbaa'
  final int textSize;
  final Wallpaper wallpaper;
  const ResolvedAppearance({
    required this.base,
    required this.dark,
    required this.accent,
    required this.surface,
    required this.background,
    required this.text,
    required this.secondary,
    required this.border,
    required this.incoming,
    required this.outgoing,
    required this.thumbnailOutgoing,
    required this.sourceAccent,
    required this.outgoingText,
    required this.outgoingPrimary,
    required this.outgoingStops,
    required this.sourceMessageColors,
    required this.outgoingGradient,
    required this.outgoingMeta,
    required this.textSize,
    required this.wallpaper,
  });

  /// palette.ts adapt(): contrast text, input, pinned and highlight fills.
  String get accentText =>
      relativeLuminance(hexToRgb(accent)) > .179 ? '#000000' : '#ffffff';
  String get input =>
      rgbaToHexa(mixColors(hexToRgb(secondary), hexToRgb(surface), .12));
  String get pinned => rgbaToHexa(
    mixColors(
      hexToRgb(text),
      hexToRgb(surface),
      relativeLuminance(hexToRgb(surface)) < .2 ? .05 : .035,
    ),
  );
  String get highlight => rgbaToHexa(
    mixColors(
      hexToRgb(accent),
      hexToRgb(surface),
      relativeLuminance(hexToRgb(surface)) < .2 ? .22 : .12,
    ),
  );
}

BaseTheme resolvedBase(Appearance appearance, bool systemDark) =>
    appearance.base == 'system'
    ? (systemDark ? BaseTheme.night : BaseTheme.day)
    : BaseTheme.values.byName(appearance.base);

ResolvedAppearance resolveAppearance(Appearance appearance, bool systemDark) {
  final base = resolvedBase(appearance, systemDark);
  return resolveTheme(
    base,
    appearance.themes[base] ?? const ThemeSelection(),
    appearance.textSize,
  );
}

String _alphaHex(int r, int g, int b, double a) =>
    '#${[r, g, b, (a * 255).round()].map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';

ResolvedAppearance resolveTheme(
  BaseTheme base, [
  ThemeSelection selection = const ThemeSelection(),
  int textSize = 16,
]) {
  final original = _baseOf(base);
  final dark = base == BaseTheme.night || base == BaseTheme.tinted;
  final themeBundle = AppearanceCatalog.themes
      .where((t) => t.id == selection.theme)
      .firstOrNull;
  final chatTheme = themeBundle?.variants[base];
  var themeWallpaper = chatTheme;
  if (base == BaseTheme.light &&
      themeWallpaper != null &&
      !themeWallpaper.pattern &&
      themeWallpaper.source == null &&
      themeWallpaper.wallpaperColors.first == 0xffffff &&
      themeWallpaper.wallpaperColors.skip(1).every((c) => c == 0)) {
    themeWallpaper = themeBundle!.variants[BaseTheme.day];
  }
  final presets = AppearanceCatalog.presets[base] ?? const <AccentPreset>[];
  final picked = presets.where((p) => p.id == selection.preset).firstOrNull;
  final presetAccent = chatTheme?.accentColor ?? picked?.accentColor;
  final presetMessages = chatTheme?.messageColors ?? picked?.messageColors;
  final custom = selection.messages;
  final sourceAccent = custom != null
      ? custom.accent
      : presetAccent != null
      ? hexOf(presetAccent)
      : original.accent;
  var accent = custom != null
      ? ensureTextContrast(custom.accent, hexToRgb(original.surface), 3)
      : sourceAccent;
  var surface = original.surface,
      background = original.background,
      secondary = original.secondary;
  var border = original.border, incoming = original.incoming;
  if (base == BaseTheme.tinted) {
    final rgb = hexToRgb(accent);
    final hsv = rgbToHsv(rgb[0], rgb[1], rgb[2]);
    final v = math.max(hsv[2], .18);
    String multiplied(double h, double s, double b) => rgbaToHexa(
      hsvToRgb(hsv[0] * h % 360, math.min(1, hsv[1] * s), math.min(1, v * b)),
    );
    accent = rgbaToHexa(hsvToRgb(hsv[0], hsv[1], v));
    surface = incoming = multiplied(1.024, .585, .25);
    background = multiplied(1.024, .573, .18);
    border = multiplied(1.033, .426, .34);
    secondary = multiplied(.956, .17, 1);
    if (custom != null)
      secondary = ensureTextContrast(secondary, hexToRgb(surface), 4.5);
  } else if (custom == null) {
    final o = hexToRgb(original.accent), a = hexToRgb(accent);
    accent = rgbaToHexa(
      changeColorAccent(
        rgbToHsv(o[0], o[1], o[2]),
        rgbToHsv(a[0], a[1], a[2]),
        o,
        !dark,
      ),
    );
  }
  final sourceMessageColors = custom != null
      ? custom.colors
      : (presetMessages ?? original.bubble).map(hexOf).toList();
  final baseMessageColor = hexToRgb(
    base == BaseTheme.tinted ? '#3685fa' : hexOf(original.bubble.first),
  );
  final surfaceRgb = hexToRgb(surface);
  final weight = dark ? 1.0 : .12;
  final raw = sourceMessageColors.map(hexToRgb).toList();
  var messageAccent = raw.first;
  if (raw.length > 1) {
    messageAccent = raw.skip(1).fold(messageAccent, getAverageColor);
    messageAccent = getAccentColor(
      rgbToHsv(baseMessageColor[0], baseMessageColor[1], baseMessageColor[2]),
      mixColors(baseMessageColor, surfaceRgb, weight),
      messageAccent,
    );
  }
  var outgoing = mixColors(messageAccent, surfaceRgb, weight);
  if (!dark) {
    final hsl = rgbaToHsla(outgoing[0], outgoing[1], outgoing[2]);
    outgoing = hslaToRgba(
      hsl.h,
      math.min(hsl.s + 63, 100),
      hsl.l,
      hsl.a,
    ).sublist(0, 3);
  }
  final customLight =
      custom != null &&
      relativeLuminance(custom.colors.map(hexToRgb).reduce(getAverageColor)) >
          .179;
  final customText = customLight ? '#000000' : '#ffffff';
  final outgoingHex = rgbaToHexa(outgoing);
  final outboxAccent = custom != null ? null : chatTheme?.outboxAccentColor;
  final outgoingPrimary = dark
      ? '#ffffff'
      : rgbaToHexa(
          outboxAccent == null ? messageAccent : hexToRgb(hexOf(outboxAccent)),
        );
  final thumbnailOutgoing = rgbaToHexa(
    mixColors(
      dark
          ? [255, 255, 255]
          : outboxAccent == null
          ? messageAccent
          : hexToRgb(hexOf(outboxAccent)),
      outgoing,
      .08,
    ),
  );
  final wp = picked?.wallpaper;
  final colors = wp != null
      ? telegramWallpaperColors([
          for (final key in [
            'background_color',
            'second_background_color',
            'third_background_color',
            'fourth_background_color',
          ])
            if (wp[key] != null) wp[key] as int,
        ]).map(hexOf).toList()
      : original.wallpaper.map(hexOf).toList();
  var themeColors = themeWallpaper == null
      ? null
      : telegramWallpaperColors(
          themeWallpaper.wallpaperColors,
        ).map(hexOf).toList();
  if (chatTheme != null && base == BaseTheme.tinted) {
    final accentRgb = hexToRgb(hexOf(chatTheme.accentColor));
    int distance(int color) {
      final c = hexToRgb(hexOf(color));
      var sum = 0;
      for (var i = 0; i < 3; i++) {
        sum += (c[i] - accentRgb[i]) * (c[i] - accentRgb[i]);
      }
      return sum;
    }

    final nearest = presets.reduce(
      (best, candidate) =>
          distance(candidate.accentColor) < distance(best.accentColor)
          ? candidate
          : best,
    );
    final target = nearest.wallpaper!;
    final targets = [
      target['background_color'],
      target['second_background_color'],
      target['third_background_color'],
      target['fourth_background_color'],
    ];
    themeColors = [
      for (var index = 0; index < chatTheme.wallpaperColors.length; index++)
        () {
          final p = hexToRgb(hexOf(chatTheme.wallpaperColors[index]));
          final t = hexToRgb(
            hexOf(
              (targets.length > index ? targets[index] : null) ??
                  target['background_color'],
            ),
          );
          return rgbaToHexa([
            for (var i = 0; i < 3; i++) _jsRound(t[i] * .85 + p[i] * .15),
          ]);
        }(),
    ];
  }
  final wallpaper =
      selection.wallpaper ??
      (themeWallpaper != null
          ? Wallpaper(
              kind: themeColors!.length > 1 ? 'gradient' : 'color',
              colors: themeColors,
              pattern: themeWallpaper.pattern,
              intensity: base == BaseTheme.tinted
                  ? 38
                  : themeWallpaper.intensity.abs(),
              source: themeWallpaper.source,
            )
          : Wallpaper(
              kind: 'gradient',
              colors: colors,
              pattern: true,
              intensity: base == BaseTheme.tinted
                  ? 38
                  : (wp?['intensity'] as num?)?.toDouble() ?? 50,
            ));
  final outgoingFill = custom != null ? custom.colors.last : outgoingHex;
  final stops = custom != null && custom.colors.length > 1
      ? [custom.colors.first, custom.colors.last]
      : [
          custom?.colors.first ?? outgoingHex,
          custom?.colors.first ?? outgoingHex,
        ];
  return ResolvedAppearance(
    base: base,
    dark: dark,
    accent: accent,
    surface: surface,
    background: background,
    text: original.text,
    secondary: secondary,
    border: border,
    incoming: incoming,
    outgoing: outgoingFill,
    thumbnailOutgoing: custom != null ? custom.colors.first : thumbnailOutgoing,
    sourceAccent: sourceAccent,
    sourceMessageColors: sourceMessageColors,
    outgoingText: custom != null ? customText : original.text,
    outgoingPrimary: custom != null ? customText : outgoingPrimary,
    outgoingMeta: custom != null
        ? (customLight ? _alphaHex(0, 0, 0, .55) : _alphaHex(255, 255, 255, .7))
        : dark
        ? _alphaHex(255, 255, 255, .6)
        : outgoingPrimary,
    outgoingStops: stops,
    outgoingGradient: custom != null && custom.colors.length > 1,
    textSize: textSize,
    wallpaper: wallpaper,
  );
}

/// THEME_LABELS in AppearancePreview.tsx.
final themeLabels = <String, String Function(AppLocalizations)>{
  'day': (AppLocalizations l) => l.themeClassic,
  'night': (AppLocalizations l) => l.themeNight,
  'light': (AppLocalizations l) => l.themeDay,
  'tinted': (AppLocalizations l) => l.themeDark,
  'system': (AppLocalizations l) => l.themeSystemDefault,
};
