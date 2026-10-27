import '../l10n/l10n.dart';
import 'app_header.dart';
import 'app_scaffold.dart';
import 'app_button.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/session.dart';
import 'app_section.dart';
import 'app_field.dart';

class ActionForm extends StatefulWidget {
  final String title;
  final String action;
  final Map<String, String> fields;
  final Set<String>? requiredFields;
  final Json initial;
  final Json extra;
  final Json Function(Json)? transform;
  final Widget Function(BuildContext, ActionFormState)? contentBuilder;
  final bool sliverContent;
  final Future<void> Function()? onSaved;
  const ActionForm({
    super.key,
    required this.title,
    required this.action,
    required this.fields,
    this.requiredFields,
    this.initial = const {},
    this.extra = const {},
    this.transform,
    this.contentBuilder,
    this.sliverContent = false,
    this.onSaved,
  });
  @override
  State<ActionForm> createState() => ActionFormState();
}

class ActionFormState extends State<ActionForm> {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  late final controllers = {
    for (final key in widget.fields.keys)
      key: TextEditingController(
        text: widget.initial[key] is Map
            ? plainText(widget.initial[key])
            : string(widget.initial[key]),
      ),
  };
  final extraValues = <String, dynamic>{};
  void setValue(String key, String value) =>
      setState(() => controllers[key]!.text = value);
  void setExtra(Json values) => setState(() => extraValues.addAll(values));
  bool busy = false;
  bool saveVisible = true;
  void setSaveVisible(bool value) => setState(() => saveVisible = value);
  String? error;
  @override
  void dispose() {
    scroll.dispose();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      Json body = {
        ...widget.extra,
        for (final entry in controllers.entries)
          entry.key: entry.key.contains('password')
              ? entry.value.text
              : entry.value.text.trim(),
      };
      body.addAll(extraValues);
      if (widget.transform != null) body = widget.transform!(body);
      await AppScope.of(context).api.call(widget.action, body: body);
      await widget.onSaved?.call();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
        if (scroll.hasClients) {
          scroll.animateTo(
            0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String key, {
    bool showLabel = true,
    String? prefix,
    String? placeholder,
    int? minLines,
  }) => AppField(
    key: ValueKey("form.$key"),
    showLabel: showLabel,
    prefix: prefix,
    placeholder: placeholder,
    enabled: !busy,
    controller: controllers[key]!,
    label: widget.fields[key]!,
    obscureText: key.contains('password'),
    autocorrect: !['username', 'email', 'website'].contains(key),
    keyboardType: key == 'email'
        ? TextInputType.emailAddress
        : key == 'website'
        ? TextInputType.url
        : null,
    minLines:
        minLines ?? (['content', 'description', 'bio'].contains(key) ? 4 : 1),
    autofillHints: switch (key) {
      'displayname' => const [AutofillHints.name],
      'username' => const [AutofillHints.username],
      'email' => const [AutofillHints.email],
      _ => null,
    },
    maxLines: ['content', 'description', 'bio'].contains(key) ? 12 : 1,
    validator: (value) {
      if ((widget.requiredFields == null ||
              widget.requiredFields!.contains(key)) &&
          (value == null || value.trim().isEmpty)) {
        return context.l10n.required;
      }
      if (key == 'new_password_confirmation' &&
          value != controllers['new_password']?.text) {
        return context.l10n.passwordsDoNotMatch;
      }
      if (key == 'email' &&
          (value?.isNotEmpty ?? false) &&
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!)) {
        return context.l10n.enterAValidEmail;
      }
      return null;
    },
  );

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(
      title: Text(widget.title),
      actions: [
        if (saveVisible)
          AppButton.text(
            onPressed: busy ? null : save,
            child: Text(context.l10n.save),
          ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Form(
          key: form,
          child: CustomScrollView(
            controller: scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: widget.contentBuilder == null ? 16 : 8),
              ),
              if (error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.contentBuilder != null)
                if (widget.sliverContent)
                  widget.contentBuilder!(context, this)
                else
                  SliverToBoxAdapter(
                    child: widget.contentBuilder!(context, this),
                  )
              else
                SliverToBoxAdapter(
                  child: AppSection(
                    children: [
                      for (final key in widget.fields.keys) field(key),
                    ],
                  ),
                ),
              if (busy)
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 24,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
