import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api.dart';
import 'chat_data.dart';

enum RealtimeStatus { offline, connecting, authenticating, online, rejected }

class RealtimeEvent {
  final String name;
  final Json data;
  const RealtimeEvent(this.name, this.data);

  bool affects(String action) {
    if (name == 'sync') return true;
    if (name == 'chat' || name == 'message') {
      if (data['action'] == 'chat.typing' || data['typing'] != null) {
        return false;
      }
      return action.startsWith('chat.');
    }
    if (name == 'post') {
      return action.startsWith('post.') ||
          action.startsWith('classifieds.') ||
          action.startsWith('user.fetch_');
    }
    if (name == 'private_photo_changed') {
      return action.startsWith('user.') || action.startsWith('post.');
    }
    if (name == 'notification') return action == 'user.fetch.notifications';
    if (name == 'user' || name == 'presence') return action.startsWith('user.');
    return false;
  }
}

/// A stable app-wide event bus. Screen listeners survive transport replacement,
/// reconnects and foreground recovery; an old account cannot publish into it.
class AppRealtime extends ChangeNotifier {
  final io.Socket Function(String, Map<String, dynamic>) createSocket;
  AppRealtime({io.Socket Function(String, Map<String, dynamic>)? createSocket})
    : createSocket = createSocket ?? io.io;
  final _events = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _events.stream;
  io.Socket? socket;
  RealtimeStatus status = RealtimeStatus.offline;
  bool get configured => _token != null;
  Timer? _authenticationTimeout;
  String? _token, _url;
  int _generation = 0;
  bool _disposed = false;

  void _state(RealtimeStatus value) {
    if (_disposed || status == value) return;
    status = value;
    notifyListeners();
  }

  void connect({required String url, required String token}) {
    if (_disposed) return;
    final normalized = token.startsWith('Bearer ') ? token : 'Bearer $token';
    if (_token == normalized && _url == url && socket != null) {
      resume();
      return;
    }
    disconnect();
    _token = normalized;
    _url = url;
    final generation = _generation;
    final connection = createSocket(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': normalized})
          .enableForceNew()
          .disableMultiplex()
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .setTimeout(15000)
          .build(),
    );
    socket = connection;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        identical(socket, connection);
    connection.on('connect', (_) {
      // Go may emit auth:ack inside OnConnect before Socket.IO flushes its
      // buffered namespace events and dispatches the local connect event.
      if (!current() ||
          status == RealtimeStatus.online ||
          status == RealtimeStatus.rejected) {
        return;
      }
      _state(RealtimeStatus.authenticating);
      _armAuthenticationDeadline(connection, generation);
    });
    connection.on('auth:ack', (raw) {
      if (!current()) return;
      _authenticationTimeout?.cancel();
      final data = socketPayload(raw);
      if (data['success'] != true) {
        connection.disconnect();
        _state(RealtimeStatus.rejected);
        _events.add(RealtimeEvent('auth:rejected', data));
        return;
      }
      final alreadyOnline = status == RealtimeStatus.online;
      _state(RealtimeStatus.online);
      if (!alreadyOnline) _events.add(RealtimeEvent('sync', data));
    });
    for (final event in [
      'chat',
      'message',
      'private_photo_changed',
      'notification',
      'post',
      'user',
      'presence',
    ]) {
      connection.on(event, (raw) {
        if (current() && status == RealtimeStatus.online) {
          _events.add(RealtimeEvent(event, socketPayload(raw)));
        }
      });
    }
    connection.on('disconnect', (_) {
      if (!current()) return;
      _authenticationTimeout?.cancel();
      _state(RealtimeStatus.offline);
    });
    connection.on('connect_error', (_) {
      if (current()) {
        _state(RealtimeStatus.offline);
      }
    });
    _state(RealtimeStatus.connecting);
    connection.connect();
  }

  void _armAuthenticationDeadline(io.Socket connection, int generation) {
    _authenticationTimeout?.cancel();
    _authenticationTimeout = Timer(const Duration(seconds: 15), () {
      if (_disposed ||
          generation != _generation ||
          status != RealtimeStatus.authenticating) {
        return;
      }
      connection.disconnect();
      _state(RealtimeStatus.offline);
      connection.connect();
    });
  }

  void resume() {
    if (_disposed || socket == null || status == RealtimeStatus.rejected) {
      return;
    }
    if (socket!.connected) {
      // Go auth re-establishes all authorized chat/user rooms.
      _state(RealtimeStatus.authenticating);
      _armAuthenticationDeadline(socket!, _generation);
      socket!.emit('auth', _token);
    } else {
      _state(RealtimeStatus.connecting);
      socket!.connect();
    }
  }

  void disconnect() {
    _generation++;
    _authenticationTimeout?.cancel();
    socket?.dispose();
    socket = null;
    _token = null;
    _url = null;
    _state(RealtimeStatus.offline);
  }

  @override
  void dispose() {
    disconnect();
    _disposed = true;
    _events.close();
    super.dispose();
  }
}
