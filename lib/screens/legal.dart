import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/components.dart';
import '../core/api.dart';
import '../design/app_design.dart';
import '../l10n/l10n.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});
  @override
  Widget build(BuildContext context) => const _LegalPage();
}

class LegalDetail extends StatelessWidget {
  final String documentId;
  const LegalDetail({super.key, required this.documentId});
  @override
  Widget build(BuildContext context) => _LegalPage(documentId: documentId);
}

class _LegalPage extends StatefulWidget {
  final String? documentId;
  const _LegalPage({this.documentId});
  @override
  State<_LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<_LegalPage> {
  String? language;
  Future<Json>? content;
  final sections = <GlobalKey>[];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Localizations.localeOf(context).languageCode;
    if (next != language) {
      language = next;
      load();
    }
  }

  void load() {
    content = rootBundle
        .loadString(
          'assets/data/legal-${['tr', 'ar', 'en'].contains(language) ? language : 'en'}.json',
        )
        .then((value) => object(jsonDecode(value)));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: content,
    builder: (context, snapshot) {
      final data = snapshot.data ?? {}, pages = object(data['pages']);
      final page = object(pages[widget.documentId]), p = AppPalette.of(context);
      final chapters = page['sections'] is List
          ? (page['sections'] as List).map(object).toList()
          : <Json>[];
      while (sections.length < chapters.length) {
        sections.add(GlobalKey());
      }
      final title = widget.documentId == null
          ? context.l10n.legal
          : string(page['title']);
      return AppScaffold(
        appBar: AppHeader(
          title: Text(title.isEmpty ? context.l10n.legal : title),
          actions: [
            if (chapters.isNotEmpty)
              AppContextMenu(
                pressTrigger: true,
                label: string(data['table_of_contents']),
                items: [
                  for (var index = 0; index < chapters.length; index++)
                    AppMenuItem(
                      title: string(chapters[index]['heading']),
                      onPressed: () {
                        final target = sections[index].currentContext;
                        if (target != null) {
                          Scrollable.ensureVisible(
                            target,
                            alignment: .16,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                    ),
                ],
                child: const SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: AppSymbol(
                      'list.bullet',
                      fallback: Icons.list_rounded,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: !snapshot.hasData
            ? ScreenStatus(
                loading: !snapshot.hasError,
                error: snapshot.hasError ? context.l10n.legalUnavailable : null,
                retry: snapshot.hasError ? () => setState(load) : null,
              )
            : widget.documentId != null && page.isEmpty
            ? ScreenStatus(error: string(data['not_found_body']))
            : SingleChildScrollView(
                key: PageStorageKey(
                  'legal.${widget.documentId ?? 'index'}.$language',
                ),
                padding: EdgeInsets.only(
                  top:
                      MediaQuery.paddingOf(context).top +
                      AppDesign.headerHeight +
                      16,
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppDesign.groupCorner,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 16 / 8,
                                  child: AppImage(
                                    source: AssetImage(
                                      'assets/images/legal/${widget.documentId ?? 'about'}.avif',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Semantics(
                                header: true,
                                child: Text(
                                  widget.documentId == null
                                      ? string(data['center_title'])
                                      : title,
                                  style: AppDesign.font(
                                    28,
                                    weight: FontWeight.w700,
                                    color: p.text,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                string(
                                  widget.documentId == null
                                      ? data['center_description']
                                      : page['description'],
                                ),
                                style: AppDesign.font(
                                  15,
                                  color: p.secondaryLabel,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                        if (widget.documentId == null)
                          AppSection(
                            children: [
                              for (final entry in pages.entries)
                                AppRow(
                                  key: ValueKey('legal.document.${entry.key}'),
                                  leading: SizedBox.square(
                                    dimension: 48,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AppImage(
                                        source: AssetImage(
                                          'assets/images/legal/${entry.key}.avif',
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    string(object(entry.value)['title']),
                                  ),
                                  subtitle: Text(
                                    string(object(entry.value)['description']),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => open(
                                    context,
                                    LegalDetail(documentId: entry.key),
                                  ),
                                ),
                            ],
                          )
                        else ...[
                          for (var index = 0; index < chapters.length; index++)
                            Padding(
                              key: sections[index],
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      string(chapters[index]['heading']),
                                      style: AppDesign.font(
                                        20,
                                        weight: FontWeight.w600,
                                        color: p.text,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SelectableText(
                                    string(chapters[index]['body']),
                                    style: AppDesign.font(
                                      17,
                                      color: p.text,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (widget.documentId != 'help')
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: AppButton.outlined(
                                onPressed: () => open(
                                  context,
                                  const LegalDetail(documentId: 'help'),
                                ),
                                leadingIcon: Icons.help_outline,
                                child: Text(string(data['help_cta'])),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      );
    },
  );
}
