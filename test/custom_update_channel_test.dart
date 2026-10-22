import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/pages/onboarding/steps/update_source_step.dart';
import 'package:kazumi/pages/settings/update_settings.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/update/auto_updater.dart';
import 'package:kazumi/services/update/update_channel.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    // Reproduce a preference saved by the previous custom package.
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
    expect(directory.absolute.path.startsWith(Directory.systemTemp.absolute.path), isTrue);
    expect(directory.uri.pathSegments.where((p) => p.isNotEmpty).last, startsWith('kirakira_update_test_'));
    await directory.delete(recursive: true);
  });

  test('old enabled preference cannot request or offer an upstream application', () async {
    final updater = AutoUpdater();
    expect(await updater.checkForUpdates(), isNull);
    await updater.autoCheckForUpdates();
    expect(adapter.requests, isEmpty);
    expect(GStorage.getSetting(SettingsKeys.autoUpdate), isTrue);
  });

  test('rule catalog and rule version updates continue independently', () async {
    String? saved;
    final controller = PluginsController(pluginJsonWriter: (json) async => saved = json);
    controller.pluginList.add(Plugin.fromJson({'name':'sample','version':'1.0','api':'9'}));
    await controller.refreshPluginCatalog();
    expect(await controller.tryUpdatePluginByName('sample'), PluginUpdateResult.updated);
    expect(controller.pluginList.single.version, '2.0');
    expect((jsonDecode(saved!) as List).single['version'], '2.0');
    expect(adapter.requests.map((request) => request.uri.toString()), [
      '${ApiEndpoints.pluginShop}index.json', '${ApiEndpoints.pluginShop}sample.json',
    ]);
    expect(GStorage.getSetting(SettingsKeys.checkPluginUpdateOnStartup), isTrue);
    expect(await AutoUpdater().checkForUpdates(), isNull);
    expect(adapter.requests, hasLength(2));
  });

  test('newer-client rule remains blocked rather than installing upstream app', () async {
    final controller = PluginsController(
      pluginLoader: (_) async => Plugin.fromJson({'name':'sample','version':'3.0','api':'${ApiEndpoints.apiLevel + 1}'}),
      pluginJsonWriter: (_) async => fail('Incompatible rule must not be saved'),
    );
    expect(await controller.tryUpdatePluginByName('sample'), PluginUpdateResult.requiresNewerClient);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('settings keeps only the rule update switch, even for old preferences', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UpdateSettingsPage()));
    expect(find.text(UpdateChannel.notice), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('规则更新'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('first launch describes custom updates without offering upstream stores', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UpdateSourceStep())));
    expect(find.text(UpdateChannel.title), findsOneWidget);
    expect(find.text(UpdateChannel.notice), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);
    expect(find.text('F-Droid'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _UpdateAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async {
    requests.add(options);
    final Object data;
    if (options.uri.path.endsWith('/index.json')) {
      data = [{'name':'sample','version':'2.0','useNativePlayer':true,'author':'test'}];
    } else if (options.uri.path.endsWith('/sample.json')) {
      data = {'name':'sample','version':'2.0','api':'9'};
    } else {
      // Before the fix this advertises a newer original Kazumi package.
      data = {'tag_name':'99.0.0','assets':[{'name':'Kazumi_android_99.0.0.apk','browser_download_url':'https://example.invalid/original.apk'}]};
    }
    return ResponseBody.fromString(jsonEncode(data),200,
      headers:{Headers.contentTypeHeader:[Headers.jsonContentType]});
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
