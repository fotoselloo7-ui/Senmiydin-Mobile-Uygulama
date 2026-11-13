import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/communication_api.dart';
import 'package:senmiydin/data/location_service.dart';
import 'package:senmiydin/data/map_notes_api.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/screens/live_map.dart';
import 'package:senmiydin/screens/live_notifications.dart';
import 'package:senmiydin/screens/map_notes.dart';
import 'package:senmiydin/screens/settings.dart';
import 'package:senmiydin/widgets/map_note_widgets.dart';

Map<String, dynamic> noteJson({
  int id = 1,
  String body = 'Çok güzeldin kırmızı başlıklı kız.',
  bool anonymous = false,
  bool mine = false,
  int replies = 0,
  bool canReply = true,
  String created = '2026-11-14T11:15:00Z',
}) => {
  'id': id,
  'body': body,
  'is_anonymous': anonymous,
  'mine': mine,
  'author': anonymous
      ? null
      : {'id': 7, 'username': 'ada', 'name': 'Ada Test', 'avatar': null},
  'city': {'id': 1, 'name': 'Alanya', 'slug': 'alanya'},
  'place_label': 'Alanya · Yaklaşık bölge',
  'group': '36.54500_32.00000',
  'latitude': 36.545,
  'longitude': 32.0,
  'reply_count': replies,
  'can_reply': canReply,
  'created_at': created,
  'expires_at': '2026-11-21T11:15:00Z',
};

Map<String, dynamic> replyJson(
  int id,
  String body, {
  bool anonymous = false,
  bool mine = false,
  bool fromAuthor = false,
}) => {
  'id': id,
  'body': body,
  'is_anonymous': anonymous || fromAuthor,
  'mine': mine,
  'from_note_author': fromAuthor,
  'author': anonymous || fromAuthor
      ? null
      : {'id': 9, 'username': 'ece', 'name': 'Ece Test', 'avatar': null},
  'created_at': '2026-11-14T11:42:00Z',
};

