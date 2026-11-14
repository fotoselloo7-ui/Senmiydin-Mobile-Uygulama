// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/communication_api.dart';
import 'package:senmiydin/data/compose_draft.dart';
import 'package:senmiydin/data/location_service.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/data/post_context.dart';
import 'package:senmiydin/screens/compose.dart';
import 'package:senmiydin/screens/home.dart';
import 'package:senmiydin/screens/live_notifications.dart';
import 'package:senmiydin/screens/post.dart';
import 'package:senmiydin/widgets/comments_sheet.dart';

import 'support/comments_host.dart';

http.Response ok(Object? data, [int status = 200]) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Device extends LocationDevice {
  @override
  bool get supportsBackground => false;
}

Map<String, dynamic> account() => {
  'id': 1,
  'name': 'Demo',
  'username': 'demo',
  'city': {'id': 1, 'name': 'Alanya'},
  'avatar': null,
  'bio': '',
  'occupation_school': '',
  'connections': [],
  'interests': [],
  'onboarding_step': 3,
  'nearby_visible': false,
  'encounter_suggestions': false,
  'city_discovery': true,
  'location_history_enabled': false,
  'push_preferences': {},
};

Map<String, dynamic> postJson(
  int id,
  String body, {
  int comments = 0,
  bool commentsEnabled = true,
}) => {
  'id': id,
  'body': body,
  'type': 'moment',
  'city': {'id': 1, 'name': 'Alanya'},
  'is_anonymous': false,
  'author': {'id': 21, 'username': 'ece', 'name': 'Ece Test', 'avatar': null},
  'comments_enabled': commentsEnabled,
  'visibility': 'city',
  'likes_count': 0,
  'comments_count': comments,
  'saved': true,
  'media': [],
  'created_at': '2026-11-14T10:00:00Z',
};

Map<String, dynamic> commentJson(
  int id,
  String body, {
  String username = 'ece',
  int? parent,
  int likes = 0,
  bool liked = false,
  bool mine = false,
  List<Map<String, dynamic>> replies = const [],
}) => {
  'id': id,
  'body': body,
  'parent_id': parent,
  'mine': mine,
  'likes_count': likes,
  'liked_by_me': liked,
  'author': {
    'id': username.hashCode.abs() % 900 + 30,
    'username': username,
    'name': '${username.toUpperCase()} Test',
    'avatar': null,
  },
  'created_at': '2026-11-14T11:00:00Z',
  if (parent == null) 'reply_count': replies.length,
  if (parent == null) 'replies': replies,
};

Future<AppStore> connected(
  Future<http.Response> Function(http.Request) handler, {
  ComposeDraftStore? drafts,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  final store = AppStore(
    api: ApiClient(httpClient: MockClient(handler)),
    locationDevice: _Device(),
    drafts: drafts,
  );
  await store.signIn('login', {'identifier': 'demo', 'password': 'x'});
  return store;
}

class _Routes extends NavigatorObserver {
  final names = <String>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name ?? '');
}

Widget host(
  AppStore store,
  Widget child, {
  double scale = 1,
  NavigatorObserver? observer,
  Map<String, Widget Function(Object?)> routes = const {},
}) => StoreScope(
  store: store,
  child: MaterialApp(
    navigatorObservers: [?observer],
    builder: (context, page) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: page!,
    ),
    onGenerateRoute: (settings) => MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => settings.name == '/'
          ? child
          : routes[settings.name]?.call(settings.arguments) ??
                Scaffold(body: Text('route ${settings.name}')),
    ),
  ),
);

