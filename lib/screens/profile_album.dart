import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/l10n.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../components/components.dart';
import '../design/app_design.dart';
import 'media.dart';
import 'settings.dart';

class AlbumScreen extends StatefulWidget {
  final String? ownerId;
  final bool embedded, includePublic, primary;
  final Widget? header;
  const AlbumScreen({
    super.key,
    this.ownerId,
    this.embedded = false,
    this.includePublic = false,
    this.primary = false,
    this.header,
  });
  @override
  State<AlbumScreen> createState() => AlbumScreenState();
}

class AlbumScreenState extends State<AlbumScreen> {
  var key = GlobalKey<RecordListState>();
  Json? metadata;
  int? revision;
  bool uploading = false, requesting = false;
  String filter = 'all';
  Timer? processingTimer;
  int processingPolls = 0;
  final changing = <String>{};
  String get access => string(object(metadata?['access'])['status']);
  bool get canView =>
      widget.ownerId == null ||
      const ['owner', 'approved', 'granted'].contains(access);
  bool get canRequest {
    final allowed =
        metadata?['can_request'] ?? object(metadata?['access'])['can_request'];
    return !canView &&
        access != 'pending' &&
        (allowed is bool ? allowed : const ['none', 'denied'].contains(access));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = AppScope.of(context).mediaRevision;
    if (revision != null && revision != current) reset();
    revision = current;
  }

