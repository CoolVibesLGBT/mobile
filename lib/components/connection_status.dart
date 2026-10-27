import '../l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import '../core/session.dart';
import '../core/realtime.dart';

/// Shared status copy: transport connectivity is distinct from authenticated live delivery.
String? connectionStatus(BuildContext context) {
  final live = AppScope.of(context).realtime;
  if (!live.configured || live.status == RealtimeStatus.online) return null;
  return switch (live.status) {
    RealtimeStatus.connecting ||
    RealtimeStatus.authenticating => context.l10n.connecting,
    RealtimeStatus.rejected => context.l10n.liveConnectionCouldNotBeVerified,
    _ => context.l10n.waitingForConnection,
  };
}
