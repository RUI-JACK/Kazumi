import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/update_available_dialog.dart';
import 'package:kazumi/pages/onboarding/steps/update_source_step.dart';
import 'package:kazumi/pages/settings/update_settings.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/update/auto_updater.dart';
import 'package:kazumi/services/update/update_channel.dart';
import 'package:kazumi/services/update/update_downloader.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory directory;
  late PathProviderPlatform originalPaths;
  late _UpdateAdapter adapter;
  setUpAll(() async {
    Logger.level = Level.off;
    directory = await Directory.systemTemp.createTemp('kirakira_update_test_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    Hive.init(directory.path);
    await GStorage.init();
  });
  setUp(() async {
    DioFactory.reset();
    await GStorage.putSetting(SettingsKeys.autoUpdate, true);
    await GStorage.putSetting(SettingsKeys.enableGitProxy, false);
    await GStorage.putSetting(SettingsKeys.checkPluginUpdateOnStartup, true);
    adapter = _UpdateAdapter();
    for (final dio in [DioFactory.downloadDio, DioFactory.rulesRepoDio]) {
      dio.httpClientAdapter.close();
      dio.httpClientAdapter = adapter;
    }
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
      startsWith('kirakira_update_test_'),
    );
    await directory.delete(recursive: true);
  });

  test(
    'only own releases are requested; v-prefixed version and EXE are supported',
    () async {
      final info = await AutoUpdater().checkForUpdates();
      expect(adapter.requests.single.uri.toString(), ApiEndpoints.latestApp);
      expect(
        ApiEndpoints.latestApp,
        'https://api.github.com/repos/RUI-JACK/kirakira/releases/latest',
      );
      expect(info?.version, 'v99.0.0');
      expect(info?.releaseNotes, '${UpdateChannel.releasesUrl}/tag/v99.0.0');
      expect(info?.availableInstallationTypes, [
        InstallationType.windowsInstaller,
        InstallationType.windowsPortable,
      ]);
      expect(
        info?.recommendedInstallationType,
        InstallationType.windowsInstaller,
      );
      expect(
        getUpdateAssetForType(
          info!.assets,
          InstallationType.windowsInstaller,
        )?['name'],
        endsWith('-setup.exe'),
      );
    },
  );

  test(
    'missing first release is a normal state, without upstream fallback',
    () async {
      adapter.status = 404;
      expect(await AutoUpdater().checkForUpdates(), isNull);
      expect(AutoUpdater().noUpdateMessage, UpdateChannel.noReleaseNotice);
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'rate limits and other failures are not reported as latest or retried upstream',
    () async {
      adapter.status = 403;
      await expectLater(
        AutoUpdater().checkForUpdates(),
        throwsA(isA<NetworkException>()),
      );
      expect(adapter.requests.single.uri.toString(), ApiEndpoints.latestApp);
    },
  );

  test(
    'unchanged versions, draft and preview releases do not offer installation',
    () async {
      for (final release in [
        _release(tag: ApiEndpoints.version),
        {..._release(), 'draft': true},
        {..._release(), 'prerelease': true},
      ]) {
        adapter.release = release;
        expect(await AutoUpdater().checkForUpdates(), isNull);
      }
    },
  );

  test(
    'invalid version cannot become a filename or trigger a parse crash silently',
    () async {
      for (final tag in ['../../original', 'latest', '99.0.0-beta']) {
        adapter.release = _release(tag: tag);
        await expectLater(
          AutoUpdater().checkForUpdates(),
          throwsA(isA<FormatException>()),
        );
      }
    },
  );

  test(
    'source-only or incompatible assets do not advertise an installable update',
    () async {
      for (final assets in [
        [],
        [_asset('Kazumi_windows_99.0.0.zip')],
        [_asset('kirakira-99.0.0-android-x86_64.apk')],
      ]) {
        adapter.release = {..._release(), 'assets': assets};
        expect(await AutoUpdater().checkForUpdates(), isNull);
        expect(AutoUpdater().noUpdateMessage, UpdateChannel.noPackageNotice);
      }
    },
  );

  test(
    'asset selection rejects upstream, external URLs, wrong tags, names and missing hashes',
    () {
      final good = _asset('キラキラ-99.0.0-windows-x64-setup.exe');
      final bad = [
        {
          ...good,
          'browser_download_url': good['browser_download_url']
              .toString()
              .replaceFirst('RUI-JACK/kirakira', 'Predidit/Kazumi'),
        },
        {
          ...good,
          'browser_download_url': good['browser_download_url']
              .toString()
              .replaceFirst('github.com', 'example.com'),
        },
        {
          ...good,
          'browser_download_url': good['browser_download_url']
              .toString()
              .replaceFirst('v99.0.0', 'v98.0.0'),
        },
        {...good, 'digest': ''},
        {...good, 'name': 'original.exe'},
      ];
      for (final item in bad) {
        expect(UpdateChannel.isTrustedAsset(item, tag: 'v99.0.0'), isFalse);
      }
      expect(
        getUpdateAssetForType([
          null,
          ...bad,
          good,
        ], InstallationType.windowsInstaller),
        good,
      );
      expect(getUpdateAssetForType([good], InstallationType.unknown), isNull);
      final android = _asset('kirakira-99.0.0-android-arm64-v8a.apk');
      expect(
        getUpdateAssetForType([
          _asset('kirakira-99.0.0-android-x86_64.apk'),
          android,
        ], InstallationType.androidApk),
        android,
      );
    },
  );

  test('automatic checks respect saved on and off choices', () async {
    adapter.release = _release(tag: ApiEndpoints.version);
    await GStorage.putSetting(SettingsKeys.autoUpdate, false);
    await AutoUpdater().autoCheckForUpdates();
    expect(adapter.requests, isEmpty);
    await GStorage.putSetting(SettingsKeys.autoUpdate, true);
    await AutoUpdater().autoCheckForUpdates();
    expect(adapter.requests.single.uri.toString(), ApiEndpoints.latestApp);
  });

  test(
    'installer download verifies checksum and reuses only verified cached bytes',
    () async {
      final bytes = utf8.encode('synthetic installer fixture - never executed');
      adapter.downloadBytes = bytes;
      final digest = sha256.convert(bytes).toString();
      final target = '${directory.path}/fixture-setup.exe';
      Future<String> download() => downloadUpdateFile(
        url: _asset(
          'kirakira-99.0.0-windows-x64-setup.exe',
        )['browser_download_url'],
        filePath: target,
        expectedHash: digest,
        cancelToken: CancelToken(),
        onReceiveProgress: (_, _) {},
      );
      expect(await download(), target);
      expect(await File(target).readAsBytes(), bytes);
      expect(await download(), target);
      expect(adapter.requests, hasLength(1));
      await File(target).writeAsString('damaged cache');
      expect(await download(), target);
      expect(adapter.requests, hasLength(2));
      expect(await File(target).readAsBytes(), bytes);
    },
  );

  test('rule catalog and version updates continue independently', () async {
    String? saved;
    final controller = PluginsController(
      pluginJsonWriter: (json) async => saved = json,
    );
    controller.pluginList.add(
      Plugin.fromJson({'name': 'sample', 'version': '1.0', 'api': '9'}),
    );
    await controller.refreshPluginCatalog();
    expect(
      await controller.tryUpdatePluginByName('sample'),
      PluginUpdateResult.updated,
    );
    expect((jsonDecode(saved!) as List).single['version'], '2.0');
    expect(adapter.requests.map((request) => request.uri.toString()), [
      '${ApiEndpoints.pluginShop}index.json',
      '${ApiEndpoints.pluginShop}sample.json',
    ]);
  });

  test('newer-client rules still require a compatible custom client', () async {
    final controller = PluginsController(
      pluginLoader: (_) async => Plugin.fromJson({
        'name': 'sample',
        'version': '3.0',
        'api': '${ApiEndpoints.apiLevel + 1}',
      }),
      pluginJsonWriter: (_) async =>
          fail('Incompatible rule must not be saved'),
    );
    expect(
      await controller.tryUpdatePluginByName('sample'),
      PluginUpdateResult.requiresNewerClient,
    );
    expect(adapter.requests, isEmpty);
  });

  testWidgets(
    'settings restores the application switch and saves it independently',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UpdateSettingsPage()));
      expect(find.text(UpdateChannel.notice), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(2));
      await tester.runAsync(() async {
        await tester.tap(find.byType(Switch).first);
        await Hive.box<dynamic>('setting').flush();
      });
      await tester.pumpAndSettle();
      expect(GStorage.getSetting(SettingsKeys.autoUpdate), isFalse);
      expect(
        GStorage.getSetting(SettingsKeys.checkPluginUpdateOnStartup),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('first launch describes own repository without upstream stores', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: UpdateSourceStep())),
    );
    expect(find.text(UpdateChannel.notice), findsOneWidget);
    expect(find.text('F-Droid'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('update dialog defaults to EXE and exposes no upstream mirror', (
    tester,
  ) async {
    final info = (await tester.runAsync(
      () => AutoUpdater().checkForUpdates(),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UpdateAvailableDialog(updateInfo: info)),
      ),
    );
    expect(find.text('GitHub · RUI-JACK/kirakira'), findsOneWidget);
    expect(find.text('镜像'), findsNothing);
    expect(find.text('EXE'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'LIVE: own latest-release endpoint is reachable before first release',
    () => HttpOverrides.runWithHttpOverrides(() async {
      DioFactory.reset();
      final urls = <String>[];
      DioFactory.downloadDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            urls.add(options.uri.toString());
            handler.next(options);
          },
        ),
      );
      await AutoUpdater().checkForUpdates();
      expect(urls, [ApiEndpoints.latestApp]);
      // ignore: avoid_print
      print(
        'LIVE custom update feed: ${urls.single}; ${AutoUpdater().noUpdateMessage}',
      );
    }, _LiveHttp()),
    skip: !const bool.fromEnvironment('RUN_LIVE_CUSTOM_UPDATE'),
  );
}

