// Actions is this file's own API-action-name registry; Flutter's own
// Actions (intent/shortcuts) widget isn't used here.
import 'package:flutter/material.dart' hide Actions;
import '../core/actions.dart';
import '../core/api.dart';
import '../core/localized_content.dart';
import '../core/session.dart';
import '../design/app_design.dart';
import '../l10n/l10n.dart';
import 'app_button.dart';
import 'app_field.dart';
import 'app_header.dart';
import 'app_row.dart';
import 'app_scaffold.dart';
import 'app_section.dart';
import 'illustrated_icon.dart';
import 'navigation.dart';

/// ReportButton (web/src/components/ui/ReportButton.tsx): a report kind from
/// the server's own list plus a description, submitted as `post.report`
/// {post_id, reason, description}. Unlike the web client, [kinds] is never
/// hardcoded here — session.system['report_kinds'] is the one source, so a
/// submission can't fail validation against reason values this client
/// guessed wrong.
///
/// The sheet is a two-step master→detail flow (NativeListController push,
/// Telegram's own reportPeer flow): pick a case first, then write the
/// comment on its own screen. A single long list-plus-text-field screen let
/// the case list grow tall enough to start underneath the floating header.
class PostReportSheet extends StatefulWidget {
  final Json post;
  const PostReportSheet({super.key, required this.post});
  @override
  State<PostReportSheet> createState() => _PostReportSheetState();
}

enum _ReportStep { reason, description }

class _PostReportSheetState extends State<PostReportSheet> {
  final description = TextEditingController();
  String? reason;
  bool busy = false;
  _ReportStep step = _ReportStep.reason;
  bool _forward = true;

  /// Web requires at least 200 characters of description before submitting.
  static const _minDescription = 200;

  /// Computed once: re-sorting on every rebuild (every keystroke/tap calls
  /// setState) visibly reshuffled the list whenever two kinds shared (or
  /// both lacked) a display_order, since List.sort isn't stable — the rows
  /// would jump around as you typed. A single, cached sort can't do that.
  late final List<Json> kinds = _loadKinds();

  List<Json> _loadKinds() {
    final raw = AppScope.of(context).system['report_kinds'];
    final list = raw is List
        ? raw.map(object).where((k) => string(k['key']).isNotEmpty).toList()
        : <Json>[];
    final indexed = list.indexed.toList()
      ..sort((a, b) {
        final order = (num.tryParse(string(a.$2['display_order'])) ?? 0)
            .compareTo(num.tryParse(string(b.$2['display_order'])) ?? 0);
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return [for (final (_, kind) in indexed) kind];
  }

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  void chooseReason(String key) {
    setState(() {
      reason = key;
      _forward = true;
      step = _ReportStep.description;
    });
  }

  void backToReason() {
    setState(() {
      _forward = false;
      step = _ReportStep.reason;
    });
  }

  Future<void> submit() async {
    final selected = reason;
    if (selected == null ||
        description.text.trim().length < _minDescription ||
        busy) {
      return;
    }
    setState(() => busy = true);
    await perform(context, () async {
      await AppScope.of(context).api.call(
        Actions.cmdPostReport,
        body: {
          'post_id': recordId(widget.post),
          'reason': selected,
          'description': description.text.trim(),
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final language = AppScope.of(context).locale.languageCode;
    final options = kinds;
    final remaining = _minDescription - description.text.trim().length;
    final canSubmit = reason != null && remaining <= 0 && !busy;
    final topInset =
        MediaQuery.paddingOf(context).top + AppDesign.headerInset(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // No cases to choose from: there's nothing to master/detail, so the
    // description screen is the only step.
    final activeStep = options.isEmpty ? _ReportStep.description : step;

    var selectedName = '';
    for (final kind in options) {
      if (string(kind['key']) == reason) {
        selectedName = localizedText(
          kind['name'],
          language: language,
        ).ifEmpty(string(kind['key']));
        break;
      }
    }

    final Widget page;
    final PreferredSizeWidget header;
    switch (activeStep) {
      case _ReportStep.reason:
        header = AppHeader(title: Text(context.l10n.report));
        page = ListView(
          key: const ValueKey(_ReportStep.reason),
          padding: EdgeInsets.only(top: topInset + 8, bottom: bottomInset + 24),
          children: [
            AppSection(
              children: [
                for (final kind in options)
                  AppRow(
                    // ReportButton.tsx: `report-${kind.key}` — the same
                    // per-reason Dott artwork, not a generic system icon.
                    leading: IllustratedIcon(
                      'report-${string(kind['key'])}',
                      fallback: 'report-other',
                      size: 28,
                    ),
                    title: Text(
                      localizedText(
                        kind['name'],
                        language: language,
                      ).ifEmpty(string(kind['key'])),
                    ),
                    onTap: () => chooseReason(string(kind['key'])),
                  ),
              ],
            ),
          ],
        );
        break;
      case _ReportStep.description:
        header = AppHeader(
          title: Text(
            selectedName.isEmpty ? context.l10n.report : selectedName,
          ),
          leading: options.isEmpty
              ? null
              : AppIconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: backToReason,
                ),
          actions: [
            AppButton.text(
              loading: busy,
              onPressed: canSubmit ? submit : null,
              child: Text(context.l10n.send),
            ),
          ],
        );
        page = ListView(
          key: const ValueKey(_ReportStep.description),
          padding: EdgeInsets.only(
            top: topInset + 16,
            bottom: bottomInset + 24,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppField(
                controller: description,
                label: context.l10n.description,
                labelAbove: true,
                minLines: 4,
                maxLines: 8,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                remaining > 0
                    ? context.l10n.reportDescriptionMinLength(remaining)
                    : '',
                style: AppDesign.font(
                  13,
                  color: AppPalette.of(context).secondaryLabel,
                ),
              ),
            ),
          ],
        );
        break;
    }

    return AppScaffold(
      appBar: header,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) {
          final entering =
              (child.key as ValueKey<_ReportStep>).value == activeStep;
          final sign = _forward ? 1.0 : -1.0;
          return ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(entering ? sign : -sign, 0),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
          );
        },
        child: page,
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
