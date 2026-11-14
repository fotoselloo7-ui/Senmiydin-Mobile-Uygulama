// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/data/account_api.dart';
import 'support/comments_host.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/location_service.dart';
import 'package:senmiydin/data/map_notes_api.dart';
import 'package:senmiydin/screens/auth.dart';
import 'package:senmiydin/screens/home.dart';
import 'package:senmiydin/screens/map_notes.dart';
import 'package:senmiydin/widgets/app_drawer.dart';
import 'package:senmiydin/widgets/common.dart';
import 'package:senmiydin/widgets/map_note_widgets.dart';

http.Response ok(Object? data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response fail(
  int status,
  String message, [
  Map<String, Object?>? errors,
]) => http.Response(
  jsonEncode({'success': false, 'message': message, 'errors': errors ?? {}}),
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

Map<String, dynamic> postJson(int id, String body, {int comments = 0}) => {
  'id': id,
  'body': body,
  'type': 'moment',
  'city': {'id': 1, 'name': 'Alanya'},
  'is_anonymous': false,
  'author': {'id': 21, 'username': 'ece', 'name': 'Ece Test', 'avatar': null},
  'comments_enabled': true,
  'visibility': 'city',
  'likes_count': 0,
  'comments_count': comments,
  'media': [],
  'created_at': '2026-11-14T10:00:00Z',
};

Map<String, dynamic> commentJson(
  int id,
  String body, {
  String username = 'ece',
  int? parent,
  int replyCount = 0,
  List<Map<String, dynamic>> replies = const [],
  bool mine = false,
}) => {
  'id': id,
  'body': body,
  'parent_id': parent,
  'mine': mine,
  'author': {
    'id': username.hashCode.abs() % 900 + 30,
    'username': username,
    'name': '${username.toUpperCase()} Test',
    'avatar': null,
  },
  'created_at': '2026-11-14T11:00:00Z',
  if (parent == null) 'reply_count': replyCount,
  if (parent == null) 'replies': replies,
};

Future<AppStore> connected(
  Future<http.Response> Function(http.Request) handler,
) async {
  FlutterSecureStorage.setMockInitialValues({});
  final store = AppStore(
    api: ApiClient(httpClient: MockClient(handler)),
    locationDevice: _Device(),
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
  Map<String, Widget>? routes,
  NavigatorObserver? observer,
}) => StoreScope(
  store: store,
  child: MaterialApp(
    navigatorObservers: [?observer],
    onGenerateRoute: (settings) => MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => settings.name == '/'
          ? child
          : routes?[settings.name] ??
                Scaffold(body: Text('route ${settings.name}')),
    ),
  ),
);

Map<String, dynamic> letterJson(
  int id, {
  String state = 'active',
  int replies = 0,
  bool republished = false,
  bool canRepost = false,
  bool live = false,
  String occurred = '2026-11-10T18:20:00Z',
  String created = '2026-11-10T18:20:00Z',
  String expires = '2026-11-17T18:20:00Z',
}) => {
  'id': id,
  'body': 'Yarın 11:00’de yine burada olacağım.',
  'is_anonymous': false,
  'mine': true,
  'author': null,
  'city': {'id': 1, 'name': 'Alanya', 'slug': 'alanya'},
  'place_label': 'Alanya · Yaklaşık bölge',
  'group': '36.54500_32.00000',
  'latitude': 36.545,
  'longitude': 32.0,
  'reply_count': replies,
  'state': state,
  'can_reply': false,
  'occurred_at': occurred,
  'created_at': created,
  'expires_at': expires,
  'archived_at': state == 'archived' ? '2026-11-12T10:00:00Z' : null,
  'republished': republished,
  'has_live_repost': live,
  'can_repost': canRepost,
};

void main() {
  void size(WidgetTester tester, double width, [double height = 900]) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('Takip feed', () {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets(
        'Takip is a fourth feed tab that asks for the followed feed and shows the empty state at $width px',
        (tester) async {
          size(tester, width, 1000);
          final feedQueries = <Map<String, String>>[];
          var follows = false;
          final store = await connected((request) async {
            final path = request.url.path;
            if (path.endsWith('/auth/login'))
              return ok({'token': 't', 'user': account()});
            if (path.endsWith('/cities'))
              return ok([
                {'id': 1, 'name': 'Alanya'},
              ]);
            if (path.endsWith('/feed')) {
              feedQueries.add(request.url.queryParameters);
              return ok({'items': [], 'next_page': null});
            }
            if (path.endsWith('/users/demo/following')) {
              return ok({
                'items': follows
                    ? [
                        {
                          'id': 21,
                          'username': 'ece',
                          'name': 'Ece Test',
                          'avatar': null,
                        },
                      ]
                    : [],
                'next_page': null,
              });
            }
            return ok({
              'items': [],
              'next_page': null,
              'location_required': false,
            });
          });
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
          expect(tester.takeException(), isNull);
          expect(find.text('Akış'), findsOneWidget);
          expect(find.text('Takip'), findsOneWidget);
          expect(find.text('Yakın'), findsOneWidget);
          expect(find.text('Popüler'), findsOneWidget);
          expect(
            feedQueries.every((q) => !q.containsKey('following')),
            isTrue,
            reason: 'The default feed is not the follow feed.',
          );

          await tester.ensureVisible(find.text('Takip'));
          await tester.tap(find.text('Takip'));
          await tester.pumpAndSettle();
          expect(feedQueries.last['following'], '1');
          expect(feedQueries.last['sort'], 'new');
          expect(find.text('Henüz kimseyi takip etmiyorsun.'), findsOneWidget);
          expect(find.text('İnsanları Keşfet'), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'No overflow at $width px.',
          );

          await tester.ensureVisible(find.text('İnsanları Keşfet'));
          tester
              .widget<SecondaryButton>(
                find.widgetWithText(SecondaryButton, 'İnsanları Keşfet'),
              )
              .onPressed!();
          await tester.pumpAndSettle();
          expect(
            routes.names,
            contains('/search'),
            reason: 'The CTA goes to the existing discovery (search) flow.',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          follows = true;
        },
      );
    }

    testWidgets(
      'When followed people have not posted yet the empty state says so, and followed posts paginate',
      (tester) async {
        size(tester, 390, 1400);
        var following = false;
        final store = await connected((request) async {
          final path = request.url.path;
          if (path.endsWith('/auth/login'))
            return ok({'token': 't', 'user': account()});
          if (path.endsWith('/cities'))
            return ok([
              {'id': 1, 'name': 'Alanya'},
            ]);
          if (path.endsWith('/feed') &&
              request.url.queryParameters['following'] == '1') {
            if (!following) return ok({'items': [], 'next_page': null});
            final page = request.url.queryParameters['page'] ?? '1';
            return ok(
              page == '1'
                  ? {
                      'items': [postJson(1, 'Takip edilen birinci paylaşım')],
                      'next_page': 2,
                    }
                  : {
                      'items': [postJson(2, 'Takip edilen ikinci paylaşım')],
                      'next_page': null,
                    },
            );
          }
          if (path.endsWith('/users/demo/following')) {
            return ok({
              'items': [
                {
                  'id': 21,
                  'username': 'ece',
                  'name': 'Ece Test',
                  'avatar': null,
                },
              ],
              'next_page': null,
            });
          }
          return ok({
            'items': [],
            'next_page': null,
            'location_required': false,
          });
        });
        addTearDown(store.dispose);
        await tester.pumpWidget(
          host(store, Scaffold(body: HomeContent(onMap: () {}))),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Takip'));
        await tester.tap(find.text('Takip'));
        await tester.pumpAndSettle();
        expect(
          find.text('Takip ettiklerin henüz bir şey paylaşmadı.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Anonim paylaşımlar Takip akışında yer almaz'),
          findsOneWidget,
        );

        following = true;
        await tester.ensureVisible(find.text('Akış'));
        await tester.tap(find.text('Akış'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Takip'));
        await tester.tap(find.text('Takip'));
        await tester.pumpAndSettle();
        expect(find.text('Takip edilen birinci paylaşım'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Daha Fazla Göster'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Daha Fazla Göster'));
        await tester.pumpAndSettle();
        expect(find.text('Takip edilen ikinci paylaşım'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('Comment replies', () {
    testWidgets(
      'Yanıtla starts the composer with @username, a reply is sent to its top-level comment and replies read oldest first',
      (tester) async {
        size(tester, 390, 1000);
        final sent = <Map<String, dynamic>>[];
        final replies = <Map<String, dynamic>>[
          commentJson(11, 'Saat kaç civarı?', username: 'kaan', parent: 10),
          commentJson(12, '18:30 gibi.', username: 'ece', parent: 10),
        ];
        final store = await connected((request) async {
          final path = request.url.path;
          if (path.endsWith('/auth/login'))
            return ok({'token': 't', 'user': account()});
          if (path.endsWith('/posts/5') && request.method == 'GET')
            return ok(postJson(5, 'Dün sahildeydim.', comments: 3));
          if (path.endsWith('/posts/5/comments') && request.method == 'POST') {
            sent.add(jsonDecode(request.body) as Map<String, dynamic>);
            replies.add(
              commentJson(
                13,
                'Teşekkürler!',
                username: 'demo',
                parent: 10,
                mine: true,
              ),
            );
            return http.Response(
              jsonEncode({'success': true, 'data': replies.last}),
              201,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (path.endsWith('/posts/5/comments/10/replies'))
            return ok({'items': replies, 'next_page': null});
          if (path.endsWith('/posts/5/comments')) {
            return ok({
              'items': [
                commentJson(
                  10,
                  'Ben de dün oradaydım.',
                  username: 'ece',
                  replyCount: replies.length,
                  replies: replies.take(1).toList(),
                ),
              ],
              'next_page': null,
            });
          }
          return ok({'items': [], 'next_page': null});
        });
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, const OpenComments('5')));
        await tester.pumpAndSettle();

        expect(find.text('Ben de dün oradaydım.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('reply-10')),
          findsOneWidget,
          reason: 'Every top-level comment carries a small Yanıtla action.',
        );
        expect(
          find.byKey(const ValueKey('reply-11')),
          findsNothing,
          reason: 'Replies cannot be answered.',
        );
        expect(find.text('Saat kaç civarı?'), findsOneWidget);
        expect(find.text('1 yanıt daha'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('more-replies-10')));
        await tester.pumpAndSettle();
        final order = [
          'Saat kaç civarı?',
          '18:30 gibi.',
        ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
        expect(order[0], lessThan(order[1]), reason: 'Oldest reply first.');

        await tester.tap(find.byKey(const ValueKey('reply-10')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('replying-banner')), findsOneWidget);
        expect(
          (tester
                  .widget<TextField>(find.byKey(const Key('comment-field')))
                  .controller!)
              .text,
          '@ece ',
        );
        await tester.enterText(
          find.byKey(const Key('comment-field')),
          '@ece Teşekkürler!',
        );
        await tester.tap(find.byKey(const Key('send-comment')));
        await tester.pumpAndSettle();
        expect(sent.single, {'body': '@ece Teşekkürler!', 'parent_id': '10'});
        expect(find.byKey(const Key('replying-banner')), findsNothing);
        expect(
          find.text('Teşekkürler!'),
          findsOneWidget,
          reason: 'The whole conversation, including the new reply, is shown.',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'A plain comment (no reply context) does not send a parent id, and a reply can be cancelled',
      (tester) async {
        size(tester, 390, 900);
        final sent = <Map<String, dynamic>>[];
        final store = await connected((request) async {
          final path = request.url.path;
          if (path.endsWith('/auth/login'))
            return ok({'token': 't', 'user': account()});
          if (path.endsWith('/posts/5') && request.method == 'GET')
            return ok(postJson(5, 'Dün sahildeydim.'));
          if (path.endsWith('/posts/5/comments') && request.method == 'POST') {
            sent.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              jsonEncode({
                'success': true,
                'data': commentJson(
                  20,
                  'Merhaba',
                  username: 'demo',
                  mine: true,
                ),
              }),
              201,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (path.endsWith('/posts/5/comments')) {
            return ok({
              'items': [commentJson(10, 'Ana yorum', username: 'ece')],
              'next_page': null,
            });
          }
          return ok({'items': [], 'next_page': null});
        });
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, const OpenComments('5')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('reply-10')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('cancel-reply')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('replying-banner')), findsNothing);
        await tester.enterText(
          find.byKey(const Key('comment-field')),
          'Merhaba',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('send-comment')));
        await tester.pumpAndSettle();
        expect(sent.single, {'body': 'Merhaba'});
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('Mektuplarım', () {
    Future<AppStore> letters({
      required List<Map<String, dynamic>> active,
      required List<Map<String, dynamic>> archive,
      List<String>? log,
    }) => connected((request) async {
      final path = request.url.path;
      log?.add('${request.method} $path');
      if (path.endsWith('/auth/login'))
        return ok({'token': 't', 'user': account()});
      if (path.endsWith('/my/map-notes')) {
        return ok({
          'items': request.url.queryParameters['scope'] == 'archive'
              ? archive
              : active,
          'next_page': null,
        });
      }
      if (path.endsWith('/map-notes/9/repost')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': letterJson(30, republished: true),
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (path.endsWith('/map-notes/9') && request.method == 'DELETE')
        return ok(null);
      if (path.endsWith('/my/map-notes/9')) {
        return ok({
          'note': archive.first,
          'replies': {'items': [], 'next_page': null},
        });
      }
      return ok({'items': [], 'next_page': null});
    });

    testWidgets(
      'Aktif shows body, area, replies, the letter date and what is left; Arşiv keeps expired and removed letters',
      (tester) async {
        size(tester, 320, 900);
        final store = await letters(
          active: [
            letterJson(
              1,
              replies: 4,
              expires: DateTime.now()
                  .add(const Duration(days: 2, hours: 3))
                  .toUtc()
                  .toIso8601String(),
            ),
          ],
          archive: [
            letterJson(9, state: 'expired', canRepost: true, replies: 2),
            letterJson(
              10,
              state: 'archived',
              canRepost: true,
              republished: true,
            ),
          ],
        );
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, const MyLettersPage()));
        await tester.pumpAndSettle();
        expect(find.text('Aktif'), findsOneWidget);
        expect(find.text('Arşiv'), findsOneWidget);
        expect(find.byType(ChoicePillsFinder.type), findsNothing);
        expect(find.textContaining('Yarın 11:00'), findsOneWidget);
        expect(find.textContaining('4 cevap'), findsOneWidget);
        expect(find.text('2 gün kaldı'), findsOneWidget);
        expect(find.byKey(const ValueKey('my-letter-date-1')), findsOneWidget);
        expect(
          find.textContaining('10 Kasım 2026'),
          findsWidgets,
          reason: 'The real date of the letter, with its year.',
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Arşiv'));
        await tester.pumpAndSettle();
        expect(find.text('Süresi doldu'), findsOneWidget);
        expect(find.text('Haritadan kaldırıldı'), findsOneWidget);
        expect(find.text('Tekrar paylaşıldı'), findsOneWidget);
        expect(find.text('2 gün kaldı'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'An archived letter offers Tekrar Paylaş and Kalıcı Sil to its owner only, and both reach the server',
      (tester) async {
        size(tester, 390, 1000);
        final log = <String>[];
        final store = await letters(
          active: [],
          archive: [
            letterJson(9, state: 'expired', canRepost: true, replies: 2),
          ],
          log: log,
        );
        addTearDown(store.dispose);
        await tester.pumpWidget(
          host(store, const MapNoteDetailPage(9, mine: true)),
        );
        await tester.pumpAndSettle();
        expect(log, contains('GET /api/v1/my/map-notes/9'));
        expect(find.byKey(const Key('repost-map-note')), findsOneWidget);
        expect(find.byKey(const Key('delete-map-note')), findsOneWidget);
        expect(find.byKey(const Key('archive-map-note')), findsNothing);
        expect(
          find.byKey(const Key('send-map-note-reply')),
          findsNothing,
          reason: 'An archived letter takes no replies.',
        );
        expect(
          find.textContaining('10 Kasım'),
          findsWidgets,
          reason: 'The original date is shown.',
        );

        await tester.tap(find.byKey(const Key('repost-map-note')));
        await tester.pumpAndSettle();
        expect(log, contains('POST /api/v1/map-notes/9/repost'));

        await tester.tap(find.byKey(const Key('delete-map-note')));
        await tester.pumpAndSettle();
        expect(find.text('Mektup kalıcı olarak silinsin mi?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Kalıcı Sil'));
        await tester.pumpAndSettle();
        expect(log, contains('DELETE /api/v1/map-notes/9'));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'The drawer has one Mektuplarım row with the outline envelope icon',
      (tester) async {
        final store = AppStore();
        addTearDown(store.dispose);
        await tester.pumpWidget(
          StoreScope(
            store: store,
            child: const MaterialApp(
              home: Scaffold(
                body: Text('Ana'),
                drawer: AppDrawer(currentRoute: '/home'),
              ),
            ),
          ),
        );
        tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
        await tester.pumpAndSettle();
        expect(find.text('Mektuplarım'), findsOneWidget);
        expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
        expect(
          find.byType(ListTile).evaluate().length +
              find.text('Ayarlar').evaluate().length,
          greaterThan(0),
        );
      },
    );
  });

  group('Yakındaki yeni mektuplar', () {
    Future<AppStore> nearby({
      required Map<String, dynamic> unread,
      bool module = true,
    }) => connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login'))
        return ok({'token': 't', 'user': account()});
      if (path.endsWith('/app-config'))
        return ok({
          'nearby_notes_enabled': module,
          'minimum_age': 18,
          'nearby_enabled': true,
          'featured_enabled': true,
        });
      if (path.endsWith('/map/notes/unread')) return ok(unread);
      if (path.endsWith('/cities'))
        return ok([
          {'id': 1, 'name': 'Alanya'},
        ]);
      return ok({'items': [], 'next_page': null, 'location_required': false});
    });

    testWidgets(
      'A small card appears only with unopened nearby letters and opens the map in Notlar',
      (tester) async {
        size(tester, 320, 1000);
        var opened = false;
        final store = await nearby(
          unread: {'count': 4, 'location_required': false, 'enabled': true},
        );
        addTearDown(store.dispose);
        store.nearbyUnread = const MapNoteUnread(4);
        await tester.pumpWidget(
          host(store, Scaffold(body: HomeContent(onMap: () => opened = true))),
        );
        await tester.pumpAndSettle();
        expect(find.text('Yakınında 4 yeni mektup var'), findsOneWidget);
        expect(find.text('Haritada keşfet'), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const Key('nearby-letters-card'))).height,
          lessThan(72),
          reason: 'A compact card, not a big module.',
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('nearby-letters-card')));
        expect(opened, isTrue);
        expect(
          store.openMapInNotes,
          isTrue,
          reason: 'The map opens straight in Notlar.',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    for (final (label, unread, module) in [
      (
        'zero unread',
        {'count': 0, 'location_required': false, 'enabled': true},
        true,
      ),
      (
        'no location permission',
        {'count': 3, 'location_required': true, 'enabled': true},
        true,
      ),
      (
        'the admin module switched off',
        {'count': 3, 'location_required': false, 'enabled': true},
        false,
      ),
    ]) {
      testWidgets('No card with $label', (tester) async {
        size(tester, 390, 1000);
        final store = await nearby(unread: unread, module: module);
        addTearDown(store.dispose);
        store.nearbyUnread = MapNoteUnread(
          unread['count'] as int,
          locationRequired: unread['location_required'] == true,
        );
        store.nearbyNotesEnabled = module;
        await tester.pumpWidget(
          host(store, Scaffold(body: HomeContent(onMap: () {}))),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('nearby-letters-card')), findsNothing);
        expect(find.textContaining('yeni mektup var'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    test('Reading a letter only counts through the detail request and lowers the private unread count', () async {
      final store = await connected((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login'))
          return ok({'token': 't', 'user': account()});
        if (path.endsWith('/map-notes/5/read'))
          return ok({'count': 2, 'location_required': false, 'enabled': true});
        return ok({'items': [], 'next_page': null});
      });
      store.nearbyUnread = const MapNoteUnread(3);
      await store.markMapNoteRead(5);
      expect(store.nearbyUnread.count, 2);
      store.dispose();
    });
  });

  group('Age gate', () {
    testWidgets(
      'The registration age comes from the server config, not from hardcoded text',
      (tester) async {
        size(tester, 390, 1000);
        final store = await connected((request) async {
          final path = request.url.path;
          if (path.endsWith('/auth/login'))
            return ok({'token': 't', 'user': account()});
          if (path.endsWith('/app-config')) return ok({'minimum_age': 16});
          return ok({'items': [], 'next_page': null});
        });
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, const AuthPage(register: true)));
        await tester.pumpAndSettle();
        expect(store.minimumAge, 16);
        expect(find.textContaining('16 yaşını doldurdum'), findsOneWidget);
        expect(find.textContaining('18 yaşını'), findsNothing);
        await tester.ensureVisible(find.text('Doğum Tarihi'));
        await tester.tap(find.text('Doğum Tarihi'));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        final help = find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data ?? '').toLowerCase().contains('yaşını doldurmalısın'),
          ),
        );
        expect(help, findsOneWidget);
        expect(
          tester.widget<Text>(help).data,
          'Devam etmek için 16 yaşını doldurmalısın',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    test('Default is the production minimum 16 until the server says otherwise', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = AppStore(
        api: ApiClient(httpClient: MockClient((_) async => ok({}))),
        locationDevice: _Device(),
      );
      expect(store.minimumAge, 16);
      store.dispose();
    });
  });

  testWidgets('MyLetterCard shows the archive state of an expired letter', (
    tester,
  ) async {
    final note = MapNoteItem.fromJson(
      letterJson(3, state: 'expired', canRepost: true),
      (json) => throw StateError('no author'),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MyLetterCard(note))),
    );
    expect(find.text('Süresi doldu'), findsOneWidget);
    expect(note.canRepost, isTrue);
    expect(note.isActive, isFalse);
  });
}

/// Placeholder so the expectation above documents that the filter pills are plain choice pills (no extra tab widgets).
class ChoicePillsFinder {
  static const type = TabBar;
}
