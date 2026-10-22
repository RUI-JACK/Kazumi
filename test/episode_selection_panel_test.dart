import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/video/episode_selection_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('MI_Sans_Regular')
          ..addFont(rootBundle.load('assets/fonts/MiSans-Regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets('separate number labels retain original titles and selection',
      (tester) async {
    final road = Road(
      name: '线路一',
      data: ['/one', '/two'],
      identifier: ['冒险的开始', '新的旅程'],
    );
    (int, int)? selection;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EpisodeSelectionPanel(
          title: '选集',
          roads: [road],
          selectedRoad: 0,
          selectedEpisode: 1,
          downloads: const {},
          disableAnimations: true,
          onEpisodeSelected: (episode, road) => selection = (episode, road),
        ),
      ),
    ));
    expect(find.text('第1集'), findsOneWidget);
    expect(find.text('第2集'), findsOneWidget);
    expect(find.text('冒险的开始'), findsOneWidget);
    expect(find.text('第2集 · 新的旅程'), findsNothing);
    await tester.tap(find.text('新的旅程'));
    await tester.pumpAndSettle();
    expect(selection, (2, 0));
    expect(road.identifier, ['冒险的开始', '新的旅程']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source numbering and special episode names remain intact',
      (tester) async {
    const names = ['第13话 归来', 'EP 14 Reunion', '12.5 总集篇', 'OVA', '第三集', ''];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EpisodeSelectionPanel(
          title: '选集',
          roads: [Road(name: '线路', data: List.filled(6, '/ep'), identifier: names)],
          selectedRoad: 0,
          selectedEpisode: 1,
          downloads: const {},
          disableAnimations: true,
          onEpisodeSelected: (_, _) {},
        ),
      ),
    ));
    for (final name in names.where((name) => name.isNotEmpty)) {
      expect(find.text(name), name == '第三集' ? findsNWidgets(2) : findsOneWidget);
    }
    expect(find.text('第13集'), findsOneWidget);
    expect(find.text('第14集'), findsOneWidget);
    expect(find.text('第12.5集'), findsOneWidget);
    expect(find.text('第6集'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline subset shows cached episode numbers, not list positions',
      (tester) async {
    (int, int)? selection;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EpisodeSelectionPanel(
          title: '缓存选集',
          roads: [Road(name: '缓存', data: ['3', '12'], identifier: ['重逢', '终点'])],
          selectedRoad: 0,
          selectedEpisode: 1,
          downloads: const {},
          isOffline: true,
          disableAnimations: true,
          onEpisodeSelected: (episode, road) => selection = (episode, road),
        ),
      ),
    ));
    expect(find.text('第3集'), findsOneWidget);
    expect(find.text('重逢'), findsOneWidget);
    expect(find.text('第12集'), findsOneWidget);
    await tester.tap(find.text('终点'));
    await tester.pumpAndSettle();
    expect(selection, (2, 0));
    expect(tester.takeException(), isNull);
  });

  for (final width in [280.0, 420.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('panel fits $width px in $brightness with enlarged text',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final boundary = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness, fontFamily: 'MI_Sans_Regular'),
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 800), textScaler: const TextScaler.linear(1.4)),
            child: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: EpisodeSelectionPanel(
                  title: '剧集列表',
                  roads: [Road(
                    name: '播放线路一',
                    data: ['/1', '/2', '/3', '/4'],
                    identifier: ['冒险的开始', '一个很长的剧集标题也应该能正常显示而不会挤出选集面板', '第03集', '再见，远方的朋友'],
                  )],
                  selectedRoad: 0,
                  selectedEpisode: 2,
                  downloads: const {},
                  isPlaying: true,
                  disableAnimations: true,
                  onEpisodeSelected: (_, _) {},
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('第1集'), findsOneWidget);
        expect(find.text('冒险的开始'), findsOneWidget);
        expect(tester.takeException(), isNull);
        const output = String.fromEnvironment('EPISODE_SCREENSHOT_DIR');
        if (output.isNotEmpty) {
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            Directory(output).createSync(recursive: true);
            File('$output/panel-${width.toInt()}-${brightness.name}.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
