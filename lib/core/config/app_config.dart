/// Runtime API configuration. Pass `--dart-define=API_URL=https://sandbox.badrgo.com`.
/// Do not put session tokens or passwords in this class.
class AppConfig {
  const AppConfig({required this.apiUrl});

  factory AppConfig.fromEnvironment() {
    const raw = String.fromEnvironment(
      'API_URL',
      defaultValue: 'https://sandbox.badrgo.com',
    );
    return AppConfig(apiUrl: normalizeBaseUrl(raw));
  }

  final String apiUrl;

  Uri restUri(String path, [Map<String, String>? query]) {
    return Uri.parse('$apiUrl$path').replace(queryParameters: query);
  }

  Uri get graphqlUri => Uri.parse('$apiUrl/graphql');

  Uri eventsUri({required String token, String? topics, String? lastEventId}) {
    return restUri('/api/events', {
      'token': token,
      'topics': ?topics,
      'lastEventId': ?lastEventId,
    });
  }

  Uri websocketUri({required String token}) {
    final http = Uri.parse(apiUrl);
    final scheme = http.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: http.host,
      port: http.hasPort ? http.port : null,
      path: '/ws',
      queryParameters: {'token': token},
    );
  }

  static String normalizeBaseUrl(String raw) {
    var value = raw.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}
