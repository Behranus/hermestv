/// v2.1: Test sunucu servisi tamamen devre dışı bırakıldı.
/// Hiçbir test sunucusuna bağlanmaz, kanal yüklemez.

class TestServer {
  final String name, server, username, password, description;
  bool working = false;
  int liveCount = 0, vodCount = 0;

  TestServer({
    required this.name,
    required this.server,
    required this.username,
    required this.password,
    required this.description,
  });

  Map<String, dynamic> toJson() => {};
  static TestServer? fromJson(Map<String, dynamic> json) => null;
}

class TestServerService {
  /// Hiçbir zaman sunucu döndürmez — test sistemi kaldırıldı.
  static Future<List<TestServer>> refresh({bool force = false}) async =>
      const <TestServer>[];
}
