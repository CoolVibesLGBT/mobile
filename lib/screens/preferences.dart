import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../core/api.dart';
import '../core/app_failure.dart';
import '../core/session.dart';
import '../core/profile_preferences.dart';
import '../components/components.dart';
import '../components/illustrated_icon.dart';
import '../design/app_design.dart';

String localized(BuildContext context, dynamic value) =>
    preferenceText(value, AppScope.of(context).locale.languageCode);
String preferenceTitle(BuildContext context, String? kind) => switch (kind) {
  'attributes' => context.l10n.attributes,
  'interests' => context.l10n.interests,
  'fantasies' => context.l10n.fantasies,
  _ => context.l10n.profilePreferences,
};

class PreferencesScreen extends StatelessWidget {
  final String? kind;
  const PreferencesScreen({super.key, this.kind});
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(title: Text(preferenceTitle(context, kind))),
    body: CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(
            top:
                MediaQuery.paddingOf(context).top + AppDesign.headerHeight + 12,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
          ),
          sliver: PreferencesSliver(kind: kind),
        ),
      ],
    ),
  );
}

/// The same lazy preference rows serve the editor and standalone catalogue.
class PreferencesSliver extends StatefulWidget {
  final String? kind;
  const PreferencesSliver({super.key, this.kind});
  @override
  State<PreferencesSliver> createState() => _PreferencesSliverState();
}

class _PreferencesSliverState extends State<PreferencesSliver> {
  String? expanded;
  bool attemptedLoad = false, loading = false;
  Object? error;
  Session? session;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    session = AppScope.of(context);
    if (!attemptedLoad && preferenceGroups(session!.system).isEmpty) {
      attemptedLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  @override
  void didUpdateWidget(PreferencesSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) expanded = null;
  }

  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await session!.syncSystem(throwOnError: true);
    } catch (failure) {
      if (mounted) setState(() => error = failure);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> change(Json group, Json item, bool enabled) async {
    try {
      await session!.updatePreference(group, item, enabled);
    } catch (failure) {
      if (mounted) {
        await showErrorSheet(
          context,
          AppFailure.from(failure, action: 'user.update_preferences'),
        );
      }
    }
  }

  String groupKey(Json group) =>
      '${group['_kind']}:${group['id'] ?? group['slug'] ?? group['tag']}';
  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final groups = preferenceGroups(session.system, kind: widget.kind);
    if (groups.isEmpty) {
      return SliverToBoxAdapter(
        child: ScreenStatus(
          loading: loading,
          error: error == null
              ? null
              : context.l10n.yourAccountCouldNotBeLoaded,
          retry: load,
        ),
      );
    }
    final palette = AppPalette.of(context),
        language = session.locale.languageCode;
    final rows = <({Json group, Json? item, bool last})>[];
    var chosenCount = 0, totalCount = 0;
    for (final group in groups) {
      final items = preferenceItems(group),
          chosen = selectedPreferenceItems(session.user, group);
      chosenCount += group['_kind'] == 'attributes'
          ? (chosen.isEmpty ? 0 : 1)
          : chosen.length;
      totalCount += group['_kind'] == 'attributes' ? 1 : items.length;
      final opened = expanded == groupKey(group) && items.isNotEmpty;
      rows.add((group: group, item: null, last: !opened));
      if (opened) {
        for (var i = 0; i < items.length; i++) {
          rows.add((group: group, item: items[i], last: i == items.length - 1));
        }
      }
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                AppRow(
                  leading: IllustratedIcon(switch (widget.kind) {
                    'interests' => 'interest-category-lifestyle',
                    'fantasies' => 'fantasy-category-amusement',
                    _ => 'system-user',
                  }, size: 40),
                  title: Semantics(
                    header: true,
                    child: Text(preferenceTitle(context, widget.kind)),
                  ),
                  value: '$chosenCount / $totalCount',
                  contentPadding: EdgeInsets.zero,
                ),
                if (session.updatingPreferences)
                  const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index], group = row.group, item = row.item;
            final id = groupKey(group), icon = preferenceGroupIcon(group);
            final selected = selectedPreferenceItems(session.user, group);
            final title = preferenceGroupTitle(group, language),
                opened = expanded == id;
            final selectedNames = selected
                .map(
                  (item) => preferenceText(
                    item['title'] ?? item['name'] ?? item['slug'],
                    language,
                  ),
                )
                .join(' · ');
            return Padding(
              key: ValueKey(
                item == null
                    ? 'preference.group.$id'
                    : 'preference.item.${item['id']}',
              ),
              padding: EdgeInsets.fromLTRB(16, 0, 16, row.last ? 12 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: item == null
                      ? const Radius.circular(AppDesign.profileEditCardRadius)
                      : Radius.zero,
                  bottom: row.last
                      ? const Radius.circular(AppDesign.profileEditCardRadius)
                      : Radius.zero,
                ),
                child: item == null
                    ? Semantics(
                        expanded: opened,
                        child: AppRow(
                          leading: IllustratedIcon(icon, size: 40),
                          title: Text(title),
                          subtitle: Text(
                            selectedNames.isEmpty
                                ? context.l10n.profileNotSet
                                : selectedNames,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(
                            opened
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: palette.secondaryLabel,
                          ),
                          onTap: () =>
                              setState(() => expanded = opened ? null : id),
                        ),
                      )
                    : AppChoiceRow(
                        secondary: IllustratedIcon(
                          string(item['id'] ?? item['slug']),
                          fallback: group['_kind'] == 'attributes'
                              ? icon
                              : group['_kind'] == 'interests'
                              ? 'system-heart'
                              : 'system-sparkles',
                        ),
                        title: Text(
                          preferenceText(
                            item['title'] ?? item['name'] ?? item['slug'],
                            language,
                          ),
                        ),
                        subtitle:
                            preferenceText(
                              item['description'],
                              language,
                            ).isEmpty
                            ? null
                            : Text(
                                preferenceText(item['description'], language),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                        value: selected.any(
                          (value) => value['id'] == item['id'],
                        ),
                        onChanged: session.updatingPreferences
                            ? null
                            : (value) => change(group, item, value ?? false),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }
}
