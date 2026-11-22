import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/core/relative_time.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:senmiydin/core/theme.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/screens/home.dart' show AppBottomNav;
import 'package:senmiydin/screens/live_map.dart';
import 'package:senmiydin/widgets/common.dart';
import 'package:senmiydin/widgets/media_viewer.dart';
import 'package:senmiydin/widgets/post_map_preview.dart';
import 'package:senmiydin/widgets/social.dart';

import 'global_release_test.dart' show account, connected, ok;
import 'memories_test.dart' show shapedPhoto;
import 'support/chat_harness.dart' show loadAppFont, realWait;

const alanya = LatLng(36.5446, 32.0021);
const photos3 = [
  'assets/images/coast.jpg',
  'assets/images/sunset.jpg',
  'assets/images/coffee.jpg',
];

class Routes extends NavigatorObserver {
  final names = <String>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Menus, sheets and dialogs are unnamed routes; only pages count.
    if (route.settings.name case final name?) names.add(name);
  }

  /// Pages opened after the app started.
  List<String> get opened => [
    for (final name in names)
      if (name != '/') name,
  ];
}

Post feedPost(
  AppStore store, {
  String id = 'p1',
  String text = 'Sahilde kahve içtim.',
  List<String> images = const [],
  LatLng? at,
  bool liked = false,
  int likes = 0,
  bool remote = false,
  bool mine = false,
  int hoursAgo = 17,
}) => Post(
  id: id,
  authorId: store.people[1].id,
  text: text,
  images: images,
  mapPoint: at,
  locationLabel: at == null ? null : 'Alanya',
  liked: liked,
  likes: likes,
  remote: remote,
  mine: mine,
  createdAt: DateTime.now().subtract(Duration(hours: hoursAgo)),
);

void screen(WidgetTester tester, double width, [double height = 900]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget feed(
  AppStore store,
  List<Post> posts,
  Routes routes, {
  double scale = 1,
}) => host(
  store,
  Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [for (final post in posts) PostCard(post)]),
      ),
    ),
  ),
  observer: routes,
  scale: scale,
);

/// The app as it is: its theme (and so its font), language and a route log. Text scale optional.
Widget host(
  AppStore store,
  Widget child, {
  double scale = 1,
  NavigatorObserver? observer,
}) => StoreScope(
  store: store,
  child: MaterialApp(
    theme: buildTheme(),
    navigatorObservers: [?observer],
    locale: const Locale('tr'),
    supportedLocales: AppLocale.supported,
    localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    builder: (context, page) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: page!,
    ),
    onGenerateRoute: (settings) => MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => settings.name == '/' ? child : Scaffold(body: Text('route ${settings.name}')),
    ),
  ),
);

/// The Flutter `Text` inside the app's translated `Text` that carries [key].
Text innerText(WidgetTester tester, Key key) => tester.widget<Text>(
  find.descendant(of: find.byKey(key), matching: find.byType(Text)),
);

/// Two quick taps (the double-tap window is 300 ms).
Future<void> doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tap(finder);
  await tester.pump();
}

