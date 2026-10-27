import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/article.dart';
import '../core/localized_content.dart';
import '../design/app_design.dart';

class ArticleContent extends StatefulWidget {
  final dynamic content;
  final TextStyle? style;
  final String? defaultLanguage;
  const ArticleContent({
    super.key,
    required this.content,
    this.style,
    this.defaultLanguage,
  });
  @override
  State<ArticleContent> createState() => _ArticleContentState();
}

class _ArticleContentState extends State<ArticleContent> {
  final recognizers = <TapGestureRecognizer>[];
  final revealed = <String>{};
  void release() {
    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
    recognizers.clear();
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    release();
    final palette = AppPalette.of(context);
    final base =
        widget.style ??
        AppDesign.font(
          AppDesign.articleTextSize,
          color: palette.text,
          height: 1.35,
        );
    final root = localizedDocument(
      widget.content,
      language: Localizations.localeOf(context).toLanguageTag(),
      defaultLanguage: widget.defaultLanguage,
    );
    List<dynamic> childrenOf(Json node) =>
        node['children'] is List ? node['children'] as List : const [];
    List<InlineSpan> spans(
      List<dynamic> children, {
      String? link,
      String path = '',
    }) {
      final result = <InlineSpan>[];
      for (var i = 0; i < children.length; i++) {
        final node = object(children[i]), key = '$path.$i';
        if (node['type'] == 'linebreak') {
          result.add(const TextSpan(text: '\n'));
          continue;
        }
        if (node['type'] == 'text' || node['type'] == 'code-highlight') {
          final mark = ArticleMark(
            format: node['format'] is num ? (node['format'] as num).toInt() : 0,
            link: link,
            spoiler: string(node['style']).contains('currentcolor'),
          );
          TapGestureRecognizer? recognizer;
          if (mark.spoiler && !revealed.contains(key)) {
            recognizer = TapGestureRecognizer()
              ..onTap = () => setState(() => revealed.add(key));
          } else if (link != null) {
            final uri = Uri.tryParse(link);
            if (uri != null &&
                ['http', 'https', 'mailto', 'tel'].contains(uri.scheme)) {
              recognizer = TapGestureRecognizer()
                ..onTap = () =>
                    launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
          if (recognizer != null) recognizers.add(recognizer);
          result.add(
            TextSpan(
              text: string(node['text']),
              style: mark.style(context, reveal: revealed.contains(key)),
              recognizer: recognizer,
            ),
          );
        } else {
          result.addAll(
            spans(
              childrenOf(node),
              link: node['type'] == 'link' || node['type'] == 'autolink'
                  ? string(node['url'])
                  : link,
              path: key,
            ),
          );
        }
      }
      return result;
    }

    Widget render(Json node, String path) {
      final type = string(node['type']), children = childrenOf(node);
      if (type == 'table') {
        final rows = children.map((row) => childrenOf(object(row))).toList();
        final columns = rows.fold<int>(
          0,
          (count, row) => row.length > count ? row.length : count,
        );
        if (columns == 0) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, size) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: FixedColumnWidth(
                (size.maxWidth / columns).clamp(100, 280),
              ),
              border: TableBorder.all(color: palette.border),
              children: [
                for (var r = 0; r < rows.length; r++)
                  TableRow(
                    children: [
                      for (var c = 0; c < columns; c++)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (c < rows[r].length)
                                for (final paragraph in childrenOf(
                                  object(rows[r][c]),
                                ))
                                  render(object(paragraph), '$path.$r.$c'),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      }
      if (type == 'list') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: node['listType'] == 'check'
                          ? Icon(
                              object(children[i])['checked'] == true
                                  ? Icons.check_box_outlined
                                  : Icons.check_box_outline_blank,
                              size: 20,
                              color: palette.accent,
                            )
                          : Text(
                              node['listType'] == 'number' ? '${i + 1}.' : '•',
                              style: base,
                            ),
                    ),
                    Expanded(child: render(object(children[i]), '$path.$i')),
                  ],
                ),
              ),
          ],
        );
      }
      final heading = type == 'heading'
          ? int.tryParse(string(node['tag']).replaceFirst('h', ''))
          : null;
      var style = base;
      if (heading != null) {
        style = style.copyWith(
          fontSize: AppDesign.articleHeadingSizes[(heading - 1).clamp(0, 5)],
          fontWeight: FontWeight.w600,
          fontFamily: 'Georgia',
          fontFamilyFallback: ['serif'],
        );
      }
      if (type == 'code') style = style.copyWith(fontFamily: 'monospace');
      Widget text = Text.rich(
        TextSpan(children: spans(children, path: path)),
        style: style,
        textDirection: switch (node['direction']) {
          'rtl' => TextDirection.rtl,
          'ltr' => TextDirection.ltr,
          _ => null,
        },
        textAlign: switch (node['format']) {
          'center' => TextAlign.center,
          'right' => TextAlign.right,
          'left' => TextAlign.left,
          'justify' => TextAlign.justify,
          _ => TextAlign.start,
        },
      );
      if (type == 'quote' || type == 'code') {
        text = Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: type == 'quote'
                ? palette.accent.withValues(alpha: .08)
                : palette.highlight,
            border: type == 'quote'
                ? BorderDirectional(
                    start: BorderSide(color: palette.accent, width: 3),
                  )
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: text,
        );
      }
      return heading == null ? text : Semantics(header: true, child: text);
    }

    final nodes = childrenOf(object(root['root']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < nodes.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == nodes.length - 1 ? 0 : 8),
            child: render(object(nodes[i]), '$i'),
          ),
      ],
    );
  }
}
