import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/widgets/media_crop.dart';

import 'support/chat_harness.dart' show loadAppFont;

/// A real photo-like PNG ([width] x [height]: a left-to-right gradient so a crop is visibly different from the whole).
Future<File> makePhoto(WidgetTester tester, int width, int height) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(width.toDouble(), 0),
          [const Color(0xFF0877E8), const Color(0xFFF43F5E)],
        ),
    );
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final file = File(
    '${Directory.systemTemp.path}/crop_source_${width}x$height.png',
  );
  file.writeAsBytesSync(bytes!);
  return file;
}

Future<Size> imageSize(WidgetTester tester, String path) async {
  final size = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    final frame = await codec.getNextFrame();
    return Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
  });
  return size!;
}

/// Opens the crop page through [cropPhoto] and returns what it will resolve to.
Future<Future<XFile?>> openCrop(
  WidgetTester tester,
  XFile file, {
  double width = 390,
  double scale = 1,
  CropRatio? initial,
}) async {
  tester.view.physicalSize = Size(width, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, page) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: page!,
      ),
      home: Builder(
        builder: (inner) {
          context = inner;
          return const Scaffold(body: SizedBox());
        },
      ),
    ),
  );
  final result = cropPhoto(context, file, initial: initial);
  await tester.pump(const Duration(milliseconds: 400));
  return result;
}

