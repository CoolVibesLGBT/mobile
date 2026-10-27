import 'package:coolvibes/core/realtime.dart';
import 'package:coolvibes/core/server_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class TestSocket extends io.Socket {
  final sent = <(String, dynamic)>[];
  bool closed = false;
  TestSocket()
    : super(
        io.io('http://socket.test', <String, dynamic>{
          'autoConnect': false,
          'forceNew': true,
        }).io,
        '/',
        <String, dynamic>{'autoConnect': false},
      );
  @override
  io.Socket connect() {
    connected = true;
    emitEvent(['connect', null]);
    return this;
  }

  @override
  void emit(String event, [dynamic data]) => sent.add((event, data));
  @override
  io.Socket disconnect() {
    connected = false;
    emitEvent(['disconnect', 'test']);
    return this;
  }

  @override
  void dispose() {
    closed = true;
    connected = false;
    clearListeners();
  }

  void receive(String event, dynamic data) => emitEvent([event, data]);
}

void main() {
  test('API LAN override also routes Socket.IO to that Mac', () {
    final endpoints = ServerEndpoints.resolve(
      apiOverride: 'http://192.168.1.20:4001/api',
    );
    expect(endpoints.socket.toString(), 'http://192.168.1.20:4002');
    expect(
      ServerEndpoints.resolve(developmentHost: 'coolvibes.local').api.host,
      'coolvibes.local',
    );
    expect(ServerEndpoints.resolve(release: true).socket.scheme, 'https');
    expect(ServerEndpoints.resolve(android: true).api.host, '10.0.2.2');
  });
  test('explicit socket URL wins over development inference', () {
    expect(
      ServerEndpoints.resolve(
        apiOverride: 'http://10.1.1.5:4001/api',
        socketOverride: 'https://realtime.example',
      ).socket.host,
      'realtime.example',
    );
  });
  test(
    'transport connect is not authenticated live; reconnect preserves subscribers',
    () async {
      final sockets = <TestSocket>[];
      final realtime = AppRealtime(
        createSocket: (_, options) {
          expect(options['forceNew'], isTrue);
          final socket = TestSocket();
          sockets.add(socket);
          return socket;
        },
      );
      final received = <RealtimeEvent>[];
      final subscription = realtime.events.listen(received.add);
      realtime.connect(url: 'http://localhost:4002', token: 'one');
      expect(realtime.status, RealtimeStatus.authenticating);
      sockets.first.receive('chat', {'content': 'unauthenticated'});
      expect(received, isEmpty);
      sockets.first.receive('auth:ack', {'success': true});
      sockets.first.receive('connect', null);
      expect(realtime.status, RealtimeStatus.online);
      sockets.first.receive('chat', '{"chat_id":"room","content":"hello"}');
      await Future<void>.delayed(Duration.zero);
      expect(received.map((e) => e.name), ['sync', 'chat']);
      realtime.connect(url: 'http://localhost:4002', token: 'two');
      expect(sockets.first.closed, isTrue);
      sockets.first.receive('chat', {'content': 'stale account'});
      sockets.last.receive('auth:ack', {'success': true});
      sockets.last.receive('chat', {'content': 'new account'});
      await Future<void>.delayed(Duration.zero);
      expect(received.last.data['content'], 'new account');
      expect(received.length, 4);
      await subscription.cancel();
      realtime.dispose();
    },
  );
  test(
    'foreground recovery reauthenticates and resynchronizes rooms',
    () async {
      final socket = TestSocket();
      final realtime = AppRealtime(createSocket: (_, _) => socket);
      var syncs = 0;
      final sub = realtime.events.listen((e) {
        if (e.name == 'sync') syncs++;
      });
      realtime.connect(url: 'http://localhost:4002', token: 'token');
      socket.receive('auth:ack', {'success': true});
      realtime.resume();
      expect(socket.sent.last, ('auth', 'Bearer token'));
      expect(realtime.status, RealtimeStatus.authenticating);
      socket.receive('auth:ack', {'success': true});
      await Future<void>.delayed(Duration.zero);
      expect(syncs, 2);
      await sub.cancel();
      realtime.dispose();
    },
  );
  test(
    'auth rejection stops delivery without dropping unrelated HTTP credentials',
    () {
      final socket = TestSocket();
      final realtime = AppRealtime(createSocket: (_, _) => socket);
      realtime.connect(url: 'http://localhost:4002', token: 'bad');
      socket.receive('auth:ack', {
        'success': false,
        'error': 'invalid_session',
      });
      socket.receive('connect', null);
      expect(realtime.status, RealtimeStatus.rejected);
      realtime.disconnect();
      expect(realtime.configured, isFalse);
      expect(realtime.status, RealtimeStatus.offline);
      realtime.dispose();
    },
  );
  test('list invalidations skip typing and include post changes', () {
    expect(
      const RealtimeEvent('chat', {
        'action': 'chat.typing',
      }).affects('chat.fetch_chats'),
      isFalse,
    );
    expect(
      const RealtimeEvent('post', {
        'action': 'post.changed',
      }).affects('post.timeline'),
      isTrue,
    );
    expect(
      const RealtimeEvent(
        'private_photo_changed',
        {},
      ).affects('user.private_photos.fetch'),
      isTrue,
    );
  });
}
