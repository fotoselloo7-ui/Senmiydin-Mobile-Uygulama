import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/communication_api.dart';
import 'package:senmiydin/data/memories_api.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/screens/map_notes.dart';
import 'package:senmiydin/screens/memories.dart';
import 'package:senmiydin/screens/memory_place_pick.dart';
import 'package:senmiydin/widgets/common.dart' show Avatar;
import 'package:senmiydin/widgets/home_memories.dart';
import 'package:senmiydin/widgets/memories_map.dart';
import 'package:senmiydin/screens/profile.dart';
import 'package:senmiydin/screens/settings.dart';
import 'package:senmiydin/widgets/map_note_widgets.dart';
import 'package:senmiydin/data/map_notes_api.dart';
import 'package:senmiydin/widgets/media_viewer.dart';
import 'package:senmiydin/widgets/memory_widgets.dart';
import 'package:senmiydin/widgets/social.dart';

import 'support/chat_harness.dart' show loadAppFont, realWait;

Map<String, dynamic> memoryJson(
  int id, {
  String body = 'Sahilde yürüdüğümüz akşam.',
  bool mine = true,
  int photos = 0,
  String visibility = 'private',
  bool hidden = false,
  String? source,
  String occurred = '2026-08-14T17:30:00Z',
  String place = 'Alanya · Yaklaşık bölge',
  int width = 900,
  int height = 1600,
  bool area = true,
}) => {
  'id': id,
  'mine': mine,
  'author': {
    'id': mine ? 1 : 7,
    'username': mine ? 'demo' : 'ada',
    'name': mine ? 'Demo' : 'Ada Test',
    'avatar': null,
  },
  'body': body,
  'occurred_at': occurred,
  'city': {'id': 1, 'name': 'Alanya', 'slug': 'alanya'},
  'place': null,
  'place_label': place,
  'map_area': area ? {'lat': 36.54, 'lng': 32.0, 'radius_m': 1500} : null,
  'visibility': mine ? visibility : null,
  'is_hidden': mine ? hidden : null,
  'source_type': mine ? source : null,
  'media': [
    for (var i = 0; i < photos; i++)
      {
        'id': id * 10 + i,
        'url': '/api/v1/memory-media/${id * 10 + i}',
        'thumb_url': '/api/v1/memory-media/${id * 10 + i}/thumb',
        'width': width,
        'height': height,
        'aspect_ratio': width / height,
      },
  ],
  'created_at': '2026-11-21T12:00:00Z',
  'updated_at': '2026-11-21T12:00:00Z',
};

Map<String, dynamic> accountJson({String memoryDefault = 'private'}) => {
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
  'age_band': 'adult',
  'memory_default_visibility': memoryDefault,
};

