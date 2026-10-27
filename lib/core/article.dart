import 'dart:convert';
import 'package:flutter/material.dart';
import '../design/app_design.dart';
import 'api.dart';

@immutable
class ArticleMark {
  final int format;
  final String? link;
  final bool spoiler;
  const ArticleMark({this.format = 0, this.link, this.spoiler = false});
  ArticleMark copy({
    int? format,
    String? link,
    bool clearLink = false,
    bool? spoiler,
  }) => ArticleMark(
    format: format ?? this.format,
    link: clearLink ? null : link ?? this.link,
    spoiler: spoiler ?? this.spoiler,
  );
  TextStyle style(BuildContext context, {bool reveal = true}) {
    final palette = AppPalette.of(context);
    return TextStyle(
      fontWeight: format & 1 != 0 ? FontWeight.w700 : null,
      fontStyle: format & 2 != 0 ? FontStyle.italic : null,
      fontFamily: format & 16 != 0 ? 'monospace' : null,
      color: spoiler && !reveal
          ? Colors.transparent
          : link != null
          ? palette.accent
          : null,
      backgroundColor: spoiler
          ? palette.highlight
          : format & 16 != 0
          ? palette.input
          : null,
      decoration: TextDecoration.combine([
        if (format & 4 != 0) TextDecoration.lineThrough,
        if (format & 8 != 0 || link != null) TextDecoration.underline,
      ]),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ArticleMark &&
      other.format == format &&
      other.link == link &&
      other.spoiler == spoiler;
  @override
  int get hashCode => Object.hash(format, link, spoiler);
}

class ArticleTextController extends TextEditingController {
  List<ArticleMark> marks = [];
  ArticleMark typing = const ArticleMark();
  bool _setting = false;
  ArticleTextController([String text = '', List<ArticleMark>? styles])
    : super(text: text) {
    marks = styles ?? List.filled(text.length, const ArticleMark());
  }
  @override
  set value(TextEditingValue next) {
    if (!_setting && next.text != text) {
      final before = text;
      var prefix = 0;
      while (prefix < before.length &&
          prefix < next.text.length &&
          before.codeUnitAt(prefix) == next.text.codeUnitAt(prefix)) {
        prefix++;
      }
      var suffix = 0;
      while (suffix < before.length - prefix &&
          suffix < next.text.length - prefix &&
          before.codeUnitAt(before.length - suffix - 1) ==
              next.text.codeUnitAt(next.text.length - suffix - 1)) {
        suffix++;
      }
      marks = [
        ...marks.take(prefix),
        ...List.filled(next.text.length - prefix - suffix, typing),
        ...marks.skip(before.length - suffix),
      ];
    }
    super.value = next;
    if (!_setting &&
        next.selection.isValid &&
        next.selection.isCollapsed &&
        text.isNotEmpty) {
      typing = marks[(next.selection.start - 1).clamp(0, marks.length - 1)];
    }
  }

  void replace(String next, List<ArticleMark> styles, {int? caret}) {
    _setting = true;
    marks = List.of(styles);
    super.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: (caret ?? next.length).clamp(0, next.length),
      ),
    );
    _setting = false;
  }

  ArticleMark get selectedMark {
    final range = selection;
    if (!range.isValid || range.isCollapsed || marks.isEmpty) return typing;
    final selected = marks.sublist(
      range.start.clamp(0, marks.length),
      range.end.clamp(0, marks.length),
    );
    if (selected.isEmpty) return typing;
    return ArticleMark(
      format: selected.map((m) => m.format).reduce((a, b) => a & b),
      link: selected.every((m) => m.link == selected.first.link)
          ? selected.first.link
          : null,
      spoiler: selected.every((m) => m.spoiler),
    );
  }

  void apply(ArticleMark Function(ArticleMark) change) {
    final range = selection;
    if (range.isValid && !range.isCollapsed) {
      for (var i = range.start; i < range.end && i < marks.length; i++) {
        marks[i] = change(marks[i]);
      }
    }
    typing = change(typing);
    notifyListeners();
  }

  List<Json> get nodes {
    final result = <Json>[];
    var start = 0;
    while (start < text.length) {
      final mark = marks[start];
      var end = start + 1;
      while (end < text.length &&
          marks[end] == mark &&
          text[end] != '\n' &&
          text[start] != '\n') {
        end++;
      }
      Json node = text[start] == '\n'
          ? {'type': 'linebreak', 'version': 1}
          : {
              'type': 'text',
              'version': 1,
              'text': text.substring(start, end),
              'format': mark.format,
              'detail': 0,
              'mode': 'normal',
              'style': mark.spoiler ? 'background-color: currentcolor;' : '',
            };
      if (mark.link != null) {
        node = {
          'type': 'link',
          'version': 1,
          'url': mark.link,
          'children': [node],
          'direction': null,
          'format': '',
          'indent': 0,
        };
      }
      result.add(node);
      start = end;
    }
    return result;
  }

