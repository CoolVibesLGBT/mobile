import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../core/api.dart';
import '../core/classified_data.dart';
import '../components/classified_card.dart';
import '../components/components.dart';
import '../design/app_design.dart';
import 'app_forms.dart';
import 'composer.dart';
import 'feed.dart';

class ClassifiedsScreen extends StatefulWidget {
  const ClassifiedsScreen({super.key});
  @override
  State<ClassifiedsScreen> createState() => _ClassifiedsScreenState();
}

class _ClassifiedsScreenState extends State<ClassifiedsScreen> {
  bool offers = true;
  final search = TextEditingController();
  final list = GlobalKey<RecordListState>();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> create() async {
    final sent = await sheet<bool>(
      context,
      AppForms.classified(context, offers: offers),
    );
    if (sent == true && mounted) list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, p = AppPalette.of(context);
    final language = Localizations.localeOf(context).toLanguageTag();
    return AppScaffold(
      appBar: AppHeader(
        title: Text(l.classifieds),
        actions: [
          AppIconButton(
            tooltip: l.createListing,
            icon: const AppSymbol(
              'square.and.pencil',
              fallback: Icons.edit_square,
            ),
            onPressed: create,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.classifiedIntro,
                  style: AppDesign.font(15, color: p.secondaryLabel),
                ),
                const SizedBox(height: 16),
                AppSegments<bool>(
                  values: {true: Text(l.offers), false: Text(l.seeking)},
                  selected: offers,
                  onChanged: (value) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => offers = value);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppField(
                        key: const ValueKey('classified.search'),
                        controller: search,
                        label: l.search,
                        placeholder: l.classifiedSearch,
                        showLabel: false,
                        outlined: true,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (search.text.isNotEmpty)
                      AppIconButton(
                        tooltip: l.clearSearch,
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(search.clear),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RecordList(
              key: list,
              action: offers ? 'classifieds.offers' : 'classifieds.search',
              filter: search.text.trim().isEmpty
                  ? null
                  : (post) => classifiedMatches(post, search.text, language),
              topInset: 8,
              empty: ScreenStatus(
                title: search.text.isEmpty
                    ? l.classifiedEmpty
                    : l.classifiedNoResults,
                message: search.text.isEmpty
                    ? l.classifiedEmptyBody
                    : l.classifiedSearchHint,
                animation: 'search',
                actions: search.text.isEmpty
                    ? AppButton(
                        variant: AppButtonVariant.accent,
                        leadingIcon: Icons.add,
                        onPressed: create,
                        child: Text(l.createListing),
                      )
                    : null,
              ),
              itemBuilder: (context, post, _) => ClassifiedCard(
                key: ValueKey('classified.${recordId(post)}'),
                post: post,
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  open(context, ClassifiedScreen(post: post));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClassifiedScreen extends StatefulWidget {
  final Json post;
  const ClassifiedScreen({super.key, required this.post});
  @override
  State<ClassifiedScreen> createState() => _ClassifiedScreenState();
}

class _ClassifiedScreenState extends State<ClassifiedScreen> {
  final remote = GlobalKey<RemoteContentState>();
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(title: Text(context.l10n.classifiedDetails)),
    body: Column(
      children: [
        Expanded(
          child: RemoteContent(
            key: remote,
            action: 'classifieds.get',
            params: {'post_id': recordId(widget.post)},
            builder: (context, response, reload) {
              final item = classifiedFromResponse(
                response,
                recordId(widget.post),
              );
              if (item == null) {
                return ScreenStatus(
                  error: context.l10n.classifiedUnavailable,
                  retry: reload,
                );
              }
              final children = item['children'] is List
                  ? (item['children'] as List).map(object).toList()
                  : <Json>[];
              return CustomScrollView(
                key: PageStorageKey('classified.detail.${recordId(item)}'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: ClassifiedCard(post: item, detail: true),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Semantics(
                        header: true,
                        child: Text(
                          context.l10n.comments2(children.length),
                          style: AppDesign.font(
                            20,
                            weight: FontWeight.w600,
                            color: AppPalette.of(context).text,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (children.isEmpty)
                    SliverToBoxAdapter(
                      child: ScreenStatus(
                        compact: true,
                        title: context.l10n.noCommentsYet,
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: children.length,
                      itemBuilder: (_, index) => PostTile(
                        post: children[index],
                        comment: true,
                        detail: true,
                        reload: reload,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              );
            },
          ),
        ),
        if (recordId(widget.post).isNotEmpty)
          ComposerScreen(
            key: ValueKey('classified.comment.${recordId(widget.post)}'),
            replyTo: recordId(widget.post),
            inline: true,
            onSubmitted: () => remote.currentState?.load(),
          ),
      ],
    ),
  );
}