http.Response ok(Object? data, [int status = 200]) => http.Response(
  jsonEncode({'success': true, 'message': '', 'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// An in-memory stand-in for the memories API.
class Backend {
  final memories = <Map<String, dynamic>>[];
  final requests = <http.Request>[];
  Map<String, dynamic>? prefill, existing;
  // Where each memory's pin stands on the Anılar map (a memory without an entry has no place).
  final points = <int, (double, double)>{};
  final distances = <int, int>{};
  String memoryDefault = 'private';
  int nextId = 100;
  bool owner = true;

  List<http.Request> where(String method, String pattern) => [
    for (final r in requests)
      if (r.method == method && RegExp(pattern).hasMatch(r.url.path)) r,
  ];

  Map<String, dynamic> jsonBody(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path.replaceFirst('/api/v1', '');
    if (path.endsWith('/auth/login')) {
      return ok({'token': 't', 'user': accountJson(memoryDefault: memoryDefault)});
    }
    requests.add(r);
    if (path == '/profile' && r.method == 'PUT') {
      final fields = jsonBody(r);
      memoryDefault = fields['memory_default_visibility'] as String? ?? memoryDefault;
      return ok(accountJson(memoryDefault: memoryDefault));
    }
    if (path == '/map/memories' && r.method == 'GET') {
      return ok({
        'items': [
          for (final m in memories)
            if (points[m['id']] case final at?)
              {
                'id': m['id'],
                'lat': at.$1,
                'lng': at.$2,
                'occurred_at': m['occurred_at'],
                'place_label': m['place_label'],
                'excerpt': m['body'],
                'media_count': (m['media'] as List).length,
                'cover_thumb': (m['media'] as List).isEmpty ? null : ((m['media'] as List).first as Map)['thumb_url'],
                'cover_aspect': null,
                'mine': m['mine'],
                'visibility': m['visibility'],
                'is_hidden': m['is_hidden'],
                'author': {'id': 7, 'username': 'ada', 'name': 'Ada Test'},
                'distance_meters': distances[m['id']],
              },
        ],
        'location_required': false,
      });
    }
    final mapRoute = RegExp(r'^/users/([^/]+)/memories/map$').firstMatch(path);
    if (mapRoute != null && r.method == 'GET') {
      final filter = r.url.queryParameters['filter'];
      final pins = <Map<String, dynamic>>[], unlocated = <Map<String, dynamic>>[];
      for (final m in memories) {
        if (m['mine'] != (mapRoute.group(1) == 'demo') ||
            (filter == 'visible' && m['is_hidden'] == true) ||
            (filter == 'hidden' && m['is_hidden'] != true)) {
          continue;
        }
        final at = points[m['id']];
        if (at == null) {
          unlocated.add(m);
          continue;
        }
        final media = m['media'] as List;
        pins.add({
          'id': m['id'],
          'lat': at.$1,
          'lng': at.$2,
          'occurred_at': m['occurred_at'],
          'place_label': m['place_label'],
          'excerpt': (m['body'] as String).length > 140 ? (m['body'] as String).substring(0, 140) : m['body'],
          'media_count': media.length,
          'cover_thumb': media.isEmpty ? null : (media.first as Map)['thumb_url'],
          'cover_aspect': media.isEmpty ? null : (media.first as Map)['aspect_ratio'],
          'mine': m['mine'],
          'visibility': m['visibility'],
          'is_hidden': m['is_hidden'],
        });
      }
      return ok({'items': pins, 'unlocated': unlocated, 'unlocated_count': unlocated.length});
    }
    final list = RegExp(r'^/users/([^/]+)/memories$').firstMatch(path);
    if (list != null && r.method == 'GET') {
      final page = int.parse(r.url.queryParameters['page'] ?? '1');
      final filter = r.url.queryParameters['filter'];
      final all = [
        for (final m in memories)
          if (m['mine'] == (list.group(1) == 'demo') &&
              (filter != 'visible' || m['is_hidden'] != true) &&
              (filter != 'hidden' || m['is_hidden'] == true))
            m,
      ];
      final slice = all.skip((page - 1) * 20).take(20).toList();
      return ok({'items': slice, 'next_page': all.length > page * 20 ? page + 1 : null});
    }
    if (path == '/memories/prefill') {
      return ok({'existing': existing, 'prefill': prefill});
    }
    if (path == '/memories' && r.method == 'POST') {
      final created = memoryJson(nextId++, body: 'Yeni kayıt', mine: true);
      memories.insert(0, created);
      return ok(created, 201);
    }
    final one = RegExp(r'^/memories/(\d+)(?:/(hide|unhide))?$').firstMatch(path);
    if (one != null) {
      final id = int.parse(one.group(1)!);
      final index = memories.indexWhere((m) => m['id'] == id);
      if (index < 0) return http.Response(jsonEncode({'success': false, 'message': 'x', 'data': null}), 404, headers: {'content-type': 'application/json'});
      if (r.method == 'GET') return ok(memories[index]);
      if (r.method == 'DELETE') {
        memories.removeAt(index);
        return ok(null);
      }
      if (one.group(2) != null) {
        memories[index] = {...memories[index], 'is_hidden': one.group(2) == 'hide'};
        return ok(memories[index]);
      }
      final fields = r.headers['content-type']!.contains('json') ? jsonBody(r) : <String, dynamic>{};
      memories[index] = {
        ...memories[index],
        if (fields['visibility'] != null) 'visibility': fields['visibility'],
        if (fields['body'] != null) 'body': fields['body'],
      };
      return ok(memories[index]);
    }
    if (path == '/reports') return ok(null, 201);
    if (RegExp(r'^/my/map-notes/\d+$').hasMatch(path)) {
      return ok({'note': noteJson(mine: true, memoryId: existing == null ? null : 5), 'replies': {'items': [], 'next_page': null}});
    }
    return ok({'items': [], 'next_page': null, 'location_required': false});
  }
}

Map<String, dynamic> noteJson({bool mine = false, int? memoryId, String state = 'active'}) => {
  'id': 7,
  'body': 'Seni burada gördüm.',
  'is_anonymous': false,
  'mine': mine,
  'author': {'id': 1, 'username': 'demo', 'name': 'Demo', 'avatar': null},
  'city': {'id': 1, 'name': 'Alanya', 'slug': 'alanya'},
  'place_label': 'Alanya · Yaklaşık bölge',
  'group': '36.54500_32.00000',
  'latitude': 36.545,
  'longitude': 32.0,
  'reply_count': 0,
  'can_reply': false,
  'created_at': '2026-11-14T11:15:00Z',
  'expires_at': '2026-11-21T11:15:00Z',
  'state': state,
  'republished': false,
  'can_repost': state != 'active',
  'memory_id': ?memoryId,
};

Map<String, dynamic> prefillJson({int photos = 1, String type = 'map_note', String visibility = 'private'}) => {
  'source_type': type,
  'body': 'Seni burada gördüm, yarın yine buradayım.',
  'occurred_at': '2026-11-14T11:15:00Z',
  'city': {'id': 1, 'name': 'Alanya', 'slug': 'alanya'},
  'place': null,
  'place_label': 'Alanya · Yaklaşık bölge',
  'visibility': visibility,
  'media': [
    for (var i = 0; i < photos; i++) {'ref': 's${12 + i}', 'url': '/api/v1/map-notes/7/image', 'width': null, 'height': null},
  ],
};

String tinyPng() {
  final file = File('${Directory.systemTemp.path}/senmiydin_memory_photo_test.png');
  file.writeAsBytesSync(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ));
  return file.path;
}

/// A real PNG of the given shape (for the feed ratio checks).
Future<String> shapedPhoto(WidgetTester tester, int width, int height) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF0877E8),
    );
    final image = await recorder.endRecording().toImage(width, height);
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  });
  final file = File('${Directory.systemTemp.path}/shape_${width}x$height.png')..writeAsBytesSync(bytes!);
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFont);
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  const picker = MethodChannel('plugins.flutter.io/image_picker');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  final pickerCalls = <MethodCall>[];
  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(paths, (call) async => Directory.systemTemp.path);
    pickerCalls.clear();
    messenger.setMockMethodCallHandler(picker, (call) async {
      pickerCalls.add(call);
      return call.method == 'pickMultiImage' ? [tinyPng(), tinyPng()] : tinyPng();
    });
  });
  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(picker, null);
    messenger.setMockMethodCallHandler(paths, null);
  });

  Future<AppStore> signedIn(Backend backend) async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = AppStore(api: ApiClient(httpClient: MockClient(backend.handle)));
    await store.signIn('login', {'identifier': 'demo', 'password': 'x'});
    return store;
  }

  void screen(WidgetTester tester, double width, [double height = 900]) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  final reportsOpened = <ReportTarget>[];
  Widget host(AppStore store, Widget child, {double scale = 1, Locale locale = const Locale('tr')}) => StoreScope(
    store: store,
    child: MaterialApp(
      // A new app per call: the first route's builder would otherwise keep showing the first widget.
      key: UniqueKey(),
      locale: locale,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      builder: (context, page) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: page!,
      ),
      onGenerateRoute: (settings) {
        final arg = settings.arguments;
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => switch (settings.name) {
            '/' => child,
            '/memory' => MemoryDetailPage(arg as int),
            '/memory-form' => MemoryFormPage(arg as MemoryFormArgs),
            '/memory-pick' => MemoryPlacePickPage(arg as MemoryPickArgs),
            '/report' => Builder(builder: (context) {
              reportsOpened.add(arg as ReportTarget);
              return Scaffold(body: Text('report ${arg.type} ${arg.id}'));
            }),
            _ => Scaffold(body: Text('route ${settings.name}')),
          },
        );
      },
    ),
  );

  Future<void> pumpStore(WidgetTester tester, Backend backend, Widget Function(AppStore) child, {double width = 390, double scale = 1}) async {
    screen(tester, width);
    final store = await signedIn(backend);
    addTearDown(store.dispose);
    await tester.pumpWidget(host(store, child(store), scale: scale));
    await tester.pumpAndSettle();
  }

  Widget section(AppStore store, {bool own = true}) => Scaffold(
    body: SingleChildScrollView(child: MemoriesSection(username: own ? 'demo' : 'ada', own: own)),
  );

  /// Scrolls a list entry fully into view (lazy list extents need a settle between the jumps).
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 250, scrollable: find.byType(Scrollable).first, maxScrolls: 80);
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> confirmCrops(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      for (var n = 0; n < 120 && find.byKey(const Key('crop-frame')).evaluate().isEmpty; n++) {
        await realWait(tester, 30);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('crop-confirm')));
      for (var n = 0; n < 120 && find.byKey(const Key('crop-confirm')).evaluate().isNotEmpty; n++) {
        await realWait(tester, 30);
      }
      await tester.pumpAndSettle();
    }
  }

  group('Profile → Anılar', () {
    testWidgets('An empty list shows the empty state and "+ Anı Ekle" for the owner only', (tester) async {
      final backend = Backend();
      await pumpStore(tester, backend, (s) => section(s));
      expect(find.text('Henüz bir anın yok.'), findsOneWidget);
      expect(find.byKey(const Key('memory-add')), findsOneWidget);
      expect(find.text('+ Anı Ekle'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      final other = Backend();
      await pumpStore(tester, other, (s) => section(s, own: false));
      expect(find.text('Henüz paylaşılmış bir anı yok.'), findsOneWidget);
      expect(find.byKey(const Key('memory-add')), findsNothing);
      expect(other.where('GET', r'/users/ada/memories'), hasLength(1));
    });

    testWidgets('The profile has an Anılar tab that loads that person’s memories', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1, body: 'Profildeki anı'));
      await pumpStore(tester, backend, (s) => Scaffold(body: ProfileContent(personId: s.me.id)));
      expect(find.byKey(const Key('profile-tab-Anılar')), findsOneWidget);
      expect(backend.where('GET', r'/users/demo/memories'), isEmpty, reason: 'Loaded only when the tab opens.');
      await tester.ensureVisible(find.byKey(const Key('profile-tab-Anılar')));
      await tester.tap(find.byKey(const Key('profile-tab-Anılar')));
      await tester.pumpAndSettle();
      // The tab is a map now: pins come from the map endpoint, the card list is not loaded at all.
      expect(find.byKey(const Key('memories-map')), findsOneWidget);
      expect(backend.where('GET', r'/users/demo/memories/map'), hasLength(1));
      expect(backend.where('GET', r'/users/demo/memories$'), isEmpty);
      expect(find.text('Konumsuz Anılar'), findsOneWidget, reason: 'This memory has no place, so it waits in the sheet.');
    });

    testWidgets('A card shows date, approximate place, short text and (owner only) the visibility', (tester) async {
      final backend = Backend()
        ..memories.addAll([
          memoryJson(1, body: 'Uzun bir anı. ' * 40, visibility: 'followers'),
          memoryJson(2, body: 'Başkasının', mine: false),
        ]);
      await pumpStore(tester, backend, (s) => section(s));
      expect(find.byKey(const Key('memory-date-1')), findsOneWidget);
      expect(find.text('14 Ağustos 2026'), findsOneWidget);
      expect(find.text('Alanya'), findsOneWidget);
      expect(find.byKey(const Key('memory-visibility-1')), findsOneWidget);
      expect(find.text('Takipçilerim'), findsOneWidget);
      final body = tester.widget<Text>(find.textContaining('Uzun bir anı.'));
      expect(body.maxLines, 3, reason: 'A short preview, never the whole text.');

      await tester.pumpWidget(const SizedBox.shrink());
      final other = Backend()..memories.add(memoryJson(2, body: 'Başkasının', mine: false));
      await pumpStore(tester, other, (s) => section(s, own: false));
      expect(find.text('Başkasının'), findsOneWidget);
      expect(find.byKey(const Key('memory-visibility-2')), findsNothing, reason: 'Visibility is the owner’s business.');
      expect(find.byKey(const Key('memory-hidden-2')), findsNothing);
    });

    testWidgets('A hidden memory is marked "Gizli" for its owner', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1, hidden: true));
      await pumpStore(tester, backend, (s) => section(s));
      expect(find.byKey(const Key('memory-hidden-1')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('memory-hidden-1')), matching: find.text('Gizli')), findsOneWidget);
    });

    testWidgets('One photo is a single preview: no pager counter', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1, photos: 1));
      await pumpStore(tester, backend, (s) => section(s));
      expect(find.byKey(const Key('memory-photos')), findsOneWidget);
      expect(find.byKey(const Key('memory-photo-0')), findsOneWidget);
      expect(find.byKey(const Key('memory-photo-counter')), findsNothing);
    });

    testWidgets('Five photos are a horizontal pager with a 1/5 counter that follows the swipe', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1, photos: 5));
      await pumpStore(tester, backend, (s) => section(s));
      expect(find.text('1/5'), findsOneWidget);
      await tester.drag(find.byKey(const Key('memory-photos')), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/5'), findsOneWidget);
      await tester.drag(find.byKey(const Key('memory-photos')), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('3/5'), findsOneWidget);
      await tester.drag(find.byKey(const Key('memory-photos')), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('A list loads thumbnails, never the full photos', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1, photos: 3));
      await pumpStore(tester, backend, (s) => section(s));
      final urls = <String>{};
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        final provider = image.image;
        if (provider is NetworkImage) urls.add(provider.url);
      }
      expect(urls, isNotEmpty);
      expect(urls.every((url) => url.endsWith('/thumb')), isTrue, reason: '$urls');
    });

    testWidgets('Tapping a photo opens the full screen Media Viewer on that photo, with the full photos', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1, photos: 3));
      await pumpStore(tester, backend, (s) => section(s));
      await tester.drag(find.byKey(const Key('memory-photos')), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory-photo-1')));
      await tester.pumpAndSettle();
      final viewer = tester.widget<MediaViewer>(find.byType(MediaViewer));
      expect(viewer.initialIndex, 1);
      expect(viewer.images, hasLength(3));
      expect(viewer.images.every((url) => !url.endsWith('/thumb')), isTrue);
    });

    testWidgets('A long list is loaded 20 at a time', (tester) async {
      final backend = Backend()..memories.addAll([for (var i = 1; i <= 25; i++) memoryJson(i, body: 'Anı $i')]);
      await pumpStore(tester, backend, (s) => section(s));
      expect(find.byType(MemoryCard, skipOffstage: false), findsNWidgets(20));
      expect(find.text('Daha Fazla Göster'), findsOneWidget);
      await tester.ensureVisible(find.text('Daha Fazla Göster'));
      await tester.tap(find.text('Daha Fazla Göster'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryCard, skipOffstage: false), findsNWidgets(25));
      expect(backend.where('GET', r'/memories$').map((r) => r.url.queryParameters['page']), ['1', '2']);
    });
  });

  group('Adding a memory', () {
    testWidgets('+ Anı Ekle opens the form with the account default visibility and the home place selected', (tester) async {
      final backend = Backend()..memoryDefault = 'followers';
      await pumpStore(tester, backend, (s) => section(s));
      await tester.tap(find.byKey(const Key('memory-add')));
      await tester.pumpAndSettle();
      expect(find.text('Yeni Anı'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('memory-visibility-followers')), matching: find.byIcon(Icons.check_circle_rounded)),
        findsOneWidget,
        reason: 'The default from Ayarlar → Gizlilik comes preselected.',
      );
      expect(find.descendant(of: find.byKey(const Key('memory-visibility-public')), matching: find.byIcon(Icons.check_circle_rounded)), findsNothing);
      expect(find.text('Alanya'), findsOneWidget, reason: 'The home area is the starting place.');
      expect(find.text('Fotoğraflar (0/5)'), findsOneWidget);
    });

    testWidgets('A memory needs a text or a photo, and "Bu Bölgedekiler" needs a place', (tester) async {
      final backend = Backend();
      await pumpStore(tester, backend, (s) => MemoryFormPage(const MemoryFormArgs()));
      await tester.tap(find.byKey(const Key('memory-save')));
      await tester.pumpAndSettle();
      expect(find.text('Anı için bir metin yaz veya fotoğraf ekle.'), findsOneWidget);
      expect(backend.where('POST', r'/memories$'), isEmpty);
    });

    testWidgets('Choosing a visibility and saving sends the text, date, place and visibility as JSON', (tester) async {
      final backend = Backend();
      await pumpStore(tester, backend, (s) => section(s));
      await tester.tap(find.byKey(const Key('memory-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('memory-text')), 'Çocukluğumdaki yaz.');
      await reveal(tester, find.byKey(const Key('memory-visibility-area')));
      await tester.tap(find.byKey(const Key('memory-visibility-area')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('memory-save')));
      await tester.pumpAndSettle();
      final sent = backend.where('POST', r'/memories$').single;
      expect(sent.headers['content-type'], contains('json'));
      final body = backend.jsonBody(sent);
      expect(body['body'], 'Çocukluğumdaki yaz.');
      expect(body['visibility'], 'area');
      expect(body['city_id'], 1);
      expect(body['layout'], isEmpty);
      expect(body['request_id'], isNotEmpty);
      expect(body['occurred_at'], endsWith('Z'));
      expect(body.containsKey('source_type'), isFalse);
      // Back on the profile list, which reloaded with the new memory.
      expect(find.text('Yeni kayıt'), findsOneWidget);
    });

    testWidgets('Photos: gallery pick goes through the crop step, shows tiles, caps at five', (tester) async {
      final backend = Backend();
      await pumpStore(tester, backend, (s) => MemoryFormPage(const MemoryFormArgs()));
      await tester.tap(find.byKey(const Key('memory-add-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory-photo-gallery')));
      await tester.pump();
      expect(pickerCalls.single.method, 'pickMultiImage');
      expect(pickerCalls.single.arguments['limit'], 5);
      await confirmCrops(tester, 2);
      expect(find.text('Fotoğraflar (2/5)'), findsOneWidget);
      expect(find.byKey(const Key('memory-photo-remove-1')), findsOneWidget);

      // Two more picks of two photos: the fifth fits, the sixth never does.
      for (var round = 0; round < 2; round++) {
        if (find.byKey(const Key('memory-add-photo')).evaluate().isEmpty) break;
        await tester.tap(find.byKey(const Key('memory-add-photo')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('memory-photo-gallery')));
        await tester.pump();
        final remaining = 5 - int.parse(RegExp(r'\((\d)/5\)').firstMatch(tester.widget<Text>(find.textContaining('Fotoğraflar (')).data!)!.group(1)!);
        await confirmCrops(tester, remaining.clamp(1, 2));
      }
      expect(find.text('Fotoğraflar (5/5)'), findsOneWidget);
      expect(find.byKey(const Key('memory-add-photo')), findsNothing, reason: 'No add tile at the limit.');

      await tester.tap(find.byKey(const Key('memory-photo-remove-0')));
      await tester.pump();
      expect(find.text('Fotoğraflar (4/5)'), findsOneWidget);
      expect(find.byKey(const Key('memory-add-photo')), findsOneWidget);
    });

    testWidgets('Saving with two photos sends one multipart request: the files, in order, and the layout', (tester) async {
      final backend = Backend();
      await pumpStore(tester, backend, (s) => MemoryFormPage(const MemoryFormArgs()));
      await tester.enterText(find.byKey(const Key('memory-text')), 'İki fotoğraflı anı');
      await tester.tap(find.byKey(const Key('memory-add-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory-photo-gallery')));
      await tester.pump();
      await confirmCrops(tester, 2);
      await tester.tap(find.byKey(const Key('memory-save')));
      for (var n = 0; n < 60 && backend.where('POST', r'/memories$').isEmpty; n++) {
        await realWait(tester, 30);
      }
      await tester.pumpAndSettle();
      final sent = backend.where('POST', r'/memories$').single;
      expect(sent.headers['content-type'], startsWith('multipart/form-data'));
      final body = utf8.decode(sent.bodyBytes, allowMalformed: true);
      expect(body, contains('name="media[0]"'));
      expect(body, contains('name="media[1]"'));
      expect(body, isNot(contains('name="media[2]"')));
      expect(body, contains('name="layout[0]"'));
      expect(body, contains('name="layout[1]"'));
      expect(RegExp(r'name="layout\[0\]"\s+n0').hasMatch(body), isTrue);
      expect(RegExp(r'name="layout\[1\]"\s+n1').hasMatch(body), isTrue);
      expect(body, contains('İki fotoğraflı anı'));
    });

    testWidgets('The server’s refusal is shown and nothing is lost', (tester) async {
      final backend = Backend();
      screen(tester, 390);
      FlutterSecureStorage.setMockInitialValues({});
      final store = AppStore(
        api: ApiClient(
          httpClient: MockClient((r) async {
            if (r.url.path.endsWith('/auth/login')) return ok({'token': 't', 'user': accountJson()});
            return http.Response(
              jsonEncode({'success': false, 'message': 'Bilgilerini kontrol et.', 'data': null, 'errors': {'body': ['Paylaşımında topluluk kurallarına uygun olmayan bir ifade var.']}}),
              422,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      addTearDown(store.dispose);
      await store.signIn('login', {'identifier': 'demo', 'password': 'x'});
      await tester.pumpWidget(host(store, MemoryFormPage(const MemoryFormArgs())));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('memory-text')), 'Yasaklı bir söz');
      await tester.tap(find.byKey(const Key('memory-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory-error')), findsOneWidget);
      expect(find.text('Yasaklı bir söz'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });
  });

  group('A map note or a post becomes a memory', () {
    Widget starter(String type, int id) => Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          key: const Key('start'),
          onPressed: () => addSourceToMemories(context, sourceType: type, sourceId: id),
          child: const Text('Anılarıma Ekle'),
        ),
      ),
    );

    testWidgets('Note → memory: the form comes prefilled and editable; saving sends the source reference and its photo', (tester) async {
      final backend = Backend()..prefill = prefillJson();
      await pumpStore(tester, backend, (s) => starter('map_note', 7));
      await tester.tap(find.byKey(const Key('start')));
      await tester.pumpAndSettle();
      final query = backend.where('GET', r'/memories/prefill').single.url.queryParameters;
      expect(query, {'source_type': 'map_note', 'source_id': '7'});
      expect(find.text('Seni burada gördüm, yarın yine buradayım.'), findsOneWidget);
      expect(find.text('Alanya · Yaklaşık bölge'), findsOneWidget);
      expect(find.text('14 Kasım 2026'), findsOneWidget);
      expect(find.text('Fotoğraflar (1/5)'), findsOneWidget, reason: 'The note’s photo is prefilled.');
      expect(find.text('Kaydetmeden önce her şeyi değiştirebilirsin. Kaynak içerik aynen kalır.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('memory-text')), 'Değiştirdim.');
      await tester.tap(find.byKey(const Key('memory-save')));
      await tester.pumpAndSettle();
      final body = backend.jsonBody(backend.where('POST', r'/memories$').single);
      expect(body['source_type'], 'map_note');
      expect(body['source_id'], 7);
      expect(body['layout'], ['s12']);
      expect(body['body'], 'Değiştirdim.');
      expect(body['visibility'], 'private');
      expect(find.text('Anı kaydedildi.'), findsOneWidget);
    });

    testWidgets('Post → memory: text, photos, date and place come prefilled (the source is only referenced)', (tester) async {
      final backend = Backend()..prefill = prefillJson(photos: 3, type: 'post');
      await pumpStore(tester, backend, (s) => starter('post', 5));
      await tester.tap(find.byKey(const Key('start')));
      await tester.pumpAndSettle();
      expect(backend.where('GET', r'/memories/prefill').single.url.queryParameters['source_type'], 'post');
      expect(find.text('Fotoğraflar (3/5)'), findsOneWidget);
      // A photo can be dropped before saving.
      await tester.tap(find.byKey(const Key('memory-photo-remove-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('memory-save')));
      await tester.pumpAndSettle();
      final body = backend.jsonBody(backend.where('POST', r'/memories$').single);
      expect(body['source_type'], 'post');
      expect(body['layout'], ['s13', 's14']);
    });

    testWidgets('A source that is already a memory opens that memory instead of making a copy', (tester) async {
      final backend = Backend()
        ..existing = memoryJson(5, body: 'Zaten burada')
        ..memories.add(memoryJson(5, body: 'Zaten burada'))
        ..prefill = null;
      await pumpStore(tester, backend, (s) => starter('map_note', 7));
      await tester.tap(find.byKey(const Key('start')));
      await tester.pumpAndSettle();
      expect(find.text('Zaten burada'), findsOneWidget, reason: 'The existing memory’s detail page.');
      expect(find.text('Yeni Anı'), findsNothing);
      expect(backend.where('POST', r'/memories$'), isEmpty);
    });

    testWidgets('Mektuplarım: the letter detail offers “Anılarıma Ekle”, and “Anılarında” once it is one', (tester) async {
      final backend = Backend();
      await pumpStore(tester, backend, (s) => const MapNoteDetailPage(7, mine: true));
      expect(find.byKey(const Key('memory-map-note')), findsOneWidget);
      expect(find.text('Anılarıma Ekle'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      final added = Backend()..existing = memoryJson(5);
      await pumpStore(tester, added, (s) => const MapNoteDetailPage(7, mine: true));
      expect(find.text('Anılarında'), findsOneWidget);
    });

    testWidgets('The Mektuplarım card says “Anılarında” for a letter that is already a memory (active or archived)', (tester) async {
      final store = await signedIn(Backend());
      addTearDown(store.dispose);
      screen(tester, 390);
      Person person(Map<String, dynamic> j) => Person(id: 'account-${j['id']}', name: j['name'] as String, handle: j['username'] as String, photo: '', remote: true);
      for (final state in ['active', 'archived']) {
        final note = MapNoteItem.fromJson(noteJson(mine: true, memoryId: 5, state: state), person);
        await tester.pumpWidget(host(store, Scaffold(body: MyLetterCard(note))));
        await tester.pump();
        expect(find.byKey(const ValueKey('my-letter-memory-7')), findsOneWidget, reason: state);
        expect(find.text('Anılarında'), findsOneWidget);
      }
      final plain = MapNoteItem.fromJson(noteJson(mine: true), person);
      await tester.pumpWidget(host(store, Scaffold(body: MyLetterCard(plain))));
      await tester.pump();
      expect(find.byKey(const ValueKey('my-letter-memory-7')), findsNothing);
    });

    testWidgets('A post’s ⋮ menu has “Anılarıma Ekle” for the owner only', (tester) async {
      final backend = Backend()..prefill = prefillJson(type: 'post');
      screen(tester, 390, 1400);
      final store = await signedIn(backend);
      addTearDown(store.dispose);
      Post post({required bool mine}) => Post(
        id: mine ? '5' : '6',
        authorId: store.me.id,
        text: 'Kaleden gün batımı.',
        mine: mine,
        remote: true,
        createdAt: DateTime(2026, 11, 20),
      );
      await tester.pumpWidget(host(store, Scaffold(body: SingleChildScrollView(child: PostCard(post(mine: true))))));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
      await tester.pumpAndSettle();
      expect(find.text('Anılarıma Ekle'), findsOneWidget);
      await tester.tap(find.text('Anılarıma Ekle'));
      await tester.pumpAndSettle();
      expect(backend.where('GET', r'/memories/prefill').single.url.queryParameters, {'source_type': 'post', 'source_id': '5'});
      expect(find.text('Yeni Anı'), findsOneWidget);

      await tester.pumpWidget(host(store, Scaffold(body: SingleChildScrollView(child: PostCard(post(mine: false))))));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
      await tester.pumpAndSettle();
      expect(find.text('Anılarıma Ekle'), findsNothing);
    });
  });

  group('Memory detail, edit, hide, visibility, delete', () {
    testWidgets('The detail shows date, place, text, the photo gallery and (owner) the visibility and source', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1, photos: 3, visibility: 'public', source: 'map_note'));
      await pumpStore(tester, backend, (s) => const MemoryDetailPage(1));
      expect(find.byKey(const Key('memory-detail-date')), findsOneWidget);
      expect(find.text('14 Ağustos 2026'), findsOneWidget);
      expect(find.byKey(const Key('memory-detail-place')), findsOneWidget);
      expect(find.byKey(const Key('memory-detail-body')), findsOneWidget);
      expect(find.byType(ImageCarousel), findsOneWidget);
      expect(find.text('Herkes'), findsOneWidget);
      expect(find.text('Bir Harita Notundan oluşturuldu'), findsOneWidget);
      expect(find.byKey(const Key('memory-edit')), findsOneWidget);
    });

    testWidgets('Someone else’s memory shows the author and a report action; no owner controls', (tester) async {
      final backend = Backend()..memories.add(memoryJson(2, mine: false, photos: 1));
      await pumpStore(tester, backend, (s) => const MemoryDetailPage(2));
      expect(find.text('Ada Test'), findsOneWidget);
      expect(find.byKey(const Key('memory-edit')), findsNothing);
      expect(find.byKey(const Key('memory-delete')), findsNothing);
      expect(find.byKey(const Key('memory-detail-visibility')), findsNothing);
      await tester.ensureVisible(find.text('Şikâyet Et').last);
      await tester.tap(find.text('Şikâyet Et').last);
      await tester.pumpAndSettle();
      expect(reportsOpened.last.type, 'memory');
      expect(reportsOpened.last.id, 2);
    });

    testWidgets('A memory that is gone says so', (tester) async {
      final backend = Backend();
      await pumpStore(tester, backend, (s) => const MemoryDetailPage(99));
      expect(find.text('Bu anı artık kullanılamıyor.'), findsOneWidget);
    });

    testWidgets('Edit: changes text, visibility and removes a photo; the unchanged place is not resent', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1, photos: 2, visibility: 'private'));
      await pumpStore(tester, backend, (s) => const MemoryDetailPage(1));
      await tester.ensureVisible(find.byKey(const Key('memory-edit')));
      await tester.tap(find.byKey(const Key('memory-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Anıyı Düzenle'), findsOneWidget);
      expect(find.text('Sahilde yürüdüğümüz akşam.'), findsOneWidget);
      expect(find.text('Fotoğraflar (2/5)'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('memory-text')), 'Düzenlenmiş anı');
      await tester.tap(find.byKey(const Key('memory-photo-remove-0')));
      await tester.pump();
      await reveal(tester, find.byKey(const Key('memory-visibility-public')));
      await tester.tap(find.byKey(const Key('memory-visibility-public')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('memory-save')));
      await tester.pumpAndSettle();
      final sent = backend.where('POST', r'/memories/1$').single;
      final body = backend.jsonBody(sent);
      expect(body['body'], 'Düzenlenmiş anı');
      expect(body['visibility'], 'public');
      expect(body['layout'], ['m11'], reason: 'Only the second photo is kept.');
      expect(body.containsKey('city_id'), isFalse);
      expect(body.containsKey('place_id'), isFalse);
      expect(body.containsKey('request_id'), isFalse);
      expect(body.containsKey('source_type'), isFalse, reason: 'Editing never involves the source.');
    });

    testWidgets('Hide and show live in the ⋮ menu: two calls, the “Gizli” mark follows', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1));
      await pumpStore(tester, backend, (s) => const MemoryDetailPage(1));
      expect(find.byKey(const Key('memory-detail-hidden')), findsNothing);
      expect(find.byKey(const Key('memory-hide')), findsNothing, reason: 'No big Gizle button on the page.');
      await tester.tap(find.byKey(const Key('memory-detail-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gizle'));
      await tester.pumpAndSettle();
      expect(backend.where('POST', r'/memories/1/hide'), hasLength(1));
      expect(find.byKey(const Key('memory-detail-hidden')), findsOneWidget);
      await tester.tap(find.byKey(const Key('memory-detail-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tekrar Göster'));
      await tester.pumpAndSettle();
      expect(backend.where('POST', r'/memories/1/unhide'), hasLength(1));
      expect(find.byKey(const Key('memory-detail-hidden')), findsNothing);
    });

    testWidgets('Visibility: four choices in a sheet, the pick is saved on its own', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1, visibility: 'private'));
      await pumpStore(tester, backend, (s) => const MemoryDetailPage(1));
      await tester.ensureVisible(find.byKey(const Key('memory-change-visibility')));
      await tester.tap(find.byKey(const Key('memory-change-visibility')));
      await tester.pumpAndSettle();
      for (final label in ['Sadece Ben', 'Takipçilerim', 'Herkes', 'Bu Bölgedekiler']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      await tester.tap(find.byKey(const Key('memory-visibility-area')));
      await tester.pumpAndSettle();
      expect(backend.jsonBody(backend.where('POST', r'/memories/1$').single), {'visibility': 'area'});
      expect(find.byKey(const Key('memory-detail-visibility')), findsOneWidget);
      expect(find.text('Bu Bölgedekiler'), findsWidgets);
    });

    testWidgets('Delete asks first, then removes only the memory and returns to the list', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1));
      await pumpStore(tester, backend, (s) => Builder(builder: (context) => TextButton(onPressed: () => Navigator.pushNamed(context, '/memory', arguments: 1), child: const Text('aç'))));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('memory-delete')));
      await tester.tap(find.byKey(const Key('memory-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Anı silinsin mi?'), findsOneWidget);
      expect(find.textContaining('Paylaşımın veya Harita Notun etkilenmez'), findsOneWidget);
      expect(backend.where('DELETE', r'/memories/1'), isEmpty, reason: 'Nothing happens before confirming.');
      await tester.tap(find.text('Sil').last);
      await tester.pumpAndSettle();
      expect(backend.where('DELETE', r'/memories/1'), hasLength(1));
      expect(backend.requests.where((r) => r.url.path.contains('map-notes') || r.url.path.contains('/posts/')).where((r) => r.method == 'DELETE'), isEmpty);
      expect(find.text('aç'), findsOneWidget, reason: 'Back where it was opened from.');
    });
  });

  group('Haritada Gör, filter and cover', () {
    testWidgets('Haritada Gör opens the app map on the approximate AREA (a circle), only when the memory has one', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1));
      late AppStore captured;
      await pumpStore(tester, backend, (s) {
        captured = s;
        return const MemoryDetailPage(1);
      });
      expect(find.byKey(const Key('memory-see-on-map')), findsOneWidget);
      expect(find.text('Haritada Gör'), findsOneWidget);
      await tester.tap(find.byKey(const Key('memory-see-on-map')));
      await tester.pumpAndSettle();
      expect(captured.mapFocus?.latitude, 36.54);
      expect(captured.mapFocus?.longitude, 32.0);
      expect(captured.mapFocusRadius, 1500);
      // No coordinate is ever printed for the person.
      expect(find.textContaining('36.5'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      final none = Backend()..memories.add(memoryJson(2, area: false, place: ''));
      await pumpStore(tester, none, (s) => const MemoryDetailPage(2));
      expect(find.byKey(const Key('memory-see-on-map')), findsNothing);
    });

    testWidgets('The owner gets Tümü · Görünür · Gizli; the filter asks the server; others get no filter', (tester) async {
      final backend = Backend()
        ..memories.addAll([memoryJson(1, body: 'Açık anı'), memoryJson(2, body: 'Saklı anı', hidden: true)]);
      await pumpStore(tester, backend, (s) => section(s));
      expect(find.byKey(const Key('memory-filter')), findsOneWidget);
      for (final label in ['Tümü', 'Görünür', 'Gizli']) {
        expect(find.descendant(of: find.byKey(const Key('memory-filter')), matching: find.text(label)), findsOneWidget);
      }
      expect(find.text('Açık anı'), findsOneWidget);
      expect(find.text('Saklı anı'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(const Key('memory-filter')), matching: find.text('Gizli')));
      await tester.pumpAndSettle();
      expect(find.text('Açık anı'), findsNothing);
      expect(find.text('Saklı anı'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(const Key('memory-filter')), matching: find.text('Görünür')));
      await tester.pumpAndSettle();
      expect(find.text('Açık anı'), findsOneWidget);
      expect(find.text('Saklı anı'), findsNothing);
      expect(backend.where('GET', r'/memories$').map((r) => r.url.queryParameters['filter']), [null, 'hidden', 'visible']);

      await tester.pumpWidget(const SizedBox.shrink());
      final other = Backend()..memories.add(memoryJson(3, mine: false, body: 'Ada’nın anısı'));
      await pumpStore(tester, other, (s) => section(s, own: false));
      expect(find.byKey(const Key('memory-filter')), findsNothing, reason: 'Never on somebody else’s profile.');
      expect(other.where('GET', r'/memories$').single.url.queryParameters.containsKey('filter'), isFalse);
    });

    testWidgets('The first photo of a memory is its cover: marked in the form, first in the card', (tester) async {
      final backend = Backend()..memories.add(memoryJson(1, photos: 3));
      await pumpStore(tester, backend, (s) => MemoryFormPage(MemoryFormArgs(edit: MemoryItem.fromJson(memoryJson(1, photos: 3), (j) => Person(id: 'a', name: 'n', handle: 'h', photo: '')))));
      expect(find.byKey(const Key('memory-cover-badge')), findsOneWidget);
      expect(find.text('Kapak'), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('memory-cover-badge'))).left, lessThan(tester.getRect(find.byKey(const Key('memory-photo-remove-0'))).left));
      // "Kapak yap" on the last photo moves it to the front; the layout sent on save says so.
      expect(find.byKey(const Key('memory-make-cover-0')), findsNothing, reason: 'The cover itself has no such button.');
      await tester.tap(find.byKey(const Key('memory-make-cover-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory-save')));
      await tester.pumpAndSettle();
      expect(backend.jsonBody(backend.where('POST', r'/memories/1$').single)['layout'], ['m12', 'm10', 'm11']);
    });
  });

  group('Settings → Gizlilik → Anılar', () {
    testWidgets('Shows the default visibility and saves a new one without touching old memories', (tester) async {
      final backend = Backend();
      await pumpStore(tester, backend, (s) => const PreferencesPage());
      expect(find.text('Anılar'), findsOneWidget);
      expect(find.text('Yeni anılar: Sadece Ben'), findsOneWidget);
      await tester.ensureVisible(find.text('Anılar'));
      await tester.tap(find.text('Anılar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory-visibility-public')));
      await tester.pumpAndSettle();
      expect(backend.jsonBody(backend.where('PUT', r'/profile$').single), {'memory_default_visibility': 'public'});
      expect(find.text('Yeni anılar: Herkes'), findsOneWidget);
      expect(backend.where('POST', r'/memories'), isEmpty, reason: 'No memory is rewritten by the setting.');
    });
  });

  group('The shared ratios in the feed', () {
    for (final (label, width, height) in [('9:16', 90, 160), ('4:5', 80, 100), ('16:9', 160, 90)]) {
      testWidgets('A $label photo is shown whole in its own shape (not squared, not a fixed height)', (tester) async {
        final path = await shapedPhoto(tester, width, height);
        final backend = Backend();
        screen(tester, 390, 1400);
        final store = await signedIn(backend);
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, Scaffold(body: ListView(children: [ImageCarousel([path])]))));
        await realWait(tester, 300);
        await tester.pumpAndSettle();
        final box = tester.getSize(find.descendant(of: find.byType(ImageCarousel), matching: find.byType(PageView)));
        expect(box.width / box.height, closeTo(width / height, .02), reason: label);
      });
    }
  });

  group('Sizes and text scale', () {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('${width.toInt()} dp at ${scale}x: card, detail, form and sheet fit without overflow', (tester) async {
          final backend = Backend()
            ..memories.add(memoryJson(1, photos: 5, visibility: 'area', hidden: true, place: 'Konyaaltı Mahallesi, Muratpaşa, Antalya', body: 'Çok uzun bir anı metni. ' * 12));
          await pumpStore(tester, backend, (s) => section(s), width: width, scale: scale);
          expect(tester.takeException(), isNull, reason: 'card');
          for (final key in ['memory-visibility-1', 'memory-hidden-1']) {
            // A pill is one line: its text never wraps to a second one.
            final text = find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text));
            expect(tester.getSize(text).height, lessThan(20 * scale), reason: '$key at $width');
          }
          expect(tester.getRect(find.byKey(const Key('memory-card-1'))).right, lessThanOrEqualTo(width));

          await tester.pumpWidget(const SizedBox.shrink());
          await pumpStore(tester, backend, (s) => const MemoryDetailPage(1), width: width, scale: scale);
          expect(tester.takeException(), isNull, reason: 'detail');

          await tester.pumpWidget(const SizedBox.shrink());
          await pumpStore(tester, backend, (s) => MemoryFormPage(MemoryFormArgs(edit: MemoryItem.fromJson(memoryJson(1, photos: 5, visibility: 'area'), (j) => Person(id: 'a', name: 'n', handle: 'h', photo: '')))), width: width, scale: scale);
          expect(tester.takeException(), isNull, reason: 'form');
          for (final name in ['Sadece Ben', 'Takipçilerim', 'Herkes', 'Bu Bölgedekiler']) {
            await reveal(tester, find.text(name));
            expect(tester.getSize(find.text(name)).height, lessThan(24 * scale), reason: '$name wrapped at $width');
          }
          await tester.ensureVisible(find.byKey(const Key('memory-save')));
          expect(tester.getSize(find.text('Kaydet')).height, lessThan(26 * scale));
        });
      }
    }

    testWidgets('English: the memory screens carry no Turkish system text', (tester) async {
      AppLocale.debugSet(const Locale('en'));
      final backend = Backend()..memories.add(memoryJson(1, photos: 2, visibility: 'followers', body: 'Content', place: 'Alanya'));
      await pumpStore(tester, backend, (s) => section(s));
      final turkish = RegExp('[çğıöşüÇĞİÖŞÜ]');
      Set<String> texts() => {
        for (final rich in tester.widgetList<RichText>(find.byType(RichText, skipOffstage: false))) rich.text.toPlainText().trim(),
      }..removeWhere((t) => t.isEmpty);
      expect(texts().where(turkish.hasMatch), isEmpty, reason: '${texts()}');
      expect(find.text('+ Add Memory'), findsOneWidget);
      expect(find.text('My Followers'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpStore(tester, backend, (s) => const MemoryDetailPage(1));
      expect(texts().where(turkish.hasMatch), isEmpty, reason: '${texts()}');
      expect(find.text('Edit'), findsWidgets);
      expect(find.text('Visibility'), findsOneWidget);
    });
  });

  group('Anılar map', () {
    Widget profile(AppStore s) => Scaffold(body: ProfileContent(personId: s.me.id));

    Future<void> openMap(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('profile-tab-Anılar')));
      await tester.tap(find.byKey(const Key('profile-tab-Anılar')));
      await tester.pumpAndSettle();
    }

    Backend twelve() {
      final backend = Backend();
      for (var i = 1; i <= 6; i++) {
        backend.memories.add(memoryJson(i, body: 'Anı numarası $i', photos: i == 2 ? 3 : (i % 2), visibility: i == 3 ? 'public' : 'private', hidden: i == 4));
        backend.points[i] = (36.0 + i * 0.5, 30.0 + i * 0.5);
      }
      return backend;
    }

    testWidgets('Every placed memory is a small marker; a multi-photo memory carries its count, a photoless one the memory icon', (tester) async {
      final backend = twelve();
      await pumpStore(tester, backend, profile);
      await openMap(tester);
      expect(find.byKey(const Key('memories-map')), findsOneWidget);
      for (var i = 1; i <= 6; i++) {
        expect(find.byKey(ValueKey('memory-pin-$i')), findsOneWidget, reason: 'pin $i');
      }
      expect(find.byKey(const Key('memory-pin-count-2')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('memory-pin-count-2')), matching: find.text('3')), findsOneWidget);
      expect(find.byKey(const Key('memory-pin-count-1')), findsNothing, reason: 'A single photo has no badge.');
      expect(find.descendant(of: find.byKey(const ValueKey('memory-pin-1')), matching: find.byType(Image)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('memory-pin-6')), matching: find.byIcon(Icons.auto_stories_rounded)), findsOneWidget);
      // markers are drawn from thumbnails only
      expect(backend.requests.where((r) => r.url.path.contains('memory-media') && !r.url.path.endsWith('/thumb')), isEmpty);
    });

    testWidgets('Tapping a marker previews it; the preview opens the existing memory', (tester) async {
      final backend = twelve();
      await pumpStore(tester, backend, profile);
      await openMap(tester);
      expect(find.byKey(const Key('memory-preview')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('memory-pin-3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory-preview')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('memory-preview')), matching: find.text('14 Ağustos 2026')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('memory-preview')), matching: find.text('Alanya')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('memory-preview')), matching: find.text('Anı numarası 3')), findsOneWidget);
      expect(find.byKey(const Key('memory-preview-visibility')), findsOneWidget, reason: 'The owner sees the visibility.');
      await tester.tap(find.byKey(const Key('memory-preview-open')));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryDetailPage), findsOneWidget);
      expect(backend.where('GET', r'/memories/3$'), hasLength(1));
      Navigator.of(tester.element(find.byType(MemoryDetailPage))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memories-map')), findsOneWidget);
      await tester.tap(find.byKey(const Key('memory-preview-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory-preview')), findsNothing);
    });

    testWidgets('Someone else’s map: only what the server returned, no owner controls, no visibility in the preview', (tester) async {
      final backend = Backend()
        ..memories.add(memoryJson(7, body: 'Ada’nın anısı', mine: false, photos: 1))
        ..points[7] = (36.5, 32.0);
      await pumpStore(tester, backend, (s) => Scaffold(body: MemoriesMap(username: 'ada', own: false)));
      expect(find.byKey(const ValueKey('memory-pin-7')), findsOneWidget);
      expect(find.byKey(const Key('memory-add')), findsNothing);
      expect(find.byKey(const Key('memory-filter')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('memory-pin-7')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory-preview')), findsOneWidget);
      expect(find.byKey(const Key('memory-preview-visibility')), findsNothing);
      expect(backend.where('GET', r'/users/ada/memories/map'), hasLength(1));
    });


    testWidgets('Harita → Anılar: everybody’s memories of the area as pins, with the author, and no owner controls', (tester) async {
      final backend = Backend()
        ..memories.addAll([memoryJson(7, body: 'Ada’nın anısı', mine: false, photos: 2), memoryJson(8, body: 'Benim anım', visibility: 'public')])
        ..points[7] = (36.5, 32.0)
        ..points[8] = (36.6, 32.3);
      await pumpStore(tester, backend, (s) => const Scaffold(body: MemoriesMap.area()));
      expect(backend.where('GET', r'/map/memories'), hasLength(1));
      expect(backend.where('GET', r'/users/'), isEmpty, reason: 'No per-person request.');
      expect(find.byKey(const ValueKey('memory-pin-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('memory-pin-8')), findsOneWidget);
      expect(find.byKey(const Key('memory-add')), findsNothing);
      expect(find.byKey(const Key('memory-filter')), findsNothing);
      expect(find.byKey(const Key('memory-unlocated')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('memory-pin-7')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory-preview-author')), findsOneWidget);
      expect(find.text('Ada Test · @ada'), findsOneWidget);
      await tester.tap(find.byKey(const Key('memory-preview-open')));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryDetailPage), findsOneWidget);
    });

    testWidgets('Home: Yakındaki Anılar shows the photo of a memory, or its author’s picture with a memory badge', (tester) async {
      final backend = Backend()
        ..memories.addAll([
          memoryJson(7, body: 'Fotoğraflı', mine: false, photos: 1),
          memoryJson(8, body: 'Fotoğrafsız', mine: false),
        ])
        ..points[7] = (36.5, 32.0)
        ..points[8] = (36.6, 32.1);
      await pumpStore(tester, backend, (s) => const Scaffold(body: HomeMemoriesStrip()));
      expect(backend.where('GET', r'/map/memories'), hasLength(1));
      expect(find.byKey(const Key('home-memories-add')), findsOneWidget);
      expect(find.byKey(const Key('home-memory-7')), findsOneWidget);
      expect(find.byKey(const Key('home-memory-8')), findsOneWidget);
      expect(find.byKey(const Key('home-memory-badge-7')), findsNothing, reason: 'It has its own photo.');
      expect(find.byKey(const Key('home-memory-badge-8')), findsOneWidget, reason: 'No photo: the author’s picture, marked as a memory.');
      expect(find.descendant(of: find.byKey(const Key('home-memory-8')), matching: find.byType(Avatar)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('home-memory-7')), matching: find.byType(Avatar)), findsNothing);
      expect(find.text('Alanya'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('home-memory-8')));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryDetailPage), findsOneWidget);
    });

    testWidgets('Home: with the device position the strip keeps the server’s nearest-first order and shows the distance', (tester) async {
      final backend = Backend()
        ..memories.addAll([
          memoryJson(7, body: 'Yakın', mine: false, photos: 1),
          memoryJson(8, body: 'Uzak', mine: false, photos: 1),
        ])
        ..points[7] = (36.5, 32.0)
        ..points[8] = (36.6, 32.1)
        ..distances[7] = 500
        ..distances[8] = 12400;
      await pumpStore(tester, backend, (s) => const Scaffold(body: HomeMemoriesStrip()));
      expect(find.text('500 m'), findsOneWidget);
      expect(find.text('12,4 km'), findsOneWidget);
      expect(find.text('Alanya'), findsNothing, reason: 'The distance replaces the place name.');
      // The distance is a band along the lower rim of the circle: as wide as the photo, flush with its bottom edge.
      final label = tester.getRect(find.byKey(const Key('home-memory-label-7')));
      final photo = tester.getRect(find.descendant(of: find.byKey(const Key('home-memory-7')), matching: find.byType(ClipOval)));
      expect(label.width, closeTo(photo.width, 1));
      expect(label.bottom, closeTo(photo.bottom, 1));
      final near = tester.getTopLeft(find.byKey(const Key('home-memory-7'))).dx;
      final far = tester.getTopLeft(find.byKey(const Key('home-memory-8'))).dx;
      expect(near, lessThan(far));
    });

    testWidgets('Home: the strip says so when nobody shared a memory in the area', (tester) async {
      await pumpStore(tester, Backend(), (s) => const Scaffold(body: HomeMemoriesStrip()));
      expect(find.byKey(const Key('home-memories-empty')), findsOneWidget);
      expect(find.byKey(const Key('home-memories-add')), findsOneWidget);
    });

    testWidgets('Harita → Anılar with nothing in the area says so', (tester) async {
      await pumpStore(tester, Backend(), (s) => const Scaffold(body: MemoriesMap.area()));
      expect(find.text('Bu bölgede henüz paylaşılmış bir anı yok.'), findsOneWidget);
    });

    testWidgets('The owner’s Tümü · Görünür · Gizli chips ask the server; Gizli leaves only the hidden memory', (tester) async {
      final backend = twelve();
      await pumpStore(tester, backend, profile);
      await openMap(tester);
      expect(find.byKey(const Key('memory-filter')), findsOneWidget);
      await tester.tap(find.byKey(const Key('memory-filter-hidden')));
      await tester.pumpAndSettle();
      expect(backend.where('GET', r'/users/demo/memories/map').last.url.queryParameters['filter'], 'hidden');
      expect(find.byKey(const ValueKey('memory-pin-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('memory-pin-1')), findsNothing);
      await tester.tap(find.byKey(const Key('memory-filter-visible')));
      await tester.pumpAndSettle();
      expect(backend.where('GET', r'/users/demo/memories/map').last.url.queryParameters['filter'], 'visible');
      expect(find.byKey(const ValueKey('memory-pin-4')), findsNothing);
      expect(find.byKey(const ValueKey('memory-pin-1')), findsOneWidget);
    });

    testWidgets('Memories without a place wait behind a small “Konumsuz Anılar” button', (tester) async {
      final backend = Backend()
        ..memories.addAll([memoryJson(1, body: 'Yeri olan'), memoryJson(2, body: 'Yeri olmayan', area: false)])
        ..points[1] = (36.5, 32.0);
      await pumpStore(tester, backend, profile);
      await openMap(tester);
      expect(find.byKey(const ValueKey('memory-pin-1')), findsOneWidget);
      expect(find.byKey(const Key('memory-unlocated')), findsOneWidget);
      await tester.tap(find.byKey(const Key('memory-unlocated')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory-unlocated-sheet')), findsOneWidget);
      expect(find.text('Yeri olmayan'), findsOneWidget);
      expect(find.byKey(const Key('memory-card-2')), findsOneWidget);
    });

    testWidgets('Memories that stand close together become a counted cluster; a stack on one spot opens as a list', (tester) async {
      final backend = Backend();
      for (var i = 1; i <= 5; i++) {
        backend.memories.add(memoryJson(i, body: 'Aynı yer $i'));
        backend.points[i] = (36.545, 32.0);
      }
      await pumpStore(tester, backend, profile);
      await openMap(tester);
      final cluster = find.byWidgetPredicate((w) => w.key is ValueKey && (w.key! as ValueKey).value.toString().startsWith('memory-cluster-'));
      expect(cluster, findsOneWidget);
      expect(find.descendant(of: cluster, matching: find.text('5')), findsOneWidget);
      expect(find.byKey(const ValueKey('memory-pin-1')), findsNothing);
      await tester.tap(cluster);
      await tester.pumpAndSettle();
      expect(find.text('5 Anı'), findsOneWidget);
      expect(find.byKey(const Key('memory-group-3')), findsOneWidget);
      await tester.tap(find.byKey(const Key('memory-group-3')));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryDetailPage), findsOneWidget);
    });

    testWidgets('+ Anı: pick the place under a fixed pin, then Fotoğraf Çek / Galeriden Seç / Fotoğrafsız Devam Et, then the form', (tester) async {
      final backend = twelve();
      await pumpStore(tester, backend, profile);
      await openMap(tester);
      await tester.tap(find.byKey(const Key('memory-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory-pick-map')), findsOneWidget);
      expect(find.byKey(const Key('memory-pick-pin')), findsOneWidget);
      expect(find.byKey(const Key('memory-pick-crosshair')), findsOneWidget);
      expect(find.byKey(const Key('memory-pick-label')), findsOneWidget);
      await tester.tap(find.byKey(const Key('memory-pick-next')));
      await tester.pumpAndSettle();
      expect(find.text('Fotoğraf Ekle'), findsWidgets);
      expect(find.byKey(const Key('memory-photo-camera')), findsOneWidget);
      expect(find.byKey(const Key('memory-photo-gallery')), findsOneWidget);
      expect(find.byKey(const Key('memory-photo-skip')), findsOneWidget);
      await tester.tap(find.byKey(const Key('memory-photo-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory-text')), findsOneWidget);
      expect(find.byKey(const Key('memory-place-row')), findsOneWidget, reason: 'The location stays changeable in the form.');
      await tester.enterText(find.byKey(const Key('memory-text')), 'Haritadan seçtiğim yer');
      await tester.tap(find.byKey(const Key('memory-save')));
      await tester.pumpAndSettle();
      final create = backend.where('POST', r'/memories$').single;
      final body = backend.jsonBody(create);
      expect(body['latitude'], isA<num>());
      expect(body['longitude'], isA<num>());
      expect(body.containsKey('city_id'), isFalse, reason: 'A picked spot replaces the home area: the server finds the area itself.');
      expect(body['body'], 'Haritadan seçtiğim yer');
    });

    testWidgets('Galeriden Seç goes through the shared crop and lands in the form as photos', (tester) async {
      final backend = Backend();
      await pumpStore(tester, backend, profile);
      await openMap(tester);
      await tester.tap(find.byKey(const Key('memory-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory-pick-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory-photo-gallery')));
      await tester.pump();
      await confirmCrops(tester, 2);
      expect(find.byKey(const Key('memory-text')), findsOneWidget);
      expect(find.textContaining('Fotoğraflar (2/5)'), findsOneWidget);
    });

    testWidgets('Backing out of the pick screen changes nothing', (tester) async {
      final backend = twelve();
      await pumpStore(tester, backend, profile);
      await openMap(tester);
      await tester.tap(find.byKey(const Key('memory-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory-pick-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memories-map')), findsOneWidget);
      expect(backend.where('POST', r'/memories$'), isEmpty);
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 1.5), (390.0, 1.5), (430.0, 1.0)]) {
      testWidgets('The map, preview and sheets fit at $width dp, ${scale}x text', (tester) async {
        final backend = Backend()
          ..memories.addAll([
            memoryJson(2, body: 'Uzun bir anı. ' * 30, photos: 3, visibility: 'followers', hidden: true),
            memoryJson(9, body: 'Yeri olmayan ' * 20, area: false),
          ])
          ..points[2] = (36.545, 32.0);
        await pumpStore(tester, backend, profile, width: width, scale: scale);
        await openMap(tester);
        await tester.tap(find.byKey(const ValueKey('memory-pin-2')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('memory-preview-open')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('memory-unlocated')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
