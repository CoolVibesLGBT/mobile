/// One endpoint contract for HTTP and Socket.IO, including real LAN devices.
class ServerEndpoints {
  final Uri api, socket;
  const ServerEndpoints(this.api, this.socket);

  factory ServerEndpoints.resolve({
    String apiOverride = '',
    String socketOverride = '',
    String developmentHost = '',
    bool release = false,
    bool android = false,
  }) {
    final host = developmentHost.isNotEmpty
        ? developmentHost
        : android
        ? '10.0.2.2'
        : 'localhost';
    final api = Uri.parse(
      apiOverride.isNotEmpty
          ? apiOverride
          : release
          ? 'https://api.coolvibes.lgbt/api'
          : Uri(
              scheme: 'http',
              host: host,
              port: 4001,
              path: '/api',
            ).toString(),
    );
    final Uri socket;
    if (socketOverride.isNotEmpty) {
      socket = Uri.parse(socketOverride);
    } else if (api.port == 4001) {
      socket = api.replace(port: 4002, path: '', query: null, fragment: null);
    } else if (apiOverride.isNotEmpty) {
      // A reverse proxy can serve /api and /socket.io on the same origin.
      socket = api.replace(path: '', query: null, fragment: null);
    } else {
      socket = Uri.parse('https://socket.coolvibes.app');
    }
    return ServerEndpoints(api, socket);
  }
}
