import 'package:kazumi/request/config/api_endpoints.dart';

/// Only this distribution's GitHub releases can supply application packages.
abstract final class UpdateChannel {
  static const applicationUpdatesEnabled = true;
  static const repository = 'RUI-JACK/kirakira';
  static const repositoryUrl = ApiEndpoints.sourceUrl;
  static const releasesUrl = '$repositoryUrl/releases';
  static const title = '检查更新';
  static const notice = '从 RUI-JACK/kirakira 检查定制版更新，播放源规则仍可单独更新。';
  static const noReleaseNotice = '仓库暂未发布正式版本，请等待 Releases 发布定制安装包。';
  static const noPackageNotice = '仓库新版本暂无适配当前设备的定制安装包。';

  static String? versionNumber(String tag) {
    final match = RegExp(r'^v?(\d+\.\d+\.\d+)(?:\+\d+)?$').firstMatch(tag);
    return match?.group(1);
  }

  static String releasePage(String tag) =>
      '$releasesUrl/tag/${Uri.encodeComponent(tag)}';

  static bool isTrustedAsset(Map<String, dynamic> asset, {String? tag}) {
    final name = asset['name'];
    final url = asset['browser_download_url'];
    if (name is! String || url is! String) return false;
    final lowerName = name.toLowerCase();
    if (!(lowerName.startsWith('kirakira-') || name.startsWith('キラキラ-')) ||
        name.contains('/') ||
        name.contains('\\')) {
      return false;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port != 443) {
      return false;
    }
    final parts = uri.pathSegments;
    if (parts.length != 6 ||
        parts.take(2).join('/').toLowerCase() != repository.toLowerCase() ||
        parts[2] != 'releases' ||
        parts[3] != 'download' ||
        parts[5] != name ||
        (tag != null && parts[4] != tag)) {
      return false;
    }
    final version = versionNumber(parts[4]);
    if (version == null || !lowerName.contains('-$version-')) return false;
    // GitHub computes this digest for uploaded release assets. Never install
    // a package without the checksum consumed by downloadUpdateFile.
    return RegExp(
      r'^sha256:[a-fA-F0-9]{64}$',
    ).hasMatch(asset['digest'] is String ? asset['digest'] : '');
  }
}
