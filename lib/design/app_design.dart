import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/appearance.dart';

/// Semantic colours of the source `useNativePalette()` (NativeStyle.ts) over the
/// default `resolvePalette(defaultAppearance())`: Telegram Day for light and
/// Telegram Night for dark, exactly as the React Native app resolves them.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background, row, text, secondaryLabel, border, accent, accentText;
  final Color destructive, highlight, disclosure, input, pinned;
  final Color glassSelection, glassEdge, incoming, outgoing, outgoingText;
  final Color outgoingMeta, success;

  /// The chat palette's accent wash (palette.ts `highlight`) for pressed chat
  /// rows; [highlight] is the system list highlight of NativeStyle.
  final Color chatHighlight, outgoingPrimary;
  final List<Color> outgoingStops;
  final String outgoingGradientType;
  final double outgoingGradientAngle;
  final double textSize;

  /// The full resolved appearance (wallpaper, base) when built from one.
  final ResolvedAppearance? resolved;
  const AppPalette({
    this.chatHighlight = const Color(0xffe6f1fc),
    this.outgoingPrimary = const Color(0xff5ca853),
    this.outgoingStops = const [Color(0xffe3fee0), Color(0xffe3fee0)],
    this.outgoingGradientType = 'linear',
    this.outgoingGradientAngle = 90,
    this.textSize = 16,
    this.resolved,
    required this.background,
    required this.row,
    required this.text,
    required this.secondaryLabel,
    required this.border,
    required this.accent,
    required this.accentText,
    required this.destructive,
    required this.highlight,
    required this.disclosure,
    required this.input,
    required this.pinned,
    required this.glassSelection,
    required this.glassEdge,
    required this.incoming,
    required this.outgoing,
    required this.outgoingText,
    required this.outgoingMeta,
    required this.success,
  });

  static const day = AppPalette(
    background: Color(0xfff4f4f5),
    row: Color(0xffffffff),
    text: Color(0xff000000),
    secondaryLabel: Color(0xff707579),
    border: Color(0xffdfe1e5),
    accent: Color(0xff3390ec),
    accentText: Color(0xff000000),
    destructive: Color(0xffc92820),
    highlight: Color(0xffe5e5ea),
    disclosure: Color(0xffc7c7cc),
    input: Color(0xffedeeee),
    pinned: Color(0xfff6f6f6),
    glassSelection: Color(0xc2ffffff),
    glassEdge: Color(0xe6ffffff),
    incoming: Color(0xffffffff),
    outgoing: Color(0xffe3fee0),
    outgoingText: Color(0xff000000),
    outgoingMeta: Color(0xff5ca853),
    success: Color(0xff34c759),
  );

  static const night = AppPalette(
    background: Color(0xff181818),
    row: Color(0xff212121),
    text: Color(0xffffffff),
    secondaryLabel: Color(0xffaaaaaa),
    border: Color(0xff0f0f0f),
    accent: Color(0xff8774e1),
    accentText: Color(0xff000000),
    destructive: Color(0xffff6961),
    highlight: Color(0xff313135),
    disclosure: Color(0xff5a5a5e),
    input: Color(0xff313131),
    pinned: Color(0xff2c2c2c),
    glassSelection: Color(0x1fffffff),
    glassEdge: Color(0x24ffffff),
    incoming: Color(0xff212121),
    outgoing: Color(0xff8774e1),
    outgoingText: Color(0xffffffff),
    outgoingMeta: Color(0x99ffffff),
    success: Color(0xff30d158),
  );

  static Color _hex(String value) {
    final hex = value.replaceAll('#', '');
    final rgb = int.parse(hex.substring(0, 6), radix: 16);
    final alpha = hex.length == 8
        ? int.parse(hex.substring(6, 8), radix: 16)
        : 255;
    return Color((alpha << 24) | rgb);
  }

  /// useNativePalette() over a resolved appearance.
  factory AppPalette.fromResolved(ResolvedAppearance r) {
    final dark = r.dark;
    final fallback = dark ? night : day;
    return AppPalette(
      background: _hex(r.background),
      row: _hex(r.surface),
      text: _hex(r.text),
      secondaryLabel: _hex(r.secondary),
      border: _hex(r.border),
      accent: _hex(r.accent),
      accentText: _hex(r.accentText),
      destructive: fallback.destructive,
      highlight: fallback.highlight,
      disclosure: fallback.disclosure,
      input: _hex(r.input),
      pinned: _hex(r.pinned),
      glassSelection: fallback.glassSelection,
      glassEdge: fallback.glassEdge,
      incoming: _hex(r.incoming),
      outgoing: _hex(r.outgoing),
      outgoingText: _hex(r.outgoingText),
      outgoingMeta: _hex(r.outgoingMeta),
      success: fallback.success,
      chatHighlight: _hex(r.highlight),
      outgoingPrimary: _hex(r.outgoingPrimary),
      outgoingStops: r.outgoingStops.map(_hex).toList(),
      outgoingGradientType: r.outgoingGradientType,
      outgoingGradientAngle: r.outgoingGradientAngle,
      textSize: r.textSize.toDouble(),
      resolved: r,
    );
  }

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ??
      (Theme.of(context).brightness == Brightness.dark ? night : day);

  @override
  AppPalette copyWith() => this;
  @override
  AppPalette lerp(AppPalette? other, double t) =>
      other == null || t < .5 ? this : other;
}

