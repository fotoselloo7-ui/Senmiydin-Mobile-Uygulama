import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/map_notes_api.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/screens/map_notes.dart';
import 'package:senmiydin/widgets/map_note_widgets.dart';

import 'support/chat_harness.dart' show loadAppFont;

Map<String, dynamic> noteJson({
  int id = 1,
  String body = 'Çok güzeldin kırmızı başlıklı kız.',
  bool anonymous = false,
  bool mine = false,
  String? image,
  String state = 'active',
  bool republished = false,
  String created = '2026-11-14T11:15:00Z',
  String? occurred,
}) => {
  'id': id,
  'body': body,
  'is_anonymous': anonymous,
  'mine': mine,
  'author': anonymous ? null : {'id': 7, 'username': 'ada', 'name': 'Ada Test', 'avatar': null},
  'city': {'id': 1, 'name': 'Alanya', 'slug': 'alanya'},
  'place_label': 'Alanya · Yaklaşık bölge',
  'group': '36.54500_32.00000',
  'latitude': 36.545,
  'longitude': 32.0,
  'reply_count': 0,
  'can_reply': true,
  'created_at': created,
  'occurred_at': ?occurred,
  'expires_at': '2026-11-21T11:15:00Z',
  'image': ?image,
  'state': state,
  'republished': republished,
  'can_repost': state != 'active',
};

http.Response ok(Object? data, [int status = 200]) => http.Response(
  jsonEncode({'success': true, 'data': data}),
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
  'push_preferences': {},
};

Future<AppStore> connected(Future<http.Response> Function(http.Request) handler) async {
  FlutterSecureStorage.setMockInitialValues({});
  final store = AppStore(api: ApiClient(httpClient: MockClient(handler)));
  await store.signIn('login', {'identifier': 'demo', 'password': 'x'});
  return store;
}

Future<AppStore> quietStore() => connected((request) async {
  if (request.url.path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
  return ok({'items': []});
});

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

/// A real PNG file the fake picker hands out.
String tinyPng() {
  final file = File('${Directory.systemTemp.path}/senmiydin_note_photo_test.png');
  file.writeAsBytesSync(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ));
  return file.path;
}

