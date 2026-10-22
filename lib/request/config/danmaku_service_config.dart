/// Private endpoints are supplied at build time, never committed to source.
class DanmakuServiceConfig {
  const DanmakuServiceConfig({
    this.baseUrl = const String.fromEnvironment('DANMAKU_API_BASE_URL'),
  });

  final String baseUrl;

  bool get isSelfHosted => baseUrl.trim().isNotEmpty;

  Uri get baseUri {
    final uri = Uri.parse(baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''));
    final local =
        uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    if (!uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && !(local && uri.scheme == 'http'))) {
      throw const FormatException('弹幕服务地址无效，公网服务须使用 HTTPS');
    }
    return uri;
  }

  bool owns(Uri uri) {
    if (!isSelfHosted) return false;
    final base = baseUri;
    return uri.origin == base.origin && uri.path.startsWith('${base.path}/');
  }

  String endpoint(String path) => isSelfHosted
      ? '${baseUri.toString()}$path'
      : 'https://api.dandanplay.net$path';
}
