import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show Locale, Rect;

import 'package:flutter/material.dart' hide Locale;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/deep_links.dart';
import 'package:senmiydin/data/map_notes_api.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/data/share_service.dart';
import 'package:senmiydin/widgets/share_card.dart';
import 'package:senmiydin/widgets/share_sheet.dart';

import 'global_release_test.dart' show host;
import 'support/chat_harness.dart' show loadAppFont;

class FakeSharePlatform implements SharePlatform {
  FakeSharePlatform({this.instagram = false, this.instagramWorks = true, this.failShare = false});
  bool instagram, instagramWorks, failShare;
  final copied = <String>[];
  final texts = <String>[];
  final images = <String>[];
  final imageTexts = <String>[];
  final stories = <String>[];

  @override
  Future<void> copyText(String text) async => copied.add(text);
  @override
  Future<void> shareText(String text, {Rect? origin}) async {
    if (failShare) throw PlatformException(code: 'share');
    texts.add(text);
  }

  @override
  Future<void> shareImage(String path, {required String text, Rect? origin}) async {
    if (failShare) throw PlatformException(code: 'share');
    images.add(path);
    imageTexts.add(text);
  }

  @override
  Future<bool> canShareToInstagramStory() async => instagram;
  @override
  Future<bool> shareToInstagramStory(String path) async {
    stories.add(path);
    return instagramWorks;
  }
}

Future<Uint8List> pngBytes(String path) async => (await rootBundle.load(path)).buffer.asUint8List();

