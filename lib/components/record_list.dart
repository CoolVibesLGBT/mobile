import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/realtime.dart';
import 'navigation.dart';
import 'screen_status.dart';

class RecordList extends StatefulWidget {
  final String action;
  final Json params;
  final String? dataKey;
  final bool Function(Json)? filter;
  final Widget Function(BuildContext, Json, VoidCallback) itemBuilder;
  final Widget? header;
  final bool primary, clearOnError;
  final Future<Json> Function(Api api, Json params)? fetchPage;
  final ValueChanged<Json>? onPageLoaded;
  final Widget? empty;
  final int columns;
  final double gap;

  /// Grid edge inset; null keeps the 12pt card-grid inset.
  final double? edgeInset;

  /// Extra content inset; the transparent bar's inset comes from MediaQuery.
  final double topInset;
  final Color? background;
  const RecordList({
    this.topInset = 0,
    this.background,
    super.key,
    required this.action,
    this.params = const {},
    this.dataKey,
    this.filter,
    required this.itemBuilder,
    this.header,
    this.primary = false,
    this.clearOnError = false,
    this.fetchPage,
    this.onPageLoaded,
    this.empty,
    this.columns = 1,
    this.gap = 8,
    this.edgeInset,
  });
  @override
  State<RecordList> createState() => RecordListState();
}

class RecordListState extends State<RecordList> {
  final records = <Json>[];
  List<Json> get visibleRecords =>
      widget.filter == null ? records : records.where(widget.filter!).toList();
  StreamSubscription? uploads;
  StreamSubscription<RealtimeEvent>? liveEvents;
  Timer? refreshTimer;
  bool dirty = false;

  void invalidate() {
    if (!mounted) return;
    dirty = true;
    if (!TickerMode.valuesOf(context).enabled) return;
    refreshTimer?.cancel();
    refreshTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      dirty = false;
      reload();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (dirty && TickerMode.valuesOf(context).enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => invalidate());
    }
  }

  final scroll = ScrollController();
  int generation = 0;
  bool loading = false;
  bool loaded = false;
  String? error;
  String? cursor;
  bool replaceOnLoad = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = AppScope.of(context);
      liveEvents = session.realtime.events.listen((event) {
        if (event.affects(widget.action)) invalidate();
      });
      uploads = session.uploads.completed.stream.listen((event) {
        if (mounted &&
            [
              'post.create',
              'user.check_in',
              'user.upload_story',
            ].contains(event['action'])) {
          invalidate();
        }
      });
      reload(keepRecords: false);
    });
  }

  void loadMore(ScrollMetrics metrics) {
    if (metrics.extentAfter < 400 &&
        cursor != null &&
        !loading &&
        error == null) {
      load();
    }
  }

  @override
  void didUpdateWidget(RecordList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action ||
        oldWidget.params.toString() != widget.params.toString()) {
      reload(keepRecords: false);
    } else if (widget.filter != null &&
        oldWidget.filter == null &&
        cursor != null &&
        !loading) {
      load();
    }
  }

  Future<void> reload({bool keepRecords = true}) async {
    if (!mounted) return;
    generation++;
    loading = false;
    cursor = null;
    replaceOnLoad = true;
    if (!keepRecords) {
      loaded = false;
      records.clear();
    }
    await load();
  }

  Future<void> load() async {
    if (loading) return;
    final requestGeneration = generation;
    final previousCursor = cursor;
    final replacing = replaceOnLoad;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = AppScope.of(context).api;
      final params = <String, dynamic>{
        ...widget.params,
        'limit': 30,
        if (cursor != null) 'cursor': cursor,
      };
      final result =
          await (widget.fetchPage?.call(api, params) ??
              api.call(widget.action, body: params));
      final page = RecordPage.parse(result, key: widget.dataKey);
      if (!mounted || requestGeneration != generation) return;
      setState(() {
        if (replacing) records.clear();
        replaceOnLoad = false;
        final ids = records.map(recordId).where((id) => id.isNotEmpty).toSet();
        records.addAll(
          page.records.where(
            (record) => recordId(record).isEmpty || ids.add(recordId(record)),
          ),
        );
        cursor = page.next;
        loaded = true;
      });
      widget.onPageLoaded?.call(result);
    } catch (e) {
      if (mounted && requestGeneration == generation) {
        setState(() {
          error = '$e';
          if (widget.clearOnError) records.clear();
        });
      }
    } finally {
      if (mounted && requestGeneration == generation) {
        setState(() => loading = false);
        // Recipient search filters the authorized conversation pages locally.
        // Continue paging so a match beyond the first page is not lost.
        if (widget.filter != null &&
            error == null &&
            cursor != null &&
            cursor != previousCursor) {
          scheduleMicrotask(() {
            if (mounted) load();
          });
        }
      }
    }
  }

  @override
  void dispose() {
    uploads?.cancel();
    liveEvents?.cancel();
    refreshTimer?.cancel();
    scroll.dispose();
    super.dispose();
  }

  Widget row(BuildContext context, int index) {
    final records = visibleRecords;
    final rowCount = (records.length / widget.columns).ceil();
    if (index < rowCount) {
      if (widget.columns == 1) {
        return widget.itemBuilder(context, records[index], reload);
      }
      return Padding(
        padding: EdgeInsets.only(bottom: widget.gap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var column = 0; column < widget.columns; column++) ...[
              if (column > 0) SizedBox(width: widget.gap),
              Expanded(
                child: index * widget.columns + column < records.length
                    ? widget.itemBuilder(
                        context,
                        records[index * widget.columns + column],
                        reload,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    if (loading) return const ScreenStatus(loading: true);
    if (error != null) return ScreenStatus(error: error, retry: load);
    if (loaded && records.isEmpty) return widget.empty ?? const ScreenStatus();
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    TickerMode.valuesOf(
      context,
    ); // Resume deferred invalidations when this tab becomes active.
    final records = visibleRecords;
    final rowCount = (records.length / widget.columns).ceil();
    final pad = widget.edgeInset ?? (widget.columns > 1 ? 12.0 : 0.0);
    // UIRefreshControl: the iOS pull-to-refresh drawn above the content.
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) loadMore(notification.metrics);
        return false;
      },
      child: CustomScrollView(
        controller: widget.primary ? null : scroll,
        primary: widget.primary,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + widget.topInset,
            ),
          ),
          if (!widget.primary) CupertinoSliverRefreshControl(onRefresh: reload),
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
            sliver: SliverList.builder(
              itemCount: rowCount + 1,
              itemBuilder: row,
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
          ),
        ],
      ),
    );
  }
}