/// Measurements transcribed from the source NativeStyle.ts and Telegram-iOS.
/// ItemListDisclosureItem.swift: 16pt leading inset, 17pt text, 15/17 detail.
/// ChatTextInputPanelNode.swift: 17pt text, 8pt panel horizontal inset.
abstract final class AppDesign {
  // TGPhotoAvatarCropView.areaInsetSize and TGPhotoEditorInterfaceAssets.
  static const photoCropInset = 10.0;
  static const photoCropShade = Color(0xb3000000);
  // web/src/styles/telegram-panels.css and telegram-foundation.css.
  static const authFontFamily = 'WebRoboto';
  static const authMaxWidth = 560.0;
  static const authControlRadius = 16.0;
  static const authHeadingImageSize = 102.0;
  static const authChoiceImageSize = 128.0;
  static const authCompactChoiceImageSize = 88.0;
  // The renderer's frost samples live content; tint is only a light overlay.
  // Do not substitute a mostly opaque white fill for backdrop refraction.
  static const glassInputLight = Color.fromRGBO(255, 255, 255, .72);
  static const glassSheetLight = Color.fromRGBO(255, 255, 255, .86);
  // GlassBackgroundComponent regular material fallback.
  static const glassMenuLight = Color.fromRGBO(255, 255, 255, .7);
  static const glassMenuDark = Color.fromRGBO(28, 28, 28, .85);
  static const glassFrostedDark = Color.fromRGBO(28, 28, 30, .82);
  static const glassSurfaceBlur = 16.0;
  // Telegram GlassBackgroundComponent/TouchEffect.swift, Parameters and
  // currentTransform: size-based lift and volume-preserving drag stretch.
  static const glassPressGrowth = 20.0;
  static const glassStretchExtent = 16.0;
  static const glassDragOffset = 24.0;
  static const glassDragResistance = 5.0;
  static const glassLiftOn = SpringDescription(
    mass: 1.36,
    stiffness: 568,
    damping: 39.7,
  );
  static const glassLiftOff = SpringDescription(
    mass: 2,
    stiffness: 460,
    damping: 21.8,
  );
  // Telegram GlassBackgroundView.generateLegacyShadowImage: one soft outer
  // shadow, 4% black, 40pt blur and a 1pt downward offset.
  static const glassShadow = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, .04),
      blurRadius: 40,
      offset: Offset(0, 1),
    ),
  ];
  // What a tab-bar lens shows where it has nothing to refract: over the
  // WebView map its capture holds only the icon layer, and the pressed lens
  // reaching past the bar would otherwise resolve to black. The lens's own
  // resting fill (Telegram's light selection pill / its dark counterpart).
  static const glassLensFallbackLight = Color(0xffffffff);
  static const glassLensFallbackDark = Color(0xff2c2c2e);
  static const glassPanelLight = Color.fromRGBO(255, 255, 255, .12);
  // FullProfileView / PeerInfoHeaderNode.
  static const profileAvatarDiameter = 100.0;
  static const profileTopInset = 22.0;
  static const profileTitleSize = 28.0;
  static const profileActionDiameter = 56.0;
  static const profileActionSpacing = 24.0;
  static const profileCoverHeight = 200.0;
  static const profileCoverOverlap = 50.0;
  static const profileAvatarBorder = 3.0;
  static const profileIdentityGap = 9.0;
  static const profileCoverShade = Color(0xff000000);
  // Web ProfileScreen edit view: h-48 cover, w-32 avatar, rounded-2xl cards.
  static const profileEditCoverRadius = 20.0;
  static const profileEditCoverHeight = 192.0;
  static const profileEditAvatarDiameter = 128.0;
  static const profileEditCardRadius = 16.0;
  static const glassPanelDark = Color.fromRGBO(255, 255, 255, .04);
  static const glassClearDark = Color.fromRGBO(0, 0, 0, .28);
  static const glassBlur = 1.0;
  static const glassClearBlur = 0.6;
  static const glassFrost = 12.0;
  static const glassThickness = 20.0;
  static const glassLightIntensity = .2;
  static const glassFresnelStrength = .15;
  // ChatEntityKeyboardInputNode: a blurred panel tinted with
  // inputMediaPanel.backgroundColor (day: white 0.7; night: 0x242424 blit
  // at 0.95 * 0.7) under 30pt top corners.
  static const inputMediaPanelLight = Color.fromRGBO(255, 255, 255, .7);
  static const inputMediaPanelDark = Color.fromRGBO(36, 36, 36, .665);
  static const inputMediaPanelCorner = 30.0;
  static const mediaExpandedTopInset = 10.0;
  static const mediaBackdropInset = 16.0;
  static const mediaBackdropDim = .2;
  static const mediaExpansionDuration = Duration(milliseconds: 400);
  static final mediaExpansionSpring = SpringDescription.withDurationAndBounce(
    duration: mediaExpansionDuration,
    bounce: 0,
  );
  // EntityKeyboardBottomPanelComponent / LiquidLensView.
  static const mediaTabsHeight = 40.0;
  static const mediaTabsFontSize = 14.0;
  static const mediaTabsTextInset = 12.0;
  static const mediaTabsOverlap = 8.0;
  static const mediaTabsLensInset = 3.0;
  static const mediaTabsLiftedInset = 4.0;
  static Color mediaTabsSelectionColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color.fromRGBO(255, 255, 255, .1)
      : const Color.fromRGBO(0, 0, 0, .075);
  static Color inputMediaPanelColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? inputMediaPanelDark
      : inputMediaPanelLight;
  static const emojiSearchHeight = 36.0;
  static const emojiSearchIconSize = 24.0;
  static const emojiSearchSpacing = 11.0;
  static const emojiSearchSelectionSize = 28.0;
  static const emojiSearchTransition = Duration(milliseconds: 200);
  static ({Color fill, Color overlay, Color selected, Color highlight})
  emojiSearchColors(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? (
          fill: const Color(0x1affffff),
          overlay: const Color(0xff808080),
          selected: const Color(0xff808080),
          highlight: const Color(0x40808080),
        )
      : (
          fill: const Color.fromRGBO(217, 217, 217, .1),
          overlay: const Color.fromRGBO(153, 153, 153, .55),
          selected: const Color.fromRGBO(102, 102, 102, .6),
          highlight: const Color.fromRGBO(51, 51, 51, .02),
        );

  // LocationInfoListItem: 40pt icon, 14pt vertical inset; place photos use the web 16:10 frame.
  static const placeIconSize = 40.0;
  static const placeRowInset = 14.0;
  static const placeImageRatio = 16 / 10;

  // PremiumIntroScreen: 28pt title, 15pt intro, 17/13pt benefit rows.
  static const premiumTitleSize = 28.0;
  static const premiumHeroSize = 156.0;
  static const premiumContentWidth = 600.0;
  static const premiumColors = [
    Color(0xff4492ff),
    Color(0xff676bff),
    Color(0xff9b4fed),
    Color(0xffcb3e6d),
  ];
  static const premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: premiumColors,
  );

  /// VenueIconResources.venueColors / randomColors.
  static Color venueColor(String type, [String seed = '']) {
    const colors = {
      'building/medical': Color(0xff43b3f4),
      'building/gym': Color(0xff43b3f4),
      'arts_entertainment': Color(0xffaf52de),
      'travel/bedandbreakfast': Color(0xff9987ff),
      'travel/hotel': Color(0xff9987ff),
      'travel/hostel': Color(0xff9987ff),
      'travel/resort': Color(0xff9987ff),
      'building': Color(0xff6e81b2),
      'education': Color(0xffa57348),
      'event': Color(0xff959595),
      'food': Color(0xffff9500),
      'education/cafeteria': Color(0xffff9500),
      'nightlife': Color(0xffaf52de),
      'travel/hotel_bar': Color(0xffaf52de),
      'parks_outdoors': Color(0xff6cc138),
      'shops': Color(0xffffb300),
      'travel': Color(0xff1c9fff),
      'work': Color(0xffad7854),
      'home': Color(0xff00aeef),
    };
    const random = [
      Color(0xffe56cd5),
      Color(0xfff89440),
      Color(0xff9986ff),
      Color(0xff44b3f5),
      Color(0xff6dc139),
      Color(0xffff5d5a),
      Color(0xfff87aad),
      Color(0xff6e82b3),
      Color(0xfff5ba21),
    ];
    if (type.isEmpty && seed.isEmpty) return const Color(0xff008df2);
    final known = colors[type] ?? colors[type.split('/').first];
    if (known != null) return known;
    var hash = 0;
    for (final code in (type.isEmpty ? seed : type).codeUnits) {
      hash = (code + ((hash << 5) - hash)).toSigned(32);
    }
    return random[hash.abs() % random.length];
  }

  // ChatMessageInteractiveFileNode (voice): 44pt control at (3, -3), the
  // waveform from x 57 at 18pt, the 11/17 duration at (56, 22), 38pt tall;
  // width grows 120pt → (constrained − 36) over 2 → 30 seconds.
  static const voiceControl = 44.0;
  static const voiceHeight = 38.0;
  static const voiceMinWidth = 120.0;

  // AudioWaveformComponent: 2pt round-capped bars, 2pt apart, 18pt peak.
  static const waveformBar = 2.0, waveformGap = 2.0, waveformPeak = 18.0;

  // ChatMessageMapBubbleContentNode: 2:1 map up to the 300pt image width
  // inside 2pt image insets; LocationPinBackground is 62x74.
  static const mapBubbleMaxWidth = 300.0;
  static const composerSendSize = 34.0;
  static const composerSideInset = 8.0;
  static const composerGap = 6.0;
  static const composerControl = 44.0;
  static const composerFieldInsets = EdgeInsetsDirectional.fromSTEB(
    12,
    11,
    4,
    11,
  );
  static const messageCorner = 22.0;
  static const messageLineHeight = 22.0;
  static const articleToolsTransition = Duration(milliseconds: 200);
  static const articleBarHeight = 44.0;
  static const articleToolWidth = 40.0;
  static const articleToolGap = 6.0;
  static const articleSideInset = 12.0;
  static const articleRestingSideInset = 20.0;
  static const articleDisabledSend = Color.fromRGBO(114, 123, 135, .5);
  static const articleTextSize = 17.0;
  static const articleMenuHeadingSizes = [24.0, 21.0, 19.0, 18.0, 17.0, 16.0];
  static const articleHeadingSizes = [22.0, 20.0, 18.0, 17.0, 16.0, 15.0];
  static const headerHeight = 44.0;
  static double get headerTitlebarGap =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS ? 10.0 : 0.0;
  static double headerInset(BuildContext context) =>
      headerHeight + headerTitlebarGap;
  // Vendored ProgressiveBlur header defaults.
  static const headerBlurSigma = 18.0;
  static const headerBlurFalloff = 1.2;
  static const fontFamily = 'CupertinoSystemText';
  static const displayFamily = 'CupertinoSystemDisplay';
  static const controlCorner = 10.0;
  // Source NativeStyle.groupRadius (inset form/settings sections).
  static const groupCorner = 26.0;

  /// Glass modal sheets: NavigationModalContainer and AttachmentContainer use
  /// 38pt when the presented controller has the glass style.
  static const sheetCorner = 38.0;
  static const sheetHeaderInset = 16.0;
  static const pressedOpacity = .4;
  static const buttonRelease = Duration(milliseconds: 200);
  static const rowRelease = Duration(milliseconds: 400);
  static const inset = 16.0;
  static const bodySize = 17.0;
  static const detailSize = 15.0;
  static const chatAvatar = 60.0;
  static const minimumTarget = 44.0;
  static const rowHeight = 44.0;
  static const brand = Color(0xffff37c7);

  /// UIKit applies the San Francisco tracking table automatically; Skia does
  /// not, which makes unadjusted Flutter text visibly looser than the React
  /// Native (UIKit) source. Values are Apple's SF Pro table, in points.
  static double tracking(double size) {
    const table = <(double, double)>[
      (9, .17),
      (10, .12),
      (11, .06),
      (12, 0),
      (13, -.08),
      (14, -.15),
      (15, -.23),
      (16, -.31),
      (17, -.43),
      (18, -.44),
      (19, -.45),
      (20, -.45),
      (21, -.36),
      (22, -.26),
      (23, -.10),
      (24, .07),
      (25, .15),
      (26, .22),
      (27, .29),
      (28, .38),
      (29, .40),
      (30, .40),
      (31, .39),
      (32, .41),
      (33, .40),
      (34, .40),
      (36, .37),
    ];
    if (size <= table.first.$1) return table.first.$2;
    if (size >= table.last.$1) return table.last.$2;
    for (var i = 0; i < table.length - 1; i++) {
      final (a, ta) = table[i];
      final (b, tb) = table[i + 1];
      if (size >= a && size <= b) return ta + (tb - ta) * (size - a) / (b - a);
    }
    return 0;
  }

  /// The one way to describe system text: SF Text below 20pt, SF Display
  /// from 20pt, with the matching UIKit tracking.
  static TextStyle font(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) => TextStyle(
    fontFamily: size >= 20 ? displayFamily : fontFamily,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: tracking(size),
    color: color,
    height: height,
  );

  static ThemeData theme(
    Brightness brightness, {
    double pixelRatio = 1,
    ResolvedAppearance? resolved,
  }) {
    final palette = resolved != null
        ? AppPalette.fromResolved(resolved)
        : brightness == Brightness.dark
        ? AppPalette.night
        : AppPalette.day;
    final dark = resolved?.dark ?? brightness == Brightness.dark;
    brightness = dark ? Brightness.dark : Brightness.light;
    final text = palette.text;
    final secondary = palette.secondaryLabel;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: brightness,
        ).copyWith(
          primary: palette.accent,
          onPrimary: Colors.white,
          surface: palette.row,
          onSurface: text,
          onSurfaceVariant: secondary,
          surfaceContainerHighest: palette.background,
          outlineVariant: palette.border,
          error: palette.destructive,
        );
    final typography =
        (dark ? Typography.whiteCupertino : Typography.blackCupertino).copyWith(
          bodyLarge: font(bodySize, color: text, height: 22 / 17),
          bodyMedium: font(bodySize, color: text, height: 22 / 17),
          bodySmall: font(detailSize, color: secondary, height: 20 / 15),
          labelSmall: font(13, color: secondary),
          labelMedium: font(15, color: secondary),
          labelLarge: font(17, weight: FontWeight.w600, color: text),
          titleSmall: font(15, weight: FontWeight.w600, color: text),
          titleMedium: font(bodySize, weight: FontWeight.w500, color: text),
          titleLarge: font(bodySize, weight: FontWeight.w600, color: text),
          headlineSmall: font(22, weight: FontWeight.w700, color: text),
          headlineMedium: font(28, weight: FontWeight.w700, color: text),
          headlineLarge: font(34, weight: FontWeight.w700, color: text),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [palette],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      fontFamily: fontFamily,
      textTheme: typography,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
        primaryColor: palette.accent,
        brightness: brightness,
        scaffoldBackgroundColor: palette.background,
        barBackgroundColor: palette.row,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: palette.accent.withValues(alpha: .3),
        selectionHandleColor: palette.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: secondary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        centerTitle: true,
        toolbarHeight: headerHeight,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: font(17, weight: FontWeight.w600, color: text),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsetsDirectional.only(
          start: inset,
          end: inset,
        ),
        minTileHeight: minimumTarget,
        horizontalTitleGap: 12,
        minLeadingWidth: 29,
        titleTextStyle: typography.bodyLarge,
        subtitleTextStyle: typography.bodySmall,
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1 / pixelRatio,
        space: 1 / pixelRatio,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xff2c2c2e)
            : const Color(0xf2333333),
        contentTextStyle: font(15, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        hintStyle: font(17, color: secondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: palette.accent,
          textStyle: font(17),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