/// Real-time waits (file reads) interleaved with pumps until [done].
Future<void> until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFont);

  const picker = MethodChannel('plugins.flutter.io/image_picker');
  final pickerCalls = <MethodCall>[];
  var pickerFails = false;

  const paths = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() {
    // flutter_map keeps a tile cache folder
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(paths, (call) async => Directory.systemTemp.path);
    pickerCalls.clear();
    pickerFails = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(picker, (call) async {
      pickerCalls.add(call);
      if (pickerFails) throw PlatformException(code: 'denied');
      return tinyPng();
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(picker, null));

  Person person(Map<String, dynamic> json) => Person(
    id: 'account-${json['id']}',
    name: json['name'] as String,
    handle: json['username'] as String,
    photo: '',
    remote: true,
  );

  group('Private media authorization', () {
    test('The token is sent for post photos, message photos, voice messages and letter photos, memory photos, and for nothing else', () async {
      final store = await quietStore();
      addTearDown(store.dispose);
      String url(String path) => ApiClient.mediaUrl('/api/v1/$path');
      for (final path in ['post-media/3', 'message-images/9', 'message-audio/115', 'map-notes/16/image', 'memory-media/12', 'memory-media/12/thumb']) {
        expect(store.mediaHeaders(url(path)), {'Authorization': 'Bearer t'}, reason: path);
      }
      for (final path in ['avatars/x.jpg', 'map-notes/16', 'map-notes/16/image/extra', 'map-notes/abc/image', 'users/1', 'memories/12', 'memory-media/abc', 'memory-media/12/other']) {
        expect(store.mediaHeaders(url(path)), isEmpty, reason: path);
      }
      expect(store.mediaHeaders('https://evil.example/api/v1/message-audio/1'), isEmpty, reason: 'Never another origin.');
    });
  });

  group('The letter model and card', () {
    test('A note with an image exposes it; one without has none and a foreign host is dropped', () {
      final withImage = MapNoteItem.fromJson(noteJson(image: '/api/map-notes/1/image'), person);
      expect(withImage.hasImage, isTrue);
      expect(withImage.image, endsWith('/map-notes/1/image'));
      expect(MapNoteItem.fromJson(noteJson(), person).hasImage, isFalse);
      final foreign = MapNoteItem.fromJson(noteJson(image: 'http://evil.example/x.png'), person);
      expect(foreign.hasImage, isFalse, reason: 'Only the app’s own origin (or https) may be loaded.');
    });

    testWidgets('A letter shows its photo; a letter without one shows none', (tester) async {
      final withPhoto = MapNoteItem.fromJson(noteJson(image: '/api/map-notes/1/image'), person);
      final without = MapNoteItem.fromJson(noteJson(id: 2, body: 'Fotoğrafsız.'), person);
      final store = await quietStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, Scaffold(body: ListView(children: [MapNoteLetter(withPhoto), MapNoteLetter(without)]))));
      await tester.pump();
      expect(find.byKey(const Key('letter-photo-1')), findsOneWidget);
      expect(find.byKey(const Key('letter-photo-2')), findsNothing);
      expect(find.bySemanticsLabel('Mektup fotoğrafı'), findsOneWidget);
    });

    testWidgets('An anonymous letter with a photo still carries no identity', (tester) async {
      final note = MapNoteItem.fromJson(noteJson(anonymous: true, image: '/api/map-notes/1/image'), person);
      final store = await quietStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, Scaffold(body: ListView(children: [MapNoteLetter(note)]))));
      await tester.pump();
      expect(find.byKey(const Key('letter-photo-1')), findsOneWidget);
      expect(find.text('Anonim'), findsOneWidget);
      expect(find.text('Ada Test'), findsNothing);
      expect(find.text('@ada'), findsNothing);
      expect(note.author, isNull);
    });

    test('A re-publication keeps its image and real date while the public window starts over', () {
      final repost = MapNoteItem.fromJson(
        noteJson(image: '/api/map-notes/9/image', republished: true, created: '2026-11-20T09:00:00Z', occurred: '2026-11-14T11:15:00Z'),
        person,
      );
      expect(repost.hasImage, isTrue);
      expect(repost.republished, isTrue);
      expect(repost.occurredAt, DateTime.parse('2026-11-14T11:15:00Z'));
      expect(repost.createdAt, DateTime.parse('2026-11-20T09:00:00Z'));
    });
  });

  group('The composer', () {
    Future<(AppStore, List<http.Request>)> composer(WidgetTester tester, {Future<http.Response> Function(http.Request)? onCreate, double width = 390, double scale = 1}) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sent = <http.Request>[];
      final store = await connected((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
        if (path.endsWith('/cities')) return ok([{'id': 1, 'name': 'Alanya'}]);
        if (request.method == 'POST' && path.endsWith('/map-notes')) {
          sent.add(request);
          return onCreate != null ? onCreate(request) : ok(noteJson(mine: true, image: '/api/map-notes/5/image'), 201);
        }
        return ok({'items': [], 'location_required': false});
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const MapNoteComposePage(center: LatLng(36.5, 32.0), zoom: 14), scale: scale));
      await tester.pumpAndSettle();
      return (store, sent);
    }

    /// Picks a photo and, like a person would, accepts the shared crop step (9:16 / 4:5 / 16:9) that follows.
    Future<void> choosePhoto(WidgetTester tester, [Key source = const Key('map-note-photo-gallery'), bool crop = true]) async {
      await tester.ensureVisible(find.byKey(const Key('map-note-photo-add')));
      await tester.tap(find.byKey(const Key('map-note-photo-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(source));
      if (!crop) {
        await tester.pumpAndSettle();
        return;
      }
      await tester.pump();
      await until(tester, () => find.byKey(const Key('crop-frame')).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('crop-ratio-9:16')), findsOneWidget);
      expect(find.byKey(const Key('crop-ratio-4:5')), findsOneWidget);
      expect(find.byKey(const Key('crop-ratio-16:9')), findsOneWidget);
      await tester.tap(find.byKey(const Key('crop-confirm')));
      await until(tester, () => find.byKey(const Key('crop-confirm')).evaluate().isEmpty);
      await tester.pumpAndSettle();
    }

    testWidgets('A photo is optional: the composer offers "Fotoğraf Ekle", gallery or camera', (tester) async {
      await composer(tester);
      expect(find.byKey(const Key('map-note-photo-add')), findsOneWidget);
      expect(find.byKey(const Key('map-note-photo-preview')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('map-note-photo-add')));
      await tester.tap(find.byKey(const Key('map-note-photo-add')));
      await tester.pumpAndSettle();
      expect(find.text('Galeriden Seç'), findsOneWidget);
      expect(find.text('Fotoğraf Çek'), findsOneWidget);
    });

    testWidgets('Gallery pick shows a preview with a remove button; removing brings the add button back', (tester) async {
      await composer(tester);
      await choosePhoto(tester);
      expect(pickerCalls.single.method, 'pickImage');
      expect(pickerCalls.single.arguments['source'], 1, reason: 'Gallery.');
      expect(pickerCalls.single.arguments['maxWidth'], 2048.0);
      expect(find.byKey(const Key('map-note-photo-preview')), findsOneWidget);
      expect(find.byKey(const Key('map-note-photo-add')), findsNothing);
      await tester.tap(find.byKey(const Key('map-note-photo-remove')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-note-photo-preview')), findsNothing);
      expect(find.byKey(const Key('map-note-photo-add')), findsOneWidget);
    });

    testWidgets('The camera option asks the picker for the camera', (tester) async {
      await composer(tester);
      await choosePhoto(tester, const Key('map-note-photo-camera'));
      expect(pickerCalls.single.arguments['source'], 0, reason: 'Camera.');
      expect(find.byKey(const Key('map-note-photo-preview')), findsOneWidget);
    });

    testWidgets('A picker failure leaves the composer intact and says so', (tester) async {
      await composer(tester);
      pickerFails = true;
      await choosePhoto(tester, const Key('map-note-photo-gallery'), false);
      expect(find.text('Fotoğraf seçilemedi. Tekrar dene.'), findsOneWidget);
      expect(find.byKey(const Key('map-note-photo-add')), findsOneWidget);
    });

    testWidgets('Publishing with a photo posts one multipart request: the text, the point and exactly one image', (tester) async {
      final (_, sent) = await composer(tester);
      await tester.enterText(find.byKey(const Key('map-note-field')), 'Sahilde gördüm seni.');
      await choosePhoto(tester);
      final publish = find.widgetWithText(FilledButton, 'Notu Bırak');
      await tester.ensureVisible(publish);
      await tester.tap(publish);
      await until(tester, () => sent.isNotEmpty);
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(sent.single.headers['content-type'], startsWith('multipart/form-data'));
      final body = utf8.decode(sent.single.bodyBytes, allowMalformed: true);
      expect('name="image"'.allMatches(body), hasLength(1));
      expect(body, contains('Sahilde gördüm seni.'));
      expect(body, contains('name="latitude"'));
      expect(body, contains('name="request_id"'));
    });

    testWidgets('Publishing without a photo stays a plain JSON request', (tester) async {
      final (_, sent) = await composer(tester, onCreate: (request) async => ok(noteJson(mine: true), 201));
      await tester.enterText(find.byKey(const Key('map-note-field')), 'Sadece metin.');
      final publish = find.widgetWithText(FilledButton, 'Notu Bırak');
      await tester.ensureVisible(publish);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(sent.single.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(sent.single.body)['body'], 'Sadece metin.');
    });

    testWidgets('A rejected photo shows the server message and keeps text and photo for a retry', (tester) async {
      final (_, sent) = await composer(
        tester,
        onCreate: (request) async => http.Response(
          jsonEncode({'success': false, 'message': 'Fotoğraf okunamadı.', 'errors': {}}),
          422,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await tester.enterText(find.byKey(const Key('map-note-field')), 'Metin kalsın.');
      await choosePhoto(tester);
      final publish = find.widgetWithText(FilledButton, 'Notu Bırak');
      await tester.ensureVisible(publish);
      await tester.tap(publish);
      await until(tester, () => sent.isNotEmpty);
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(find.byKey(const Key('map-note-error')), findsOneWidget);
      expect(find.text('Metin kalsın.'), findsOneWidget);
      expect(find.byKey(const Key('map-note-photo-preview')), findsOneWidget);
    });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('The composer with a photo fits ${width.toInt()} px at 1.5x text', (tester) async {
        await composer(tester, width: width, scale: 1.5);
        await choosePhoto(tester);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.byKey(const Key('map-note-photo-preview'))).right, lessThanOrEqualTo(width));
      });
    }
  });

  group('Detail, replies and Mektuplarım', () {
    testWidgets('The detail page shows the photo; replies are text only (no photo controls)', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await connected((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
        if (path.endsWith('/map-notes/1')) {
          return ok({'note': noteJson(image: '/api/map-notes/1/image'), 'replies': {'items': [], 'next_page': null}});
        }
        return ok({'items': [], 'next_page': null});
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const MapNoteDetailPage(1)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('letter-photo-1')), findsOneWidget);
      expect(find.byKey(const Key('map-note-reply-field')), findsOneWidget);
      expect(find.byKey(const Key('map-note-photo-add')), findsNothing, reason: 'Replies are text only.');
    });

    testWidgets('Mektuplarım Arşiv still shows the photo of a letter taken off the map', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await connected((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
        if (path.endsWith('/my/map-notes')) {
          final archive = request.url.queryParameters['scope'] == 'archive';
          return ok({
            'items': archive ? [noteJson(mine: true, image: '/api/map-notes/1/image', state: 'archived')] : [],
            'next_page': null,
          });
        }
        return ok({'items': [], 'next_page': null});
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const MyLettersPage()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('letter-photo-1')), findsNothing, reason: 'Aktif is empty.');
      await tester.tap(find.text('Arşiv'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('letter-photo-1')), findsOneWidget);
    });
  });
}