  static ArticleTextController fromNodes(List<dynamic> nodes) {
    final buffer = StringBuffer();
    final styles = <ArticleMark>[];
    void read(dynamic value, String? url) {
      final node = object(value);
      final type = node['type'];
      if (type == 'text' || type == 'linebreak' || type == 'code-highlight') {
        final value = type == 'linebreak' ? '\n' : string(node['text']);
        buffer.write(value);
        styles.addAll(
          List.filled(
            value.length,
            ArticleMark(
              format: node['format'] is num
                  ? (node['format'] as num).toInt()
                  : 0,
              link: url,
              spoiler: string(node['style']).contains('currentcolor'),
            ),
          ),
        );
      } else {
        for (final child in node['children'] as List? ?? []) {
          read(
            child,
            type == 'link' || type == 'autolink' ? string(node['url']) : url,
          );
        }
      }
    }

    for (final node in nodes) {
      read(node, null);
    }
    return ArticleTextController(buffer.toString(), styles);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <InlineSpan>[];
    var start = 0;
    while (start < text.length) {
      final mark = marks[start];
      final composing =
          withComposing &&
          value.composing.isValid &&
          start >= value.composing.start &&
          start < value.composing.end;
      var end = start + 1;
      while (end < text.length &&
          marks[end] == mark &&
          (!withComposing ||
              end != value.composing.start && end != value.composing.end)) {
        end++;
      }
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: mark
              .style(context)
              .merge(
                composing
                    ? const TextStyle(decoration: TextDecoration.underline)
                    : null,
              ),
        ),
      );
      start = end;
    }
    return TextSpan(style: style, children: spans);
  }
}