Map<String, dynamic> _asset(String name, {String tag = 'v99.0.0'}) => {
  'name': name,
  'browser_download_url': Uri(
    scheme: 'https',
    host: 'github.com',
    pathSegments: ['RUI-JACK', 'kirakira', 'releases', 'download', tag, name],
  ).toString(),
  'digest': 'sha256:${'a' * 64}',
};
Map<String, dynamic> _release({String tag = 'v99.0.0'}) => {
  'tag_name': tag, 'body': 'Custom release',
  // The client derives the project page instead of trusting this field.
  'html_url': 'https://github.com/Predidit/Kazumi/releases/latest',
  'assets': [
    _asset(
      'キラキラ-${UpdateChannel.versionNumber(tag) ?? '99.0.0'}-windows-x64-setup.exe',
      tag: tag,
    ),
    _asset(
      'キラキラ-${UpdateChannel.versionNumber(tag) ?? '99.0.0'}-windows-x64-portable.zip',
      tag: tag,
    ),
  ],
};

class _UpdateAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Map<String, dynamic> release = _release();
  List<int>? downloadBytes;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (downloadBytes != null &&
        options.uri.path.contains('/releases/download/')) {
      return ResponseBody.fromBytes(
        downloadBytes!,
        200,
        headers: {
          Headers.contentLengthHeader: ['${downloadBytes!.length}'],
        },
      );
    }
    final Object data;
    if (options.uri.path.endsWith('/index.json')) {
      data = [
        {
          'name': 'sample',
          'version': '2.0',
          'useNativePlayer': true,
          'author': 'test',
        },
      ];
    } else if (options.uri.path.endsWith('/sample.json')) {
      data = {'name': 'sample', 'version': '2.0', 'api': '9'};
    } else {
      data = release;
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
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
  Future<String?> getApplicationSupportPath() async => path;
}

class _LiveHttp extends HttpOverrides {}
