import 'package:kazumi/modules/danmaku/danmaku_ch_convert.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/request/clients/danmaku_client.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

class DanmakuApi {
  static final _service = DanmakuService(DanmakuClient.instance);

  static Future<int> getDanDanBangumiIDByBgmBangumiID(int id) =>
      _service.getDanDanBangumiIDByBgmBangumiID(id);
  static Future<DanmakuEpisodeResponse> getDanDanEpisodesByDanDanBangumiID(
    int id,
  ) => _service.getDanDanEpisodesByDanDanBangumiID(id);
  static Future<DanmakuSearchResponse> searchAnimes(String title) =>
      _service.searchAnimes(title);
  static Future<List<DanmakuEntry>> getDanDanmaku(int id, int episode) =>
      _service.getDanDanmaku(id, episode);
  static Future<List<DanmakuEntry>> getDanDanmakuByEpisodeID(int id) =>
      _service.getDanDanmakuByEpisodeID(id);
  static Future<({int bangumiID, List<DanmakuEntry> danmakus})> fetchForSubject(
    int id,
    int episode, {
    String title = '',
    String originalTitle = '',
    String airDate = '',
  }) => _service.fetchForSubject(
    id,
    episode,
    title: title,
    originalTitle: originalTitle,
    airDate: airDate,
  );
}

/// Testable transport shared by automatic matching and the manual source sheet.
class DanmakuService {
  DanmakuService(this._client);
  final DanmakuClient _client;

  String _endpoint(String path) => _client.config.endpoint(path);

  Future<int> getDanDanBangumiIDByBgmBangumiID(int bgmBangumiID) async {
    if (_client.config.isSelfHosted) {
      throw UnsupportedError('自建弹幕使用番剧名和集数匹配');
    }
    final path = ApiEndpoints.formatUrl(
      ApiEndpoints.dandanAPIInfoByBgmBangumiId,
      [bgmBangumiID],
    );
    final endPoint = _endpoint(path);
    final jsonData = await _client.get(endPoint);
    return DanmakuEpisodeResponse.fromJson(jsonData).bangumiId;
  }

  Future<DanmakuEpisodeResponse> getDanDanEpisodesByDanDanBangumiID(
    int bangumiID,
  ) async {
    final path = ApiEndpoints.dandanAPIInfo + bangumiID.toString();
    final endPoint = _endpoint(path);
    final jsonData = await _client.get(endPoint);
    return DanmakuEpisodeResponse.fromJson(jsonData);
  }

  // v2 episode search avoids the anime search's 25-result cap.
  // Fetch full episode lists separately; search results can truncate them.
  Future<DanmakuSearchResponse> searchAnimes(String title) async {
    final endPoint = _endpoint(ApiEndpoints.dandanAPISearchEpisodes);
    final jsonData = await _client.get(
      endPoint,
      queryParameters: {'anime': title, 'v2': 'true'},
    );
    return DanmakuSearchResponse.fromJson(jsonData);
  }

  Future<List<DanmakuEntry>> getDanDanmaku(int bangumiID, int episode) async {
    if (bangumiID == 0) {
      return [];
    }
    if (_client.config.isSelfHosted) {
      // Self-hosted episode IDs are allocated by the service, not concatenated.
      final details = await getDanDanEpisodesByDanDanBangumiID(bangumiID);
      if (episode < 1 || episode > details.episodes.length) return [];
      return getDanDanmakuByEpisodeID(details.episodes[episode - 1].episodeId);
    }
    // Automatic matching relies on an undocumented episode ID convention.
    return _getComments('$bangumiID${episode.toString().padLeft(4, '0')}');
  }

  Future<List<DanmakuEntry>> getDanDanmakuByEpisodeID(int episodeID) =>
      _getComments(episodeID.toString());

  Future<({int bangumiID, List<DanmakuEntry> danmakus})> fetchForSubject(
    int bgmId,
    int episode, {
    String title = '',
    String originalTitle = '',
    String airDate = '',
  }) async {
    if (episode < 1) return (bangumiID: 0, danmakus: const <DanmakuEntry>[]);
    if (!_client.config.isSelfHosted) {
      final id = await getDanDanBangumiIDByBgmBangumiID(bgmId);
      return (bangumiID: id, danmakus: await getDanDanmaku(id, episode));
    }
    final year = RegExp(r'^\d{4}(?=-|$)').firstMatch(airDate)?.group(0);
    // Keep any season markers in the title; never hard-code S01 for sequels.
    final titles = {title.trim(), originalTitle.trim()}..remove('');
    for (final candidate in titles) {
      final data = await _client.post(
        _endpoint('/api/v2/match'),
        data: {
          'fileName':
              '$candidate${year == null ? '' : '.$year'}.E${episode.toString().padLeft(2, '0')}',
        },
      );
      if (data is! Map || data['success'] != true || data['matches'] is! List) {
        throw const FormatException('弹幕匹配服务返回异常');
      }
      final matches = data['matches'] as List;
      if (data['isMatched'] != true || matches.isEmpty) continue;
      final match = matches.first as Map;
      final animeId = int.tryParse('${match['animeId']}');
      final episodeId = int.tryParse('${match['episodeId']}');
      if (animeId == null ||
          animeId <= 0 ||
          episodeId == null ||
          episodeId <= 0) {
        throw const FormatException('弹幕匹配结果缺少有效集数编号');
      }
      return (
        bangumiID: animeId,
        danmakus: await getDanDanmakuByEpisodeID(episodeId),
      );
    }
    return (bangumiID: 0, danmakus: const <DanmakuEntry>[]);
  }

  Future<List<DanmakuEntry>> _getComments(String episodeID) async {
    final endPoint = _endpoint('${ApiEndpoints.dandanAPIComment}$episodeID');
    final conversion = DanmakuChConvert.fromValue(
      GStorage.getSetting(SettingsKeys.danmakuChConvert),
    );
    KazumiLogger().i('Danmaku: requesting episode $episodeID');
    final jsonData = await _client.get(
      endPoint,
      queryParameters: {
        'withRelated': 'true',
        'chConvert': conversion.value.toString(),
        if (_client.config.isSelfHosted) 'format': 'json',
      },
    );
    final List<dynamic> comments = jsonData['comments'];
    return [for (final comment in comments) _parseComment(comment)];
  }

  DanmakuEntry _parseComment(Map<String, dynamic> comment) {
    final entry = DanmakuEntry.fromJson(comment);
    if (_client.config.isSelfHosted) {
      final source = entry.source.toLowerCase();
      if (source.contains('bahamut')) entry.source = '[Gamer]';
      if (source.contains('bilibili')) entry.source = '[BiliBili]';
    }
    return entry;
  }
}
