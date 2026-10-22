import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/search/search_page.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/request/clients/bangumi_client.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory directory;
  late PathProviderPlatform originalPaths;
  late _SearchAdapter adapter;

  setUpAll(() async {
    Logger.level = Level.off;
    directory = await Directory.systemTemp.createTemp('kirakira_search_test_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    Hive.init(directory.path);
    await GStorage.init();
  });

  setUp(() async {
    DioFactory.reset();
    await GStorage.putSetting(SettingsKeys.bangumiAcceleration, 'mirror');
    await GStorage.putSetting(SettingsKeys.bangumiSyncEnable, false);
    await GStorage.putSetting(SettingsKeys.bangumiAccessToken, '');
    adapter = _SearchAdapter();
    DioFactory.bangumiDio.httpClientAdapter.close();
    DioFactory.bangumiDio.httpClientAdapter = adapter;
  });

  tearDownAll(() async {
    DioFactory.reset();
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    expect(
      directory.absolute.path.startsWith(Directory.systemTemp.absolute.path),
      isTrue,
    );
    expect(
      directory.uri.pathSegments.where((p) => p.isNotEmpty).last,
      startsWith('kirakira_search_test_'),
    );
    await directory.delete(recursive: true);
  });

  test(
    'custom build searches public API; signed builds retain mirror search',
    () async {
      adapter.respond = (_) async => _results();
      final page = await BangumiApi.bangumiSearch('葬送的芙莉莲', offset: 20);
      expect(page?.items.single.nameCn, '葬送的芙莉莲');
      final request = adapter.requests.single;
      expect(
        request.uri.host,
        hasBangumiMirrorCredentials ? 'api.kazumi.fyi' : 'api.bgm.tv',
      );
      expect(request.uri.queryParameters, {'limit': '20', 'offset': '20'});
      expect(request.data['keyword'], '葬送的芙莉莲');
      expect(request.data['filter']['type'], [2]);
      expect(
        request.headers.containsKey('X-Signature'),
        hasBangumiMirrorCredentials,
      );
      expect(
        request.headers.containsKey('X-AppId'),
        hasBangumiMirrorCredentials,
      );
    },
  );

  test('metadata still uses mirror with query parameters intact', () async {
    await BangumiClient.instance.get(
      'https://next.bgm.tv/p1/subjects/1?test=value',
    );
    expect(
      adapter.requests.single.uri.toString(),
      'https://api.kazumi.fyi/p1/subjects/1?test=value',
    );
  });

  test(
    'episode, subject and character comments bypass unsigned mirror',
    () async {
      adapter.respond = (request) async =>
          request.uri.path.contains('/subjects/')
          ? _json({'list': [], 'total': 0})
          : _json([]);
      await BangumiApi.getBangumiCommentsByEpisodeID(1227087);
      await BangumiApi.getBangumiCommentsByID(400602, offset: 20);
      await BangumiApi.getCharacterCommentsByCharacterID(1);
      expect(adapter.requests.map((r) => r.uri.path), [
        '/p1/episodes/1227087/comments',
        '/p1/subjects/400602/comments',
        '/p1/characters/1/comments',
      ]);
      for (final request in adapter.requests) {
        expect(
          request.uri.host,
          hasBangumiMirrorCredentials ? 'api.kazumi.fyi' : 'next.bgm.tv',
        );
        expect(
          request.headers.containsKey('X-Signature'),
          hasBangumiMirrorCredentials,
        );
        expect(
          request.headers.containsKey('X-AppId'),
          hasBangumiMirrorCredentials,
        );
      }
      expect(adapter.requests[1].uri.queryParameters, {
        'limit': '20',
        'offset': '20',
      });
    },
  );

  test(
    'episode comments parse nested replies; request failures stay failures',
    () async {
      final user = {
        'id': 1,
        'username': 'tester',
        'nickname': 'Reader',
        'avatar': <String, String>{},
      };
      adapter.respond = (_) async => _json([
        {
          'user': user,
          'content': 'Episode discussion',
          'createdAt': 10,
          'replies': [
            {'user': user, 'content': 'Reply', 'createdAt': 11},
          ],
        },
      ]);
      final comments = await BangumiApi.getBangumiCommentsByEpisodeID(1227087);
      expect(comments.commentList.single.comment.comment, 'Episode discussion');
      expect(comments.commentList.single.replies.single.comment, 'Reply');
      adapter.respond = (_) async => _json({}, status: 503);
      await expectLater(
        BangumiApi.getBangumiCommentsByEpisodeID(1227087),
        throwsA(isA<NetworkException>()),
      );
      adapter.respond = (_) async => _json([]);
      expect(
        (await BangumiApi.getBangumiCommentsByEpisodeID(1227087)).commentList,
        isEmpty,
      );
    },
  );

  test(
    'direct and ECH comments preserve selected mode without mirror keys',
    () async {
      adapter.respond = (_) async => _json([]);
      for (final mode in ['direct', 'ech']) {
        await GStorage.putSetting(SettingsKeys.bangumiAcceleration, mode);
        await BangumiApi.getBangumiCommentsByEpisodeID(1227087);
        final request = adapter.requests.last;
        expect(request.uri.host, 'next.bgm.tv');
        expect(request.extra['bangumiEch'] == true, mode == 'ech');
        expect(request.headers.containsKey('X-Signature'), isFalse);
        expect(request.headers.containsKey('X-AppId'), isFalse);
      }
    },
  );

  test(
    'LIVE: episode mapping and real discussion parse in default mirror mode',
    () => HttpOverrides.runWithHttpOverrides(() async {
      DioFactory.reset();
      final episode = await BangumiApi.getBangumiEpisodeByID(400602, 1);
      expect(episode.id, 1227087);
      final comments = await BangumiApi.getBangumiCommentsByEpisodeID(
        episode.id,
      );
      expect(comments.commentList, isNotEmpty);
      expect(
        comments.commentList.any((c) => c.comment.comment.isNotEmpty),
        isTrue,
      );
      // Public counts only; do not print comment bodies or user information.
      // ignore: avoid_print
      print(
        'LIVE episode ${episode.id}: ${comments.commentList.length} discussions',
      );
    }, _LiveHttp()),
    skip: !const bool.fromEnvironment('RUN_LIVE_COMMENTS'),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'direct and ECH search retain chosen transport and never send mirror keys',
    () async {
      for (final mode in ['direct', 'ech']) {
        await GStorage.putSetting(SettingsKeys.bangumiAcceleration, mode);
        await BangumiApi.bangumiSearch('frieren');
        final request = adapter.requests.last;
        expect(request.uri.host, 'api.bgm.tv');
        expect(request.extra['bangumiEch'] == true, mode == 'ech');
        expect(request.headers.containsKey('X-Signature'), isFalse);
        expect(request.headers.containsKey('X-AppId'), isFalse);
      }
    },
  );

  test(
    'controller distinguishes request failure from a successful empty page',
    () async {
      final controller = SearchPageController(
        CollectRepository(),
        SearchHistoryRepository(),
      );
      adapter.respond = (_) async => _json({}, status: 503);
      await controller.searchBangumi('frieren', type: 'init');
      expect(controller.isLoading, isFalse);
      expect(controller.isTimeOut, isTrue);
      expect(controller.bangumiList, isEmpty);

      adapter.respond = (_) async => _json({'data': []});
      await controller.searchBangumi('no-such-title', type: 'init');
      expect(controller.isLoading, isFalse);
      expect(controller.isTimeOut, isFalse);
      expect(controller.hasMoreSearchResults, isFalse);

      adapter.respond = (_) async => _results();
      await controller.searchBangumi('葬送的芙莉莲', type: 'init');
      expect(controller.isTimeOut, isFalse);
      expect(controller.bangumiList.single.id, 400602);
    },
  );

  test(
    'pagination keeps offset and existing results on an added-page failure',
    () async {
      final controller = SearchPageController(
        CollectRepository(),
        SearchHistoryRepository(),
      );
      adapter.respond = (_) async =>
          _json({'data': List.generate(20, (i) => _item(i + 1))});
      await controller.searchBangumi('anime', type: 'init');
      expect(controller.hasMoreSearchResults, isTrue);
      adapter.respond = (_) async => _json({}, status: 503);
      await controller.searchBangumi('anime');
      expect(controller.bangumiList, hasLength(20));
      expect(controller.isTimeOut, isTrue);
      adapter.respond = (_) async => _results();
      await controller.searchBangumi('anime');
      expect(adapter.requests.last.uri.queryParameters['offset'], '20');
      expect(controller.bangumiList, hasLength(21));
      expect(controller.isTimeOut, isFalse);
    },
  );

  testWidgets('search page shows failure and retries to visible result cards', (
    tester,
  ) async {
    final controller = SearchPageController(
      CollectRepository(),
      SearchHistoryRepository(),
    );
    adapter.respond = (_) async => _json({}, status: 503);
    await tester.pumpWidget(
      MaterialApp(home: SearchPage(controller: controller)),
    );
    await tester.enterText(find.byType(EditableText), 'frieren');
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.search);
      while (controller.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('搜索请求失败，请检查网络后重试'), findsOneWidget);
    expect(find.text('没有找到番剧'), findsNothing);
    adapter.respond = (_) async => _results();
    await tester.runAsync(() async {
      await tester.tap(find.text('重试'));
      while (controller.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('葬送的芙莉莲'), findsOneWidget);
    expect(find.text('搜索请求失败，请检查网络后重试'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'LIVE: production controller returns real titles in default mirror mode',
    () async {
      DioFactory.reset(); // Real configured adapter, interceptor and JSON parser.
      for (final keyword in ['葬送的芙莉莲', '孤独摇滚', '学生会也有洞']) {
        final controller = SearchPageController(
          CollectRepository(),
          SearchHistoryRepository(),
        );
        await controller.searchBangumi(keyword, type: 'init');
        expect(controller.isLoading, isFalse);
        expect(controller.isTimeOut, isFalse, reason: keyword);
        expect(controller.bangumiList, isNotEmpty, reason: keyword);
        // Only public result names/counts; never log request headers or tokens.
        // ignore: avoid_print
        print(
          'LIVE search "$keyword": ${controller.bangumiList.length} results; '
          '${controller.bangumiList.first.nameCn}',
        );
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_SEARCH'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Map<String, dynamic> _item(int id) => {
  'id': id,
  'name': 'Sousou no Frieren',
  'name_cn': '葬送的芙莉莲',
  'rating': {'rank': 1, 'score': 9.0, 'total': 1},
  'images': <String, String>{},
};

ResponseBody _results() => _json({
  'data': [_item(400602)],
});
ResponseBody _json(Object data, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _SearchAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Future<ResponseBody> Function(RequestOptions) respond = (_) async =>
      _results();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

// Restore real sockets only inside the opt-in live check; widget tests keep
// Flutter's network isolation and the deterministic cases use their adapter.
class _LiveHttp extends HttpOverrides {}
