import '../l10n/l10n.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import '../design/app_design.dart';
import '../vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;
import 'app_button.dart';
import 'app_pressable.dart';
import 'glass_surface.dart';
import 'navigation.dart';

/// One action of the attachment tab bar (Telegram AttachmentPanel button).
class AttachmentAction {
  final String id, label, symbol;
  final IconData fallback;
  final VoidCallback onPressed;
  const AttachmentAction({
    required this.id,
    required this.label,
    required this.symbol,
    required this.fallback,
    required this.onPressed,
  });
}

/// A picked library item, ready for the outbox.
class AttachmentPick {
  final String path, name, mime;
  final bool video, spoiler;
  const AttachmentPick({
    required this.path,
    required this.name,
    required this.mime,
    required this.video,
    this.spoiler = false,
  });
}

/// The attachment menu (Telegram-iOS AttachmentController / AttachmentPanel,
/// source components/chat/AttachmentSheet.tsx): a draggable sheet with the
/// recent photo/video grid (camera tile first, numbered multi-selection) and a
/// floating glass tab bar; a selection replaces it with a send capsule.
Future<void> showAttachmentSheet(
  BuildContext context, {
  required String sendLabel,
  required VoidCallback onCamera,
  required VoidCallback onLibrary,
  required List<AttachmentAction> actions,
  required Future<bool> Function(List<AttachmentPick>) onSelect,
  bool allowSpoiler = false,
  bool singlePhoto = false,
  String? title,
}) async {
  HapticFeedback.selectionClick();
  FocusScope.of(context).unfocus();
  VoidCallback? next;
  // The vendored Liquid Glass modal sheet: rests at .62 of the screen and
  // drags up to .94, the source sheet's snap points.
  await sheet<void>(
    context,
    _AttachmentSheet(
      key: const ValueKey('media.library'),
      sendLabel: sendLabel,
      allowSpoiler: allowSpoiler,
      singlePhoto: singlePhoto,
      title: title,
      onSelect: onSelect,
      tabs: [
        AttachmentAction(
          id: 'gallery',
          label: context.l10n.gallery,
          symbol: 'photo.on.rectangle',
          fallback: Icons.photo_library_outlined,
          onPressed: () {},
        ),
        AttachmentAction(
          id: 'camera',
          label: context.l10n.camera,
          symbol: 'camera',
          fallback: Icons.camera_alt_outlined,
          onPressed: onCamera,
        ),
        ...actions,
      ],
      onLibrary: onLibrary,
      run: (action) => next = action,
    ),
    halfSize: .62,
    fullSize: .94,
    initialState: liquid.GlassSheetState.half,
    barrierColor: const Color(0x40000000),
  );
  // An action runs after the sheet has gone (source `nextAction`).
  next?.call();
}

class _AttachmentSheet extends StatefulWidget {
  final String sendLabel;
  final bool allowSpoiler, singlePhoto;
  final String? title;
  final List<AttachmentAction> tabs;
  final VoidCallback onLibrary;
  final Future<bool> Function(List<AttachmentPick>) onSelect;
  final ValueChanged<VoidCallback> run;
  const _AttachmentSheet({
    super.key,
    required this.sendLabel,
    required this.allowSpoiler,
    required this.singlePhoto,
    this.title,
    required this.tabs,
    required this.onLibrary,
    required this.onSelect,
    required this.run,
  });
  @override
  State<_AttachmentSheet> createState() => _AttachmentSheetState();
}

enum _Access { unknown, granted, limited, denied }

