import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/article.dart';
import '../core/attachments.dart';
import '../core/api.dart';
import '../design/app_design.dart';
import '../l10n/l10n.dart';
import '../screens/emoticons.dart';
import 'components.dart';
import 'attachment_controls.dart';
import 'glass_surface.dart';
import 'message_field.dart';

class ArticleEditor extends StatelessWidget {
  final ArticleController controller;
  final AttachmentController attachments;
  final bool sending;
  final String? error;
  final VoidCallback onSend;
  const ArticleEditor({
    super.key,
    required this.controller,
    required this.attachments,
    required this.onSend,
    this.sending = false,
    this.error,
  });

  Future<void> _link(BuildContext context) async {
    final input = controller.input;
    final value = await sheet<String>(
      context,
      _ArticleLink(initial: input.selectedMark.link),
    );
    if (value != null && context.mounted) {
      controller.link(value.isEmpty ? null : value);
    }
    controller.focusActive();
  }

  Future<void> _emoji(BuildContext context) async {
    final value = await EmoticonPicker.show(context, initialTab: 'emoji');
    if (value == null || !context.mounted) return;
    if (value['kind'] == 'emoji') {
      controller.insert(string(value['emoji']));
    } else {
      attachments.emoticon = value;
      attachments.changed();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, attachments]),
    builder: (context, _) {
      final palette = AppPalette.of(context), l = context.l10n;
      final selected = controller.hasSelection,
          mark = controller.input.selectedMark;
      final table = controller.table;
      final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
      final sideInset = keyboardVisible
          ? AppDesign.articleSideInset
          : AppDesign.articleRestingSideInset;
      _ArticleTool tool(
        String label,
        String glyph,
        VoidCallback? action, {
        bool active = false,
      }) => (
        id: glyph,
        selected: active,
        child: Semantics(
          selected: active,
          child: AppIconButton(
            tooltip: label,
            icon: AppSymbol.native('article.$glyph'),
            embedded: true,
            dimension: AppDesign.articleToolWidth,
            onPressed: sending ? null : action,
            color: active ? Colors.white : palette.text,
          ),
        ),
      );
      _ArticleTool menu(String label, String glyph, List<AppMenuItem> items) =>
          (
            id: glyph,
            selected: false,
            child: AppContextMenu(
              label: label,
              pressTrigger: true,
              liftContent: false,
              enabled: !sending,
              items: items,
              child: SizedBox(
                width: AppDesign.articleToolWidth,
                height: AppDesign.articleBarHeight,
                child: Center(
                  child: AppSymbol.native(
                    'article.$glyph',
                    color: sending
                        ? palette.text.withValues(alpha: .4)
                        : palette.text,
                  ),
                ),
              ),
            ),
          );
      final blockMenu = menu(l.add, selected ? 'quote' : 'add', [
        AppMenuItem(
          title: l.articleParagraph,
          symbol: 'textformat.paragraph',
          onPressed: () => controller.block('paragraph'),
          checked: controller.active?.type == 'paragraph',
        ),
        AppMenuItem(
          title: l.articleHeading,
          symbol: 'textformat.heading',
          children: [
            for (var i = 1; i <= 6; i++)
              AppMenuItem(
                title: '${l.articleHeading} $i',
                symbol: 'textformat.h$i',
                textStyle:
                    AppDesign.font(
                      AppDesign.articleMenuHeadingSizes[i - 1],
                      weight: FontWeight.w600,
                    ).copyWith(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: ['serif'],
                    ),
                onPressed: () => controller.block('h$i'),
                checked: controller.active?.type == 'h$i',
              ),
          ],
        ),
        AppMenuItem(
          title: l.articleQuote,
          symbol: 'text.quote',
          onPressed: () => controller.block('quote'),
          separatorBefore: true,
        ),
        AppMenuItem(
          title: l.articleCode,
          symbol: 'chevron.left.forwardslash.chevron.right',
          onPressed: () => controller.block('code'),
        ),
      ]);
      final listMenu = menu(l.articleList, 'list', [
        AppMenuItem(
          title: l.articleParagraph,
          symbol: 'textformat.paragraph',
          onPressed: () => controller.block('paragraph'),
        ),
        AppMenuItem(
          title: l.articleBullets,
          symbol: 'article.bullet',
          onPressed: () => controller.block('bullet'),
          checked: controller.active?.type == 'bullet',
        ),
        AppMenuItem(
          title: l.articleNumbered,
          symbol: 'list.number',
          onPressed: () => controller.block('number'),
          checked: controller.active?.type == 'number',
        ),
        AppMenuItem(
          title: l.articleChecklist,
          symbol: 'checklist',
          onPressed: () => controller.block('check'),
          checked: controller.active?.type == 'check',
        ),
      ]);
      final tools = selected
          ? <_ArticleTool>[
              tool(
                l.articleBold,
                'bold',
                () => controller.format(1),
                active: mark.format & 1 != 0,
              ),
              tool(
                l.articleItalic,
                'italic',
                () => controller.format(2),
                active: mark.format & 2 != 0,
              ),
              tool(
                l.articleStrike,
                'strike',
                () => controller.format(4),
                active: mark.format & 4 != 0,
              ),
              tool(
                l.articleUnderline,
                'underline',
                () => controller.format(8),
                active: mark.format & 8 != 0,
              ),
              tool(
                l.articleSpoiler,
                'spoiler',
                controller.spoiler,
                active: mark.spoiler,
              ),
              tool(
                l.articleLink,
                'link',
                () => _link(context),
                active: mark.link != null,
              ),
              if (table == null) ...[listMenu, blockMenu],
            ]
          : <_ArticleTool>[
              if (table == null) blockMenu,
              if (table == null) listMenu,
              if (table == null)
                tool(l.articleTable, 'table', controller.addTable)
              else
                menu(l.articleTable, 'table', [
                  AppMenuItem(
                    title: l.articleAddRow,
                    symbol: 'table.row.add',
                    onPressed: () => controller.tableAction('row'),
                  ),
                  AppMenuItem(
                    title: l.articleAddColumn,
                    symbol: 'table.column.add',
                    onPressed: () => controller.tableAction('column'),
                  ),
                  AppMenuItem(
                    title: l.articleDeleteRow,
                    symbol: 'table.row.remove',
                    onPressed: () => controller.tableAction('deleteRow'),
                    destructive: true,
                    separatorBefore: true,
                  ),
                  AppMenuItem(
                    title: l.articleDeleteColumn,
                    symbol: 'table.column.remove',
                    onPressed: () => controller.tableAction('deleteColumn'),
                    destructive: true,
                  ),
                  AppMenuItem(
                    title: l.articleDeleteTable,
                    symbol: 'table.remove',
                    onPressed: () => controller.tableAction('deleteTable'),
                    destructive: true,
                  ),
                ]),
              tool(
                l.attach,
                'attach',
                () => chooseAttachment(context, attachments),
              ),
              tool(l.emojiStickersAndGifs, 'emoji', () => _emoji(context)),
            ];
      return AppScaffold(
        backgroundColor: palette.row,
        extendBodyBehindAppBar: true,
        appBar: AppHeader(
          edge: AppHeaderEdge.soft,
          title: Text(l.article),
          leading: AppIconButton(
            tooltip: l.cancel,
            icon: const AppSymbol.native('article.close'),
            onPressed: sending ? null : () => Navigator.of(context).maybePop(),
          ),
          actions: [
            GlassSurface(
              role: GlassSurfaceRole.control,
              radius: 22,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconButton(
                    tooltip: l.undo,
                    icon: const AppSymbol.native('article.undo'),
                    embedded: true,
                    color: palette.text,
                    onPressed: !sending && controller.canUndo
                        ? controller.undo
                        : null,
                  ),
                  AppIconButton(
                    tooltip: l.redo,
                    icon: const AppSymbol.native('article.redo'),
                    embedded: true,
                    color: palette.text,
                    onPressed: !sending && controller.canRedo
                        ? controller.redo
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        body: CallbackShortcuts(
          bindings: sending
              ? const {}
              : {
                  const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
                      controller.undo,
                  const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                    shift: true,
                  ): controller.redo,
                  const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                      controller.undo,
                  const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    control: true,
                    shift: true,
                  ): controller.redo,
                  const SingleActivator(
                    LogicalKeyboardKey.keyB,
                    meta: true,
                  ): () =>
                      controller.format(1),
                  const SingleActivator(
                    LogicalKeyboardKey.keyI,
                    meta: true,
                  ): () =>
                      controller.format(2),
                  const SingleActivator(
                    LogicalKeyboardKey.keyU,
                    meta: true,
                  ): () =>
                      controller.format(8),
                },
          child: Stack(
            children: [
              Positioned.fill(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.paddingOf(context).top +
                        AppDesign.headerInset(context) +
                        16,
                    16,
                    MediaQuery.paddingOf(context).bottom + 88,
                  ),
                  children: [
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            error!,
                            style: TextStyle(color: palette.destructive),
                          ),
                        ),
                      ),
                    for (var i = 0; i < controller.blocks.length; i++)
                      _ArticleBlockView(
                        key: ValueKey(controller.blocks[i].id),
                        block: controller.blocks[i],
                        controller: controller,
                        enabled: !sending,
                        autofocus: i == 0,
                        number: _number(i),
                      ),
                    if (attachments.hasContent)
                      IgnorePointer(
                        ignoring: sending,
                        child: AttachmentPreview(controller: attachments),
                      ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: sending ? null : controller.focusActive,
                      child: const SizedBox(height: 120),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: sideInset + MediaQuery.paddingOf(context).left,
                right: sideInset + MediaQuery.paddingOf(context).right,
                bottom:
                    MediaQuery.paddingOf(context).bottom +
                    AppDesign.articleToolGap,
                child: Row(
                  children: [
                    AppIconButton(
                      tooltip: l.articleKeyboard,
                      icon: RotatedBox(
                        quarterTurns: keyboardVisible ? 0 : 2,
                        child: const AppSymbol.native('article.keyboard'),
                      ),
                      surfaceRole: GlassSurfaceRole.control,
                      onPressed: keyboardVisible
                          ? () => FocusManager.instance.primaryFocus?.unfocus()
                          : controller.focusActive,
                    ),
                    const SizedBox(width: AppDesign.articleToolGap),
                    Expanded(
                      child: _ArticleActionBar(
                        mode: selected
                            ? 'selection'
                            : table != null
                            ? 'table'
                            : 'insert',
                        tools: tools,
                        enabled: !sending,
                      ),
                    ),
                    const SizedBox(width: AppDesign.articleToolGap),
                    AppIconButton(
                      key: const ValueKey('article.send'),
                      tooltip: l.share,
                      icon: sending
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const AppSymbol.native('article.send'),
                      prominent: true,
                      backgroundColor:
                          controller.text.trim().isEmpty &&
                              !attachments.hasContent
                          ? AppDesign.articleDisabledSend
                          : palette.accent,
                      color: Colors.white,
                      onPressed:
                          sending ||
                              controller.text.trim().isEmpty &&
                                  !attachments.hasContent
                          ? null
                          : onSend,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  int _number(int index) {
    var count = 1;
    while (index > 0 && controller.blocks[--index].type == 'number') {
      count++;
    }
    return count;
  }
}

typedef _ArticleTool = ({String id, bool selected, Widget child});

class _ArticleActionBar extends StatefulWidget {
  final String mode;
  final List<_ArticleTool> tools;
  final bool enabled;
  const _ArticleActionBar({
    required this.mode,
    required this.tools,
    required this.enabled,
  });
  @override
  State<_ArticleActionBar> createState() => _ArticleActionBarState();
}

class _ArticleActionBarState extends State<_ArticleActionBar>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(vsync: this, value: 1);
  List<_ArticleTool>? outgoing;
  @override
  void didUpdateWidget(_ArticleActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      if (MediaQuery.disableAnimationsOf(context)) {
        outgoing = null;
        motion.value = 1;
      } else {
        outgoing = oldWidget.tools;
        motion.duration =
            AppDesign.articleToolsTransition +
            Duration(
              milliseconds:
                  40 +
                  (math.max(oldWidget.tools.length, widget.tools.length) - 1) *
                      20,
            );
        motion.forward(from: 0).whenComplete(() {
          if (mounted) setState(() => outgoing = null);
        });
      }
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPressable(
    label: '',
    style: AppPressStyle.glass,
    observeOnly: true,
    enabled: widget.enabled,
    child: GlassSurface(
      role: GlassSurfaceRole.control,
      radius: 22,
      interactive: widget.enabled,
      hostsScrolling: true,
      child: SizedBox(
        height: AppDesign.articleBarHeight,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AnimatedBuilder(
              animation: motion,
              builder: (context, _) => Stack(
                children: [
                  if (outgoing != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: strip(context, outgoing!, exiting: true),
                        ),
                      ),
                    ),
                  strip(context, widget.tools),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget strip(
    BuildContext context,
    List<_ArticleTool> tools, {
    bool exiting = false,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final available = constraints.maxWidth;
      const width = AppDesign.articleToolWidth;
      final fits = tools.length * width <= available;
      final visible = math.max(1.5, (available / width - .5).floor() + .5);
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final gap = fits
          ? (math.max(
                          0.0,
                          (available - tools.length * width) /
                              math.max(1, tools.length - 1),
                        ) *
                        pixelRatio)
                    .floor() /
                pixelRatio
          : math.max(0.0, available / visible - width);
      final contentWidth =
          tools.length * width + math.max(0, tools.length - 1) * gap;
      final elapsed = motion.value * (motion.duration?.inMilliseconds ?? 0);
      double progress(int i) {
        if (MediaQuery.disableAnimationsOf(context)) return exiting ? 0 : 1;
        if (outgoing == null) return 1;
        final t =
            ((elapsed - (exiting ? 0 : 40) - i * 20) /
                    AppDesign.articleToolsTransition.inMilliseconds)
                .clamp(0.0, 1.0);
        return exiting
            ? 1 - Curves.easeInCubic.transform(t)
            : Curves.easeOutCubic.transform(t);
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: contentWidth,
          height: 36,
          child: Stack(
            children: [
              for (var i = 0; i < tools.length; i++)
                if (tools[i].selected)
                  PositionedDirectional(
                    start: i * (width + gap),
                    top: 0,
                    bottom: 0,
                    width: i + 1 < tools.length && tools[i + 1].selected
                        ? width * 2 + gap - 4
                        : width,
                    child: Opacity(
                      opacity: progress(i),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppPalette.of(context).accent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
              Row(
                children: [
                  for (var i = 0; i < tools.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    SizedBox(
                      width: width,
                      height: 36,
                      child: Opacity(
                        opacity: progress(i),
                        child: Transform.scale(
                          scale: .001 + .999 * progress(i),
                          child: tools[i].child,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ArticleBlockView extends StatelessWidget {
  final ArticleBlock block;
  final ArticleController controller;
  final bool enabled, autofocus;
  final int number;
  const _ArticleBlockView({
    super.key,
    required this.block,
    required this.controller,
    required this.enabled,
    this.autofocus = false,
    this.number = 1,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (block.type == 'table') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.sizeOf(context).width - 32,
            ),
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(160),
              border: TableBorder.all(color: palette.border),
              children: [
                for (final row in block.rows)
                  TableRow(
                    children: [
                      for (final cell in row)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: _ArticleBlockView(
                            key: ValueKey(cell.id),
                            block: cell,
                            controller: controller,
                            enabled: enabled,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final heading = block.type.startsWith('h') && block.type.length == 2
        ? int.tryParse(block.type.substring(1))
        : null;
    final quote = block.type == 'quote', code = block.type == 'code';
    final fontSize = heading == null
        ? AppDesign.articleTextSize
        : AppDesign.articleHeadingSizes[(heading - 1).clamp(0, 5)];
    Widget field = Focus(
      onKeyEvent: (_, event) =>
          enabled &&
              event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.mergePrevious()
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: MessageField(
        key: ValueKey('field.${block.id}'),
        controller: block.text,
        focusNode: block.focus,
        plain: true,
        maxHeight: null,
        maxLines: null,
        autofocus: autofocus,
        enabled: enabled,
        placeholder: controller.blocks.length == 1
            ? context.l10n.articlePlaceholder
            : '',
        textStyle:
            AppDesign.font(
              fontSize,
              color: palette.text,
              height: 1.35,
              weight: heading == null ? FontWeight.w400 : FontWeight.w500,
            ).copyWith(
              fontFamily: code
                  ? 'monospace'
                  : heading != null
                  ? 'Georgia'
                  : null,
            ),
      ),
    );
    if (['bullet', 'number', 'check'].contains(block.type)) {
      field = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: block.type == 'check' ? 59 : 30,
            child: block.type == 'check'
                ? AppSwitch(
                    value: block.checked,
                    onChanged: enabled
                        ? (value) =>
                              controller.mutate(() => block.checked = value)
                        : null,
                  )
                : Text(
                    block.type == 'number' ? '$number.' : '•',
                    style: AppDesign.font(
                      fontSize,
                      height: 1.35,
                      color: palette.text,
                    ),
                  ),
          ),
          Expanded(child: field),
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        top: heading != null
            ? 14
            : quote || code
            ? 6
            : 0,
        bottom: 8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: quote
              ? palette.accent.withValues(alpha: .08)
              : code
              ? palette.highlight
              : null,
          border: quote
              ? BorderDirectional(
                  start: BorderSide(color: palette.accent, width: 3),
                )
              : null,
          borderRadius: quote || code ? BorderRadius.circular(4) : null,
        ),
        child: Padding(
          padding: quote
              ? const EdgeInsets.symmetric(horizontal: 9, vertical: 4)
              : code
              ? const EdgeInsets.all(12)
              : EdgeInsets.zero,
          child: field,
        ),
      ),
    );
  }
}

class _ArticleLink extends StatefulWidget {
  final String? initial;
  const _ArticleLink({this.initial});
  @override
  State<_ArticleLink> createState() => _ArticleLinkState();
}

class _ArticleLinkState extends State<_ArticleLink> {
  late final input = TextEditingController(text: widget.initial);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState!.validate()) {
      Navigator.pop(context, input.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(
      title: Text(context.l10n.articleLink),
      actions: [
        AppButton.text(onPressed: submit, child: Text(context.l10n.done)),
      ],
    ),
    body: Form(
      key: form,
      child: Column(
        children: [
          AppSection(
            children: [
              AppField(
                controller: input,
                label: context.l10n.articleLink,
                placeholder: 'https://',
                autofocus: true,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onSubmitted: (_) => submit(),
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  return uri != null &&
                          [
                            'http',
                            'https',
                            'mailto',
                            'tel',
                          ].contains(uri.scheme) &&
                          (uri.host.isNotEmpty ||
                              ['mailto', 'tel'].contains(uri.scheme) &&
                                  uri.path.isNotEmpty)
                      ? null
                      : context.l10n.articleInvalidLink;
                },
              ),
            ],
          ),
          if (widget.initial != null)
            AppButton.text(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(context.l10n.articleRemoveLink),
            ),
        ],
      ),
    ),
  );
}