class ArticleBlock {
  final String id;
  String type;
  bool checked;
  final ArticleTextController text;
  final FocusNode focus = FocusNode();
  final List<List<ArticleBlock>> rows;
  static int _sequence = 0;
  ArticleBlock({
    this.type = 'paragraph',
    ArticleTextController? text,
    this.checked = false,
    List<List<ArticleBlock>>? rows,
  }) : id = 'article-${_sequence++}',
       text = text ?? ArticleTextController(),
       rows = rows ?? [];
  Json get node {
    final base = <String, dynamic>{
      'type': type,
      'version': 1,
      'direction': null,
      'format': '',
      'indent': 0,
      'children': text.nodes,
    };
    if (type.startsWith('h') && type.length == 2) {
      return {...base, 'type': 'heading', 'tag': type};
    }
    if (type == 'table') {
      return {
        ...base,
        'children': rows
            .map(
              (row) => {
                'type': 'tablerow',
                'version': 1,
                'children': row
                    .map(
                      (cell) => {
                        'type': 'tablecell',
                        'version': 1,
                        'headerState': 0,
                        'colSpan': 1,
                        'rowSpan': 1,
                        'children': [cell.node],
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      };
    }
    if (['bullet', 'number', 'check'].contains(type)) {
      return {
        ...base,
        'type': 'listitem',
        'value': 1,
        'checked': type == 'check' ? checked : null,
      };
    }
    return base;
  }

  void dispose() {
    text.dispose();
    focus.dispose();
    for (final row in rows) {
      for (final cell in row) {
        cell.dispose();
      }
    }
  }
}

class ArticleController extends ChangeNotifier {
  List<ArticleBlock> blocks = [];
  ArticleBlock? active;
  final _undo = <Json>[], _redo = <Json>[];
  Json _last = {};
  bool _mutating = false;
  DateTime? _typedAt;
  ArticleController() {
    restore(lexical(''));
  }
  ArticleTextController get input => (active ?? blocks.first).text;
  bool get hasSelection =>
      input.selection.isValid && !input.selection.isCollapsed;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  String get text => blocks
      .map(
        (b) => b.type == 'table'
            ? b.rows.map((r) => r.map((c) => c.text.text).join('\t')).join('\n')
            : b.text.text,
      )
      .join('\n');
  ArticleBlock? get table => blocks
      .where((b) => b.type == 'table' && b.rows.any((r) => r.contains(active)))
      .firstOrNull;
  Json get document {
    final children = <Json>[];
    for (final block in blocks) {
      if (['bullet', 'number', 'check'].contains(block.type)) {
        if (children.isEmpty ||
            children.last['type'] != 'list' ||
            children.last['listType'] != block.type) {
          children.add({
            'type': 'list',
            'version': 1,
            'listType': block.type,
            'tag': block.type == 'number' ? 'ol' : 'ul',
            'start': 1,
            'direction': null,
            'format': '',
            'indent': 0,
            'children': <Json>[],
          });
        }
        final items = children.last['children'] as List<Json>;
        items.add({...block.node, 'value': items.length + 1});
      } else {
        children.add(block.node);
      }
    }
    return {
      'root': {
        'type': 'root',
        'version': 1,
        'direction': null,
        'format': '',
        'indent': 0,
        'children': children,
      },
    };
  }

  void _bind(ArticleBlock block) {
    block.text.addListener(() => _changed(block));
    block.focus.addListener(() {
      if (block.focus.hasFocus && !_mutating) {
        active = block;
        notifyListeners();
      }
    });
    for (final row in block.rows) {
      for (final cell in row) {
        _bind(cell);
      }
    }
  }

  void restore(Json document, {bool history = false}) {
    _mutating = true;
    final old = blocks;
    blocks = [];
    ArticleBlock decode(Json node, {String? listType}) {
      final type = string(node['type']);
      if (type == 'table') {
        return ArticleBlock(
          type: 'table',
          rows: (node['children'] as List? ?? [])
              .map(
                (row) => (object(row)['children'] as List? ?? [])
                    .map(
                      (cell) => ArticleBlock(
                        text: ArticleTextController.fromNodes(
                          object(cell)['children'] as List? ?? [],
                        ),
                      ),
                    )
                    .toList(),
              )
              .toList(),
        );
      }
      return ArticleBlock(
        type: listType ?? (type == 'heading' ? string(node['tag']) : type),
        checked: node['checked'] == true,
        text: ArticleTextController.fromNodes(node['children'] as List? ?? []),
      );
    }

    for (final item in object(document['root'])['children'] as List? ?? []) {
      final node = object(item);
      if (node['type'] == 'list') {
        for (final child in node['children'] as List? ?? []) {
          blocks.add(decode(object(child), listType: string(node['listType'])));
        }
      } else {
        blocks.add(decode(node));
      }
    }
    if (blocks.isEmpty) blocks.add(ArticleBlock());
    for (final block in blocks) {
      _bind(block);
    }
    active = blocks.first.type == 'table'
        ? blocks.first.rows.firstOrNull?.firstOrNull
        : blocks.first;
    _last = this.document;
    if (!history) {
      _undo.clear();
      _redo.clear();
    }
    _mutating = false;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final block in old) {
        block.dispose();
      }
    });
  }

  void _commit({bool typing = false}) {
    final next = document;
    if (jsonEncode(next) != jsonEncode(_last)) {
      final now = DateTime.now();
      if (!typing ||
          _typedAt == null ||
          now.difference(_typedAt!).inMilliseconds > 400) {
        _undo.add(_last);
      }
      if (_undo.length > 100) _undo.removeAt(0);
      _redo.clear();
      _last = next;
      _typedAt = typing ? now : null;
    }
    notifyListeners();
  }

  void _changed(ArticleBlock block) {
    if (_mutating) return;
    active = block;
    if (block.text.text.contains('\n') &&
        block.type != 'code' &&
        table == null &&
        block.text.value.composing.isCollapsed) {
      _mutating = true;
      final position = blocks.indexOf(block);
      final oldText = block.text.text,
          oldMarks = List<ArticleMark>.of(block.text.marks);
      final lines = oldText.split('\n');
      final selection = block.text.selection;
      final cursor = selection.isValid
          ? selection.extentOffset
          : oldText.length;
      var offset = 0;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final next = i == 0
            ? block
            : ArticleBlock(
                type: block.type.startsWith('h') ? 'paragraph' : block.type,
              );
        next.text.replace(
          line,
          oldMarks.sublist(offset, offset + line.length),
          caret: (cursor - offset).clamp(0, line.length),
        );
        if (i > 0) {
          blocks.insert(position + i, next);
          _bind(next);
        }
        if (cursor >= offset && cursor <= offset + line.length) active = next;
        offset += line.length + 1;
      }
      if (lines.length == 2 &&
          lines.every((s) => s.isEmpty) &&
          ['bullet', 'number', 'check'].contains(block.type)) {
        final extra = blocks.removeAt(position + 1);
        extra.dispose();
        block.type = 'paragraph';
        active = block;
      }
      _mutating = false;
      focusActive();
    }
    _commit(typing: true);
  }