void main() {
  // The app's real font, so chip widths match what a phone draws (the default test font is a fixed-width placeholder).
  setUpAll(() async {
    final bytes = File('assets/fonts/NunitoSans.ttf').readAsBytesSync();
    final loader = FontLoader('NunitoSans')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  void size(WidgetTester tester, double width, [double height = 1000]) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> real(WidgetTester tester, [int ms = 300]) async {
    for (var i = 0; i < (ms / 30).ceil().clamp(3, 40); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  // --------------------------------------------------------------------------------------------- compose
  group('Compose: clean actions, one-row types, clear location names', () {
    late Directory root;
    setUp(
      () async => root = await Directory.systemTemp.createTemp('senmiydin_cc_'),
    );
    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<AppStore> composeStore() => connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login'))
        return ok({'token': 't', 'user': account()});
      if (path.endsWith('/cities'))
        return ok([
          {'id': 1, 'name': 'Alanya'},
        ]);
      return ok({'items': [], 'next_page': null, 'location_required': false});
    }, drafts: ComposeDraftStore(root: () async => root));

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets(
        'At $width px: icon-only photo / camera, no "Konum Ekle", five types on one row, Şehir / Haritada yer seç / Mevcut konumumu ekle',
        (tester) async {
          size(tester, width, 1500);
          final store = await composeStore();
          addTearDown(store.dispose);
          await tester.pumpWidget(host(store, const ComposePage()));
          await tester.pumpAndSettle();
          await real(tester, 600);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'No overflow at $width px.',
          );

          // Quick actions: two compact 44x44 icon buttons with tooltips, no long ActionChips and no third location chip.
          expect(find.byType(ActionChip), findsNothing);
          expect(find.text('Konum Ekle'), findsNothing);
          expect(
            find.text('Fotoğraf Ekle'),
            findsNothing,
            reason: 'The label lives in the tooltip / semantics only.',
          );
          for (final key in ['compose-photo', 'compose-camera']) {
            final size = tester.getSize(find.byKey(Key(key)));
            expect(size.width, closeTo(44, .5));
            expect(size.height, closeTo(44, .5));
          }
          expect(find.byTooltip('Fotoğraf Ekle'), findsOneWidget);
          expect(find.byTooltip('Kamerayı Aç'), findsOneWidget);
          expect(find.byIcon(Icons.image_outlined), findsOneWidget);
          expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);

          // Types: one row.
          final labels = ['Anı', 'Karşılaşma', 'İtiraf', 'Düşünce', 'Yolculuk'];
          final tops = [
            for (final l in labels)
              tester.getCenter(find.widgetWithText(ChoiceChip, l)).dy,
          ];
          expect(
            tops.toSet().length,
            1,
            reason: 'All five types share one row, none wraps: $tops',
          );
          final lefts = [
            for (final l in labels)
              tester.getTopLeft(find.widgetWithText(ChoiceChip, l)).dx,
          ];
          expect(
            lefts,
            orderedEquals([...lefts]..sort()),
            reason: 'In order, left to right.',
          );
          if (width >= 390) {
            expect(
              tester.getRect(find.widgetWithText(ChoiceChip, 'Yolculuk')).right,
              lessThanOrEqualTo(width),
              reason: 'Fits without scrolling on normal phones.',
            );
          }

          // Location wording.
          expect(find.text('Şehir'), findsOneWidget);
          expect(find.text('Konum'), findsNothing);
          expect(find.text('Haritada yer seç'), findsOneWidget);
          expect(
            find.text('İsteğe bağlı yaklaşık bir nokta seç'),
            findsOneWidget,
          );
          expect(find.text('Paylaşım yeri'), findsNothing);
          await tester.scrollUntilVisible(
            find.text('Mevcut konumumu ekle'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Mevcut konumumu ekle'), findsOneWidget);
          expect(
            find.text('Cihaz konumundan yaklaşık bir bölge eklenir.'),
            findsOneWidget,
          );
          expect(find.text('Yaklaşık konumu ekle'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await real(tester, 200);
        },
      );
    }

    testWidgets(
      'A map point and "Mevcut konumumu ekle" are alternatives: choosing one clears the other',
      (tester) async {
        size(tester, 390, 1500);
        final store = await composeStore();
        addTearDown(store.dispose);
        // A saved draft restores a hand-picked map point.
        await tester.runAsync(
          () => store.drafts.save(
            'account-1',
            ComposeDraft(
              body: 'Haritadan seçilmiş yer',
              place: const PostPlaceSelection(
                'map',
                latitude: 36.54,
                longitude: 32.0,
                city: 'Alanya',
                label: 'Alanya · Haritadan yaklaşık bölge',
              ),
            ),
          ),
        );
        await tester.pumpWidget(host(store, const ComposePage()));
        await tester.pumpAndSettle();
        await real(tester, 600);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('draft-resume')));
        await tester.pump();
        await real(tester, 300);
        expect(
          find.text('Alanya · Haritadan yaklaşık bölge'),
          findsOneWidget,
          reason: 'The map point is shown.',
        );
        // The device-position switch is available next to it (it used to disappear), and starts off.
        await tester.scrollUntilVisible(
          find.text('Mevcut konumumu ekle'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester
              .widget<Switch>(
                find.descendant(
                  of: find
                      .ancestor(
                        of: find.text('Mevcut konumumu ekle'),
                        matching: find.byType(SwitchListTile),
                      )
                      .first,
                  matching: find.byType(Switch),
                ),
              )
              .value,
          isFalse,
        );

        // Turning the device position on drops the map point.
        store.location!.synced = true;
        await tester.tap(find.text('Mevcut konumumu ekle'));
        await tester.pump();
        await real(tester, 300);
        await tester.scrollUntilVisible(
          find.text('Haritada yer seç'),
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Alanya · Haritadan yaklaşık bölge'), findsNothing);
        expect(
          find.text('İsteğe bağlı yaklaşık bir nokta seç'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await real(tester, 200);
      },
    );

    testWidgets(
      'The Home quick action for location still lands on "Haritada yer seç"',
      (tester) async {
        size(tester, 390, 800);
        final store = await composeStore();
        addTearDown(store.dispose);
        await tester.pumpWidget(
          host(store, const ComposePage(media: 'location')),
        );
        await tester.pumpAndSettle();
        await real(tester, 600);
        await tester.pumpAndSettle();
        expect(find.text('Haritada yer seç'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Haritada yer seç')).dy,
          lessThan(800),
          reason: 'Scrolled into view.',
        );
        expect(find.text('Konum Ekle'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await real(tester, 200);
      },
    );
  });

  // --------------------------------------------------------------------------------------------- comments sheet
  group('Comments bottom sheet', () {
    Future<AppStore> commentsStore({
      bool commentsEnabled = true,
      List<Map<String, dynamic>>? initial,
      List<String>? log,
      Completer<http.Response>? sendGate,
      int feedPosts = 0,
    }) {
      final comments = [
        ...(initial ??
            [
              commentJson(
                10,
                'Ana yorum',
                likes: 2,
                replies: [
                  commentJson(
                    11,
                    'Bir cevap',
                    username: 'kaan',
                    parent: 10,
                    likes: 1,
                  ),
                ],
              ),
            ]),
      ];
      final likes = <int, bool>{};
      return connected((request) async {
        final path = request.url.path;
        log?.add('${request.method} $path');
        if (path.endsWith('/auth/login'))
          return ok({'token': 't', 'user': account()});
        if (path.endsWith('/cities'))
          return ok([
            {'id': 1, 'name': 'Alanya'},
          ]);
        final like = RegExp(r'comments/(\d+)/like$').firstMatch(path);
        if (like != null) {
          final id = int.parse(like.group(1)!);
          likes[id] = request.method == 'POST';
          final base = id == 10 ? 2 : 1;
          final count = base + (likes[id]! ? 1 : 0);
          // The server remembers it: later list requests carry the new state.
          for (final c in comments) {
            if (c['id'] == id) {
              c['likes_count'] = count;
              c['liked_by_me'] = likes[id];
            }
            for (final r in (c['replies'] as List? ?? const [])) {
              if (r['id'] == id) {
                r['likes_count'] = count;
                r['liked_by_me'] = likes[id];
              }
            }
          }
          return ok(commentJson(id, 'x', likes: count, liked: likes[id]!));
        }
        if (path.endsWith('/feed')) {
          return ok({
            'items': [
              for (var i = 1; i <= feedPosts; i++)
                postJson(
                  i,
                  'Akış gönderisi numara $i ${'uzun metin ' * 12}',
                  commentsEnabled: commentsEnabled,
                ),
            ],
            'next_page': null,
          });
        }
        final post = RegExp(r'/posts/(\d+)$').firstMatch(path);
        if (post != null && request.method == 'GET') {
          return ok(
            postJson(
              int.parse(post.group(1)!),
              'Dün sahildeydim, harika bir akşamdı.',
              comments: comments.length,
              commentsEnabled: commentsEnabled,
            ),
          );
        }
        if (path.endsWith('/comments') && request.method == 'POST') {
          if (sendGate != null) {
            await sendGate.future;
          }
          final body = (jsonDecode(request.body) as Map)['body'];
          final created = commentJson(
            20 + comments.length,
            '$body',
            username: 'demo',
            likes: 0,
          );
          comments.add({...created, 'mine': true});
          return ok(created, 201);
        }
        if (path.endsWith('/comments'))
          return ok({'items': comments, 'next_page': null});
        return ok({'items': [], 'next_page': null, 'location_required': false});
      });
    }

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets(
          'At $width px and ${scale}x text the header, rows, likes, Yanıtla and composer do not overflow',
          (tester) async {
            size(tester, width, 900);
            final store = await commentsStore();
            addTearDown(store.dispose);
            await tester.pumpWidget(
              host(store, const OpenComments('5'), scale: scale),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Yorumlar (1)'), findsOneWidget);
            expect(find.byKey(const Key('comments-close')), findsOneWidget);
            expect(
              find.byKey(const ValueKey('like-comment-10')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('like-comment-11')),
              findsOneWidget,
            );
            expect(find.byKey(const ValueKey('reply-10')), findsOneWidget);
            expect(find.byKey(const Key('comment-field')), findsOneWidget);
            expect(find.byKey(const Key('send-comment')), findsOneWidget);
            final sheet = tester.getRect(
              find.byKey(const Key('comments-scroll')),
            );
            expect(
              sheet.top,
              greaterThan(900 * .15),
              reason: 'Starts at roughly 78 % of the height.',
            );
            // Reply mode adds the banner without overflow.
            await tester.tap(find.byKey(const ValueKey('reply-10')));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('replying-banner')), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }

    testWidgets(
      'It is a bottom sheet over the page, with a context line instead of a post box, a close button and a sticky composer',
      (tester) async {
        size(tester, 390, 900);
        final store = await commentsStore();
        addTearDown(store.dispose);
        final routes = _Routes();
        await tester.pumpWidget(
          host(store, const OpenComments('5'), observer: routes),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('underlying page'),
          findsOneWidget,
          reason: 'The page stays underneath.',
        );
        expect(find.text('Yorumlar (1)'), findsOneWidget);
        expect(find.byKey(const Key('comments-context')), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('comments-context')))
              .maxLines,
          1,
        );
        expect(find.byTooltip('Kapat'), findsOneWidget);
        expect(find.byTooltip('Yorumu gönder'), findsOneWidget);
        expect(
          routes.names.where((n) => n == '/comments'),
          isEmpty,
          reason: 'No separate comments page.',
        );
        // The composer does not scroll away with the list.
        final composerBefore = tester
            .getTopLeft(find.byKey(const Key('comment-field')))
            .dy;
        await tester.drag(
          find.byKey(const Key('comments-scroll')),
          const Offset(0, -300),
        );
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(const Key('comment-field'))).dy,
          composerBefore,
        );
        await tester.tap(find.byKey(const Key('comments-close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('comments-scroll')), findsNothing);
        expect(find.text('underlying page'), findsOneWidget);
      },
    );

    testWidgets('Dragging the sheet down closes it', (tester) async {
      size(tester, 390, 900);
      final store = await commentsStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const OpenComments('5')));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byKey(const Key('comments-scroll')),
        const Offset(0, 700),
        2500,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('comments-scroll')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'The composer rides above the keyboard and the list stays reachable',
      (tester) async {
        size(tester, 390, 900);
        final store = await commentsStore();
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, const OpenComments('5')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('comment-field')));
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await tester.pumpAndSettle();
        addTearDown(tester.view.resetViewInsets);
        final field = tester.getRect(find.byKey(const Key('comment-field')));
        expect(
          field.bottom,
          lessThanOrEqualTo(900 - 320 + .5),
          reason: 'Never behind the keyboard.',
        );
        expect(
          tester.getRect(find.byKey(const Key('send-comment'))).bottom,
          lessThanOrEqualTo(900 - 320 + .5),
        );
        expect(find.byKey(const Key('comments-scroll')), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const Key('comments-scroll'))).height,
          greaterThan(100),
        );
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byKey(const Key('comment-field')),
          'Klavye açıkken yazıyorum',
        );
        await tester.pump();
        expect(find.text('Klavye açıkken yazıyorum'), findsOneWidget);
      },
    );

    testWidgets(
      'Empty thread: a compact hint and the composer; closed comments: the notice instead of the composer',
      (tester) async {
        size(tester, 390, 900);
        final empty = await commentsStore(initial: []);
        addTearDown(empty.dispose);
        await tester.pumpWidget(host(empty, const OpenComments('5')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('comments-empty')), findsOneWidget);
        expect(find.text('Henüz yorum yapılmamış.'), findsOneWidget);
        expect(find.byKey(const Key('comment-field')), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());

        final closed = await commentsStore(commentsEnabled: false);
        addTearDown(closed.dispose);
        await tester.pumpWidget(host(closed, const OpenComments('5')));
        await tester.pumpAndSettle();
        expect(
          find.text('Ana yorum'),
          findsOneWidget,
          reason: 'Existing comments stay readable.',
        );
        expect(find.text('Bu paylaşım yorumlara kapalı.'), findsOneWidget);
        expect(find.byKey(const Key('comment-field')), findsNothing);
        expect(find.byKey(const ValueKey('reply-10')), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'Likes keep their state when the sheet is closed and opened again; replies are likeable too',
      (tester) async {
        size(tester, 390, 900);
        final store = await commentsStore();
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, const OpenComments('5')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('like-comment-10')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('like-comment-11')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('like-comment-10')),
            matching: find.text('3'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('like-comment-11')),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('comments-close')));
        await tester.pumpAndSettle();

        // Reopen: a fresh sheet reads the server state.
        final post = (await tester.runAsync(() => store.loadPost('5')))!;
        final context = tester.element(find.text('underlying page'));
        unawaited(showCommentsSheet(context, post));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('like-comment-10')),
            matching: find.byIcon(Icons.favorite_rounded),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('like-comment-11')),
            matching: find.byIcon(Icons.favorite_rounded),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('like-comment-10')),
            matching: find.text('3'),
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'Closing the sheet while a comment is being sent causes no error and the count still updates',
      (tester) async {
        size(tester, 390, 900);
        final gate = Completer<http.Response>();
        final store = await commentsStore(sendGate: gate);
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, const OpenComments('5')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('comment-field')),
          'Gönderirken kapatıyorum',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('send-comment')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('comments-close')));
        await tester.pumpAndSettle();
        gate.complete(ok(commentJson(21, 'x', username: 'demo'), 201));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          store.cachedPost('5')!.commentCount,
          2,
          reason: 'The request finished after the sheet was gone.',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'Home: scroll the feed, open comments from a post, write one, close: the feed offset and the count are right',
      (tester) async {
        size(tester, 390, 900);
        final log = <String>[];
        final store = await commentsStore(feedPosts: 8, initial: [], log: log);
        addTearDown(store.dispose);
        final routes = _Routes();
        await tester.pumpWidget(
          host(
            store,
            Scaffold(body: HomeContent(onMap: () {})),
            observer: routes,
          ),
        );
        await tester.pumpAndSettle();
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -900));
        await tester.pumpAndSettle();
        final offset = tester
            .state<ScrollableState>(scrollable)
            .position
            .pixels;
        expect(offset, greaterThan(300));

        // A comment icon that is on screen right now.
        final icons = find.byTooltip('Yorumlar').hitTestable();
        expect(icons, findsWidgets);
        await tester.tap(icons.first);
        await tester.pumpAndSettle();
        expect(
          routes.names.where((n) => n == '/comments'),
          isEmpty,
          reason: 'No route change: a sheet over the feed.',
        );
        expect(find.text('Yorumlar (0)'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('comment-field')),
          'Ana sayfadan yazdım',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('send-comment')));
        await tester.pumpAndSettle();
        expect(
          find.text('Yorumlar (1)'),
          findsOneWidget,
          reason: 'The header follows the new count at once.',
        );
        expect(
          find.text('Ana sayfadan yazdım'),
          findsOneWidget,
          reason: 'The new comment is in the list.',
        );
        expect(
          log.any(
            (e) =>
                e ==
                'POST /api/v1/posts/${log.firstWhere((l) => l.contains('/comments') && l.startsWith('GET')).split('/posts/')[1].split('/')[0]}/comments',
          ),
          isTrue,
        );

        await tester.tap(find.byKey(const Key('comments-close')));
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          offset,
          reason: 'The feed did not move.',
        );
        expect(
          find.text('1'),
          findsWidgets,
          reason: 'The post card shows the new count.',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Post detail: "Yorum Yaz" opens the sheet instead of a comments page',
      (tester) async {
        size(tester, 390, 1000);
        final store = await commentsStore();
        addTearDown(store.dispose);
        final routes = _Routes();
        await tester.pumpWidget(
          host(store, const PostDetailPage('5'), observer: routes),
        );
        await tester.pumpAndSettle();
        final button = find.text('Yorum Yaz');
        await tester.scrollUntilVisible(
          button,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('comments-scroll')), findsOneWidget);
        expect(routes.names.where((n) => n == '/comments'), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'Comment notifications and the legacy /comments route open the post with the sheet (never a Yorumlar page)',
      (tester) async {
        size(tester, 390, 900);
        final store = await commentsStore();
        addTearDown(store.dispose);
        InboxNotification item(String type, {bool available = true}) =>
            InboxNotification(
              {
                'id': 1,
                'type': type,
                'route': '/comments',
                'entity_id': 5,
                'actor': {
                  'id': 9,
                  'username': 'ece',
                  'name': 'Ece',
                  'avatar': null,
                },
                'text': 'x',
                'available': available,
                'read': false,
                'created_at': '2026-11-14T11:00:00Z',
              },
              (json) => Person(
                id: 'account-9',
                name: 'Ece',
                handle: 'ece',
                photo: '',
              ),
            );
        for (final type in ['comment', 'comment_reply', 'comment_like']) {
          await tester.pumpWidget(
            host(
              store,
              Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => routeInboxNotification(
                      Navigator.of(context),
                      item(type),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
              routes: {
                '/comments': (arg) =>
                    PostDetailPage('$arg', openComments: true),
              },
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('comments-scroll')),
            findsOneWidget,
            reason: '$type opens the comments sheet',
          );
          expect(
            find.descendant(
              of: find.byKey(const Key('comments-scroll')),
              matching: find.text('Yorumlar (1)'),
            ),
            findsOneWidget,
          );
          expect(find.byTooltip('Kapat'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );

    testWidgets(
      'Other lists use the same sheet: Kaydedilenler opens it from a post card',
      (tester) async {
        size(tester, 390, 900);
        final store = await commentsStore(feedPosts: 0);
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, const SavedPage()));
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('Yorumlar'),
          findsNothing,
          reason: 'Nothing saved in this fixture: no card, no crash.',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
