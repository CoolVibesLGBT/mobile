import '../l10n/l10n.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../components/components.dart';
import '../components/chat_wallpaper.dart';
import '../core/appearance.dart';
import '../core/session.dart';
import '../design/app_design.dart';

Color _color(String hex) =>
    Color(0xff000000 | int.parse(hex.substring(1, 7), radix: 16));
String _hexOf(Color color) =>
    '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';

/// Source app/appearance.tsx (web AppearanceScreen): preview, message text
/// size, wallpaper, cloud chat themes, base theme, accent presets and custom
/// message colours over the shared Appearance model.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final appearance = session.appearanceModel;
    final base = session.currentBase(context);
    final palette = AppPalette.of(context);
    final resolved = palette.resolved ?? resolveTheme(base);
    final selection = appearance.themes[base] ?? const ThemeSelection();
    final messages =
        selection.messages ??
        MessageColors(
          resolved.sourceAccent,
          resolved.sourceMessageColors.take(1).toList(),
        );
    final gradient = messages.colors.length > 1;
    final stops = [
      messages.colors.first,
      messages.colors.length > 1 ? messages.colors[1] : messages.colors.first,
    ];
    void update(ThemeSelection next) =>
        session.updateAppearance(appearance.withSelection(base, next));
    void setMessages(MessageColors? value) => update(
      ThemeSelection(
        preset: selection.preset,
        theme: selection.theme,
        wallpaper: selection.wallpaper,
        messages: value,
      ),
    );
    Future<void> pick(String which) async {
      final value = which == 'accent'
          ? messages.accent
          : which == 'end'
          ? stops[1]
          : stops[0];
      await sheet(
        context,
        ColorPickerScreen(
          title: which == 'accent'
              ? context.l10n.accentColor
              : which == 'end'
              ? context.l10n.end
              : context.l10n.start,
          value: value,
          onChanged: (color) => setMessages(
            which == 'accent'
                ? MessageColors(
                    color,
                    messages.colors,
                    gradientType: messages.gradientType,
                    angle: messages.angle,
                  )
                : MessageColors(
                    messages.accent,
                    [
                      for (var i = 0; i < messages.colors.length; i++)
                        i == (which == 'end' ? 1 : 0)
                            ? color
                            : messages.colors[i],
                    ],
                    gradientType: messages.gradientType,
                    angle: messages.angle,
                  ),
          ),
        ),
      );
    }

    final defaultAccent = resolveTheme(base).accent;
    final presets = AppearanceCatalog.presets[base] ?? const <AccentPreset>[];
    return AppScaffold(
      appBar: AppHeader(title: Text(context.l10n.appearance)),
      body: ListView(
        padding: EdgeInsets.only(
          top:
              MediaQuery.paddingOf(context).top +
              AppDesign.headerInset(context) +
              16,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: AppearancePreview(),
          ),
          AppSection(
            title: context.l10n.settings,
            children: [
              _SliderRow(
                title: context.l10n.messageTextSize,
                value: appearance.textSize.toDouble(),
                min: 12,
                max: 20,
                divisions: 8,
                label: '${appearance.textSize}',
                onChanged: (value) => session.updateAppearance(
                  appearance.copyWith(textSize: value.round()),
                ),
              ),
              AppRow(
                leading: AppSymbol.icon(
                  'photo',
                  size: 22,
                  color: palette.accent,
                  fallback: Icons.image_outlined,
                ),
                title: Text(context.l10n.chatWallpaper),
                onTap: () => open(context, const ChatBackgroundScreen()),
              ),
            ],
          ),
          AppSection(
            title: context.l10n.colorTheme,
            children: [
              _ThemePicker(
                base: base,
                selected: selection.preset == null
                    ? selection.theme ?? ''
                    : null,
                onSelect: (id) =>
                    update(ThemeSelection(preset: null, theme: id)),
              ),
              for (final choice in themeChoices)
                AppRow(
                  title: Text(themeLabels[choice]!(context.l10n)),
                  selected: appearance.base == choice,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    session.updateAppearance(appearance.copyWith(base: choice));
                  },
                ),
            ],
          ),
          AppSection(
            title: context.l10n.accentColor,
            children: [
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  children: [
                    for (final preset in <AccentPreset?>[null, ...presets])
                      () {
                        final active = preset == null
                            ? selection.preset == null &&
                                  selection.theme == null
                            : selection.preset == preset.id;
                        final colors = preset == null
                            ? [defaultAccent, defaultAccent]
                            : preset.messageColors.length > 1
                            ? preset.messageColors.map(hexOf).toList()
                            : [
                                hexOf(preset.accentColor),
                                hexOf(preset.accentColor),
                              ];
                        return Semantics(
                          selected: active,
                          button: true,
                          label: preset == null
                              ? context.l10n.defaultLabel
                              : hexOf(preset.accentColor),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              update(ThemeSelection(preset: preset?.id));
                            },
                            child: SizedBox.square(
                              dimension: 52,
                              child: Center(
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      width: 2,
                                      color: active
                                          ? palette.accent
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: colors.map(_color).toList(),
                                      ),
                                    ),
                                    child: preset == null
                                        ? const Icon(
                                            Icons.restart_alt,
                                            size: 18,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }(),
                  ],
                ),
              ),
            ],
          ),
          AppSection(
            title: context.l10n.messageColors,
            children: [
              ColoredBox(
                color: palette.background,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                  child: const _PreviewBubbles(meta: false),
                ),
              ),
              _ColorRow(
                title: context.l10n.start,
                color: stops[0],
                onTap: () => pick('start'),
              ),
              _ColorRow(
                title: context.l10n.end,
                color: stops[1],
                disabled: !gradient,
                onTap: () => pick('end'),
              ),
              AppChoiceRow(
                title: Text(context.l10n.messageGradient),
                value: gradient,
                onChanged: (_) => setMessages(
                  MessageColors(
                    messages.accent,
                    gradient
                        ? messages.colors.take(1).toList()
                        : [
                            messages.colors.first,
                            resolved.sourceMessageColors.length > 1
                                ? resolved.sourceMessageColors[1]
                                : messages.accent,
                          ],
                    gradientType: messages.gradientType,
                    angle: messages.angle,
                  ),
                ),
              ),
              if (gradient) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: AppSegments<String>(
                    values: const {
                      'linear': Text('Linear'),
                      'radial': Text('Radial'),
                      'conic': Text('Conic'),
                    },
                    selected: messages.gradientType,
                    onChanged: (type) => setMessages(
                      MessageColors(
                        messages.accent,
                        messages.colors,
                        gradientType: type,
                        angle: messages.angle,
                      ),
                    ),
                  ),
                ),
                if (messages.gradientType != 'radial')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('Angle'),
                        Expanded(
                          child: CupertinoSlider(
                            min: 0,
                            max: 360,
                            value: messages.angle.clamp(0, 360),
                            onChanged: (angle) => setMessages(
                              MessageColors(
                                messages.accent,
                                messages.colors,
                                gradientType: messages.gradientType,
                                angle: angle,
                              ),
                            ),
                          ),
                        ),
                        Text('${messages.angle.round()}°'),
                      ],
                    ),
                  ),
              ],
              _ColorRow(
                title: context.l10n.accentColor,
                color: messages.accent,
                onTap: () => pick('accent'),
              ),
              if (selection.messages != null)
                AppRow(
                  leading: Icon(
                    Icons.restart_alt,
                    size: 20,
                    color: palette.accent,
                  ),
                  title: Text(context.l10n.resetToDefaults),
                  onTap: () => setMessages(null),
                ),
            ],
          ),
          AppSection(
            children: [
              AppRow(
                destructive: true,
                title: Text(context.l10n.resetAppearance),
                onTap: () => session.updateAppearance(
                  const Appearance(),
                  clearImage: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// AppearancePreview.tsx: the live palette on its wallpaper with both bubbles.
class AppearancePreview extends StatelessWidget {
  const AppearancePreview({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: context.l10n.preview,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 200),
        child: Stack(
          children: [
            const Positioned.fill(child: ChatWallpaper()),
            const Padding(
              padding: EdgeInsets.all(16),
              child: _PreviewBubbles(meta: true),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PreviewBubbles extends StatelessWidget {
  final bool meta;
  const _PreviewBubbles({required this.meta});
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final size = palette.textSize * scale;
    Widget bubble(bool outgoing, String text, String time) {
      final stops = palette.outgoingStops;
      return Align(
        alignment: outgoing
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: .86,
          alignment: outgoing
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Align(
            alignment: outgoing
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.fromLTRB(11, 6, 11, 6),
              decoration: BoxDecoration(
                color: outgoing ? stops.first : palette.incoming,
                gradient: outgoing && stops.first != stops.last
                    ? (palette.outgoingGradientType == 'radial'
                          ? RadialGradient(colors: stops)
                          : palette.outgoingGradientType == 'conic'
                          ? SweepGradient(
                              startAngle:
                                  palette.outgoingGradientAngle * math.pi / 180,
                              endAngle:
                                  palette.outgoingGradientAngle *
                                      math.pi /
                                      180 +
                                  2 * math.pi,
                              colors: stops,
                            )
                          : LinearGradient(
                              begin: Alignment(
                                -math.cos(
                                  palette.outgoingGradientAngle * math.pi / 180,
                                ),
                                -math.sin(
                                  palette.outgoingGradientAngle * math.pi / 180,
                                ),
                              ),
                              end: Alignment(
                                math.cos(
                                  palette.outgoingGradientAngle * math.pi / 180,
                                ),
                                math.sin(
                                  palette.outgoingGradientAngle * math.pi / 180,
                                ),
                              ),
                              colors: stops,
                            ))
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(outgoing ? 16 : 0),
                  bottomRight: Radius.circular(outgoing ? 0 : 16),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    offset: Offset(0, 1),
                    blurRadius: 1.5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    textScaler: TextScaler.noScaling,
                    style: AppDesign.font(
                      size,
                      color: outgoing ? palette.outgoingText : palette.text,
                      height: 1.3125,
                    ),
                  ),
                  if (meta)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: AppDesign.font(
                            12,
                            color: outgoing
                                ? palette.outgoingMeta
                                : palette.secondaryLabel,
                          ),
                        ),
                        if (outgoing) ...[
                          const SizedBox(width: 3),
                          Icon(
                            Icons.done_all,
                            size: 14,
                            color: palette.outgoingMeta,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble(false, context.l10n.thisIsHowYourChatsWill, '12:30'),
        const SizedBox(height: 10),
        bubble(true, context.l10n.yourMessagesYourColors, '12:31'),
      ],
    );
  }
}

/// tweb chatThemesPicker: the home tile plus cloud themes, each previewing its
/// own wallpaper, bubbles and emoji.
class _ThemePicker extends StatelessWidget {
  final BaseTheme base;
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _ThemePicker({
    required this.base,
    required this.selected,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final items = [
      ('', '🏠'),
      for (final theme in AppearanceCatalog.themes) (theme.id, theme.emoticon),
    ];
    return SizedBox(
      height: 112 + 24,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (id, emoticon) = items[index];
          final preview = resolveTheme(
            base,
            ThemeSelection(theme: id.isEmpty ? null : id),
          );
          final active = selected == id;
          return Semantics(
            selected: active,
            button: true,
            label: '${context.l10n.colorTheme} $emoticon',
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(id.isEmpty ? null : id);
              },
              child: Container(
                width: 82,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    width: 2,
                    color: active ? palette.accent : Colors.transparent,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    height: 104,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ChatWallpaper(
                            appearance: preview,
                            thumbnail: true,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: .62,
                                  child: Container(
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _color(preview.incoming),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FractionallySizedBox(
                                  widthFactor: .62,
                                  child: Container(
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _color(preview.thumbnailOutgoing),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 6,
                          child: Center(
                            child: Text(
                              emoticon,
                              style: const TextStyle(fontSize: 22),
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
        },
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String title, label;
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.title,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppDesign.font(17, color: palette.text),
                ),
              ),
              Text(
                label,
                style: AppDesign.font(
                  17,
                  color: palette.secondaryLabel,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: CupertinoSlider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              activeColor: palette.accent,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String title, color;
  final bool disabled;
  final VoidCallback onTap;
  const _ColorRow({
    required this.title,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Opacity(
      opacity: disabled ? .45 : 1,
      child: AppRow(
        title: Text(title),
        value: color.toUpperCase(),
        trailing: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _color(color),
            shape: BoxShape.circle,
            border: Border.all(
              color: palette.border,
              width: 1 / MediaQuery.devicePixelRatioOf(context),
            ),
          ),
        ),
        onTap: disabled ? null : onTap,
      ),
    );
  }
}

/// Source app/appearance-background.tsx: gradient / solid colour / photo for
/// the current theme, pattern intensity, gradient stops and rotation.
class ChatBackgroundScreen extends StatefulWidget {
  const ChatBackgroundScreen({super.key});
  @override
  State<ChatBackgroundScreen> createState() => _ChatBackgroundScreenState();
}

class _ChatBackgroundScreenState extends State<ChatBackgroundScreen> {
  bool uploading = false, failed = false;

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final base = session.currentBase(context);
    final palette = AppPalette.of(context);
    final wp = (palette.resolved ?? resolveTheme(base)).wallpaper;
    final selection =
        session.appearanceModel.themes[base] ?? const ThemeSelection();
    void patch(Wallpaper next, {String? image}) => session.updateAppearance(
      session.appearanceModel.withSelection(
        base,
        ThemeSelection(
          preset: selection.preset,
          theme: selection.theme,
          messages: selection.messages,
          wallpaper: next,
        ),
      ),
      image: image,
    );
    void chooseKind(String kind) => patch(
      wp.copyWith(
        kind: kind,
        colors: kind == 'color'
            ? wp.colors.take(1).toList()
            : wp.colors.length > 1
            ? wp.colors
            : [wp.colors.first, '#b2cee1'],
        pattern: kind == 'image' ? false : wp.pattern,
      ),
    );
    Future<void> upload() async {
      setState(() => failed = false);
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;
      setState(() => uploading = true);
      try {
        final size = await picked.length();
        if (size == 0 || size > 20 * 1024 * 1024) throw StateError('size');
        final folder = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/ui-preferences',
        );
        await folder.create(recursive: true);
        final ext = picked.name.split('.').last.toLowerCase();
        final target =
            '${folder.path}/wallpaper-${DateTime.now().millisecondsSinceEpoch}.${['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext) ? ext : 'jpg'}';
        await File(picked.path).copy(target);
        final previous = session.wallpaperImage;
        patch(
          const Wallpaper(kind: 'image', colors: ['#e6ebee'], intensity: 0),
          image: target,
        );
        if (previous != null && previous != target)
          File(previous).delete().ignore();
      } catch (_) {
        if (mounted) setState(() => failed = true);
      } finally {
        if (mounted) setState(() => uploading = false);
      }
    }

    Widget actionButton(String label, IconData icon, VoidCallback onTap) =>
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: palette.accent),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppDesign.font(
                        15,
                        weight: FontWeight.w600,
                        color: palette.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    return AppScaffold(
      appBar: AppHeader(title: Text(context.l10n.chatWallpaper)),
      body: ListView(
        padding: EdgeInsets.only(
          top:
              MediaQuery.paddingOf(context).top +
              AppDesign.headerInset(context) +
              16,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AppearancePreview(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: wp.kind,
                onValueChanged: (value) {
                  if (value != null) chooseKind(value);
                },
                children: {
                  'gradient': Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(context.l10n.gradient),
                  ),
                  'color': Text(context.l10n.setColor),
                  'image': Text(context.l10n.photo),
                },
              ),
            ),
          ),
          if (wp.kind != 'image') ...[
            if (wp.kind == 'color')
              AppSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        for (final color in backgroundColors)
                          GestureDetector(
                            onTap: () => patch(
                              wp.copyWith(colors: [color.toLowerCase()]),
                            ),
                            child: SizedBox.square(
                              dimension: 56,
                              child: Center(
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _color(color),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          wp.colors.first.toLowerCase() ==
                                              color.toLowerCase()
                                          ? palette.accent
                                          : palette.border,
                                      width:
                                          wp.colors.first.toLowerCase() ==
                                              color.toLowerCase()
                                          ? 3
                                          : 1 /
                                                MediaQuery.devicePixelRatioOf(
                                                  context,
                                                ),
                                    ),
                                  ),
                                  child:
                                      wp.colors.first.toLowerCase() ==
                                          color.toLowerCase()
                                      ? const Icon(
                                          Icons.check,
                                          size: 20,
                                          color: Colors.black,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            AppSection(
              children: [
                for (var i = 0; i < wp.colors.length; i++)
                  _ColorRow(
                    title: '${context.l10n.setColor} ${i + 1}',
                    color: wp.colors[i],
                    onTap: () => sheet(
                      context,
                      ColorPickerScreen(
                        title: context.l10n.setColor,
                        value: wp.colors[i],
                        onChanged: (color) {
                          final current =
                              (AppPalette.of(context).resolved ??
                                      resolveTheme(base))
                                  .wallpaper;
                          patch(
                            current.copyWith(
                              colors: [
                                for (var j = 0; j < current.colors.length; j++)
                                  j == i ? color : current.colors[j],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (wp.kind == 'gradient')
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        if (wp.colors.length < 4)
                          actionButton(
                            context.l10n.addColor,
                            Icons.add,
                            () => patch(
                              wp.copyWith(colors: [...wp.colors, '#c6e7cb']),
                            ),
                          ),
                        if (wp.colors.length > 2)
                          actionButton(
                            context.l10n.removeColor,
                            Icons.remove,
                            () => patch(
                              wp.copyWith(
                                colors: wp.colors.sublist(
                                  0,
                                  wp.colors.length - 1,
                                ),
                              ),
                            ),
                          ),
                        actionButton(
                          context.l10n.rotateGradient,
                          Icons.rotate_right,
                          () => patch(
                            wp.copyWith(rotation: (wp.rotation + 45) % 360),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            AppSection(
              children: [
                AppChoiceRow(
                  title: Text(context.l10n.pattern),
                  value: wp.pattern,
                  onChanged: (value) =>
                      patch(wp.copyWith(pattern: value ?? false)),
                ),
                if (wp.pattern)
                  _SliderRow(
                    title: context.l10n.intensity,
                    label: '${wp.intensity.round()}%',
                    value: wp.intensity,
                    min: 0,
                    max: 100,
                    onChanged: (value) =>
                        patch(wp.copyWith(intensity: value.roundToDouble())),
                  ),
              ],
            ),
          ] else
            AppSection(
              footer: failed ? context.l10n.chooseAnImageUpTo20 : null,
              children: [
                AppRow(
                  leading: AppSymbol.icon(
                    'photo.on.rectangle',
                    size: 22,
                    color: palette.accent,
                    fallback: Icons.add_photo_alternate_outlined,
                  ),
                  title: Text(
                    context.l10n.uploadWallpaper,
                    style: AppDesign.font(17, color: palette.accent),
                  ),
                  trailing: uploading
                      ? const CircularProgressIndicator.adaptive()
                      : const SizedBox.shrink(),
                  onTap: uploading ? null : upload,
                ),
                if (session.wallpaperImage != null)
                  AppChoiceRow(
                    title: Text(context.l10n.blurWallpaperImage),
                    value: wp.blur,
                    onChanged: (value) =>
                        patch(wp.copyWith(blur: value ?? false)),
                  ),
              ],
            ),
          AppSection(
            children: [
              AppRow(
                leading: Icon(
                  Icons.restart_alt,
                  size: 20,
                  color: palette.accent,
                ),
                title: Text(context.l10n.resetToDefaults),
                onTap: () => session.updateAppearance(
                  session.appearanceModel.withSelection(
                    base,
                    ThemeSelection(
                      preset: selection.preset,
                      theme: selection.theme,
                      messages: selection.messages,
                    ),
                  ),
                  clearImage: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// NativeColorPicker: suggested swatches, hue/saturation/brightness sliders
/// and a hex field. Changes apply live; Cancel restores the original value.
class ColorPickerScreen extends StatefulWidget {
  final String title, value;
  final ValueChanged<String> onChanged;
  const ColorPickerScreen({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });
  @override
  State<ColorPickerScreen> createState() => _ColorPickerScreenState();
}

class _ColorPickerScreenState extends State<ColorPickerScreen> {
  static const suggested = [
    '#3390EC',
    '#2D7ED5',
    '#8774E1',
    '#0088FF',
    '#5CA853',
    '#70B768',
    '#F55783',
    '#FF5D5D',
    '#FF9F0A',
    '#FDB76E',
    '#29B6F6',
    '#00B09B',
    '#AEE946',
    '#A6A997',
    '#7A7072',
    '#E6EBEE',
    '#B2CEE1',
    '#C6E7CB',
    '#FDD7AF',
    '#000000',
  ];
  late String hex = widget.value;
  late List<double> hsv = () {
    final rgb = hexToRgb(widget.value);
    return rgbToHsv(rgb[0], rgb[1], rgb[2]);
  }();
  late final field = TextEditingController(text: widget.value);
  bool valid(String value) =>
      RegExp(r'^#[0-9a-f]{6}$', caseSensitive: false).hasMatch(value);

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  void apply(String next, {bool fromSlider = false}) {
    setState(() {
      hex = next;
      if (!fromSlider && valid(next)) {
        final rgb = hexToRgb(next);
        hsv = rgbToHsv(rgb[0], rgb[1], rgb[2]);
      }
      if (field.text != next) field.text = next;
    });
    if (valid(next)) widget.onChanged(next.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    Widget slider(String label, int index, double max, String display) =>
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppDesign.font(15, color: palette.text),
                  ),
                ),
                Text(
                  display,
                  style: AppDesign.font(15, color: palette.secondaryLabel),
                ),
              ],
            ),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: CupertinoSlider(
                value: hsv[index].clamp(0, max),
                max: max,
                activeColor: palette.accent,
                onChanged: (value) {
                  final next = [...hsv]..[index] = value;
                  hsv = next;
                  apply(
                    rgbaToHexa(hsvToRgb(next[0], next[1], next[2])),
                    fromSlider: true,
                  );
                },
              ),
            ),
          ],
        );
    return AppScaffold(
      appBar: AppHeader(
        title: Text(widget.title),
        leading: AppButton.text(
          onPressed: () {
            widget.onChanged(widget.value);
            Navigator.pop(context);
          },
          child: Text(context.l10n.cancel2),
        ),
        actions: [
          AppButton.text(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.done),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top +
              AppDesign.headerInset(context) +
              16,
          16,
          32,
        ),
        children: [
          Semantics(
            label: '${context.l10n.selectedColor}, $hex',
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: _color(valid(hex) ? hex : widget.value),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: palette.border,
                  width: 1 / MediaQuery.devicePixelRatioOf(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final color in suggested)
                GestureDetector(
                  onTap: () => apply(color.toLowerCase()),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.border,
                            width: 1 / MediaQuery.devicePixelRatioOf(context),
                          ),
                        ),
                        child: color.toLowerCase() == hex.toLowerCase()
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color:
                                    hexToRgb(color).reduce((a, b) => a + b) >
                                        400
                                    ? Colors.black
                                    : Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.row,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                slider(context.l10n.hue, 0, 359, '${hsv[0].round()}°'),
                slider(
                  context.l10n.saturation,
                  1,
                  1,
                  '${(hsv[1] * 100).round()}%',
                ),
                slider(
                  context.l10n.brightness,
                  2,
                  1,
                  '${(hsv[2] * 100).round()}%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.row,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.hexColor,
                  style: AppDesign.font(13, color: palette.secondaryLabel),
                ),
                TextField(
                  controller: field,
                  maxLength: 7,
                  autocorrect: false,
                  style: AppDesign.font(17, color: palette.text),
                  decoration: const InputDecoration(
                    counterText: '',
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                  ),
                  onChanged: (text) =>
                      apply(text.startsWith('#') ? text : '#$text'),
                ),
                if (!valid(hex))
                  Text(
                    context.l10n.enterAColorLike3390ec,
                    style: AppDesign.font(13, color: palette.destructive),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `_hexOf` is kept for callers converting Flutter colours back to the model.
String colorToHex(Color color) => _hexOf(color);