  @override
  void didUpdateWidget(AlbumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.includePublic != widget.includePublic) {
      reset();
    }
  }

  void reset() {
    key = GlobalKey<RecordListState>();
    metadata = null;
    processingTimer?.cancel();
    processingPolls = 0;
  }

  Future<void> reload() async => key.currentState?.reload();

  Future<Json> fetchAlbum(Api api, Json params) async {
    final owner = <String, dynamic>{
      if (widget.ownerId != null) 'owner_id': widget.ownerId,
    };
    if (!widget.includePublic) {
      return api.call('user.private_photos.fetch', body: owner);
    }
    Future<(Json?, Object?)> fetch(String action) async {
      try {
        return (await api.call(action, body: owner), null);
      } catch (e) {
        return (null, e);
      }
    }

    final results = await Future.wait([
      fetch('user.private_photos.fetch'),
      fetch('user.profile_photos.fetch'),
    ]);
    final privateError = results[0].$2;
    if (privateError is ApiException &&
        [401, 403, 404].contains(privateError.status)) {
      throw privateError;
    }
    if (results.every((r) => r.$1 == null)) throw results.first.$2!;
    final private = object(results[0].$1?['data']);
    return {
      'data': {
        ...private,
        'load_error': results
            .map((r) => r.$2)
            .whereType<Object>()
            .map((e) => '$e')
            .join(' · '),
        'photos': [
          for (var i = 1; i >= 0; i--)
            if (results[i].$1 != null)
              for (final photo in RecordPage.parse(results[i].$1!).records)
                {...photo, '_visibility': i == 1 ? 'public' : 'private'},
        ],
      },
    };
  }

  void received(Json response) {
    if (!mounted) return;
    setState(() => metadata = object(response['data'] ?? response));
    processingTimer?.cancel();
    if (RecordPage.parse(response).records.any(
          (p) => const [
            'pending',
            'processing',
            'queued',
          ].contains(p['processing_status']),
        ) &&
        processingPolls < 20) {
      processingTimer = Timer(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        processingPolls++;
        reload();
      });
    }
  }

  Future<void> upload() async {
    if (uploading) return;
    setState(() => uploading = true);
    var changed = false;
    try {
      await perform(context, () async {
        final images = await ImagePicker().pickMultiImage();
        if (images.isEmpty || !mounted) return;
        for (var i = 0; i < images.length; i += 10) {
          final batch = images.skip(i).take(10);
          final files = await Future.wait(
            batch.map(
              (image) =>
                  MultipartFile.fromFile(image.path, filename: image.name),
            ),
          );
          if (!mounted) return;
          await AppScope.of(
            context,
          ).api.call('user.private_photos.upload', body: {'photos[]': files});
          changed = true;
        }
      });
    } finally {
      if (mounted) {
        setState(() => uploading = false);
        if (changed) AppScope.of(context).invalidateMedia();
      }
    }
  }

  Future<void> requestAccess() async {
    if (requesting || !canRequest || widget.ownerId == null) {
      return;
    }
    setState(() => requesting = true);
    try {
      await perform(context, () async {
        final response = await AppScope.of(context).api.call(
          'user.private_photos.access.request',
          body: {'owner_id': widget.ownerId},
        );
        if (!mounted) return;
        final data = object(response['data']);
        setState(
          () => metadata = {...?metadata, 'access': data['access'] ?? data},
        );
        await reload();
      });
    } finally {
      if (mounted) setState(() => requesting = false);
    }
  }

  Future<void> changePhoto(Json photo, {bool delete = false}) async {
    final id = recordId(photo);
    if (changing.contains(id)) return;
    setState(() => changing.add(id));
    try {
      await perform(context, () async {
        final visibility = photo['_visibility'] == 'public'
            ? 'public'
            : 'private';
        final destination = visibility == 'public' ? 'private' : 'public';
        if (delete || destination == 'public') {
          if (!await confirmAction(
            context,
            action: delete
                ? context.l10n.deleteLabel
                : context.l10n.profileMakePublic,
            title: delete
                ? context.l10n.deleteLabel
                : context.l10n.profileMakePublic,
            message: delete
                ? context.l10n.photo
                : context.l10n.profilePublicPhotoNotice,
          )) {
            return;
          }
        }
        if (!mounted) return;
        await AppScope.of(context).api.call(
          delete ? 'user.private_photos.delete' : 'user.photos.move',
          body: {
            'photo_id': recordId(photo),
            if (!delete) 'destination': destination,
          },
        );
        if (mounted) AppScope.of(context).invalidateMedia();
      });
    } finally {
      if (mounted) setState(() => changing.remove(id));
    }
  }

  @override
  void dispose() {
    processingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loadError = string(metadata?['load_error']);
    final content = RecordList(
      key: key,
      primary: widget.primary,
      clearOnError: true,
      action: 'user.private_photos.fetch',
      params: {if (widget.ownerId != null) 'owner_id': widget.ownerId},
      fetchPage: fetchAlbum,
      onPageLoaded: received,
      filter: filter == 'all'
          ? null
          : (photo) => (photo['_visibility'] ?? 'private') == filter,
      empty: widget.ownerId != null && !canView && filter != 'public'
          ? const SizedBox.shrink()
          : null,
      header: Column(
        children: [
          if (widget.header != null) widget.header!,
          if (widget.includePublic)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: AppSegments<String>(
                key: const ValueKey('profile.album.filter'),
                contentSized: true,
                values: {
                  'all': Text(context.l10n.all),
                  'public': Text(context.l10n.profilePublicPhotos),
                  'private': Text(context.l10n.privatePhotos),
                },
                selected: filter,
                onChanged: (next) => setState(() => filter = next),
              ),
            ),
          if (widget.ownerId == null)
            AppSection(
              children: [
                AppRow(
                  leading: const Icon(Icons.add_photo_alternate_outlined),
                  title: Text(context.l10n.upload),
                  subtitle: Text(context.l10n.profilePrivateUploadNotice),
                  trailing: uploading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator.adaptive(),
                        )
                      : null,
                  onTap: uploading ? null : upload,
                ),
                AppRow(
                  leading: const Icon(Icons.lock_open_outlined),
                  title: Text(context.l10n.photoAccessRequests),
                  onTap: () async {
                    await open(
                      context,
                      const ActivityScreen(accessRequests: true),
                    );
                    if (mounted) await reload();
                  },
                ),
              ],
            )
          else if (metadata != null &&
              !canView &&
              loadError.isEmpty &&
              filter != 'public')
            AppSection(
              children: [
                AppRow(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(context.l10n.privatePhotos),
                  subtitle: Text(
                    access == 'pending'
                        ? context.l10n.profileAccessPending
                        : context.l10n.profileAlbumLocked,
                  ),
                  disclosure: false,
                ),
                if (canRequest)
                  AppRow(
                    title: Text(context.l10n.requestAccess),
                    trailing: requesting
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : null,
                    onTap: requesting ? null : requestAccess,
                  ),
              ],
            ),
          if (loadError.isNotEmpty)
            ScreenStatus(error: loadError, retry: reload, compact: true),
        ],
      ),
      columns: 3,
      gap: 1,
      edgeInset: 0,
      itemBuilder: (context, photo, _) {
        final processing = const [
          'pending',
          'processing',
          'queued',
        ].contains(photo['processing_status']);
        final failed = photo['processing_status'] == 'failed';
        return AspectRatio(
          aspectRatio: 1,
          child: AppContextMenu(
            label: context.l10n.photo,
            items: [
              if (widget.ownerId == null &&
                  !changing.contains(recordId(photo))) ...[
                if (widget.includePublic)
                  AppMenuItem(
                    title: photo['_visibility'] == 'public'
                        ? context.l10n.profileMakePrivate
                        : context.l10n.profileMakePublic,
                    symbol: photo['_visibility'] == 'public' ? 'lock' : 'globe',
                    fallback: Icons.lock_outline,
                    onPressed: () => changePhoto(photo),
                  ),
                if (photo['_visibility'] != 'public')
                  AppMenuItem(
                    title: context.l10n.deleteLabel,
                    symbol: 'trash',
                    destructive: true,
                    onPressed: () => changePhoto(photo, delete: true),
                  ),
              ],
            ],
            onPressed: processing || failed
                ? null
                : () {
                    final album = (key.currentState?.visibleRecords ?? [photo])
                        .where(
                          (p) => !const [
                            'pending',
                            'processing',
                            'queued',
                            'failed',
                          ].contains(p['processing_status']),
                        )
                        .toList();
                    MediaScreen.show(context, {
                      'media': album,
                      '_private': true,
                      '_revision': AppScope.of(context).mediaRevision,
                    }, initial: math.max(0, album.indexOf(photo)));
                  },
            child: processing || failed
                ? ColoredBox(
                    color: AppPalette.of(context).row,
                    child: Center(
                      child: processing
                          ? const CircularProgressIndicator.adaptive()
                          : Icon(
                              Icons.broken_image_outlined,
                              color: AppPalette.of(context).secondaryLabel,
                            ),
                    ),
                  )
                : AppImage(
                    source: photo,
                    variant: 'small',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
          ),
        );
      },
    );
    return widget.embedded
        ? content
        : AppScaffold(
            appBar: AppHeader(title: Text(context.l10n.privatePhotos)),
            body: content,
          );
  }
}
