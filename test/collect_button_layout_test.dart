import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/theme/little_prince_theme.dart';

class _UnusedRepository implements ICollectCrudRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCollectController extends CollectController {
  _TestCollectController() : super(_UnusedRepository());
  int selectedType = 0;

  @override
  int getCollectType(BangumiItem bangumiItem) => selectedType;

  @override
  Future<void> addCollect(BangumiItem bangumiItem, {type = 1}) async {
    selectedType = type as int;
  }
}

BangumiItem _item() => BangumiItem(
  id: 1,
  type: 2,
  name: '收藏按钮布局检查',
  nameCn: '收藏按钮布局检查',
  summary: '',
  airDate: '2026-10-04',
  airWeekday: 0,
  rank: 6003,
  images: {},
  tags: [],
  alias: [],
  ratingScore: 6.3,
  votes: 4622,
  votesCount: [2, 0, 2, 3, 10, 50, 38, 6, 2, 2],
  info: '',
);

Future<GlobalKey> _mount(
  WidgetTester tester,
  Size size,
  Brightness brightness,
  double scale,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = _TestCollectController();
  final bootstrap = bootstrapModule(
    createModule(register: (c) => c.addInstance<CollectController>(controller)),
  );
  addTearDown(bootstrap.injector.dispose);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: styleLittlePrinceTheme(
        ThemeData(
          colorScheme: littlePrinceColorScheme(brightness),
          fontFamily: 'MI_Sans_Regular',
          platform: TargetPlatform.android,
        ),
      ),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BangumiInfoCardV(
                  bangumiItem: _item(),
                  isLoading: false,
                  showRating: true,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return boundary;
}

void _expectCompleteLabel(WidgetTester tester, String label) {
  final button = find.descendant(
    of: find.byType(CollectButton),
    matching: find.byType(FilledButton),
  );
  final text = find.descendant(of: button, matching: find.text(label));
  expect(text, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
  )..layout(maxWidth: paragraph.size.width);
  expect(
    paragraph.size.height + 0.01,
    greaterThanOrEqualTo(painter.height),
    reason: '$label must retain its full font line height',
  );
  expect(paragraph.didExceedMaxLines, isFalse);
  painter.dispose();
  final bounds = tester.getRect(button), labelBounds = tester.getRect(text);
  expect(bounds.contains(labelBounds.topLeft), isTrue);
  expect(
    bounds.contains(labelBounds.bottomRight - const Offset(0.01, 0.01)),
    isTrue,
  );
  expect(tester.takeException(), isNull);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  const output = String.fromEnvironment('COLLECT_SCREENSHOT_DIR');
  if (output.isEmpty) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(output).createSync(recursive: true);
    File('$output/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MI_Sans_Regular',
    )..addFont(rootBundle.load('assets/fonts/MiSans-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('tablet button contains its complete text', (tester) async {
    final boundary = await _mount(
      tester,
      const Size(1200, 850),
      Brightness.light,
      1,
    );
    await _capture(tester, boundary, 'tablet-light');
    _expectCompleteLabel(tester, '未追');
  });

  for (final width in [390.0, 768.0, 1200.0]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('all collect labels fit $width $brightness scale $scale', (
          tester,
        ) async {
          final boundary = await _mount(
            tester,
            Size(width, 850),
            brightness,
            scale,
          );
          _expectCompleteLabel(tester, '未追');
          for (final type in CollectType.values.where(
            (t) => t != CollectType.none,
          )) {
            await tester.tap(find.byType(FilledButton));
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(MenuItemButton, type.label));
            await tester.pumpAndSettle();
            _expectCompleteLabel(tester, type.label);
          }
          if (scale == 2) {
            await _capture(
              tester,
              boundary,
              '${width.toInt()}-${brightness.name}-large',
            );
          }
        });
      }
    }
  }
}
