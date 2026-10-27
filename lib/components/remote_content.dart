import 'dart:async';
import 'package:flutter/material.dart';
import '../core/realtime.dart';
import '../core/api.dart';
import '../core/session.dart';
import 'screen_status.dart';

/// One request owner, including retry and stale-response protection.
class RemoteContent extends StatefulWidget {
  final bool compact;
  final String action;
  final Json params;
  final Widget Function(BuildContext, Json, VoidCallback) builder;
  const RemoteContent({
    super.key,
    required this.action,
    this.compact = false,
    this.params = const {},
    required this.builder,
  });
  @override
  State<RemoteContent> createState() => RemoteContentState();
}

class RemoteContentState extends State<RemoteContent> {
  StreamSubscription<RealtimeEvent>? liveEvents;
  Timer? refreshTimer;
  Json? data;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      liveEvents = AppScope.of(context).realtime.events.listen((event) {
        if (!event.affects(widget.action)) return;
        refreshTimer?.cancel();
        refreshTimer = Timer(const Duration(milliseconds: 180), () {
          if (mounted) load();
        });
      });
      load();
    });
  }

  @override
  void didUpdateWidget(RemoteContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action ||
        oldWidget.params.toString() != widget.params.toString()) {
      load();
    }
  }

  Future<void> load() async {
    final current = ++generation;
    setState(() {
      data = null;
      error = null;
    });
    try {
      final result = await AppScope.of(
        context,
      ).api.call(widget.action, body: widget.params);
      if (mounted && current == generation) setState(() => data = result);
    } catch (e) {
      if (mounted && current == generation) setState(() => error = '$e');
    }
  }

  @override
  void dispose() {
    liveEvents?.cancel();
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => data == null
      ? ScreenStatus(
          loading: error == null,
          compact: widget.compact,
          error: error,
          retry: error == null ? null : load,
        )
      : widget.builder(context, data!, load);
}
