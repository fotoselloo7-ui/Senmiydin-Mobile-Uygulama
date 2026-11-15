import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/data/share_renderer.dart';
import 'package:senmiydin/data/share_service.dart';
import 'package:senmiydin/widgets/share_card.dart';

import 'support/chat_harness.dart' show loadAppFont;

/// PNG chunk names in order.
List<String> pngChunks(Uint8List bytes) {
  final chunks = <String>[];
  var offset = 8;
  final data = ByteData.sublistView(bytes);
  while (offset + 8 <= bytes.length) {
    final length = data.getUint32(offset);
    chunks.add(String.fromCharCodes(bytes.sublist(offset + 4, offset + 8)));
    offset += 12 + length;
  }
  return chunks;
}

Future<ui.Image> asset(String path) async {
  final data = await rootBundle.load(path);
  return decodeShareImage(data.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFont);
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  /// Set SHARE_CARD_OUT=docs/screenshots/ui-audit to write the rendered cards there (documentation screenshots).
  final out = Platform.environment['SHARE_CARD_OUT'];

  Future<ShareCardData> data(
    ShareCardKind kind, {
    String body = 'Sahilde yürürken seni gördüm, selam! 🌊 Kırmızı montlu kız, yarın aynı yerde olur musun?',
    bool anonymous = false,
    bool photo = false,
    String name = 'Ece Test',
    String? pair,
    String kindLabel = 'Anı',
    String place = 'Alanya',
    String cta = "SenMiydin?'de gör",
    String continueLabel = "Devamını SenMiydin?'de gör",
    String anonymousLabel = 'Anonim',
  }) async => ShareCardData(
    kind: kind,
    kindLabel: kindLabel,
    body: body,
    dateLabel: '15 Kasım 2026',
    placeLabel: place,
    url: 'https://senmiydin.tr/p/ab12cd34ef56',
    cta: cta,
    continueLabel: continueLabel,
    logo: await asset('assets/brand/logo_header_light.png'),
    anonymous: anonymous,
    anonymousLabel: anonymousLabel,
    authorName: anonymous || pair != null ? null : name,
    handle: anonymous || pair != null ? null : 'ece',
    avatar: anonymous || pair != null ? null : await asset('assets/images/user_0.jpg'),
    pairNames: pair,
    pairAvatars: pair == null ? const [] : [await asset('assets/images/user_0.jpg'), await asset('assets/images/coffee.jpg')],
    badge: pair == null ? null : 'Karşılaşıldı',
    photo: photo ? await asset('assets/images/coast.jpg') : null,
  );

  Future<Uint8List> render(WidgetTester tester, ShareCardData card, ShareCardFormat format) async {
    final bytes = (await tester.runAsync(() => renderShareCard(card, format)))!;
    expect(tester.takeException(), isNull);
    return bytes;
  }

  Future<ui.Image> decoded(WidgetTester tester, Uint8List bytes) async => (await tester.runAsync(() => decodeShareImage(bytes)))!;

  final scenarios = <String, Future<ShareCardData> Function()>{
    'text': () => data(ShareCardKind.post),
    'photo': () => data(ShareCardKind.post, photo: true),
    'anonymous': () => data(ShareCardKind.post, anonymous: true, kindLabel: 'İtiraf', body: 'İtiraf: bu şehirde kimse bilmiyor ama her sabah aynı kafede seni görüyorum.'),
    'encounter': () => data(ShareCardKind.encounter, pair: 'Demo Kullanıcı & Elif B.', kindLabel: 'Karşılaşma', body: 'Deniz kenarında yürürken yeniden karşılaştık. Yarım kalan merhaba sonunda tamamlandı. ☕'),
    'map-note': () => data(ShareCardKind.mapNote, kindLabel: 'Harita Notu', place: 'Alanya · Yaklaşık bölge', body: 'Sahilde gördüm seni, yarın yine buradayım.', photo: true),
  };

  for (final entry in scenarios.entries) {
    testWidgets('The ${entry.key} card renders at exactly 1080x1920 (story) and 1080x1350 (card) with no metadata', (tester) async {
      final card = await tester.runAsync(entry.value) as ShareCardData;
      for (final format in ShareCardFormat.values) {
        final bytes = await render(tester, card, format);
        final image = await decoded(tester, bytes);
        expect(image.width, format == ShareCardFormat.story ? 1080 : 1080);
        expect(image.height, format == ShareCardFormat.story ? 1920 : 1350);
        final chunks = pngChunks(bytes);
        expect(chunks.first, 'IHDR');
        expect(chunks.last, 'IEND');
        expect(chunks.toSet().intersection({'eXIf', 'tEXt', 'iTXt', 'zTXt', 'gAMA', 'iCCP', 'tIME'}), isEmpty, reason: 'No EXIF/GPS or any text metadata in the generated image: $chunks');
        if (out != null) {
          Directory(out).createSync(recursive: true);
          File('$out/share-card-${entry.key}${format == ShareCardFormat.story ? '' : '-portrait'}.png').writeAsBytesSync(bytes);
        }
      }
    });
  }

  testWidgets('A very long post, long names, emoji, Turkish letters and English texts never overflow either format', (tester) async {
    final long = '${'Çok uzun bir paylaşım: şiirler, ğüşiöç ve emoji 😀🌊👍🏽 '.padRight(60)}${'metin ' * 120}';
    for (final locale in ['tr', 'en']) {
      AppLocale.debugSet(Locale(locale));
      final card = (await tester.runAsync(() => data(
        ShareCardKind.post,
        body: long,
        photo: true,
        name: 'Çok Uzun Bir Kullanıcı Adı Soyadı Ve Daha Da Uzun Bir Şey',
        kindLabel: locale == 'tr' ? 'Düşünce' : 'Thought',
        cta: locale == 'tr' ? "SenMiydin?'de gör" : 'View on SenMiydin?',
        continueLabel: locale == 'tr' ? "Devamını SenMiydin?'de gör" : 'Continue on SenMiydin?',
      )))!;
      for (final format in ShareCardFormat.values) {
        await render(tester, card, format);
      }
    }
    final empty = (await tester.runAsync(() => data(ShareCardKind.post, body: '', photo: true)))!;
    await render(tester, empty, ShareCardFormat.story);
  });

  test('Text fitting: a short post is set big, a long one smaller, and an enormous one is cut with the continue line', () {
    final short = fitShareText('Merhaba', 280, 250);
    final medium = fitShareText('uzun ' * 40, 280, 250);
    final huge = fitShareText('uzun ' * 400, 280, 250);
    expect(short.size, 30);
    expect(medium.size, lessThan(short.size));
    expect(medium.truncated, isFalse);
    expect(huge.truncated, isTrue);
    expect(huge.size, 15);
    expect(huge.maxLines, greaterThan(2));
  });

  test('The share date follows the sharing person’s language, not the viewer’s', () {
    final date = DateTime(2026, 11, 15);
    expect(shareDateLabel(date), '15 Kasım 2026');
    AppLocale.debugSet(const Locale('en'));
    expect(shareDateLabel(date), 'November 15, 2026');
    expect(shareDateLabel(null), '');
  });
}
