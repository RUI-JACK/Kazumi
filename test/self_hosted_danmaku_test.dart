import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/request/clients/danmaku_client.dart';
import 'package:kazumi/request/config/danmaku_service_config.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _config = DanmakuServiceConfig(
  baseUrl: 'https://danmaku.example/private-test-token',
);
const _comments = {
  'comments': [
    {'m': 'A timed comment', 'p': '12.5,1,16777215,[bahamut]'},
  ],
};
Map<String, dynamic> _match({bool found = true}) => {
  'success': true,
  'isMatched': found,
  'matches': found
      ? [
          {'animeId': 351, 'episodeId': 7007},
        ]
      : [],
};
Map<String, dynamic> _details() => {
  'success': true,
  'errorCode': 0,
  'errorMessage': '',
  'bangumi': {
    'animeId': 351,
    'episodes': [
      {'episodeId': 503, 'episodeTitle': 'Original episode title'},
      {'episodeId': 7007, 'episodeTitle': 'Second episode title'},
    ],
  },
};

void main() {
  late Directory temp;
  late PathProviderPlatform originalPaths;
  late _Adapter adapter;
  late Dio dio;
  late DanmakuClient client;
  late DanmakuService service;

  setUpAll(() async {
    Logger.level = Level.off;
    temp = await Directory.systemTemp.createTemp('kirakira_danmaku_test_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temp.path);
    Hive.init(temp.path);
    await GStorage.init();
  });
  setUp(() {
    adapter = _Adapter();
    dio = Dio()..httpClientAdapter = adapter;
    client = DanmakuClient(dio: dio, config: _config);
    service = DanmakuService(client);
  });
  tearDown(() => dio.close(force: true));
  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    expect(
      temp.absolute.path.startsWith(Directory.systemTemp.absolute.path),
      isTrue,
    );
    expect(
      temp.uri.pathSegments.where((s) => s.isNotEmpty).last,
      startsWith('kirakira_danmaku_test_'),
    );
    await temp.delete(recursive: true);
  });

  test(
    'automatic matching retains season/year and uses the returned episode ID',
    () async {
      adapter.respond = (r) => r.method == 'POST' ? _match() : _comments;
      final result = await service.fetchForSubject(
        123,
        2,
        title: '番剧 第二季',
        airDate: '2026-01-01',
      );
      expect(result.bangumiID, 351);
      expect(result.danmakus.single.time, 12.5);
      expect(result.danmakus.single.source, '[Gamer]');
      expect(adapter.requests.first.data, {'fileName': '番剧 第二季.2026.E02'});
      expect(
        adapter.requests.last.uri.path,
        '/private-test-token/api/v2/comment/7007',
      );
      expect(adapter.requests.last.queryParameters['format'], 'json');
    },
  );

  test(
    'original title is retried only when the Chinese title has no match',
    () async {
      adapter.respond = (r) => r.method == 'POST'
          ? _match(
              found: (r.data as Map)['fileName'].toString().startsWith(
                'Original',
              ),
            )
          : _comments;
      final result = await service.fetchForSubject(
        123,
        1,
        title: '中文名',
        originalTitle: 'Original title',
      );
      expect(result.danmakus, hasLength(1));
      expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(2));
    },
  );

  test('no match is empty and does not invent an episode ID', () async {
    adapter.respond = (_) => _match(found: false);
    final result = await service.fetchForSubject(123, 1, title: 'Missing');
    expect(result.bangumiID, 0);
    expect(result.danmakus, isEmpty);
    expect(adapter.requests, hasLength(1));
  });

  test('invalid episode and missing titles make no remote request', () async {
    expect(
      (await service.fetchForSubject(123, 0, title: 'Title')).danmakus,
      isEmpty,
    );
    expect((await service.fetchForSubject(123, 1)).danmakus, isEmpty);
    expect(adapter.requests, isEmpty);
  });

  test(
    'business failures and invalid match IDs are errors, not empty results',
    () async {
      adapter.respond = (_) => {'success': false, 'matches': []};
      await expectLater(
        service.fetchForSubject(123, 1, title: 'Title'),
        throwsFormatException,
      );
      adapter.respond = (_) => {
        'success': true,
        'isMatched': true,
        'matches': [
          {'animeId': 351},
        ],
      };
      await expectLater(
        service.fetchForSubject(123, 1, title: 'Title'),
        throwsFormatException,
      );
    },
  );

  test(
    'manual search and full original episode titles use the same service',
    () async {
      adapter.respond = (r) => r.uri.path.contains('/search/')
          ? {
              'animes': [
                {'animeId': 351, 'animeTitle': 'Title from bahamut'},
              ],
            }
          : _details();
      final search = await service.searchAnimes('Title');
      final details = await service.getDanDanEpisodesByDanDanBangumiID(
        search.animes.single.animeId,
      );
      expect(details.episodes[0].episodeTitle, 'Original episode title');
      expect(details.episodes[1].episodeId, 7007);
      expect(adapter.requests.every((r) => _config.owns(r.uri)), isTrue);
    },
  );

  test(
    'explicit anime/episode lookup uses the full list instead of concatenation',
    () async {
      adapter.respond = (r) =>
          r.uri.path.contains('/bangumi/') ? _details() : _comments;
      final entries = await service.getDanDanmaku(351, 2);
      expect(entries, hasLength(1));
      expect(adapter.requests.last.uri.path, endsWith('/comment/7007'));
      expect(await service.getDanDanmaku(351, 9), isEmpty);
    },
  );

  test(
    'self-hosted requests omit all DanDanPlay auth and redact request logging',
    () async {
      adapter.respond = (_) => _comments;
      await client.get(
        _config.endpoint('/api/v2/comment/503'),
        headers: {'X-AppId': 'must-not-forward'},
      );
      final r = adapter.requests.single;
      expect(
        r.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('x-appid')),
      );
      expect(
        r.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('x-signature')),
      );
      expect(r.extra['sensitiveUrl'], isTrue);
      expect(r.receiveTimeout, const Duration(seconds: 120));
    },
  );

  test(
    'requests cannot leave the configured endpoint or downgrade public TLS',
    () async {
      await expectLater(
        client.get('https://other.example/api/v2/comment/1'),
        throwsFormatException,
      );
      await expectLater(
        client.get(
          'https://danmaku.example/private-test-token-evil/api/v2/comment/1',
        ),
        throwsFormatException,
      );
      expect(
        () => const DanmakuServiceConfig(
          baseUrl: 'http://public.example/token',
        ).baseUri,
        throwsFormatException,
      );
      expect(
        () => const DanmakuServiceConfig(
          baseUrl: 'https://user:pass@public.example/token',
        ).baseUri,
        throwsFormatException,
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'builds without a self-hosted endpoint retain the authorized official flow',
    () async {
      final official = DanmakuService(
        DanmakuClient(
          dio: dio,
          config: const DanmakuServiceConfig(baseUrl: ''),
        ),
      );
      adapter.respond = (r) =>
          r.uri.path.contains('/bgmtv/') ? _details() : _comments;
      final result = await official.fetchForSubject(123, 2, title: 'Title');
      expect(result.danmakus, hasLength(1));
      expect(adapter.requests.first.uri.host, 'api.dandanplay.net');
      expect(adapter.requests.last.uri.path, endsWith('/comment/3510002'));
      expect(adapter.requests.first.headers, contains('X-Signature'));
    },
  );

  test(
    'live private service matches, parses comments, and lists manual episodes',
    () async {
      final liveDio = Dio(
        BaseOptions(connectTimeout: const Duration(seconds: 20)),
      );
      try {
        final live = DanmakuService(DanmakuClient(dio: liveDio));
        final result = await live.fetchForSubject(
          400602,
          1,
          title: '葬送的芙莉莲',
          originalTitle: '葬送のフリーレン',
          airDate: '2023-09-29',
        );
        expect(result.danmakus, isNotEmpty);
        expect(
          result.danmakus.every((c) => c.time.isFinite && c.time >= 0),
          isTrue,
        );
        final search = await live.searchAnimes('葬送的芙莉莲');
        expect(search.animes, isNotEmpty);
        final details = await live.getDanDanEpisodesByDanDanBangumiID(
          result.bangumiID,
        );
        expect(details.episodes, hasLength(28));
        final manual = await live.getDanDanmakuByEpisodeID(
          details.episodes.first.episodeId,
        );
        expect(manual, isNotEmpty);
        // ignore: avoid_print
        print(
          'LIVE_DANMAKU automatic=${result.danmakus.length} manual=${manual.length} episodes=${details.episodes.length}',
        );
      } finally {
        liveDio.close(force: true);
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_DANMAKU'),
  );
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, dynamic> Function(RequestOptions) respond = (_) => _comments;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String> getApplicationSupportPath() async => path;
  @override
  Future<String> getApplicationDocumentsPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
}