/// A single tap waits for the double-tap window to close; this lets it pass and the page transition finish.
Future<void> singleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFont);
  setUp(() => AppLocale.debugSet(const Locale('tr')));
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  group('The short time', () {
    test('drops the trailing word and leaves what is already short', () {
      expect(shortRelativeTime('17 sa önce'), '17 sa');
      expect(shortRelativeTime('5 dk önce'), '5 dk');
      expect(shortRelativeTime('3 gün önce'), '3 gün');
      expect(shortRelativeTime('5 min ago'), '5 min');
      expect(shortRelativeTime('2 h ago'), '2 h');
      expect(shortRelativeTime('Az önce'), 'Az önce');
      expect(shortRelativeTime('Just now'), 'Just now');
      expect(shortRelativeTime('12.11.2026'), '12.11.2026');
    });
  });

  group('Header and footer', () {
    testWidgets('The header is the avatar and the full name; no place and no time', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final post = feedPost(store, at: alanya);
      await tester.pumpWidget(feed(store, [post], Routes()));
      await tester.pumpAndSettle();
      final name = store.people[1].name;
      expect(name.trim().split(' ').length, greaterThan(1), reason: 'The fixture person has a surname.');
      expect(find.text(name), findsOneWidget, reason: 'One person: the full name.');
      // The place is metadata of the post, never part of the card.
      expect(find.text('Alanya'), findsNothing);
      expect(find.textContaining('Yaklaşık'), findsNothing);
      expect(find.byIcon(Icons.location_on_rounded), findsNothing);
      // The time is not beside the name.
      final nameRect = tester.getRect(find.text(name));
      final time = tester.getRect(find.byKey(const Key('post-time-p1')));
      expect(time.top, greaterThan(nameRect.bottom + 20), reason: 'The time lives in the footer, below the content.');
      expect(find.byTooltip('Paylaşım seçenekleri'), findsOneWidget);
    });

    testWidgets('The footer reads like · comment · share … time · bookmark on one line', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final post = feedPost(store);
      await tester.pumpWidget(feed(store, [post], Routes()));
      await tester.pumpAndSettle();
      final like = tester.getRect(find.byTooltip('Beğen'));
      final comment = tester.getRect(find.byTooltip('Yorumlar'));
      final share = tester.getRect(find.byTooltip('Paylaş'));
      final save = tester.getRect(find.byTooltip('Kaydet'));
      final time = tester.getRect(find.byKey(const Key('post-time-p1')));
      expect(innerText(tester, const Key('post-time-p1')).data, '17 sa önce');
      expect(like.right, lessThanOrEqualTo(comment.left + 1));
      expect(comment.right, lessThanOrEqualTo(share.left + 1));
      expect(time.left, greaterThanOrEqualTo(share.right - 1), reason: 'The time is right of the actions.');
      expect(time.right, lessThanOrEqualTo(save.left + 1), reason: 'and left of the bookmark.');
      for (final rect in [comment, share, save, time]) {
        expect((rect.center.dy - like.center.dy).abs(), lessThan(14), reason: 'One line.');
      }
      final style = innerText(tester, const Key('post-time-p1')).style!;
      expect(style.fontSize, lessThanOrEqualTo(13), reason: 'Small, muted, low weight.');
      expect(style.color, AppColors.muted);
    });

    for (final (width, scale, full) in [
      (320.0, 1.0, null),
      (360.0, 1.0, null),
      (390.0, 1.0, true),
      (430.0, 1.0, true),
      (320.0, 1.5, false),
      (390.0, 1.5, null),
    ]) {
      testWidgets('At ${width.toInt()} dp / ${scale}x the time never collides with the actions', (tester) async {
        screen(tester, width);
        final store = AppStore();
        addTearDown(store.dispose);
        final post = feedPost(store, likes: 128, text: 'Uzun bir isim ve kısa bir metin.');
        await tester.pumpWidget(feed(store, [post], Routes(), scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final label = innerText(tester, const Key('post-time-p1')).data;
        expect(label, anyOf('17 sa önce', '17 sa'));
        if (full == true) expect(label, '17 sa önce');
        if (full == false) expect(label, '17 sa');
        final time = tester.getRect(find.byKey(const Key('post-time-p1')));
        expect(time.right, lessThanOrEqualTo(tester.getRect(find.byTooltip('Kaydet')).left + 1));
        expect(time.left, greaterThanOrEqualTo(tester.getRect(find.byTooltip('Paylaş')).right - 1));
        // The card stays inside the screen.
        expect(tester.getRect(find.byType(PostCard)).right, lessThanOrEqualTo(width));
      });
    }

    testWidgets('A long name stays on one line with an ellipsis', (tester) async {
      screen(tester, 320);
      final store = AppStore();
      addTearDown(store.dispose);
      store.people[1].name = 'Abdurrahman Muhammed Çağlayan-Karaçoban Yıldırım';
      final post = feedPost(store);
      await tester.pumpWidget(feed(store, [post], Routes()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final name = find.text(store.people[1].name);
      expect(tester.widget<Text>(name).maxLines, 1);
      expect(tester.getSize(name).height, lessThan(24));
    });

    testWidgets('An encounter story: two avatars, "Demo & Elif", and only a quiet "Karşılaşıldı" under the names', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final ercan = Person(id: 'e1', name: 'Ercan Yılmaz', handle: 'ercan', photo: '');
      final meliha = Person(id: 'e2', name: 'Meliha Kaya Demir', handle: 'meliha', photo: '');
      final pair = Post(
        id: 'pair',
        authorId: store.people[1].id,
        text: 'Karşılaştık.',
        kind: PostKind.encounter,
        encounterConfirmed: true,
        storyStatus: 'published',
        storyParticipants: [ercan, meliha],
        remote: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 17)),
      );
      final single = feedPost(store, id: 'one', text: 'Tek kişilik.');
      single.encounterConfirmed = true; // even a confirmed single post carries nothing but avatar and name
      await tester.pumpWidget(feed(store, [pair, single], Routes()));
      await tester.pumpAndSettle();
      expect(find.byType(EncounterAvatars), findsOneWidget);
      expect(find.text('Ercan & Meliha'), findsOneWidget);
      final label = find.text('Karşılaşıldı');
      expect(label, findsOneWidget, reason: 'Only the pair card has it.');
      final text = tester.widget<Text>(label);
      expect(text.style!.fontSize, lessThanOrEqualTo(12), reason: 'Small, not a badge.');
      expect(text.style!.fontWeight, isNot(FontWeight.w800));
      final names = tester.getRect(find.text('Ercan & Meliha'));
      final quiet = tester.getRect(label);
      expect(quiet.top, greaterThanOrEqualTo(names.bottom - 2), reason: 'Under the names.');
      expect(quiet.left, closeTo(names.left, 2));
      // The encounter pink, pulled a little towards the navy so the small text stays readable (4.5:1 on white).
      final ink = text.style!.color!;
      expect(ink.r, greaterThan(ink.b), reason: 'Still a rose.');
      double lum(Color c) => c.computeLuminance();
      expect((1.05) / (lum(ink) + .05), greaterThanOrEqualTo(4.5));
    });
  });

  group('Single tap, double tap', () {
    testWidgets('A double tap likes the post and plays the heart; a single tap waits for the window', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final routes = Routes();
      final post = feedPost(store, likes: 4);
      await tester.pumpWidget(feed(store, [post], routes));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('heart-burst')), findsNothing);
      await doubleTap(tester, find.text(post.text));
      expect(post.liked, isTrue);
      expect(post.likes, 5);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const Key('heart-burst')), findsOneWidget, reason: 'The heart grows over the content.');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('heart-burst')), findsOneWidget, reason: 'and holds a moment.');
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const Key('heart-burst')), findsNothing, reason: 'then it is gone (about 700 ms in all).');
      expect(find.text('5'), findsOneWidget, reason: 'The like count follows.');
    });

    testWidgets('An already liked post stays liked on a double tap (only the heart button takes it back)', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final post = feedPost(store, liked: true, likes: 3);
      await tester.pumpWidget(feed(store, [post], Routes()));
      await tester.pumpAndSettle();
      await doubleTap(tester, find.text(post.text));
      await tester.pumpAndSettle();
      expect(post.liked, isTrue);
      expect(post.likes, 3);
      // The heart button un-likes.
      await tester.tap(find.byTooltip('Beğen'));
      await tester.pumpAndSettle();
      expect(post.liked, isFalse);
      expect(post.likes, 2);
    });

    testWidgets('On the server: one double tap sends one like; liked already sends nothing', (tester) async {
      screen(tester, 390);
      final log = <String>[];
      final store = await connected((request) async {
        final path = request.url.path;
        log.add('${request.method} ${path.replaceFirst('/api/v1', '')}');
        if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
        if (path.endsWith('/like')) return ok({'liked': request.method == 'POST', 'likes_count': request.method == 'POST' ? 1 : 0});
        return ok({'items': [], 'next_page': null});
      });
      addTearDown(store.dispose);
      final fresh = feedPost(store, id: '11', remote: true, text: 'Yeni bir paylaşım.');
      final liked = feedPost(store, id: '12', remote: true, text: 'Zaten beğenilmiş.', liked: true, likes: 7);
      await tester.pumpWidget(feed(store, [fresh, liked], Routes()));
      await tester.pumpAndSettle();
      await doubleTap(tester, find.text('Yeni bir paylaşım.'));
      await tester.pumpAndSettle();
      expect(log.where((line) => line.endsWith('/like')), ['POST /posts/11/like']);
      expect(fresh.liked, isTrue);
      expect(fresh.likes, 1);
      await doubleTap(tester, find.text('Zaten beğenilmiş.'));
      await tester.pumpAndSettle();
      expect(log.where((line) => line.endsWith('/like')), ['POST /posts/11/like'], reason: 'Nothing was sent for the liked post.');
      expect(liked.liked, isTrue);
      expect(liked.likes, 7);
    });

    testWidgets('A located post opens the map on its point; a double tap never opens it first', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final routes = Routes();
      final post = feedPost(store, id: 'a', text: 'Metnin üstü.', at: alanya);
      final photo = feedPost(store, id: 'b', text: 'Fotoğrafın altı.', at: alanya, images: const ['assets/images/coast.jpg']);
      await tester.pumpWidget(feed(store, [post, photo], routes));
      await tester.pumpAndSettle();
      // Double tap on the text and on the photo: liked, no page.
      await doubleTap(tester, find.text('Metnin üstü.'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(routes.opened, isEmpty, reason: 'A double tap is a like, not an open.');
      expect(store.mapPostFocus, isNull);
      expect(post.liked, isTrue);
      await doubleTap(tester, find.byType(PageView));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(routes.opened, isEmpty);
      expect(photo.liked, isTrue);
      // A single tap waits for the window, then opens the map once.
      await tester.tap(find.text('Metnin üstü.'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(routes.opened, isEmpty, reason: 'Still waiting for a possible second tap.');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(routes.opened, ['/map']);
      expect(store.mapPostFocus, same(post));
    });

    testWidgets('A photo of a located post opens the map too (not the viewer)', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final routes = Routes();
      final post = feedPost(store, at: alanya, images: photos3);
      await tester.pumpWidget(feed(store, [post], routes));
      await tester.pumpAndSettle();
      await singleTap(tester, find.byType(PageView));
      expect(routes.opened, ['/map']);
      expect(find.byType(MediaViewer), findsNothing);
      expect(store.mapPostFocus, same(post));
    });

    testWidgets('A post without a place never goes to the map: its photo opens the viewer, plain text opens nothing', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final routes = Routes();
      final withPhotos = feedPost(store, id: 'a', text: 'Üç kare.', images: photos3);
      final plain = feedPost(store, id: 'b', text: 'Sadece yazı.');
      await tester.pumpWidget(feed(store, [withPhotos, plain], routes));
      await tester.pumpAndSettle();
      await singleTap(tester, find.text('Sadece yazı.'));
      expect(routes.opened, isEmpty);
      expect(find.byType(MediaViewer), findsNothing);
      expect(store.mapPostFocus, isNull);
      await singleTap(tester, find.byType(PageView));
      expect(routes.opened, isEmpty, reason: 'The viewer is a dialog on the same route, not a map and not a post page.');
      expect(find.byType(MediaViewer), findsOneWidget);
      expect(store.mapPostFocus, isNull);
    });

    testWidgets('On the post page itself a tap on the text opens nothing and a photo opens the viewer', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final routes = Routes();
      final post = feedPost(store, at: alanya, images: const ['assets/images/coast.jpg']);
      await tester.pumpWidget(
        host(
          store,
          Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: PostCard(post, detail: true)))),
          observer: routes,
        ),
      );
      await tester.pumpAndSettle();
      await singleTap(tester, find.text(post.text));
      expect(routes.opened, isEmpty);
      await singleTap(tester, find.byType(PageView));
      expect(routes.opened, isEmpty);
      expect(find.byType(MediaViewer), findsOneWidget);
    });

    testWidgets('The action buttons, the ⋮ menu and the avatar only do their own thing', (tester) async {
      screen(tester, 390, 1100);
      final store = AppStore();
      addTearDown(store.dispose);
      final routes = Routes();
      final post = feedPost(store, at: alanya, images: const ['assets/images/coast.jpg']);
      await tester.pumpWidget(feed(store, [post], routes));
      await tester.pumpAndSettle();
      // Bookmark.
      await tester.tap(find.byTooltip('Kaydet'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(post.saved, isTrue);
      expect(routes.opened, isEmpty);
      expect(store.mapPostFocus, isNull);
      // Like button: one tap is one like, no heart over the content, no page.
      await tester.tap(find.byTooltip('Beğen'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(post.liked, isTrue);
      expect(post.likes, 1);
      expect(find.byKey(const Key('heart-burst')), findsNothing);
      expect(routes.opened, isEmpty);
      // Two quick taps on the button are two taps of the button (like, then un-like), never the content's double tap.
      await tester.tap(find.byTooltip('Beğen'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byTooltip('Beğen'));
      await tester.pumpAndSettle();
      expect(post.liked, isTrue, reason: 'Un-like, like: the same state as before, button taps only.');
      expect(find.byKey(const Key('heart-burst')), findsNothing);
      expect(routes.opened, isEmpty);
      // Share opens its own sheet.
      await tester.tap(find.byTooltip('Paylaş'));
      await tester.pumpAndSettle();
      expect(find.text('Paylaşımı gönder'), findsOneWidget);
      expect(routes.opened, isEmpty);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      // The ⋮ menu opens a menu (with the map entry) and nothing else.
      await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
      await tester.pumpAndSettle();
      expect(find.text('Haritada Gör'), findsOneWidget);
      expect(routes.opened, isEmpty);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(routes.opened, isEmpty);
      // The avatar opens the profile, not the map.
      await singleTap(tester, find.byType(Avatar).first);
      expect(routes.opened, ['/profile']);
      expect(store.mapPostFocus, isNull);
    });

    testWidgets('Swiping the carousel changes the photo and neither likes nor opens anything', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final routes = Routes();
      final post = feedPost(store, at: alanya, images: photos3);
      await tester.pumpWidget(feed(store, [post], routes));
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(260, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      expect(post.liked, isFalse);
      expect(routes.opened, isEmpty);
      expect(find.byKey(const Key('heart-burst')), findsNothing);
      // A double tap on the second photo likes (and stays on it).
      await doubleTap(tester, find.byType(PageView));
      await tester.pumpAndSettle();
      expect(post.liked, isTrue);
      expect(find.text('2/3'), findsOneWidget);
      expect(routes.opened, isEmpty);
    });

    testWidgets('The heart plays over the photo, centred on it', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final post = feedPost(store, images: const ['assets/images/coast.jpg']);
      await tester.pumpWidget(feed(store, [post], Routes()));
      await tester.pumpAndSettle();
      await doubleTap(tester, find.byType(PageView));
      await tester.pump(const Duration(milliseconds: 200));
      final heart = tester.getCenter(find.byKey(const Key('heart-burst')));
      final box = tester.getRect(find.byType(PageView));
      expect((heart.dx - box.center.dx).abs(), lessThan(2));
      expect((heart.dy - box.center.dy).abs(), lessThan(2));
      await tester.pumpAndSettle();
    });

    testWidgets('A post that cannot be interacted with (pending encounter story) reacts to no touch', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final routes = Routes();
      final pending = Post(
        id: 'pending',
        authorId: store.people[1].id,
        text: 'Onay bekleyen hikâye.',
        storyStatus: 'pending',
        storyParticipants: [store.me, store.people.first],
        mapPoint: alanya,
        remote: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await tester.pumpWidget(feed(store, [pending], routes));
      await tester.pumpAndSettle();
      await doubleTap(tester, find.text('Onay bekleyen hikâye.'));
      await singleTap(tester, find.text('Onay bekleyen hikâye.'));
      expect(pending.liked, isFalse);
      expect(routes.opened, isEmpty);
      expect(find.byTooltip('Beğen'), findsNothing, reason: 'No actions yet.');
      expect(find.byKey(const Key('post-time-pending')), findsOneWidget, reason: 'The time is still told.');
    });
  });

  group('The ⋮ menu', () {
    testWidgets('A located post has "Haritada Gör" there (and only there); it opens the map', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final routes = Routes();
      final located = feedPost(store, id: 'l', text: 'Konumlu.', at: alanya);
      final plain = feedPost(store, id: 'n', text: 'Konumsuz.');
      await tester.pumpWidget(feed(store, [located, plain], routes));
      await tester.pumpAndSettle();
      expect(find.text('Haritada Gör'), findsNothing, reason: 'No location button on the card.');
      await tester.tap(find.byTooltip('Paylaşım seçenekleri').last);
      await tester.pumpAndSettle();
      expect(find.text('Haritada Gör'), findsNothing, reason: 'A post without a place has no map entry.');
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Paylaşım seçenekleri').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Haritada Gör'));
      await tester.pumpAndSettle();
      expect(routes.opened, ['/map']);
      expect(store.mapPostFocus, same(located));
    });

    testWidgets('Your own post: edit and delete, no report; someone else’s: report and block', (tester) async {
      screen(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      final mine = feedPost(store, id: 'm', text: 'Benim.', remote: true, mine: true);
      final theirs = feedPost(store, id: 't', text: 'Onun.', remote: true);
      await tester.pumpWidget(feed(store, [mine, theirs], Routes()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Paylaşım seçenekleri').first);
      await tester.pumpAndSettle();
      expect(find.text('Düzenle'), findsOneWidget);
      expect(find.text('Sil'), findsOneWidget);
      expect(find.text('Paylaşımı şikâyet et'), findsNothing);
      expect(find.text('Kullanıcıyı engelle'), findsNothing);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Paylaşım seçenekleri').last);
      await tester.pumpAndSettle();
      expect(find.text('Paylaşımı şikâyet et'), findsOneWidget);
      expect(find.text('Kullanıcıyı engelle'), findsOneWidget);
      expect(find.text('Düzenle'), findsNothing);
      expect(find.text('Sil'), findsNothing);
    });
  });

  group('Photos', () {
    for (final (label, width, height, capped) in [
      ('9:16', 90, 160, true),
      ('4:5', 80, 100, false),
      ('16:9', 160, 90, false),
    ]) {
      testWidgets('A $label photo keeps its own shape${capped ? ' and a tall one never fills the screen' : ''}', (tester) async {
        final path = await shapedPhoto(tester, width, height);
        screen(tester, 390, 800);
        final store = AppStore();
        addTearDown(store.dispose);
        final post = feedPost(store, images: [path]);
        await tester.pumpWidget(feed(store, [post], Routes()));
        await realWait(tester, 300);
        await tester.pumpAndSettle();
        final box = tester.getSize(find.descendant(of: find.byType(PostCard), matching: find.byType(PageView)));
        if (capped) {
          expect(box.height, lessThanOrEqualTo(800 * .62 + .5), reason: 'The box is capped.');
          expect(box.height, greaterThan(400), reason: 'but still generous.');
          expect(box.width / box.height, greaterThan(width / height), reason: 'The box is wider than the photo: the photo sits whole in it.');
        } else {
          expect(box.width / box.height, closeTo(width / height, .02), reason: 'The box has the photo’s own shape.');
        }
        // The photo itself is always whole (contain); a tall one also gets its own soft colours (cover, blurred) in the side bands.
        final fits = find.descendant(of: find.byType(PageView), matching: find.byType(Image)).evaluate().map((e) => (e.widget as Image).fit).toList();
        expect(fits, contains(BoxFit.contain), reason: 'Never cropped, never squeezed.');
        expect(fits.contains(BoxFit.cover), capped, reason: 'A backdrop only where the photo leaves bands.');
        File(path).deleteSync();
      });
    }
  });

  group('Bottom navigation', () {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('The labels fit their tab at ${width.toInt()} dp (they shrink, they are never cut)', (tester) async {
        screen(tester, width, 800);
        final store = AppStore();
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, Scaffold(bottomNavigationBar: AppBottomNav(selected: 0, unread: 3, onChanged: (_) {}))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final (index, label) in [(0, 'Ana Sayfa'), (1, 'Harita'), (3, 'Mesajlar'), (4, 'Profil')]) {
          final tab = tester.getRect(find.byKey(Key('nav-$index')));
          final text = tester.getRect(find.text(label));
          expect(text.width, lessThanOrEqualTo(tab.width), reason: '$label inside its tab at $width dp');
          expect(text.left, greaterThanOrEqualTo(tab.left));
          expect(text.right, lessThanOrEqualTo(tab.right));
        }
      });
    }
  });

  group('The post on the map', () {
    Map<String, dynamic> postJson(int id, String body, {List<Map<String, dynamic>> media = const [], bool located = true}) => {
      'id': id,
      'body': body,
      'type': 'moment',
      'city': {'id': 1, 'name': 'Alanya'},
      'is_anonymous': false,
      'author': {'id': 21, 'username': 'ece', 'name': 'Ece Yılmaz', 'avatar': null},
      'comments_enabled': true,
      'visibility': 'city',
      'likes_count': 0,
      'comments_count': 0,
      'saved': false,
      'media': media,
      'map_point': located ? {'latitude': 36.545, 'longitude': 32.005} : null,
      'created_at': DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
    };

    Future<AppStore> mapStore({List<Map<String, dynamic>> points = const [], Map<String, dynamic>? post}) => connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.endsWith('/map/posts')) return ok({'items': points, 'location_required': false});
      if (post != null && path.endsWith('/posts/${post['id']}')) return ok(post);
      return ok({'items': [], 'next_page': null});
    });

    Future<void> openMap(WidgetTester tester, AppStore store, {double scale = 1}) async {
      await tester.pumpWidget(host(store, const Scaffold(body: LiveMapContent()), scale: scale));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    testWidgets('A post opened from the feed: the map keeps its tabs, the preview carries avatar, name, time and the first lines', (tester) async {
      screen(tester, 390, 900);
      final store = await mapStore();
      addTearDown(store.dispose);
      final post = feedPost(store, id: '31', at: alanya, text: 'Sahilde gün ışığı tam yerindeydi. ' * 6, hoursAgo: 3);
      store.mapPostFocus = post;
      await openMap(tester, store);
      expect(store.mapPostFocus, isNull, reason: 'The request is consumed once.');
      final preview = find.byKey(const Key('post-map-preview'));
      expect(preview, findsOneWidget);
      expect(find.descendant(of: preview, matching: find.text(store.people[1].name)), findsOneWidget);
      expect(find.byKey(const Key('post-map-preview-time')), findsOneWidget);
      expect(innerText(tester, const Key('post-map-preview-time')).data, '3 sa önce');
      final text = innerText(tester, const Key('post-map-preview-text'));
      expect(text.maxLines, 3);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(find.byType(Avatar), findsWidgets);
      // The post's marker is on the map and highlighted; the camera starts on its approximate point.
      expect(find.byKey(const Key('map-post-focus')), findsOneWidget);
      // A strip, never a screen.
      expect(tester.getSize(preview).height, lessThan(900 * .25));
      // The map is still the map: its tabs are there.
      expect(find.text('Paylaşımlar'), findsOneWidget);
      // Closing puts the preview and the highlight away.
      await tester.tap(find.byKey(const Key('post-map-preview-close')));
      await tester.pumpAndSettle();
      expect(preview, findsNothing);
      expect(find.byKey(const Key('map-post-focus')), findsNothing);
    });

    testWidgets('The small photo of the preview opens the existing viewer', (tester) async {
      screen(tester, 390, 900);
      final store = await mapStore();
      addTearDown(store.dispose);
      final path = await shapedPhoto(tester, 80, 100);
      final post = feedPost(store, id: '32', at: alanya, images: [path, path]);
      store.mapPostFocus = post;
      await openMap(tester, store);
      expect(find.byKey(const Key('post-map-preview-photo')), findsOneWidget);
      expect(find.text('+1'), findsOneWidget, reason: 'More photos are counted, not shown.');
      await tester.tap(find.byKey(const Key('post-map-preview-photo')));
      await tester.pumpAndSettle();
      expect(find.byType(MediaViewer), findsOneWidget);
      File(path).deleteSync();
    });

    testWidgets('A marker opens the same preview (placeholder first, then the post); the bare map puts it away', (tester) async {
      screen(tester, 390, 900);
      final gate = Completer<void>();
      final store = await connected((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
        if (path.endsWith('/map/posts')) {
          return ok({
            'items': [
              {'post_id': 41, 'latitude': 36.5446, 'longitude': 32.0021, 'distance_meters': null},
            ],
            'location_required': false,
          });
        }
        if (path.endsWith('/posts/41')) {
          await gate.future;
          return ok(postJson(41, 'Marker’a dokununca açılan paylaşım.'));
        }
        return ok({'items': [], 'next_page': null});
      });
      addTearDown(store.dispose);
      await openMap(tester, store);
      expect(find.byKey(const Key('post-map-preview')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('map-post-41')));
      await tester.pump();
      expect(find.byKey(const Key('post-map-preview-placeholder')), findsOneWidget, reason: 'The id alone is not enough: it loads.');
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('post-map-preview-placeholder')), findsNothing);
      expect(find.text('Marker’a dokununca açılan paylaşım.'), findsOneWidget);
      expect(find.text('Ece Yılmaz'), findsOneWidget);
      // No classic post page was opened.
      expect(find.byType(PostCard), findsNothing);
      // A tap on the bare map closes it.
      final map = tester.getRect(find.byType(PostMapPreview));
      await tester.tapAt(Offset(40, map.top - 120));
      await tester.pump(const Duration(milliseconds: 400)); // the map waits for a possible double tap (zoom) first
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('post-map-preview')), findsNothing);
    });

    testWidgets('A post that cannot be loaded says so and can be retried', (tester) async {
      screen(tester, 390, 900);
      var fail = true;
      final store = await connected((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
        if (path.endsWith('/map/posts')) {
          return ok({
            'items': [
              {'post_id': 51, 'latitude': 36.5446, 'longitude': 32.0021, 'distance_meters': null},
            ],
            'location_required': false,
          });
        }
        if (path.endsWith('/posts/51')) return fail ? ok({}, 503) : ok(postJson(51, 'İkinci denemede geldi.'));
        return ok({'items': [], 'next_page': null});
      });
      addTearDown(store.dispose);
      await openMap(tester, store);
      await tester.tap(find.byKey(const ValueKey('map-post-51')));
      await tester.pumpAndSettle();
      expect(find.text('Paylaşım yüklenemedi.'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pumpAndSettle();
      expect(find.text('İkinci denemede geldi.'), findsOneWidget);
    });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('The preview fits at ${width.toInt()} dp / ${scale}x, with a long name, a long text and a photo', (tester) async {
          screen(tester, width, 900);
          final store = await mapStore();
          addTearDown(store.dispose);
          store.people[1].name = 'Abdurrahman Muhammed Çağlayan-Karaçoban Yıldırım';
          final path = await shapedPhoto(tester, 90, 160);
          final post = feedPost(store, id: '61', at: alanya, images: [path], text: 'Çok uzun bir paylaşım metni. ' * 20);
          store.mapPostFocus = post;
          await openMap(tester, store, scale: scale);
          expect(tester.takeException(), isNull);
          final preview = tester.getRect(find.byKey(const Key('post-map-preview')));
          expect(preview.left, greaterThanOrEqualTo(0));
          expect(preview.right, lessThanOrEqualTo(width));
          expect(preview.height, lessThan(900 * .34), reason: 'Still a strip at ${scale}x.');
          File(path).deleteSync();
        });
      }
    }
  });
}