Future<ui.Image> decodeFile(String path) => decodeShareImage(File(path).readAsBytesSync());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFont);
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  late Directory work;
  late FakeSharePlatform platform;
  late ShareService service;
  final requestedUrls = <String>[];

  setUp(() {
    work = Directory.systemTemp.createTempSync('senmiydin_share_test');
    platform = FakeSharePlatform();
    requestedUrls.clear();
    service = ShareService(
      platform: platform,
      workDirectory: () async => work,
      loader: (url, headers) async {
        requestedUrls.add(url);
        return pngBytes('assets/images/coast.jpg');
      },
    );
  });
  tearDown(() {
    if (work.existsSync()) work.deleteSync(recursive: true);
  });

  Post post({String? shareUrl = 'https://senmiydin.tr/p/ab12cd34ef56', bool anonymous = false, List<String> images = const [], String? storyStatus, List<Person> participants = const []}) {
    final item = Post(
      id: '7',
      authorId: AppStore().people[1].id,
      text: 'Sahilde yürürken seni gördüm 🌊',
      anonymous: anonymous,
      images: images,
      createdAt: DateTime(2026, 11, 14, 10),
      city: 'Alanya',
      storyStatus: storyStatus,
      storyParticipants: participants,
      shareUrl: shareUrl,
      remote: true,
    );
    return item;
  }

  MapNoteItem note({bool anonymous = false, String? shareUrl = 'https://senmiydin.tr/n/zz12zz34zz56', String? image}) => MapNoteItem.fromJson({
    'id': 3,
    'body': 'Kırmızı montlu kız, yarın aynı yerde.',
    'is_anonymous': anonymous,
    'mine': false,
    'author': anonymous ? null : {'id': 7, 'username': 'ada', 'name': 'Ada Test', 'avatar': null},
    'city': {'id': 1, 'name': 'Alanya', 'slug': 'alanya'},
    'place_label': 'Alanya · Yaklaşık bölge',
    'group': '36.54500_32.00000',
    'latitude': 36.545,
    'longitude': 32.0,
    'reply_count': 0,
    'can_reply': true,
    'created_at': '2026-11-14T11:15:00Z',
    'expires_at': '2026-11-21T11:15:00Z',
    'share_url': shareUrl,
    'image': image,
  }, (json) => Person(id: 'account-7', name: json['name'] as String, handle: json['username'] as String, photo: '', remote: true));

  group('Share links the app is opened with', () {
    final hosts = {'senmiydin.tr', 'www.senmiydin.tr'};
    test('Only https links on the website host with the exact /p/<id> or /n/<id> shape are accepted', () {
      expect(parseShareLink(Uri.parse('https://senmiydin.tr/p/ab12cd34ef56'), hosts: hosts), const ShareLink('p', 'ab12cd34ef56'));
      expect(parseShareLink(Uri.parse('https://www.senmiydin.tr/n/zz12zz34zz56/'), hosts: hosts), const ShareLink('n', 'zz12zz34zz56'));
      for (final bad in [
        'http://senmiydin.tr/p/ab12cd34ef56',
        'https://evil.example/p/ab12cd34ef56',
        'https://senmiydin.tr.evil.example/p/ab12cd34ef56',
        'https://senmiydin.tr/p/AB12CD34EF56',
        'https://senmiydin.tr/p/short',
        'https://senmiydin.tr/p/ab12cd34ef56/extra',
        'https://senmiydin.tr/admin/ab12cd34ef56',
        'https://senmiydin.tr/',
        'senmiydin://p/ab12cd34ef56',
      ]) {
        expect(parseShareLink(Uri.parse(bad), hosts: hosts), isNull, reason: bad);
      }
    });
  });

  group('Card data: only public content, nothing identifying for anonymous items', () {
    testWidgets('A public text post gets the author, the link and the sharing person’s language', (tester) async {
      final store = AppStore();
      final card = (await tester.runAsync(() => service.postCard(post(), store)))!;
      expect(card.kind, ShareCardKind.post);
      expect(card.authorName, store.people[1].name);
      expect(card.url, 'https://senmiydin.tr/p/ab12cd34ef56');
      expect(card.cta, "SenMiydin?'de gör");
      expect(card.photo, isNull);
      AppLocale.debugSet(const Locale('en'));
      final english = (await tester.runAsync(() => service.postCard(post(), store)))!;
      expect(english.cta, 'View on SenMiydin?');
      expect(english.continueLabel, 'Continue on SenMiydin?');
      expect(english.dateLabel, 'November 14, 2026');
      expect(english.body, 'Sahilde yürürken seni gördüm 🌊', reason: 'The person’s own words are never translated.');
    });

    testWidgets('An anonymous post carries no name, handle or avatar, even though the app knows the author', (tester) async {
      final store = AppStore();
      final card = (await tester.runAsync(() => service.postCard(post(anonymous: true), store)))!;
      expect(card.anonymous, isTrue);
      expect(card.anonymousLabel, 'Anonim');
      expect(card.authorName, isNull);
      expect(card.handle, isNull);
      expect(card.avatar, isNull);
      expect(card.pairNames, isNull);
      expect(card.pairAvatars, isEmpty);
      // The avatar of the real author is never even downloaded.
      expect(requestedUrls, isEmpty);
    });

    testWidgets('The first photo only is used and fetched; a missing photo just leaves it out', (tester) async {
      final store = AppStore();
      final many = post(images: ['https://api.senmiydin.tr/api/v1/post-media/1', 'https://api.senmiydin.tr/api/v1/post-media/2', 'https://api.senmiydin.tr/api/v1/post-media/3']);
      final card = (await tester.runAsync(() => service.postCard(many, store)))!;
      expect(card.photo, isNotNull);
      expect(requestedUrls.where((url) => url.contains('post-media')), ['https://api.senmiydin.tr/api/v1/post-media/1']);
      final failing = ShareService(platform: platform, workDirectory: () async => work, loader: (url, headers) async => null);
      final without = (await tester.runAsync(() => failing.postCard(many, store)))!;
      expect(without.photo, isNull);
    });

    testWidgets('A post without a public link (private, teen, removed) cannot become a card at all', (tester) async {
      final store = AppStore();
      await tester.runAsync(() async {
        await expectLater(service.postCard(post(shareUrl: null), store), throwsStateError);
        await expectLater(service.noteCard(note(shareUrl: null), store), throwsStateError);
      });
    });

    testWidgets('A confirmed, published encounter story shows both people and the badge; an unconfirmed one is an ordinary post', (tester) async {
      final store = AppStore();
      final pair = [store.people[1], store.people[2]];
      final published = (await tester.runAsync(() => service.postCard(post(storyStatus: 'published', participants: pair), store)))!;
      expect(published.kind, ShareCardKind.encounter);
      expect(published.badge, 'Karşılaşıldı');
      expect(published.pairNames, '${pair[0].name} & ${pair[1].name}');
      final pending = (await tester.runAsync(() => service.postCard(post(storyStatus: 'pending', participants: pair), store)))!;
      expect(pending.kind, ShareCardKind.post);
      expect(pending.badge, isNull);
    });

    testWidgets('A Map Note card has the approximate area label and no coordinate anywhere; anonymous notes have no identity', (tester) async {
      final store = AppStore();
      final open = (await tester.runAsync(() => service.noteCard(note(), store)))!;
      expect(open.kind, ShareCardKind.mapNote);
      expect(open.placeLabel, 'Alanya · Yaklaşık bölge');
      expect(open.authorName, 'Ada Test');
      final text = [open.body, open.placeLabel, open.dateLabel, open.url, open.kindLabel].join(' ');
      expect(text, isNot(contains('36.5')));
      expect(text, isNot(contains('32.0')));
      final anonymous = (await tester.runAsync(() => service.noteCard(note(anonymous: true), store)))!;
      expect(anonymous.anonymous, isTrue);
      expect(anonymous.authorName, isNull);
      expect(anonymous.handle, isNull);
      expect(anonymous.avatar, isNull);
    });
  });

  group('Share targets', () {
    Future<ShareCardData> card(WidgetTester tester) async => (await tester.runAsync(() => service.postCard(post(), AppStore())))!;

    testWidgets('Copy link and Other need no picture: the link goes to the clipboard / the share sheet as text', (tester) async {
      final data = await card(tester);
      await tester.runAsync(() async {
        await service.share(ShareTarget.link, data);
        await service.share(ShareTarget.other, data);
      });
      expect(platform.copied, [data.url]);
      expect(platform.texts, [data.url]);
      expect(work.listSync(), isEmpty, reason: 'No card is rendered for a plain link.');
    });

    testWidgets('"Görsel Kart" shares a 1080x1350 PNG with the link as text', (tester) async {
      final data = await card(tester);
      await tester.runAsync(() => service.share(ShareTarget.card, data));
      expect(platform.images, hasLength(1));
      expect(platform.imageTexts, [data.url]);
      final image = (await tester.runAsync(() => decodeFile(platform.images.single)))!;
      expect([image.width, image.height], [1080, 1350]);
    });

    testWidgets('"Hikâyede Paylaş" hands a 1080x1920 PNG straight to Instagram when it can', (tester) async {
      platform.instagram = true;
      final data = await card(tester);
      await tester.runAsync(() => service.share(ShareTarget.story, data));
      expect(platform.stories, hasLength(1));
      expect(platform.images, isEmpty);
      final image = (await tester.runAsync(() => decodeFile(platform.stories.single)))!;
      expect([image.width, image.height], [1080, 1920]);
    });

    testWidgets('Without Instagram (or when its hand-off fails) the normal share sheet gets the same Story image', (tester) async {
      final data = await card(tester);
      await tester.runAsync(() => service.share(ShareTarget.story, data));
      expect(platform.stories, isEmpty);
      expect(platform.images, hasLength(1));
      platform
        ..instagram = true
        ..instagramWorks = false;
      await tester.runAsync(() => service.share(ShareTarget.story, data));
      expect(platform.stories, hasLength(1));
      expect(platform.images, hasLength(2));
      final image = (await tester.runAsync(() => decodeFile(platform.images.last)))!;
      expect([image.width, image.height], [1080, 1920]);
    });

    testWidgets('Old cards are swept before a new one is written; fresh ones stay for the app that is still reading them', (tester) async {
      final stale = File('${work.path}/senmiydin_story_1.png')..writeAsBytesSync([1]);
      stale.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 3)));
      final fresh = File('${work.path}/senmiydin_story_2.png')..writeAsBytesSync([1]);
      final foreign = File('${work.path}/someone_elses.txt')..writeAsStringSync('x');
      final data = await card(tester);
      await tester.runAsync(() => service.share(ShareTarget.card, data));
      expect(stale.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
      expect(foreign.existsSync(), isTrue, reason: 'Only the files this service wrote are touched.');
      await tester.runAsync(service.cleanUp);
      expect(fresh.existsSync(), isFalse);
      expect(foreign.existsSync(), isTrue);
    });
  });

  group('The share sheet', () {
    Widget app(AppStore store, Widget Function(BuildContext) opener) => host(store, Builder(builder: (context) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => opener(context), child: const Text('aç'))))));

    testWidgets('Title and the four options; Bağlantıyı Kopyala copies the link and confirms', (tester) async {
      final store = AppStore();
      await tester.pumpWidget(app(store, (context) {
        showShareSheet(context, service: service, url: 'https://senmiydin.tr/p/ab12cd34ef56', build: (s) => s.postCard(post(), store));
        return const SizedBox();
      }));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('share-sheet-title')), findsOneWidget);
      expect(find.text('Paylaş'), findsOneWidget);
      expect(find.text('Hikâyede Paylaş'), findsOneWidget);
      expect(find.text('Görsel Kart Olarak Paylaş'), findsOneWidget);
      expect(find.text('Bağlantıyı Kopyala'), findsOneWidget);
      expect(find.text('Diğer…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('share-link')));
      await tester.pumpAndSettle();
      expect(platform.copied, ['https://senmiydin.tr/p/ab12cd34ef56']);
      expect(find.text('Bağlantı kopyalandı.'), findsOneWidget);
    });

    testWidgets('English labels', (tester) async {
      AppLocale.debugSet(const Locale('en'));
      final store = AppStore();
      await tester.pumpWidget(app(store, (context) {
        showShareSheet(context, service: service, url: 'https://senmiydin.tr/p/ab12cd34ef56', build: (s) => s.postCard(post(), store));
        return const SizedBox();
      }));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Share to Story'), findsOneWidget);
      expect(find.text('Share as Image Card'), findsOneWidget);
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('More…'), findsOneWidget);
    });

    testWidgets('A failing system share sheet or renderer shows a calm message and closes', (tester) async {
      platform.failShare = true;
      final store = AppStore();
      await tester.pumpWidget(app(store, (context) {
        showShareSheet(context, service: service, url: 'https://senmiydin.tr/p/ab12cd34ef56', build: (s) => s.postCard(post(), store));
        return const SizedBox();
      }));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('share-other')));
      await tester.pumpAndSettle();
      expect(find.text('Paylaşım menüsü açılamadı.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('The sheet fits ${width.toInt()} px at 1.5x text', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = AppStore();
        await tester.pumpWidget(host(
          store,
          Builder(builder: (context) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => showShareSheet(context, service: service, url: 'https://senmiydin.tr/p/ab12cd34ef56', build: (s) => s.postCard(post(), store)), child: const Text('aç'))))),
          scale: 1.5,
        ));
        await tester.tap(find.text('aç'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('share-other')), findsOneWidget);
      });
    }
  });
}