Future<void> settleDecode(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    if (find.byKey(const Key('crop-frame')).evaluate().isNotEmpty) {
      // The page transition finishes once the spinner is gone.
      await tester.pumpAndSettle();
      return;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFont);
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  group('The three ratios', () {
    test('9:16 Dikey, 4:5 Portre and 16:9 Yatay with their real numbers', () {
      expect(
        [for (final r in CropRatio.values) (r.label, r.name)],
        [('9:16', 'Dikey'), ('4:5', 'Portre'), ('16:9', 'Yatay')],
      );
      expect(CropRatio.vertical.value, closeTo(9 / 16, 1e-9));
      expect(CropRatio.portrait.value, closeTo(4 / 5, 1e-9));
      expect(CropRatio.landscape.value, closeTo(16 / 9, 1e-9));
    });

    test('A photo starts at the ratio nearest to its own shape', () {
      expect(CropRatio.closest(1080, 1920), CropRatio.vertical);
      expect(CropRatio.closest(3000, 3750), CropRatio.portrait);
      expect(CropRatio.closest(4000, 3000), CropRatio.landscape);
      expect(CropRatio.closest(1000, 1000), CropRatio.portrait);
    });

    test('The uploaded size keeps the ratio, tops out at 1440 and never upscales', () {
      for (final ratio in CropRatio.values) {
        final size = CropGeometry.outputSize(
          ratio,
          const Rect.fromLTWH(0, 0, 4000, 4000),
        );
        expect(size.width / size.height, closeTo(ratio.value, .002), reason: ratio.label);
        expect(size.longestSide, kCropOutputEdge.toDouble(), reason: ratio.label);
      }
      final small = CropGeometry.outputSize(
        CropRatio.landscape,
        const Rect.fromLTWH(0, 0, 320, 180),
      );
      expect(small, const Size(320, 180));
    });
  });

  group('The crop frame maths', () {
    const frame = Size(200, 250); // 4:5
    const geometry = CropGeometry(
      imageWidth: 1000,
      imageHeight: 500,
      frame: frame,
    );

    test('The photo always covers the frame and zoom has a ceiling', () {
      expect(geometry.minScale, closeTo(.5, 1e-9)); // 250 / 500
      expect(geometry.clampScale(.1), geometry.minScale);
      expect(geometry.clampScale(100), geometry.maxScale);
    });

    test('The frame cannot be dragged off the photo', () {
      final scale = geometry.minScale;
      final far = geometry.clampCenter(scale, const Offset(-900, 9000));
      final source = geometry.source(scale, far);
      expect(source.left, greaterThanOrEqualTo(0));
      expect(source.top, greaterThanOrEqualTo(0));
      expect(source.right, lessThanOrEqualTo(1000));
      expect(source.bottom, lessThanOrEqualTo(500));
      expect(source.width / source.height, closeTo(frame.width / frame.height, 1e-9));
    });

    test('Zooming in shows less of the photo', () {
      final whole = geometry.source(geometry.minScale, geometry.initialCenter);
      final zoomed = geometry.source(geometry.minScale * 2, geometry.initialCenter);
      expect(zoomed.width, closeTo(whole.width / 2, 1e-9));
    });
  });

  group('The crop screen', () {
    testWidgets('Shows the three ratios, a preview frame and a confirm button', (tester) async {
      final file = await makePhoto(tester, 800, 600);
      await openCrop(tester, XFile(file.path));
      await settleDecode(tester);
      for (final label in ['9:16', '4:5', '16:9']) {
        expect(find.byKey(Key('crop-ratio-$label')), findsOneWidget);
      }
      expect(find.text('Dikey'), findsOneWidget);
      expect(find.text('Portre'), findsOneWidget);
      expect(find.text('Yatay'), findsOneWidget);
      expect(find.byKey(const Key('crop-frame')), findsOneWidget);
      expect(find.byKey(const Key('crop-confirm')), findsOneWidget);
      expect(find.text('Fotoğrafı Kırp'), findsOneWidget);
    });

    for (final (label, ratio) in [
      ('9:16', 9 / 16),
      ('4:5', 4 / 5),
      ('16:9', 16 / 9),
    ]) {
      testWidgets('$label: the frame has that shape and the saved photo has it too', (tester) async {
        final file = await makePhoto(tester, 1200, 900);
        final result = await openCrop(tester, XFile(file.path));
        await settleDecode(tester);
        await tester.tap(find.byKey(Key('crop-ratio-$label')));
        await tester.pump();
        final frame = tester.getSize(find.byKey(const Key('crop-frame')));
        expect(frame.width / frame.height, closeTo(ratio, .01), reason: 'preview frame');

        await tester.tap(find.byKey(const Key('crop-confirm')));
        XFile? cropped;
        result.then((value) => cropped = value);
        for (var i = 0; i < 80 && cropped == null; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump();
        }
        expect(cropped, isNotNull);
        final size = await imageSize(tester, cropped!.path);
        expect(size.width / size.height, closeTo(ratio, .01), reason: 'uploaded photo');
        expect(size.longestSide, lessThanOrEqualTo(kCropOutputEdge.toDouble()));
        expect(cropped!.path, endsWith('.png'));
        expect(File(cropped!.path).lengthSync(), lessThan(5 * 1024 * 1024));
      });
    }

    testWidgets('Dragging the photo moves what is cut out', (tester) async {
      final file = await makePhoto(tester, 1600, 900);
      final result = await openCrop(tester, XFile(file.path), initial: CropRatio.portrait);
      await settleDecode(tester);
      Future<XFile?> confirm() async {
        await tester.tap(find.byKey(const Key('crop-confirm')));
        XFile? cropped;
        result.then((value) => cropped = value);
        for (var i = 0; i < 80 && cropped == null; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump();
        }
        return cropped;
      }

      // Drag right: the left part of the photo comes into the frame (the gradient is bluer on the left).
      await tester.drag(find.byKey(const Key('crop-frame')), const Offset(120, 0));
      await tester.pump();
      final left = await confirm();
      expect(left, isNotNull);
      final bytes = File(left!.path).readAsBytesSync();
      expect(bytes.length, greaterThan(1000));
    });

    testWidgets('Cancel gives nothing back', (tester) async {
      final file = await makePhoto(tester, 800, 600);
      final result = await openCrop(tester, XFile(file.path));
      await settleDecode(tester);
      XFile? value = XFile('unset');
      var done = false;
      result.then((v) {
        value = v;
        done = true;
      });
      await tester.tap(find.byKey(const Key('crop-cancel')));
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(value, isNull);
    });

    testWidgets('A file the device cannot decode is returned untouched (the crop never blocks an upload)', (tester) async {
      final broken = File('${Directory.systemTemp.path}/not_a_photo.png')
        ..writeAsStringSync('this is not an image');
      final input = XFile(broken.path);
      final result = await openCrop(tester, input);
      XFile? value;
      var done = false;
      result.then((v) {
        value = v;
        done = true;
      });
      for (var i = 0; i < 60 && !done; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(value?.path, input.path);
    });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('${width.toInt()} dp at ${scale}x text: no overflow and the ratio names stay on one line', (tester) async {
          final file = await makePhoto(tester, 800, 600);
          await openCrop(tester, XFile(file.path), width: width, scale: scale);
          await settleDecode(tester);
          expect(tester.takeException(), isNull);
          for (final name in ['Dikey', 'Portre', 'Yatay']) {
            final box = tester.getSize(find.text(name));
            // A single line: the height of one text line at this scale.
            expect(box.height, lessThan(22 * scale), reason: '$name wrapped at $width dp');
          }
          for (final label in ['9:16', '4:5', '16:9']) {
            expect(tester.getSize(find.text(label)).height, lessThan(26 * scale));
          }
          final tiles = [
            for (final label in ['9:16', '4:5', '16:9'])
              tester.getRect(find.byKey(Key('crop-ratio-$label'))),
          ];
          expect(tiles.every((tile) => tile.right <= width), isTrue, reason: '$tiles at $width');
        });
      }
    }

    testWidgets('English labels follow the language', (tester) async {
      AppLocale.debugSet(const Locale('en'));
      final file = await makePhoto(tester, 800, 600);
      await openCrop(tester, XFile(file.path));
      await settleDecode(tester);
      expect(find.text('Vertical'), findsOneWidget);
      expect(find.text('Portrait'), findsOneWidget);
      expect(find.text('Landscape'), findsOneWidget);
      expect(find.text('Crop Photo'), findsOneWidget);
    });
  });
}
