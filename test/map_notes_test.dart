import 'dart:convert';

import 'package:flutter/material.dart';
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
}