http.Response ok(Object? data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response fail(int status, String message, [Map<String, Object?>? errors]) =>
    http.Response(
      jsonEncode({'success': false, 'message': message, 'errors': errors ?? {}}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

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
  'push_preferences': {'map_note_nearby': true, 'map_note_reply': true},
};

Future<AppStore> connected(
  Future<http.Response> Function(http.Request) handler,
) async {
  FlutterSecureStorage.setMockInitialValues({});
  final calls = ApiClient(httpClient: MockClient(handler));
  final store = AppStore(api: calls, locationDevice: _Device());
  await store.signIn('login', {'identifier': 'demo', 'password': 'x'});
  return store;
}

class _Device extends LocationDevice {
  @override
  bool get supportsBackground => false;
}

Widget host(AppStore store, Widget child, {double scale = 1}) => StoreScope(
  store: store,
  child: MaterialApp(
    builder: (context, page) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: page!,
    ),
    home: child,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Note times read as Bugün, Dün or the date, in the device clock', () {
    final now = DateTime(2026, 11, 14, 16, 0);
    expect(mapNoteTime(DateTime(2026, 11, 14, 14, 32), now: now), 'Bugün · 14:32');
    expect(mapNoteTime(DateTime(2026, 11, 13, 22, 18), now: now), 'Dün · 22:18');
    expect(mapNoteTime(DateTime(2026, 11, 11, 17, 4), now: now), '11 Kasım · 17:04');
    expect(mapNoteTime(DateTime(2026, 1, 2, 9, 5), now: now), '2 Ocak · 09:05');
  });

  testWidgets('The envelope pin is a brand-purple outline icon with a count only for several notes', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MapNotePin(count: 1, onPressed: () => taps++),
              MapNotePin(count: 5, onPressed: () => taps++),
            ],
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.mail_outline_rounded), findsNWidgets(2));
    expect(find.text('5'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(Icons.mail_outline_rounded).first);
    expect(icon.color, const Color(0xFF7C20D4));
    expect(find.bySemanticsLabel('Haritadaki not'), findsOneWidget);
    expect(find.bySemanticsLabel('Haritadaki 5 not'), findsOneWidget);
    await tester.tap(find.text('5'));
    expect(taps, 1);
  });

  testWidgets('Open and anonymous letters render, anonymous ones carry no identity', (tester) async {
    final people = <String, Person>{};
    Person remember(Map<String, dynamic> json) => people.putIfAbsent(
      'account-${json['id']}',
      () => Person(
        id: 'account-${json['id']}',
        name: json['name'] as String,
        handle: json['username'] as String,
        photo: '',
        remote: true,
      ),
    );
    final open = MapNoteItem.fromJson(noteJson(replies: 3), remember);
    final anonymous = MapNoteItem.fromJson(noteJson(id: 2, anonymous: true, body: 'Belki bir gün.'), remember);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: [MapNoteLetter(open), MapNoteLetter(anonymous)]),
        ),
      ),
    );
    expect(find.text('Çok güzeldin kırmızı başlıklı kız.'), findsOneWidget);
    expect(find.text('Ada Test'), findsOneWidget);
    expect(find.text('@ada'), findsOneWidget);
    expect(find.text('3 yanıt'), findsOneWidget);
    expect(find.text('Anonim'), findsOneWidget);
    expect(find.text('Belki bir gün.'), findsOneWidget);
    expect(find.text('Alanya · Yaklaşık bölge'), findsNWidgets(2));
    expect(find.byIcon(Icons.mail_outline_rounded), findsNWidgets(2));
    expect(anonymous.author, isNull);
    expect(people.length, 1, reason: 'Only the open note registers an author.');
  });

  testWidgets('Letters and replies do not overflow at 320 px wide with 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final note = MapNoteItem.fromJson(
      noteJson(body: 'Çok uzun bir not ${'metin ' * 60}'),
      (json) => Person(id: 'account-7', name: 'Ada Çok Uzun Bir Kullanıcı Adı Soyadı', handle: 'ada_cok_uzun_kullanici', photo: '', remote: true),
    );
    final reply = MapNoteReplyItem.fromJson(
      replyJson(2, 'Yanıt ${'metin ' * 40}', fromAuthor: true),
      (json) => Person(id: 'account-9', name: 'Ece', handle: 'ece', photo: ''),
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 700), textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MapNoteLetter(note, actions: [TextButton(onPressed: () {}, child: const Text('Şikâyet Et'))]),
                  MapNoteReplyTile(reply, onReport: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Not sahibi'), findsOneWidget);
  });

  testWidgets('Note detail lists replies oldest first, anonymous replies without identity, and sends a reply', (tester) async {
    var posted = <String, dynamic>{};
    final store = await connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.endsWith('/map-notes/1') && request.method == 'GET') {
        return ok({
          'note': noteJson(replies: 2),
          'replies': {
            'items': [replyJson(10, 'O kişi bendim.'), replyJson(11, 'Ciddi misin? :)', anonymous: true)],
            'next_page': null,
          },
        });
      }
      if (path.endsWith('/map-notes/1/replies') && request.method == 'POST') {
        posted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'data': replyJson(12, 'Evet.', mine: true)}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return ok({'items': [], 'next_page': null});
    });
    addTearDown(store.dispose);
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(store, const MapNoteDetailPage(1)));
    await tester.pumpAndSettle();
    expect(find.text('Çok güzeldin kırmızı başlıklı kız.'), findsOneWidget);
    expect(find.text('2 yanıt'), findsWidgets);
    final first = tester.getTopLeft(find.text('O kişi bendim.')).dy;
    final second = tester.getTopLeft(find.text('Ciddi misin? :)')).dy;
    expect(first, lessThan(second), reason: 'Replies read oldest to newest.');
    expect(find.text('@ece'), findsOneWidget);
    expect(find.text('Anonim'), findsOneWidget);
    expect(find.text('Şikâyet Et'), findsOneWidget);
    expect(find.byKey(const Key('delete-map-note')), findsNothing);

    await tester.tap(find.text('Anonim yanıt'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('map-note-reply-field')), 'Evet.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-map-note-reply')));
    await tester.pumpAndSettle();
    expect(posted['body'], 'Evet.');
    expect(posted['is_anonymous'], true);
    expect(posted['request_id'], isNotEmpty);
    expect(find.text('Evet.'), findsOneWidget);
    expect(find.text('3 yanıt'), findsWidgets);
    final field = tester.widget<TextField>(find.byKey(const Key('map-note-reply-field')));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('A failed reply keeps the text and a retry reuses the same request id', (tester) async {
    final requestIds = <String>[];
    var failures = 1;
    final store = await connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.endsWith('/map-notes/1') && request.method == 'GET') {
        return ok({'note': noteJson(), 'replies': {'items': [], 'next_page': null}});
      }
      if (path.endsWith('/map-notes/1/replies') && request.method == 'POST') {
        requestIds.add((jsonDecode(request.body) as Map)['request_id'] as String);
        if (failures-- > 0) return http.Response('<html>Laravel stack trace</html>', 500);
        return http.Response(
          jsonEncode({'success': true, 'data': replyJson(5, 'Tekrar deniyorum', mine: true)}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return ok({'items': [], 'next_page': null});
    });
    addTearDown(store.dispose);
    await tester.pumpWidget(host(store, const MapNoteDetailPage(1)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-note-reply-field')), 'Tekrar deniyorum');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-map-note-reply')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Yazdığın metin korunur'), findsOneWidget);
    expect(find.textContaining('Laravel'), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('map-note-reply-field'))).controller!.text, 'Tekrar deniyorum');
    await tester.tap(find.byKey(const Key('send-map-note-reply')));
    await tester.pumpAndSettle();
    expect(requestIds.length, 2);
    expect(requestIds[0], requestIds[1], reason: 'Idempotent retry.');
    expect(find.text('Tekrar deniyorum'), findsOneWidget);
  });

  testWidgets('Own notes can be deleted, expired or removed notes explain themselves, load errors retry', (tester) async {
    var online = false;
    var deleted = false;
    final store = await connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.endsWith('/map-notes/1') && request.method == 'DELETE') {
        deleted = true;
        return ok(null);
      }
      if (path.endsWith('/map-notes/1')) {
        if (!online) return http.Response('<html>boom</html>', 500);
        return ok({'note': noteJson(mine: true, anonymous: true), 'replies': {'items': [], 'next_page': null}});
      }
      if (path.endsWith('/map-notes/2')) return fail(404, 'Aradığın kayıt bulunamadı.');
      return ok({'items': [], 'next_page': null});
    });
    addTearDown(store.dispose);

    await tester.pumpWidget(host(store, const MapNoteDetailPage(1)));
    await tester.pumpAndSettle();
    expect(find.text('Not yüklenemedi'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
    online = true;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();
    expect(find.text('Anonim'), findsWidgets);
    expect(find.text('Şikâyet Et'), findsNothing);
    expect(find.text('Not sahibi olarak yanıtlarsın; kimliğin görünmez.'), findsOneWidget);
    expect(find.text('Anonim yanıt'), findsNothing, reason: 'The owner of an anonymous note cannot unmask themselves.');
    await tester.tap(find.byKey(const Key('delete-map-note')));
    await tester.pumpAndSettle();
    expect(find.text('Notu silmek istiyor musun?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Notu Sil'));
    await tester.pumpAndSettle();
    expect(deleted, true);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host(store, const MapNoteDetailPage(2)));
    await tester.pumpAndSettle();
    expect(find.text('Bu not artık kullanılamıyor.'), findsOneWidget);
    expect(find.byKey(const Key('send-map-note-reply')), findsNothing);
  });

  testWidgets('A note that no longer accepts replies hides the reply field', (tester) async {
    final store = await connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.endsWith('/map-notes/1')) {
        return ok({'note': noteJson(canReply: false), 'replies': {'items': [], 'next_page': null}});
      }
      return ok({'items': [], 'next_page': null});
    });
    addTearDown(store.dispose);
    await tester.pumpWidget(host(store, const MapNoteDetailPage(1)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-note-reply-field')), findsNothing);
  });

  testWidgets('The point list shows newest notes first, a header count and loads the next page', (tester) async {
    final store = await connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.contains('/map/notes/')) {
        final page = request.url.queryParameters['page'];
        return ok({
          'group': '36.54500_32.00000',
          'count': 3,
          'place_label': 'Alanya · Yaklaşık bölge',
          'items': page == '2'
              ? [noteJson(id: 1, body: 'En eski not')]
              : [noteJson(id: 3, body: 'En yeni not'), noteJson(id: 2, body: 'Ortadaki not')],
          'next_page': page == '2' ? null : 2,
        });
      }
      return ok({'items': [], 'next_page': null});
    });
    addTearDown(store.dispose);
    await tester.pumpWidget(host(store, const MapNotePointPage('36.54500_32.00000')));
    await tester.pumpAndSettle();
    expect(find.text('Alanya · Yaklaşık bölge · 3 not'), findsOneWidget);
    expect(tester.getTopLeft(find.text('En yeni not')).dy, lessThan(tester.getTopLeft(find.text('Ortadaki not')).dy));
    await tester.tap(find.text('Daha Fazla Göster'));
    await tester.pumpAndSettle();
    expect(find.text('En eski not'), findsOneWidget);
  });

  testWidgets('The map offers İnsanlar, Paylaşımlar and Notlar; Notlar shows envelope pins with counts and the CTA', (tester) async {
    final store = await connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.endsWith('/cities')) return ok([{'id': 1, 'name': 'Alanya'}]);
      if (path.endsWith('/map/notes')) {
        return ok({
          'items': [
            {'group': '36.54500_32.00000', 'latitude': 36.545, 'longitude': 32.0, 'count': 5, 'newest_at': '2026-11-14T11:15:00Z', 'distance_meters': null},
            {'group': '36.60000_32.10000', 'latitude': 36.6, 'longitude': 32.1, 'count': 1, 'newest_at': '2026-11-13T11:15:00Z', 'distance_meters': null},
          ],
          'location_required': false,
        });
      }
      return ok({'items': [], 'location_required': false});
    });
    addTearDown(store.dispose);
    await tester.pumpWidget(host(store, const Scaffold(body: LiveMapContent())));
    await tester.pumpAndSettle();
    expect(find.text('İnsanlar'), findsOneWidget);
    expect(find.text('Paylaşımlar'), findsOneWidget);
    expect(find.text('Notlar'), findsOneWidget);
    expect(find.byKey(const Key('leave-map-note')), findsNothing, reason: 'Only the Notlar view carries the CTA.');
    await tester.tap(find.byKey(const Key('map-notes-tab')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mail_outline_rounded), findsWidgets);
    expect(find.text('5'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-note-36.54500_32.00000')), findsOneWidget);
    expect(find.text('Buraya Not Bırak'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsNothing, reason: 'Notes are not post pins.');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('An empty Notlar view says so and still offers the CTA; errors retry', (tester) async {
    var online = false;
    final store = await connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.endsWith('/cities')) return ok([{'id': 1, 'name': 'Alanya'}]);
      if (path.endsWith('/map/notes')) {
        if (!online) return http.Response('<html>Laravel</html>', 500);
        return ok({'items': [], 'location_required': false});
      }
      return ok({'items': [], 'location_required': false});
    });
    addTearDown(store.dispose);
    await tester.pumpWidget(host(store, const Scaffold(body: LiveMapContent())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-notes-tab')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Notlar yüklenemedi'), findsOneWidget);
    expect(find.textContaining('Laravel'), findsNothing);
    online = true;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Bu bölgede henüz bir not yok. İlk notu sen bırakabilirsin.'), findsOneWidget);
    expect(find.text('Buraya Not Bırak'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Notification settings list both map note preferences separately from the location ones', (tester) async {
    final store = await connected((request) async {
      if (request.url.path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      return ok({'items': [], 'next_page': null});
    });
    addTearDown(store.dispose);
    await tester.pumpWidget(host(store, const PreferencesPage(initial: 'Bildirimler')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Notlarıma gelen cevaplar'), 200);
    expect(find.text('Yakınıma bırakılan notlar'), findsOneWidget);
    expect(find.text('Notlarıma gelen cevaplar'), findsOneWidget);
    expect(find.text('Geçtiğim Yerlerden Haber Ver'), findsOneWidget);
    expect(find.text('Yakın bölge aktiviteleri'), findsOneWidget);
  });

  testWidgets('Map note notifications route to the note; unavailable ones say so safely', (tester) async {
    final people = <String, Person>{};
    Person person(Map<String, dynamic> json) => people.putIfAbsent('account-${json['id']}', () => Person(id: 'account-${json['id']}', name: 'x', handle: 'x', photo: ''));
    InboxNotification inbox({required bool available}) => InboxNotification({
      'id': 1,
      'type': 'map_note_nearby',
      'route': '/map-note',
      'entity_id': 42,
      'actor': null,
      'text': 'Yakınına bir not bırakıldı.',
      'subtitle': 'Birisi bulunduğun bölgede dijital bir not bıraktı.',
      'available': available,
      'read': false,
      'created_at': '2026-11-14T11:15:00Z',
    }, person);
    final routed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          routed.add('${settings.name}:${settings.arguments}');
          return MaterialPageRoute<void>(settings: settings, builder: (_) => const Scaffold(body: Text('hedef')));
        },
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(onPressed: () => routeInboxNotification(Navigator.of(context), inbox(available: true)), child: const Text('aç')),
                TextButton(onPressed: () => routeInboxNotification(Navigator.of(context), inbox(available: false)), child: const Text('kapalı')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('kapalı'));
    await tester.pump();
    expect(find.text('Bu içerik artık kullanılamıyor.'), findsOneWidget);
    expect(routed, isEmpty);
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(routed, ['/map-note:42']);
    expect(inbox(available: true).subtitle, 'Birisi bulunduğun bölgede dijital bir not bıraktı.');
  });

  group('Placement and camera after leaving a note', () {
    // Server answer: the coordinate the backend snapped the selection to (point C).
    const snappedLat = 36.4385, snappedLng = 32.2065, snappedGroup = '36.43850_32.20650';

    Map<String, dynamic> created() => {
      ...noteJson(id: 9, body: 'Konum dogrulama notu', mine: true),
      'group': snappedGroup,
      'latitude': snappedLat,
      'longitude': snappedLng,
    };

    Map<String, dynamic> markers(List<Map<String, dynamic>> items) => {'items': items, 'location_required': false};

    Map<String, dynamic> snappedMarker() => {
      'group': snappedGroup, 'latitude': snappedLat, 'longitude': snappedLng,
      'count': 1, 'newest_at': '2026-11-14T11:15:00Z', 'distance_meters': null,
    };

    Widget app(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => switch (settings.name) {
            '/map-note-compose' => switch (settings.arguments) {
              (LatLng center, double zoom) => MapNoteComposePage(center: center, zoom: zoom),
              _ => const MapNoteComposePage(),
            },
            _ => const Scaffold(body: LiveMapContent()),
          },
        ),
        initialRoute: '/',
      ),
    );

    MapCamera camera(WidgetTester tester) => MapCamera.of(tester.element(find.byType(MarkerLayer)));

    testWidgets('The map goes to the SERVER snapped point C, not to its old camera A or the composer selection B', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Map<String, dynamic>? posted;
      var serverMarkers = <Map<String, dynamic>>[];
      final store = await connected((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
        if (path.endsWith('/cities')) return ok([{'id': 1, 'name': 'Alanya'}]);
        if (path.endsWith('/map/notes') && request.method == 'GET') return ok(markers(serverMarkers));
        if (path.endsWith('/map-notes') && request.method == 'POST') {
          posted = jsonDecode(request.body) as Map<String, dynamic>;
          serverMarkers = [snappedMarker()];
          return http.Response(
            jsonEncode({'success': true, 'data': created()}),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return ok({'items': [], 'location_required': false});
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-notes-tab')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final cameraA = camera(tester).center;

      await tester.tap(find.byKey(const Key('leave-map-note')));
      await tester.pumpAndSettle();
      // The visual target is exactly the map centre, i.e. exactly the coordinate that is saved.
      expect(tester.getCenter(find.byKey(const Key('map-note-target'))), tester.getCenter(find.byType(FlutterMap)));
      await tester.drag(find.byType(FlutterMap), const Offset(-180, 120));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byKey(const Key('map-note-field')), 'Konum dogrulama notu');
      await tester.tap(find.text('Notu Bırak'));
      await tester.pumpAndSettle();

      final selected = LatLng(posted!['latitude'] as double, posted!['longitude'] as double);
      expect(selected, isNot(cameraA), reason: 'The composer map was panned away from A.');
      expect((selected.latitude - snappedLat).abs(), greaterThan(0.5), reason: 'B is nowhere near the snapped answer C in this scenario.');

      final now = camera(tester);
      expect(now.center.latitude, closeTo(snappedLat, 1e-6), reason: 'Camera follows the server answer C.');
      expect(now.center.longitude, closeTo(snappedLng, 1e-6));
      expect(now.center, isNot(cameraA));
      expect(now.center.latitude, isNot(closeTo(selected.latitude, 0.01)), reason: 'B is not authoritative.');
      expect(now.zoom, greaterThanOrEqualTo(14));
      // The pin exists exactly once at C and is inside the visible map.
      final pin = find.byKey(const ValueKey('map-note-$snappedGroup'));
      expect(pin, findsOneWidget);
      final mapRect = tester.getRect(find.byType(FlutterMap));
      expect(mapRect.contains(tester.getCenter(pin)), isTrue);
      expect(find.byKey(const Key('map-note-halo')), findsOneWidget, reason: 'A fresh note is briefly highlighted.');
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('map-note-halo')), findsNothing, reason: 'The halo disappears after about two seconds.');
      expect(find.byKey(const ValueKey('map-note-$snappedGroup')), findsOneWidget);
      expect(find.text('Notlar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('A reload that was started before the note existed can never remove the new marker', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final stale = Completer<http.Response>();
      var calls = 0;
      final store = await connected((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
        if (path.endsWith('/cities')) return ok([{'id': 1, 'name': 'Alanya'}]);
        if (path.endsWith('/map/notes') && request.method == 'GET') {
          calls++;
          if (calls == 1) return stale.future; // in flight while the user leaves a note
          return ok(markers([snappedMarker()]));
        }
        if (path.endsWith('/map-notes') && request.method == 'POST') {
          return http.Response(
            jsonEncode({'success': true, 'data': created()}),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return ok({'items': [], 'location_required': false});
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-notes-tab')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(calls, 1);
      expect(find.byKey(const Key('map-notes-loading')), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget, reason: 'Loading never unmounts the map.');

      await tester.tap(find.byKey(const Key('leave-map-note')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('map-note-field')), 'Konum dogrulama notu');
      await tester.tap(find.text('Notu Bırak'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      // Optimistic marker is visible before the reload answers.
      expect(find.byKey(const ValueKey('map-note-$snappedGroup')), findsOneWidget);

      // The old snapshot (no notes) arrives late: it must be ignored.
      stale.complete(ok(markers([])));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('map-note-$snappedGroup')), findsOneWidget);
      expect(calls, greaterThanOrEqualTo(2));
      expect(camera(tester).center.latitude, closeTo(snappedLat, 1e-6));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Map controls and the OpenStreetMap attribution', () {
    Future<AppStore> mapStore({required bool withNotes}) => connected((request) async {
          final path = request.url.path;
          if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
          if (path.endsWith('/cities')) return ok([{'id': 1, 'name': 'Alanya'}]);
          if (path.endsWith('/map/notes')) {
            return ok({
              'items': withNotes
                  ? [
                      {'group': '36.54500_32.00000', 'latitude': 36.545, 'longitude': 32.0, 'count': 5, 'newest_at': '2026-11-14T11:15:00Z', 'distance_meters': null},
                    ]
                  : [],
              'location_required': false,
            });
          }
          return ok({'items': [], 'location_required': false});
        });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      for (final withNotes in [true, false]) {
        testWidgets('Notlar at $width px (${withNotes ? 'with notes' : 'empty'}): short attribution top-left, CTA and location button never overlap', (tester) async {
          tester.view.physicalSize = Size(width, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final store = await mapStore(withNotes: withNotes);
          addTearDown(store.dispose);
          await tester.pumpWidget(host(store, const Scaffold(body: LiveMapContent())));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const Key('map-notes-tab')));
          await tester.tap(find.byKey(const Key('map-notes-tab')));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: 'No overflow at $width px.');
          expect(find.text('© OpenStreetMap'), findsOneWidget);
          expect(find.textContaining('contributors'), findsNothing);

          final map = tester.getRect(find.byType(FlutterMap));
          final pill = tester.getRect(find.descendant(of: find.byKey(const Key('map-attribution')), matching: find.byType(DecoratedBox)).first);
          final cta = tester.getRect(find.byKey(const Key('leave-map-note')));
          final locate = tester.getRect(find.byTooltip('Cihaz konumunu kontrol et'));

          expect(map.contains(pill.topLeft) && map.contains(pill.bottomRight), isTrue, reason: 'Attribution stays inside the map.');
          expect(pill.left - map.left, lessThan(16), reason: 'Top-left corner.');
          expect(pill.top - map.top, lessThan(16));
          expect(pill.height, lessThan(30), reason: 'A small pill, not a box.');
          expect(pill.width, lessThan(200), reason: 'Even in the wide test font the pill stays compact.');
          expect(pill.overlaps(cta), isFalse);
          expect(pill.overlaps(locate), isFalse);
          expect(cta.overlaps(locate), isFalse);
          expect(locate.left - cta.right, greaterThanOrEqualTo(8), reason: 'Breathing room between the CTA and the location button.');
          expect(cta.left, greaterThanOrEqualTo(map.left));
          expect(locate.right, lessThanOrEqualTo(map.right));
          expect((cta.center.dy - locate.center.dy).abs(), lessThan(8), reason: 'They sit on one row.');
          if (!withNotes) {
            final info = tester.getRect(find.text('Bu bölgede henüz bir not yok. İlk notu sen bırakabilirsin.'));
            expect(info.overlaps(pill), isFalse, reason: 'Top overlays never cover the attribution.');
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }

    testWidgets('At 320 px with 1.5x text the CTA label shrinks instead of overflowing', (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await mapStore(withNotes: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, MediaQuery(data: const MediaQueryData(size: Size(320, 760), textScaler: TextScaler.linear(1.5)), child: const Scaffold(body: LiveMapContent()))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('map-notes-tab')));
          await tester.tap(find.byKey(const Key('map-notes-tab')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const Key('leave-map-note'))).overlaps(tester.getRect(find.byTooltip('Cihaz konumunu kontrol et'))), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('The attribution is tappable and the people and posts views carry the same one', (tester) async {
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await mapStore(withNotes: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const Scaffold(body: LiveMapContent())));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('© OpenStreetMap'), findsOneWidget);
      expect(tester.widget<GestureDetector>(find.byKey(const Key('map-attribution'))).onTap, isNotNull);
      expect(tester.getSemantics(find.byKey(const Key('map-attribution'))).label, contains('OpenStreetMap'));
      await tester.ensureVisible(find.text('Paylaşımlar'));
      await tester.tap(find.text('Paylaşımlar'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('© OpenStreetMap'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('The note composer map carries the same attribution', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await mapStore(withNotes: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const MapNoteComposePage(center: LatLng(36.5, 32.0), zoom: 14)));
      await tester.pumpAndSettle();
      expect(find.text('© OpenStreetMap'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