class _AttachmentSheetState extends State<_AttachmentSheet>
    with WidgetsBindingObserver {
  static const page = 60;
  _Access access = _Access.unknown;
  final assets = <AssetEntity>[];
  final selected = <String>[];
  AssetPathEntity? album;
  int loadedPages = 0;
  bool loading = false, more = true, sending = false, spoiler = false;
  bool failed = false, loadingFailed = false;
  bool requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    requestAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !sending &&
        (access == _Access.denied ||
            (widget.singlePhoto && access == _Access.limited))) {
      requestAccess();
    }
  }

  Future<void> requestAccess() async {
    if (requesting) return;
    requesting = true;
    try {
      final state = await PhotoManager.requestPermissionExtend(
        requestOption: PermissionRequestOption(
          iosAccessLevel: IosAccessLevel.readWrite,
          androidPermission: AndroidPermission(
            type: widget.singlePhoto ? RequestType.image : RequestType.common,
            mediaLocation: false,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        loadingFailed = false;
        access = state == PermissionState.authorized
            ? _Access.granted
            : state == PermissionState.limited
            ? _Access.limited
            : _Access.denied;
      });
      if (access == _Access.granted || access == _Access.limited) {
        final paths = await PhotoManager.getAssetPathList(
          onlyAll: true,
          type: widget.singlePhoto ? RequestType.image : RequestType.common,
        );
        if (!mounted) return;
        setState(() {
          album = paths.firstOrNull;
          assets.clear();
          selected.clear();
          loadedPages = 0;
          more = true;
        });
        await load();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          access = _Access.denied;
          loadingFailed = true;
        });
      }
    } finally {
      requesting = false;
    }
  }

  Future<void> load() async {
    if (loading || !more || album == null || loadingFailed) return;
    setState(() => loading = true);
    try {
      final items = await album!.getAssetListPaged(
        page: loadedPages,
        size: page,
      );
      loadedPages++;
      if (!mounted) return;
      setState(() {
        assets.addAll(items);
        more = items.length == page;
      });
    } catch (_) {
      if (mounted) setState(() => loadingFailed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void toggle(AssetEntity asset) {
    if (sending) return;
    HapticFeedback.selectionClick();
    if (widget.singlePhoto) {
      setState(() {
        selected.clear();
        selected.add(asset.id);
      });
      send();
      return;
    }
    setState(() {
      if (!selected.remove(asset.id) && selected.length < 10) {
        selected.add(asset.id);
      }
    });
  }

  Future<void> send() async {
    if (selected.isEmpty || sending) return;
    setState(() {
      sending = true;
      failed = false;
    });
    try {
      final picks = <AttachmentPick>[];
      for (final id in selected) {
        final asset = assets.firstWhere((item) => item.id == id);
        final file = await (widget.singlePhoto ? asset.file : asset.originFile);
        if (file == null) throw StateError('missing file');
        final video = asset.type == AssetType.video;
        final name = await asset.titleAsync;
        final ext = name.split('.').last.toLowerCase();
        picks.add(
          AttachmentPick(
            path: file.path,
            name: name,
            video: video,
            spoiler: spoiler,
            mime: video
                ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4')
                : ext == 'png'
                ? 'image/png'
                : ext == 'heic'
                ? 'image/heic'
                : ext == 'gif'
                ? 'image/gif'
                : 'image/jpeg',
          ),
        );
      }
      if (!mounted) return;
      final accepted = await widget.onSelect(picks);
      if (!mounted) return;
      if (!accepted) {
        setState(() => failed = true);
        return;
      }
      Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void run(VoidCallback action) {
    if (sending) return;
    widget.run(action);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final control = dark ? const Color(0x1affffff) : const Color(0x0d000000);
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 8.0);
    // The sheet's glass is the background; its scroll controller links the
    // grid to the detents.
    return _SheetScroll(
      builder: (context, scroll) => ClipRRect(
        borderRadius: BorderRadius.zero,
        child: ColoredBox(
          color: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, box) {
              // helpers/sheetLayout attachmentGridLayout.
              final width = math.min(box.maxWidth, 640.0);
              final columns = math.max(3, (width / 130).floor());
              final cell = (width - (columns - 1) * 2) / columns;
              return Stack(
                children: [
                  CustomScrollView(
                    controller: scroll,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            // Grabber.
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 4),
                              child: Container(
                                width: 36,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: dark
                                      ? const Color(0x40ffffff)
                                      : const Color(0x2e000000),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            Container(
                              constraints: const BoxConstraints(minHeight: 52),
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                              child: Row(
                                children: [
                                  _CircleButton(
                                    color: control,
                                    label: context.l10n.close,
                                    symbol: 'xmark',
                                    fallback: Icons.close,
                                    onTap: () => Navigator.pop(context),
                                  ),
                                  Expanded(
                                    child: Text(
                                      widget.title ?? context.l10n.recents,
                                      textAlign: TextAlign.center,
                                      style: AppDesign.font(
                                        17,
                                        weight: FontWeight.w600,
                                        color: palette.text,
                                      ),
                                    ),
                                  ),
                                  _CircleButton(
                                    color: control,
                                    label: context.l10n.chooseFromLibrary,
                                    symbol: 'square.grid.2x2',
                                    fallback: Icons.grid_view,
                                    onTap: () => run(widget.onLibrary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (access == _Access.granted ||
                          access == _Access.limited) ...[
                        if (access == _Access.limited)
                          SliverToBoxAdapter(
                            child: GestureDetector(
                              onTap: () async {
                                await PhotoManager.presentLimited();
                                await requestAccess();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        context
                                            .l10n
                                            .youGaveAccessToSelectedPhotos,
                                        style: AppDesign.font(
                                          13,
                                          color: palette.secondaryLabel,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      context.l10n.manage,
                                      style: AppDesign.font(
                                        13,
                                        weight: FontWeight.w600,
                                        color: palette.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: (box.maxWidth - width) / 2,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 2,
                                  crossAxisSpacing: 2,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              if (index == 0) {
                                return Semantics(
                                  button: true,
                                  label: context.l10n.camera,
                                  child: GestureDetector(
                                    onTap: () => run(widget.tabs[1].onPressed),
                                    child: const ColoredBox(
                                      color: Color(0xff1c1c1e),
                                      child: Center(
                                        child: AppSymbol.icon(
                                          'camera.fill',
                                          size: 30,
                                          color: Colors.white,
                                          fallback: Icons.camera_alt,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (index >= assets.length - 12) load();
                              final asset = assets[index - 1];
                              return _GridItem(
                                key: ValueKey(asset.id),
                                asset: asset,
                                size: cell,
                                order: selected.indexOf(asset.id),
                                singlePhoto: widget.singlePhoto,
                                accent: palette.accent,
                                onTap: () => toggle(asset),
                              );
                            }, childCount: assets.length + 1),
                          ),
                        ),
                        if (loadingFailed)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: AppButton(
                                onPressed: () {
                                  setState(() => loadingFailed = false);
                                  load();
                                },
                                child: Text(context.l10n.retry),
                              ),
                            ),
                          ),
                        if (loading)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator.adaptive(),
                              ),
                            ),
                          ),
                      ] else
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(32, 32, 32, 120),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppSymbol.icon(
                                  'photo.on.rectangle.angled',
                                  size: 52,
                                  color: palette.secondaryLabel,
                                  fallback: Icons.photo_library_outlined,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  loadingFailed
                                      ? context.l10n.mediaCouldNotBeAddedTry
                                      : context.l10n.allowPhotoAccessToSeeYour,
                                  textAlign: TextAlign.center,
                                  style: AppDesign.font(
                                    17,
                                    weight: FontWeight.w600,
                                    color: palette.text,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (access == _Access.unknown)
                                  const CircularProgressIndicator.adaptive()
                                else
                                  GestureDetector(
                                    onTap: PhotoManager.openSetting,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 50,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: palette.accent,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Text(
                                        context.l10n.openSettings,
                                        style: AppDesign.font(
                                          17,
                                          weight: FontWeight.w600,
                                          color: palette.accentText,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => run(widget.onLibrary),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      context.l10n.chooseFromLibrary,
                                      style: AppDesign.font(
                                        16,
                                        color: palette.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: 62 + bottom + 24),
                      ),
                    ],
                  ),
                  if (widget.singlePhoto && sending)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x66000000),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      ),
                    ),
                  // Floating glass tab bar / send capsule.
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: bottom,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (failed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  context.l10n.mediaCouldNotBeAddedTry,
                                  style: AppDesign.font(
                                    13,
                                    color: palette.destructive,
                                  ),
                                ),
                              ),
                            GlassSurface(
                              radius: 31,
                              interactive: true,
                              child: selected.isEmpty || widget.singlePhoto
                                  ? Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: Row(
                                        children: [
                                          for (final tab in widget.tabs)
                                            Expanded(
                                              child: _TabButton(
                                                tab: tab,
                                                active: tab.id == 'gallery',
                                                accent: palette.accent,
                                                onTap: tab.id == 'gallery'
                                                    ? null
                                                    : () => run(tab.onPressed),
                                              ),
                                            ),
                                        ],
                                      ),
                                    )
                                  : Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 62,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          _CircleButton(
                                            label: context.l10n.cancel,
                                            symbol: 'xmark',
                                            fallback: Icons.close,
                                            onTap: () =>
                                                setState(selected.clear),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              context.l10n.selected(
                                                selected.length,
                                              ),
                                              style: AppDesign.font(
                                                17,
                                                weight: FontWeight.w600,
                                                color: palette.text,
                                              ),
                                            ),
                                          ),
                                          if (widget.allowSpoiler) ...[
                                            Semantics(
                                              toggled: spoiler,
                                              label:
                                                  context.l10n.hideWithSpoiler,
                                              child: GestureDetector(
                                                onTap: () => setState(
                                                  () => spoiler = !spoiler,
                                                ),
                                                child: Container(
                                                  width: 44,
                                                  height: 44,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: spoiler
                                                        ? palette.accent
                                                        : null,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: AppSymbol.icon(
                                                    spoiler
                                                        ? 'eye.slash.fill'
                                                        : 'eye.slash',
                                                    size: 20,
                                                    color: spoiler
                                                        ? palette.accentText
                                                        : palette.text,
                                                    fallback: Icons
                                                        .visibility_off_outlined,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          GestureDetector(
                                            onTap: send,
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minHeight: 46,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: palette.accent,
                                                borderRadius:
                                                    BorderRadius.circular(23),
                                              ),
                                              child: sending
                                                  ? Center(
                                                      child: SizedBox.square(
                                                        dimension: 20,
                                                        child: CircularProgressIndicator.adaptive(
                                                          valueColor:
                                                              AlwaysStoppedAnimation(
                                                                palette
                                                                    .accentText,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                  : Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          widget.sendLabel,
                                                          style: AppDesign.font(
                                                            16,
                                                            weight:
                                                                FontWeight.w600,
                                                            color: palette
                                                                .accentText,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          constraints:
                                                              const BoxConstraints(
                                                                minWidth: 22,
                                                                minHeight: 22,
                                                              ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 5,
                                                              ),
                                                          alignment:
                                                              Alignment.center,
                                                          decoration: BoxDecoration(
                                                            color: palette
                                                                .accentText,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  11,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            '${selected.length}',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: palette
                                                                  .accent,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final String label, symbol;
  final IconData fallback;
  final Color? color;
  final VoidCallback onTap;
  const _CircleButton({
    required this.label,
    required this.symbol,
    required this.fallback,
    required this.onTap,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: AppSymbol.icon(
          symbol,
          size: 17,
          color: AppPalette.of(context).text,
          fallback: fallback,
        ),
      ),
    ),
  );
}

class _TabButton extends StatelessWidget {
  final AttachmentAction tab;
  final bool active;
  final Color accent;
  final VoidCallback? onTap;
  const _TabButton({
    required this.tab,
    required this.active,
    required this.accent,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = active ? accent : palette.text;
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active
                ? (dark ? const Color(0x1fffffff) : const Color(0x0f000000))
                : null,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppSymbol.icon(
                tab.symbol,
                size: 26,
                color: color,
                fallback: tab.fallback,
              ),
              const SizedBox(height: 2),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppDesign.font(
                  12,
                  weight: active ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridItem extends StatefulWidget {
  final AssetEntity asset;
  final double size;
  final int order;
  final Color accent;
  final bool singlePhoto;
  final VoidCallback onTap;
  const _GridItem({
    super.key,
    required this.asset,
    required this.size,
    required this.order,
    required this.singlePhoto,
    required this.accent,
    required this.onTap,
  });
  @override
  State<_GridItem> createState() => _GridItemState();
}

class _GridItemState extends State<_GridItem> {
  late final Future<Uint8List?> thumbnail = widget.asset.thumbnailDataWithSize(
    const ThumbnailSize.square(300),
  );
  @override
  Widget build(BuildContext context) {
    final selected = widget.order >= 0;
    final video = widget.asset.type == AssetType.video;
    final seconds = widget.asset.duration;
    final duration =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Semantics(
      checked: widget.singlePhoto ? null : selected,
      button: widget.singlePhoto,
      label: video ? '${context.l10n.video}, $duration' : context.l10n.photo,
      child: AppPressable(
        label: '',
        style: AppPressStyle.opacity,
        onPressed: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: selected ? .9 : 1,
              duration: const Duration(milliseconds: 150),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(selected ? 4 : 0),
                child: FutureBuilder(
                  future: thumbnail,
                  builder: (context, snapshot) => snapshot.data == null
                      ? const ColoredBox(color: Color(0x14000000))
                      : Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                ),
              ),
            ),
            if (!widget.singlePhoto)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? widget.accent : const Color(0x2e000000),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      width: 1.5,
                      color: selected ? Colors.white : const Color(0xe6ffffff),
                    ),
                  ),
                  child: selected
                      ? Text(
                          '${widget.order + 1}',
                          style: AppDesign.font(
                            13,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
            if (video)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x73000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    duration,
                    style: AppDesign.font(
                      12,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Hands the modal sheet's shared scroll controller to [builder].
class _SheetScroll extends StatelessWidget {
  final Widget Function(BuildContext context, ScrollController? scroll) builder;
  const _SheetScroll({required this.builder});
  @override
  Widget build(BuildContext context) =>
      builder(context, liquid.ScrollControllerProvider.of(context)?.controller);
}