  void focusActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) active?.focus.requestFocus();
    });
  }

  void mutate(VoidCallback change) {
    _mutating = true;
    change();
    _mutating = false;
    _commit();
    focusActive();
  }

  void format(int bit) {
    final enabled = input.selectedMark.format & bit == 0;
    mutate(
      () => input.apply(
        (mark) =>
            mark.copy(format: enabled ? mark.format | bit : mark.format & ~bit),
      ),
    );
  }

  void spoiler() {
    final enabled = !input.selectedMark.spoiler;
    mutate(() => input.apply((mark) => mark.copy(spoiler: enabled)));
  }

  void link(String? url) => mutate(
    () => input.apply((mark) => mark.copy(link: url, clearLink: url == null)),
  );
  void block(String type) {
    if (table != null) return;
    mutate(() => active!.type = type);
  }

  void insert(String text) {
    final selection = input.selection;
    final start = selection.isValid ? selection.start : input.text.length,
        end = selection.isValid ? selection.end : input.text.length;
    input.value = TextEditingValue(
      text: input.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    focusActive();
  }

  void addTable() => mutate(() {
    final node = ArticleBlock(
      type: 'table',
      rows: List.generate(2, (_) => List.generate(2, (_) => ArticleBlock())),
    );
    final index = blocks.indexOf(active!) + 1;
    blocks.insert(index, node);
    _bind(node);
    if (index == blocks.length - 1) {
      final tail = ArticleBlock();
      blocks.add(tail);
      _bind(tail);
    }
    active = node.rows.first.first;
  });
  void tableAction(String action) {
    final node = table;
    if (node == null) return;
    mutate(() {
      final row = node.rows.indexWhere((r) => r.contains(active));
      final column = node.rows[row].indexOf(active!);
      final deleteTable =
          action == 'deleteTable' ||
          action == 'deleteRow' && node.rows.length == 1 ||
          action == 'deleteColumn' && node.rows.first.length == 1;
      if (action == 'row') {
        final cells = List.generate(
          node.rows.first.length,
          (_) => ArticleBlock(),
        );
        node.rows.insert(row + 1, cells);
        for (final cell in cells) {
          _bind(cell);
        }
        active = cells[column];
      }
      if (action == 'column') {
        for (final r in node.rows) {
          final cell = ArticleBlock();
          r.insert(column + 1, cell);
          _bind(cell);
        }
        active = node.rows[row][column + 1];
      }
      if (action == 'deleteRow' && node.rows.length > 1) {
        final removed = node.rows.removeAt(row);
        active = node.rows[row.clamp(0, node.rows.length - 1)][column];
        _retire(removed);
      }
      if (action == 'deleteColumn' && node.rows.first.length > 1) {
        final removed = <ArticleBlock>[];
        for (final r in node.rows) {
          removed.add(r.removeAt(column));
        }
        active = node.rows[row][column.clamp(0, node.rows.first.length - 1)];
        _retire(removed);
      }
      if (deleteTable) {
        final index = blocks.indexOf(node);
        blocks.remove(node);
        if (blocks.isEmpty) {
          final b = ArticleBlock();
          blocks.add(b);
          _bind(b);
        }
        active = blocks[index.clamp(0, blocks.length - 1)];
        _retire([node]);
      }
    });
  }

  void _retire(List<ArticleBlock> nodes) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final node in nodes) {
        node.dispose();
      }
    });
  }

  bool mergePrevious() {
    final current = active;
    if (current == null ||
        table != null ||
        !input.selection.isCollapsed ||
        input.selection.start != 0) {
      return false;
    }
    final index = blocks.indexOf(current);
    if (index <= 0 || blocks[index - 1].type == 'table') return false;
    mutate(() {
      final previous = blocks[index - 1];
      final caret = previous.text.text.length;
      previous.text.replace(previous.text.text + current.text.text, [
        ...previous.text.marks,
        ...current.text.marks,
      ], caret: caret);
      blocks.removeAt(index);
      active = previous;
      _retire([current]);
    });
    return true;
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(document);
    restore(_undo.removeLast(), history: true);
    _typedAt = null;
    focusActive();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(document);
    restore(_redo.removeLast(), history: true);
    _typedAt = null;
    focusActive();
  }

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    for (final block in blocks) {
      block.dispose();
    }
    super.dispose();
  }
}
