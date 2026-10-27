import '../l10n/l10n.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../design/app_design.dart';
import 'package:flutter/rendering.dart';
import '../core/geo.dart';
import '../components/components.dart';
import '../components/attachment_controls.dart';
import '../components/message_field.dart';
import '../components/chat_input.dart';
import '../components/composer_author.dart';
import '../core/api.dart';
import '../core/article.dart';
import '../components/article_editor.dart';
import '../core/attachments.dart';
import '../core/session.dart';
import '../core/upload_queue.dart';
import 'app_forms.dart';
import '../components/checkin_radar.dart';

class ComposerScreen extends StatefulWidget {
  final bool story, checkIn, inline;
  final VoidCallback? onSubmitted;
  final String? replyTo, kind;
  const ComposerScreen({
    super.key,
    this.story = false,
    this.inline = false,
    this.onSubmitted,
    this.checkIn = false,
    this.replyTo,
    this.kind,
  });
  @override
  State<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends State<ComposerScreen>
    with WidgetsBindingObserver {
  final text = TextEditingController(),
      title = TextEditingController(),
      tags = TextEditingController();
  final attachments = AttachmentController();
  late final article = ArticleController();
  bool get isArticle =>
      !widget.story &&
      !widget.checkIn &&
      !widget.inline &&
      widget.kind == null &&
      widget.replyTo == null;
  void articleChanged() {
    if (text.text != article.text) text.text = article.text;
    scheduleDraft();
  }

  final storyBoundary = GlobalKey();
  final metadata = <(TextEditingController, TextEditingController)>[];
  void addMetadata({String label = '', String value = ''}) {
    final pair = (
      TextEditingController(text: label),
      TextEditingController(text: value),
    );
    pair.$1.addListener(scheduleDraft);
    pair.$2.addListener(scheduleDraft);
    metadata.add(pair);
  }

  Timer? draftTimer;
  Future<void> draftWrites = Future<void>.value();
  bool clearingDraft = false;
  Session? session;
  bool busy = false;
  String? error;
  int storyColor = 0;
  UploadJob? pendingJob;
  String? submittedFingerprint;
  final selectedTags = <String>{};
  Future<void>? checkInLocation;
  Json checkInCoordinates = {...defaultDiscoveryCoordinates};
  String get draftKey =>
      'draft.${session?.uploads.owner}.${widget.kind ?? (widget.story
              ? 'story'
              : widget.checkIn
              ? 'checkin'
              : 'post')}.${widget.replyTo ?? ''}';
  static const palettes = [
    [Color(0xff6c4ce4), Color(0xffdb4db2)],
    [Color(0xff3390ec), Color(0xff68c8cb)],
    [Color(0xffeb8b62), Color(0xffed4c7c)],
    [Color(0xff394252), Color(0xff141820)],
    [Color(0xff78ac72), Color(0xffc8d77c)],
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (isArticle) article.addListener(articleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      session = AppScope.of(context);
      if (widget.checkIn) {
        checkInLocation = () async {
          Json location = {...defaultDiscoveryCoordinates};
          try {
            if (!session!.api.isPreview) {
              final p = await currentPosition();
              location = {'latitude': p.latitude, 'longitude': p.longitude};
            }
          } catch (_) {}
          if (mounted) checkInCoordinates = location;
        }();
      }
      if (!session!.api.isPreview) {
        try {
          final raw = await session!.api.storage.read(key: draftKey);
          if (raw != null &&
              mounted &&
              (!isArticle ||
                  article.text.isEmpty &&
                      !article.canUndo &&
                      !attachments.hasContent)) {
            final value = object(jsonDecode(raw));
            text.text = string(value['text']);
            if (isArticle) {
              article.restore(
                value['article'] is Map
                    ? object(value['article'])
                    : lexical(text.text),
              );
            }
            title.text = string(value['title']);
            if (widget.kind != null && value['metadata'] is List) {
              for (final pair in value['metadata'] as List) {
                addMetadata(
                  label: string(object(pair)['key']),
                  value: string(object(pair)['value']),
                );
              }
              setState(() {});
            }
            tags.text = string(value['tags']);
            selectedTags.addAll(
              tags.text.split(',').where((v) => v.isNotEmpty),
            );
            attachments.files.addAll(
              (value['files'] as List? ?? []).map(object),
            );
            attachments.location = value['location'] is Map
                ? object(value['location'])
                : null;
            attachments.emoticon = value['emoticon'] is Map
                ? object(value['emoticon'])
                : null;
            attachments.changed();
          }
        } catch (_) {}
      }
      if (!mounted) return;
      text.addListener(scheduleDraft);
      title.addListener(scheduleDraft);
      tags.addListener(scheduleDraft);
      attachments.addListener(scheduleDraft);
    });
  }

  Future<void> persistDraft({bool clear = false}) {
    if (session == null || session!.api.isPreview) return Future<void>.value();
    final storage = session!.api.storage, key = draftKey;
    final value = clear
        ? null
        : jsonEncode({
            'text': text.text,
            if (isArticle) 'article': article.document,
            'title': title.text,
            if (widget.kind != null)
              'metadata': [
                for (final pair in metadata)
                  {'key': pair.$1.text, 'value': pair.$2.text},
              ],
            'tags': tags.text,
            'files': attachments.files,
            'location': attachments.location,
            'emoticon': attachments.emoticon,
          });
    final write = draftWrites.then(
      (_) => clear
          ? storage.delete(key: key)
          : storage.write(key: key, value: value),
    );
    draftWrites = write.then<void>((_) {}, onError: (Object _) {});
    return write;
  }

  void scheduleDraft() {
    draftTimer?.cancel();
    if (clearingDraft) return;
    draftTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(persistDraft().catchError((Object _) {}));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (attachments.recording) attachments.stopRecording();
      if (!clearingDraft) {
        draftTimer?.cancel();
        unawaited(persistDraft().catchError((Object _) {}));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    draftTimer?.cancel();
    if (!clearingDraft) unawaited(persistDraft().catchError((Object _) {}));
    if (isArticle) article.dispose();
    text.dispose();
    title.dispose();
    tags.dispose();
    for (final pair in metadata) {
      pair.$1.dispose();
      pair.$2.dispose();
    }
    attachments.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || attachments.recording) return;
    final content = text.text.trim();
    if (content.isEmpty && !attachments.hasContent && selectedTags.isEmpty) {
      return;
    }
    if (widget.kind != null && title.text.trim().isEmpty) {
      setState(() => error = context.l10n.enterATitle);
      return;
    }
    if (widget.kind != null &&
        metadata.any(
          (pair) => pair.$1.text.trim().isEmpty != pair.$2.text.trim().isEmpty,
        )) {
      setState(() => error = context.l10n.classifiedIncompleteDetail);
      return;
    }
    final current = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.checkIn && checkInLocation != null) await checkInLocation;
      if (!mounted) return;
      if (widget.story && attachments.files.isEmpty) {
        if (content.isEmpty) {
          throw ApiException(context.l10n.addAPhotoOrText);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await WidgetsBinding.instance.endOfFrame;
        final boundary =
            storyBoundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final directory = await AttachmentController.directory();
        final path =
            '${directory.path}/story-${DateTime.now().microsecondsSinceEpoch}.png';
        await File(path).writeAsBytes(data!.buffer.asUint8List());
        await attachments.addFile(
          path,
          name: 'Story.png',
          contentType: 'image/png',
        );
      }
      final body = AppForms.postPayload(
        text: widget.checkIn && content.isEmpty ? 'Check-in' : content,
        attachments: attachments.extraFields(),
        parentPostId: widget.replyTo,
        articleDocument: isArticle ? article.document : null,
      );
      if (widget.checkIn) {
        final values = selectedTags.toList();
        body.addAll({
          'tags': values,
          'extras': {...object(body['extras']), 'tags': values},
          'lat': (attachments.location ?? checkInCoordinates)['latitude'],
          'lng': (attachments.location ?? checkInCoordinates)['longitude'],
          'latitude': (attachments.location ?? checkInCoordinates)['latitude'],
          'longitude':
              (attachments.location ?? checkInCoordinates)['longitude'],
        });
      }
      if (widget.kind != null) {
        final values = metadata
            .where(
              (pair) =>
                  pair.$1.text.trim().isNotEmpty &&
                  pair.$2.text.trim().isNotEmpty,
            )
            .map(
              (pair) => {
                'key': pair.$1.text.trim(),
                'value': pair.$2.text.trim(),
              },
            )
            .toList();
        body.addAll({
          'kind': widget.kind,
          'extras': {
            ...object(body['extras']),
            'title': title.text.trim(),
            'metadata': values,
          },
          'extras[title]': title.text.trim(),
          'metadata': values,
          'extras[metadata]': values,
        });
      }
      if (current.uploads.owner.isEmpty) {
        await current.uploads.attach(
          string(current.user['public_id'] ?? current.user['id']),
        );
      }
      final fingerprint = jsonEncode([body, attachments.files]);
      final UploadJob job;
      if (pendingJob != null &&
          pendingJob!.status == 'failed' &&
          submittedFingerprint == fingerprint) {
        job = pendingJob!;
        await current.uploads.retry(job);
      } else {
        if (pendingJob?.status == 'failed') {
          await current.uploads.remove(pendingJob!);
        }
        job = await current.uploads.enqueue(
          action: widget.story
              ? 'user.upload_story'
              : widget.checkIn
              ? 'user.check_in'
              : 'post.create',
          title: title.text.trim().isNotEmpty
              ? title.text.trim()
              : content.take(60),
          fields: body,
          files: attachments.files.map((v) => {...v}).toList(),
        );
        pendingJob = job;
        submittedFingerprint = fingerprint;
      }
      // Closing means the server accepted the submission, not merely queued it.
      await current.uploads.waitFor(job);
      clearingDraft = true;
      draftTimer?.cancel();
      try {
        await persistDraft(clear: true);
      } catch (_) {
        // Delivery succeeded. A failed draft cleanup must never resend it.
      }
      if (!mounted) return;
      if (widget.inline) {
        text.clear();
        attachments.clear();
        pendingJob = null;
        submittedFingerprint = null;
        clearingDraft = false;
        widget.onSubmitted?.call();
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget editor(BuildContext context) => MessageField(
    controller: text,
    minLines: widget.story ? 2 : 6,
    maxLines: null,
    maxHeight: null,
    story: widget.story,
    enabled: !busy,
    placeholder: context.l10n.whatIsOnYourMind,
  );
  @override
  Widget build(BuildContext context) {
    if (widget.kind != null) return classifiedEditor(context);
    if (isArticle) {
      return ArticleEditor(
        controller: article,
        attachments: attachments,
        sending: busy,
        error: error,
        onSend: send,
      );
    }
    if (widget.inline || widget.checkIn) {
      final input = ChatInput(
        controller: text,
        attachments: attachments,
        sending: busy,
        onSend: send,
        onChanged: (_) => scheduleDraft(),
        hasExtraContent: selectedTags.isNotEmpty,
        placeholder: widget.checkIn
            ? context.l10n.shareACheckIn
            : context.l10n.writeAComment,
        helper: selectedTags.isEmpty
            ? null
            : SizedBox(
                height: 104,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  children: [
                    for (final tag in selectedTags)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: CheckInTagPreview(
                          tag: tag,
                          onRemove: () => setState(() {
                            selectedTags.remove(tag);
                            tags.text = selectedTags.join(',');
                          }),
                        ),
                      ),
                  ],
                ),
              ),
      );
      final content = Column(
        mainAxisSize: widget.inline ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (widget.checkIn)
            Expanded(
              child: CheckInRadar(
                selected: selectedTags,
                onSelect: (tag) => setState(() {
                  if (!selectedTags.add(tag)) selectedTags.remove(tag);
                  tags.text = selectedTags.join(',');
                }),
                onClear: () => setState(() {
                  selectedTags.clear();
                  tags.clear();
                }),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          input,
        ],
      );
      return widget.inline
          ? content
          : AppScaffold(
              appBar: AppHeader(title: const Text('Check-in')),
              body: content,
            );
    }
    return AppScaffold(
      // CreatePost: a plain writing surface on the row colour.
      backgroundColor: AppPalette.of(context).row,
      appBar: AppHeader(
        title: Text(
          widget.story
              ? context.l10n.newStory
              : widget.checkIn
              ? 'Check-in'
              : widget.kind != null
              ? context.l10n.newListing
              : widget.replyTo != null
              ? context.l10n.comment2
              : context.l10n.createPost,
        ),
        actions: [
          ListenableBuilder(
            listenable: Listenable.merge([text, attachments]),
            builder: (context, _) => AppButton.text(
              loading: busy,
              onPressed:
                  busy || (text.text.trim().isEmpty && !attachments.hasContent)
                  ? null
                  : send,
              child: Text(
                widget.replyTo != null ? context.l10n.send : context.l10n.share,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: !widget.story && !widget.checkIn && widget.kind == null
              ? Column(
                  children: [
                    ComposerAuthor(user: AppScope.of(context).user),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ChatInput(
                        controller: text,
                        attachments: attachments,
                        sending: busy,
                        expanded: true,
                        placeholder: widget.replyTo != null
                            ? context.l10n.writeAComment
                            : null,
                        onSend: send,
                        onChanged: (_) {},
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    if (busy) const LinearProgressIndicator(),
                    Expanded(
                      child: ListView(
                        children: [
                          if (widget.story)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: RepaintBoundary(
                                key: storyBoundary,
                                child: AspectRatio(
                                  aspectRatio: 9 / 16,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: palettes[storyColor],
                                      ),
                                    ),
                                    child: Center(child: editor(context)),
                                  ),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: editor(context),
                            ),
                          if (widget.story)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  for (var i = 0; i < palettes.length; i++)
                                    AppIconButton(
                                      tooltip: '${i + 1}',
                                      icon: Icon(
                                        Icons.circle,
                                        color: palettes[i][0],
                                      ),
                                      onPressed: () =>
                                          setState(() => storyColor = i),
                                    ),
                                ],
                              ),
                            ),
                          if (widget.checkIn)
                            AppSection(
                              children: [
                                AppField(
                                  controller: tags,
                                  label: context.l10n.tags,
                                  placeholder: context.l10n.separateWithCommas,
                                ),
                              ],
                            ),
                          AttachmentPreview(controller: attachments),
                          if (error != null)
                            Padding(
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
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          AppIconButton(
                            tooltip: context.l10n.attach,
                            icon: const Icon(Icons.add),
                            onPressed: busy
                                ? null
                                : () => chooseAttachment(context, attachments),
                          ),
                          AppIconButton(
                            tooltip: context.l10n.photos,
                            icon: const Icon(Icons.photo_outlined),
                            onPressed: busy
                                ? null
                                : () =>
                                      perform(context, attachments.pickImages),
                          ),
                          AppIconButton(
                            tooltip: context.l10n.voiceMessage,
                            icon: const Icon(Icons.mic_none),
                            onPressed: busy
                                ? null
                                : () => perform(
                                    context,
                                    () => attachments.recording
                                        ? attachments.stopRecording()
                                        : attachments.startRecording(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget classifiedEditor(BuildContext context) {
    final l = context.l10n, p = AppPalette.of(context);
    return AppScaffold(
      appBar: AppHeader(
        title: Text(l.newListing),
        actions: [
          ListenableBuilder(
            listenable: Listenable.merge([text, attachments]),
            builder: (context, _) => AppButton.text(
              key: const ValueKey('classified.publish'),
              loading: busy,
              onPressed:
                  busy || (text.text.trim().isEmpty && !attachments.hasContent)
                  ? null
                  : send,
              child: Text(l.share),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 16, bottom: 12),
              children: [
                AppSection(
                  children: [
                    AppRow(
                      leading: AppSettingIcon(
                        Icons.work_outline,
                        color: p.accent,
                        symbol: 'briefcase.fill',
                      ),
                      title: Text(
                        widget.kind == 'job_search' ? l.seeking : l.offers,
                      ),
                      subtitle: Text(l.classifiedCreateHint),
                      disclosure: false,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: AppField(
                    key: const ValueKey('classified.title'),
                    controller: title,
                    enabled: !busy,
                    label: l.title,
                    placeholder: l.classifiedTitleHint,
                    labelAbove: true,
                    outlined: true,
                    maxLines: 2,
                  ),
                ),
                AppSection(
                  title: l.classifiedExtraDetails,
                  footer: l.classifiedDetailHint,
                  children: [
                    for (var index = 0; index < metadata.length; index++)
                      Padding(
                        key: ObjectKey(metadata[index].$1),
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  AppField(
                                    key: ValueKey('classified.label.$index'),
                                    controller: metadata[index].$1,
                                    label: l.label,
                                    placeholder: l.classifiedLabelHint,
                                    enabled: !busy,
                                  ),
                                  AppField(
                                    key: ValueKey('classified.value.$index'),
                                    controller: metadata[index].$2,
                                    label: l.value,
                                    placeholder: l.classifiedValueHint,
                                    enabled: !busy,
                                  ),
                                ],
                              ),
                            ),
                            AppIconButton(
                              tooltip: l.remove,
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: busy
                                  ? null
                                  : () {
                                      final pair = metadata[index];
                                      setState(() => metadata.removeAt(index));
                                      pair.$1.dispose();
                                      pair.$2.dispose();
                                      scheduleDraft();
                                    },
                            ),
                          ],
                        ),
                      ),
                    AppRow(
                      leading: Icon(Icons.add_circle_outline, color: p.accent),
                      title: Text(
                        l.addDetail,
                        style: TextStyle(color: p.accent),
                      ),
                      disclosure: false,
                      onTap: busy
                          ? null
                          : () {
                              setState(() => addMetadata());
                              scheduleDraft();
                            },
                    ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: AppDesign.font(15, color: p.destructive),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ChatInput(
            controller: text,
            attachments: attachments,
            sending: busy,
            placeholder: l.classifiedDescriptionHint,
            onSend: send,
            onChanged: (_) => scheduleDraft(),
          ),
        ],
      ),
    );
  }
}

extension _TextExcerpt on String {
  String take(int count) => length <= count ? this : substring(0, count);
}
