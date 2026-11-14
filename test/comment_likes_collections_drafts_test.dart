// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/data/account_api.dart';
import 'support/comments_host.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/communication_api.dart';
import 'package:senmiydin/data/compose_draft.dart';
import 'package:senmiydin/data/location_service.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/data/post_context.dart';
import 'package:senmiydin/screens/compose.dart';
import 'package:senmiydin/screens/live_notifications.dart';
import 'package:senmiydin/screens/post.dart';
import 'package:senmiydin/widgets/collections.dart';

http.Response ok(Object? data, [int status = 200]) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response fail(int status, String message, [Map<String, Object?>? errors]) =>
    http.Response(
      jsonEncode({'success': false, 'message': message, 'errors': errors ?? {}}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class _Device extends LocationDevice {
  @override
  bool get supportsBackground => false;
}

Map<String, dynamic> account({int id = 1, String username = 'demo'}) => {
  'id': id,
  'name': 'Demo',
  'username': username,
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

Map<String, dynamic> postJson(int id, String body, {bool saved = true}) => {
  'id': id,
  'body': body,
  'type': 'moment',
  'city': {'id': 1, 'name': 'Alanya'},
  'is_anonymous': false,
  'author': {'id': 21, 'username': 'ece', 'name': 'Ece Test', 'avatar': null},
  'comments_enabled': true,
  'visibility': 'city',
  'likes_count': 0,
  'comments_count': 0,
  'saved': saved,
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
  String created = '2026-11-14T11:00:00Z',
  List<Map<String, dynamic>> replies = const [],
}) => {
  'id': id,
  'body': body,
  'parent_id': parent,
  'mine': false,
  'likes_count': likes,
  'liked_by_me': liked,
  'author': {'id': username.hashCode.abs() % 900 + 30, 'username': username, 'name': '${username.toUpperCase()} Test', 'avatar': null},
  'created_at': created,
  if (parent == null) 'reply_count': replies.length,
  if (parent == null) 'replies': replies,
};

Future<AppStore> connected(
  Future<http.Response> Function(http.Request) handler, {
  ComposeDraftStore? drafts,
  Map<String, dynamic>? user,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  final store = AppStore(
    api: ApiClient(httpClient: MockClient(handler)),
    locationDevice: _Device(),
    drafts: drafts,
  );
  await store.signIn('login', {'identifier': 'demo', 'password': 'x', '_user': user});
  return store;
}

class _Routes extends NavigatorObserver {
  final names = <String>[];
  final arguments = <Object?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    names.add(route.settings.name ?? '');
    arguments.add(route.settings.arguments);
  }
}

Widget host(AppStore store, Widget child, {NavigatorObserver? observer, double scale = 1}) => StoreScope(
  store: store,
  child: MaterialApp(
    navigatorObservers: [?observer],
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

Future<void> chipVisible(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
}

void main() {
  void size(WidgetTester tester, double width, [double height = 1000]) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // ----------------------------------------------------------------------------------- comment likes
  group('Comment likes', () {
    Future<AppStore> commentsStore(Future<http.Response> Function(http.Request)? like, {int topLikes = 4}) => connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.endsWith('/posts/5') && request.method == 'GET') return ok(postJson(5, 'Dün sahildeydim.'));
      if (path.endsWith('/like') && like != null) return like(request);
      if (path.endsWith('/posts/5/comments')) {
        return ok({
          'items': [
            commentJson(10, 'Ana yorum', likes: topLikes, replies: [commentJson(11, 'Bir cevap', username: 'kaan', parent: 10, likes: 1, liked: true)]),
          ],
          'next_page': null,
        });
      }
      return ok({'items': [], 'next_page': null});
    });

    testWidgets('Every comment and reply shows an outline heart with its count; replies only offer the heart', (tester) async {
      size(tester, 320);
      final store = await commentsStore(null);
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const OpenComments('5')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('like-comment-10')), findsOneWidget);
      expect(find.byKey(const ValueKey('like-comment-11')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-10')), matching: find.text('4')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-10')), matching: find.byIcon(Icons.favorite_border_rounded)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-11')), matching: find.byIcon(Icons.favorite_rounded)), findsOneWidget, reason: 'Already liked: filled heart.');
      expect(find.byKey(const ValueKey('reply-10')), findsOneWidget);
      expect(find.byKey(const ValueKey('reply-11')), findsNothing, reason: 'No "Yanıtla" under a reply.');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Liking updates at once (optimistic), settles on the server answer and unliking works', (tester) async {
      size(tester, 390);
      final answer = Completer<http.Response>();
      var calls = <String>[];
      final store = await commentsStore((request) {
        calls.add('${request.method} ${request.url.path}');
        return request.method == 'POST'
            ? answer.future
            : Future.value(ok(commentJson(10, 'Ana yorum', likes: 4, liked: false)));
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const OpenComments('5')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('like-comment-10')));
      await tester.pump();
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-10')), matching: find.text('5')), findsOneWidget, reason: 'Optimistic count before the server answers.');
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-10')), matching: find.byIcon(Icons.favorite_rounded)), findsOneWidget);
      // A second tap while the request is in flight is ignored (no double count).
      await tester.tap(find.byKey(const ValueKey('like-comment-10')));
      await tester.pump();
      expect(calls.length, 1);
      answer.complete(ok(commentJson(10, 'Ana yorum', likes: 7, liked: true)));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-10')), matching: find.text('7')), findsOneWidget, reason: 'The server count wins.');

      await tester.tap(find.byKey(const ValueKey('like-comment-10')));
      await tester.pumpAndSettle();
      expect(calls.last, 'DELETE /api/v1/posts/5/comments/10/like');
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-10')), matching: find.text('4')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-10')), matching: find.byIcon(Icons.favorite_border_rounded)), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('A failed like is rolled back and explained; replies like the same way', (tester) async {
      size(tester, 390);
      var reject = true;
      final store = await commentsStore((request) async {
        if (reject) return fail(404, 'Aradığın kayıt bulunamadı.');
        return ok(commentJson(11, 'Bir cevap', username: 'kaan', parent: 10, likes: 0, liked: false));
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const OpenComments('5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('like-comment-10')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-10')), matching: find.text('4')), findsOneWidget, reason: 'Rolled back.');
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-10')), matching: find.byIcon(Icons.favorite_border_rounded)), findsOneWidget);
      expect(find.text('Aradığın kayıt bulunamadı.'), findsOneWidget);

      reject = false;
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.byKey(const ValueKey('like-comment-11')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-11')), matching: find.byIcon(Icons.favorite_border_rounded)), findsOneWidget, reason: 'Reply unliked.');
      expect(find.descendant(of: find.byKey(const ValueKey('like-comment-11')), matching: find.text('0')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('At 1.5x text the comment screen does not overflow', (tester) async {
      size(tester, 320);
      final store = await commentsStore(null);
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const OpenComments('5'), scale: 1.5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Whatever the age of a comment the time label never overflows a narrow reply at 1.5x text (wall-clock independent)', (tester) async {
      String ago(Duration d) => DateTime.now().toUtc().subtract(d).toIso8601String();
      for (final age in [const Duration(seconds: 5), const Duration(minutes: 47), const Duration(hours: 23), const Duration(days: 6), const Duration(days: 400)]) {
        size(tester, 320);
        final store = await connected((request) async {
          final path = request.url.path;
          if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
          if (path.endsWith('/posts/5') && request.method == 'GET') return ok(postJson(5, 'Dün sahildeydim.'));
          if (path.endsWith('/posts/5/comments')) {
            return ok({
              'items': [
                commentJson(10, 'Ana yorum', created: ago(age), replies: [commentJson(11, 'Bir cevap', username: 'kaan', parent: 10, created: ago(age))]),
              ],
              'next_page': null,
            });
          }
          return ok({'items': [], 'next_page': null});
        });
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, const OpenComments('5'), scale: 1.5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'comment aged $age');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('A comment_like notification opens the post comments; an unavailable one explains itself', (tester) async {
      size(tester, 390);
      final store = await connected((request) async => ok({'token': 't', 'user': account()}));
      addTearDown(store.dispose);
      final routes = _Routes();
      InboxNotification item({bool available = true}) => InboxNotification({
        'id': 1,
        'type': 'comment_like',
        'route': '/comments',
        'entity_id': 5,
        'actor': {'id': 9, 'username': 'ece', 'name': 'Ece', 'avatar': null},
        'text': 'Yorumunu beğendi.',
        'available': available,
        'read': false,
        'created_at': '2026-11-14T11:00:00Z',
      }, (json) => Person(id: 'account-9', name: 'Ece', handle: 'ece', photo: ''));
      await tester.pumpWidget(host(store, Scaffold(body: Builder(builder: (context) => Column(children: [
        TextButton(onPressed: () => routeInboxNotification(Navigator.of(context), item()), child: const Text('go')),
        TextButton(onPressed: () => routeInboxNotification(Navigator.of(context), item(available: false)), child: const Text('gone')),
      ]))), observer: routes));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(routes.names, contains('/comments'));
      expect(routes.arguments.last, '5', reason: 'The post id, so the comments screen of that post opens.');
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('gone'));
      await tester.pump();
      expect(find.text('Bu içerik artık kullanılamıyor.'), findsOneWidget);
      expect(routes.names.where((n) => n == '/comments').length, 1, reason: 'An unavailable target opens nothing.');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  // ----------------------------------------------------------------------------------- collections
  group('Saved collections', () {
    Future<AppStore> savedStore({
      required List<Map<String, dynamic>> collections,
      Map<int, List<Map<String, dynamic>>> members = const {},
      List<String>? log,
      List<Map<String, dynamic>>? all,
    }) => connected((request) async {
      final path = request.url.path;
      log?.add('${request.method} $path ${request.body}');
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.endsWith('/posts/saved')) return ok({'items': all ?? [postJson(1, 'Kaydedilen bir')], 'next_page': null});
      final posts = RegExp(r'saved-collections/(\d+)/posts$').firstMatch(path);
      if (posts != null && request.method == 'GET') return ok({'items': members[int.parse(posts.group(1)!)] ?? [], 'next_page': null});
      final member = RegExp(r'saved-collections/(\d+)/posts/(\d+)$').firstMatch(path);
      if (member != null) {
        return ok({'id': int.parse(member.group(1)!), 'name': 'Alanya', 'posts_count': request.method == 'PUT' ? 1 : 0, 'contains_post': request.method == 'PUT'});
      }
      if (path.endsWith('/saved-collections') && request.method == 'POST') {
        final name = (jsonDecode(request.body) as Map)['name'];
        if (name == 'Alanya' && collections.any((c) => c['name'] == 'Alanya')) return fail(422, 'Bilgilerini kontrol et.', {'name': ['Bu isimde bir koleksiyonun zaten var.']});
        final created = {'id': 50, 'name': name, 'posts_count': 0};
        collections.add(created);
        return ok(created, 201);
      }
      final one = RegExp(r'saved-collections/(\d+)$').firstMatch(path);
      if (one != null && request.method == 'PUT') {
        final id = int.parse(one.group(1)!);
        final name = (jsonDecode(request.body) as Map)['name'];
        collections.firstWhere((c) => c['id'] == id)['name'] = name;
        return ok(collections.firstWhere((c) => c['id'] == id));
      }
      if (one != null && request.method == 'DELETE') {
        collections.removeWhere((c) => c['id'] == int.parse(one.group(1)!));
        return ok(null);
      }
      if (path.endsWith('/saved-collections')) return ok({'items': collections, 'limit': 30});
      return ok({'items': [], 'next_page': null});
    });

    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('Tümü, the collection chips and + fit at $width px (with 1.5x text); a chip filters the list', (tester) async {
        size(tester, width);
        final store = await savedStore(
          collections: [
            {'id': 1, 'name': 'Sonra Bak', 'posts_count': 2},
            {'id': 2, 'name': 'Alanya', 'posts_count': 1},
            {'id': 3, 'name': 'Yolculuklar', 'posts_count': 0},
            {'id': 4, 'name': 'Çok uzun bir koleksiyon adı burada', 'posts_count': 0},
          ],
          members: {2: [postJson(7, 'Alanya gönderisi')]},
        );
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, const SavedPage(), scale: 1.5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('collection-all')), findsOneWidget);
        await chipVisible(tester, const Key('collection-new'));
        expect(find.byKey(const Key('collection-new')), findsOneWidget);
        expect(find.text('Kaydedilen bir'), findsOneWidget, reason: 'Tümü shows the main saved list.');

        await chipVisible(tester, const ValueKey('collection-2'));
        await tester.tap(find.byKey(const ValueKey('collection-2')));
        await tester.pumpAndSettle();
        expect(find.text('Alanya gönderisi'), findsOneWidget);
        expect(find.text('Kaydedilen bir'), findsNothing);
        expect(find.byKey(const Key('rename-collection')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await chipVisible(tester, const Key('collection-all'));
        await tester.tap(find.byKey(const Key('collection-all')));
        await tester.pumpAndSettle();
        expect(find.text('Kaydedilen bir'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('+ creates a collection (and shows server validation), rename and delete go to the server', (tester) async {
      size(tester, 390);
      final log = <String>[];
      final collections = <Map<String, dynamic>>[
        {'id': 2, 'name': 'Alanya', 'posts_count': 1},
      ];
      final store = await savedStore(collections: collections, log: log);
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const SavedPage()));
      await tester.pumpAndSettle();

      // A duplicate name is explained, no chip is added.
      await tester.tap(find.byKey(const Key('collection-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('collection-name-field')), 'Alanya');
      await tester.tap(find.byKey(const Key('collection-name-save')));
      await tester.pumpAndSettle();
      expect(find.text('Bu isimde bir koleksiyonun zaten var.'), findsOneWidget);
      expect(collections.length, 1);
      await tester.pump(const Duration(seconds: 4));

      // A new one appears and is selected.
      await tester.tap(find.byKey(const Key('collection-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('collection-name-field')), 'Güzel Anılar');
      await tester.tap(find.byKey(const Key('collection-name-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('collection-50')), findsOneWidget);
      expect(log.any((entry) => entry.startsWith('POST') && entry.contains('Güzel Anılar')), isTrue);

      // Rename.
      await tester.tap(find.byKey(const Key('rename-collection')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('collection-name-field')), 'Anılarım');
      await tester.tap(find.byKey(const Key('collection-name-save')));
      await tester.pumpAndSettle();
      expect(find.text('Anılarım'), findsWidgets);
      expect(log.any((entry) => entry.startsWith('PUT') && entry.contains('saved-collections/50') && entry.contains('Anılarım')), isTrue);

      // Delete: the posts stay in Tümü, the screen falls back to it.
      await tester.tap(find.byKey(const Key('delete-collection')));
      await tester.pumpAndSettle();
      expect(find.text('Koleksiyon silinsin mi?'), findsOneWidget);
      expect(find.textContaining('Kaydedilenler’de kalır'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await tester.pumpAndSettle();
      expect(log.any((entry) => entry.startsWith('DELETE') && entry.contains('saved-collections/50')), isTrue);
      expect(find.byKey(const ValueKey('collection-50')), findsNothing);
      expect(find.text('Kaydedilen bir'), findsOneWidget, reason: 'Deleting a collection never removes the saved post.');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('The add-to-collection sheet ticks existing collections, adds and removes a post, and can create one', (tester) async {
      size(tester, 390, 900);
      final log = <String>[];
      final collections = <Map<String, dynamic>>[
        {'id': 1, 'name': 'Sonra Bak', 'posts_count': 0, 'contains_post': true},
        {'id': 2, 'name': 'Alanya', 'posts_count': 0, 'contains_post': false},
      ];
      final store = await savedStore(collections: collections, log: log);
      addTearDown(store.dispose);
      final post = store.loadSaved; // keeps the store alive for the sheet
      expect(post, isNotNull);
      final saved = (await store.loadSaved(1)).items.first;
      await tester.pumpWidget(host(store, Builder(builder: (context) => TextButton(
        onPressed: () => showAddToCollectionSheet(context, store, saved),
        child: const Text('open'),
      ))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Koleksiyona Ekle'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('sheet-collection-1'))).value, isTrue);
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('sheet-collection-2'))).value, isFalse);

      await tester.tap(find.byKey(const ValueKey('sheet-collection-2')));
      await tester.pumpAndSettle();
      expect(log.any((entry) => entry.startsWith('PUT') && entry.contains('saved-collections/2/posts/1')), isTrue);
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('sheet-collection-2'))).value, isTrue);
      await tester.tap(find.byKey(const ValueKey('sheet-collection-1')));
      await tester.pumpAndSettle();
      expect(log.any((entry) => entry.startsWith('DELETE') && entry.contains('saved-collections/1/posts/1')), isTrue);
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('sheet-collection-1'))).value, isFalse);
      expect(saved.saved, isTrue, reason: 'Leaving a collection never un-saves the post.');

      await tester.tap(find.byKey(const Key('sheet-new-collection')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('collection-name-field')), 'Yolculuklar');
      await tester.tap(find.byKey(const Key('collection-name-save')));
      await tester.pumpAndSettle();
      expect(log.any((entry) => entry.startsWith('POST') && entry.contains('Yolculuklar')), isTrue);
      expect(log.any((entry) => entry.startsWith('PUT') && entry.contains('saved-collections/50/posts/1')), isTrue, reason: 'The new collection already holds the post.');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  // ----------------------------------------------------------------------------------- draft store (local, no UI)
  group('Compose draft storage', () {
    late Directory root;
    late ComposeDraftStore drafts;
    Directory? picker;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('senmiydin_drafts_');
      picker = await Directory.systemTemp.createTemp('senmiydin_picker_');
      drafts = ComposeDraftStore(root: () async => root);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
      if (picker != null && await picker!.exists()) await picker!.delete(recursive: true);
    });

    Future<String> photo(String name, String content) async {
      final file = File('${picker!.path}/$name');
      await file.writeAsString(content);
      return file.path;
    }

    ComposeDraft full(List<String> images) => ComposeDraft(
      body: 'Dün sahilde yürürken seni gördüm.',
      kind: PostKind.journey,
      anonymous: true,
      cityWide: false,
      city: 'Ankara',
      attachLocation: true,
      place: PostPlaceSelection('map', latitude: 36.54, longitude: 32.0, city: 'Alanya', label: 'Alanya · Haritadan', recordedAt: DateTime.utc(2026, 11, 10, 18, 20)),
      occurredAt: DateTime.utc(2026, 11, 10, 18, 20),
      taggedId: 'account-9',
      requestId: '11111111-1111-4111-8111-111111111111',
      travel: TravelDraft()
        ..enabled = true
        ..isPublic = true
        ..transport = 'train'
        ..operatorName = 'TCDD'
        ..serviceCode = 'YHT 1'
        ..vehicleIdentifier = 'A12'
        ..origin = 'Ankara'
        ..destination = 'Eskişehir'
        ..departureAt = DateTime.utc(2026, 11, 14, 7, 30),
      images: images,
    );

    test('Text, type, anonymous, location / context and travel fields survive a restart', () async {
      await drafts.save('account-1', full([]));
      // A brand-new store instance on the same folder = the app was restarted.
      final restored = (await ComposeDraftStore(root: () async => root).load('account-1'))!;
      expect(restored.body, 'Dün sahilde yürürken seni gördüm.');
      expect(restored.kind, PostKind.journey);
      expect(restored.anonymous, isTrue);
      expect(restored.cityWide, isFalse);
      expect(restored.city, 'Ankara');
      expect(restored.attachLocation, isTrue);
      expect(restored.place!.source, 'map');
      expect(restored.place!.latitude, 36.54);
      expect(restored.place!.city, 'Alanya');
      expect(restored.place!.recordedAt, DateTime.utc(2026, 11, 10, 18, 20));
      expect(restored.occurredAt, DateTime.utc(2026, 11, 10, 18, 20));
      expect(restored.taggedId, 'account-9');
      expect(restored.requestId, '11111111-1111-4111-8111-111111111111');
      expect(restored.travel.enabled, isTrue);
      expect(restored.travel.isPublic, isTrue);
      expect(restored.travel.transport, 'train');
      expect(restored.travel.operatorName, 'TCDD');
      expect(restored.travel.serviceCode, 'YHT 1');
      expect(restored.travel.vehicleIdentifier, 'A12');
      expect(restored.travel.origin, 'Ankara');
      expect(restored.travel.destination, 'Eskişehir');
      expect(restored.travel.departureAt, DateTime.utc(2026, 11, 14, 7, 30));
    });

    test('Photos are copied into private app storage in the same order and survive the picker cache being wiped', () async {
      final a = await photo('a.jpg', 'AAA');
      final b = await photo('b.png', 'BBB');
      final c = await photo('c', 'CCC');
      final stored = await drafts.save('account-1', full([c, a, b]));
      expect(stored.length, 3);
      for (final path in stored) {
        expect(path.startsWith(root.path), isTrue, reason: 'Inside the private draft folder, not the picker cache.');
      }
      await picker!.delete(recursive: true);
      final restored = (await drafts.load('account-1'))!;
      expect(restored.images.length, 3);
      expect(await File(restored.images[0]).readAsString(), 'CCC', reason: 'Order is kept.');
      expect(await File(restored.images[1]).readAsString(), 'AAA');
      expect(await File(restored.images[2]).readAsString(), 'BBB');
      expect(restored.images[1].endsWith('.jpg'), isTrue);
      expect(restored.images[2].endsWith('.png'), isTrue);
      expect(restored.images[0].endsWith('.jpg'), isTrue, reason: 'Unknown extensions fall back to .jpg.');

      // Reordering / removing keeps only what is still referenced.
      final reordered = await drafts.save('account-1', full([restored.images[2], restored.images[0]]));
      final media = Directory('${root.path}/compose_drafts/account-1/media');
      expect(media.listSync().whereType<File>().length, 2, reason: 'The removed photo\'s copy is deleted.');
      expect(await File(reordered[0]).readAsString(), 'BBB');
      expect(await File(reordered[1]).readAsString(), 'CCC');
    });

    test('Discard and an emptied composer remove the JSON and every photo copy', () async {
      final a = await photo('a.jpg', 'AAA');
      await drafts.save('account-1', full([a]));
      expect(await drafts.exists('account-1'), isTrue);
      await drafts.clear('account-1');
      expect(await drafts.exists('account-1'), isFalse);
      expect(Directory('${root.path}/compose_drafts/account-1').existsSync(), isFalse);
      expect(await drafts.load('account-1'), isNull);

      await drafts.save('account-1', full([await photo('b.jpg', 'BBB')]));
      await drafts.save('account-1', ComposeDraft()); // nothing worth keeping left
      expect(await drafts.exists('account-1'), isFalse);
      expect(Directory('${root.path}/compose_drafts/account-1').existsSync(), isFalse);
    });

    test('Drafts never cross accounts, and a hostile account id cannot escape the draft folder', () async {
      await drafts.save('account-1', ComposeDraft(body: 'Demo taslağı'));
      expect(await drafts.load('account-2'), isNull);
      expect((await drafts.load('account-1'))!.body, 'Demo taslağı');
      await drafts.save('account-2', ComposeDraft(body: 'Elif taslağı'));
      expect((await drafts.load('account-1'))!.body, 'Demo taslağı');
      await drafts.clear('account-2');
      expect((await drafts.load('account-1'))!.body, 'Demo taslağı', reason: 'Clearing one account keeps the other.');
      expect(ComposeDraftStore.key('../../etc/passwd'), isNot(contains('/')));
      await drafts.save('../outside', ComposeDraft(body: 'x'));
      expect(File('${root.parent.path}/outside/draft.json').existsSync(), isFalse);
      expect(Directory('${root.path}/compose_drafts').listSync().length, 2);
    });

    test('Corrupt, truncated, wrong-version or empty drafts are ignored without crashing and are cleaned up', () async {
      for (final content in ['{not json', '', '[]', '{"v":999,"body":"x"}', '{"v":1,"kind":5,"body":3}', '{"v":1,"body":"ok","travel":"bad","images":[1,"../x.jpg"]}', 'null']) {
        final dir = Directory('${root.path}/compose_drafts/account-9');
        await dir.create(recursive: true);
        await File('${dir.path}/draft.json').writeAsString(content);
        final loaded = await drafts.load('account-9');
        if (content.contains('"body":"ok"')) {
          expect(loaded?.body, 'ok', reason: 'A draft with a few odd fields still restores what is valid.');
          expect(loaded?.images, isEmpty, reason: 'Path-like photo names are dropped.');
        } else {
          expect(loaded, isNull, reason: 'Ignored: $content');
        }
        await drafts.clear('account-9');
      }
    });

    test('Missing photo files are dropped; a draft left with nothing is discarded; concurrent saves keep the newest', () async {
      final a = await photo('a.jpg', 'AAA');
      final stored = await drafts.save('account-1', full([a]));
      await File(stored.single).delete();
      final restored = (await drafts.load('account-1'))!;
      expect(restored.images, isEmpty);
      expect(restored.body, isNotEmpty, reason: 'The text still restores.');

      await Future.wait([
        drafts.save('account-1', ComposeDraft(body: 'ilk')),
        drafts.save('account-1', ComposeDraft(body: 'ikinci')),
        drafts.save('account-1', ComposeDraft(body: 'son')),
      ]);
      expect((await drafts.load('account-1'))!.body, 'son');
    });
  });

  // ----------------------------------------------------------------------------------- composer + drafts
  group('Composer draft behaviour', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('senmiydin_compose_');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    ComposeDraftStore newDrafts() => ComposeDraftStore(root: () async => root);

    Future<AppStore> composeStore({int id = 1, ComposeDraftStore? drafts, List<String>? log}) => connected((request) async {
      final path = request.url.path;
      log?.add('${request.method} $path');
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account(id: id)});
      if (path.endsWith('/cities')) return ok([{'id': 1, 'name': 'Alanya'}]);
      if (path.endsWith('/posts') && request.method == 'POST') return ok(postJson(99, 'Yayınlandı'), 201);
      return ok({'items': [], 'next_page': null, 'location_required': false});
    }, drafts: drafts ?? newDrafts());

    /// Real file I/O completes on the real clock: alternate short real waits with pumps until the async chain is done.
    Future<void> real(WidgetTester tester, [int ms = 150]) async {
      final rounds = (ms / 30).ceil().clamp(5, 40);
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
    }

    testWidgets('Typing saves a draft after a short debounce (not on every key), leaving keeps it, reopening offers Devam Et', (tester) async {
      size(tester, 390, 1200);
      final store = await composeStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const ComposePage()));
      await tester.pumpAndSettle();
      await real(tester, 900);
      expect(find.byKey(const Key('draft-dialog')), findsNothing, reason: 'No draft yet.');

      await tester.enterText(find.byKey(const Key('post-text')), 'Dün');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byKey(const Key('post-text')), 'Dün sahilde');
      await tester.pump(const Duration(milliseconds: 300));
      await real(tester);
      expect(File('${root.path}/compose_drafts/account-1/draft.json').existsSync(), isFalse, reason: 'Still inside the debounce window: no disk write per keystroke.');
      await tester.pump(const Duration(seconds: 2));
      await real(tester, 600);
      expect(File('${root.path}/compose_drafts/account-1/draft.json').existsSync(), isTrue);

      // Leave without publishing: no "your draft will be deleted" prompt, the draft stays.
      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Paylaşımdan çıkılsın mı?'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host(store, const ComposePage()));
      await tester.pumpAndSettle();
      await real(tester, 600);
      await tester.pumpAndSettle();
      expect(find.text('Kaydedilmiş bir taslağın var.'), findsOneWidget);
      expect(find.byKey(const Key('draft-resume')), findsOneWidget);
      expect(find.byKey(const Key('draft-discard')), findsOneWidget);
      await tester.tap(find.byKey(const Key('draft-resume')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('post-text'))).controller!.text, 'Dün sahilde');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Devam Et restores type and anonymous choice and photos in order; Sil clears everything and opens clean', (tester) async {
      size(tester, 390, 1400);
      final photoDir = Directory.systemTemp.createTempSync('senmiydin_pick_');
      addTearDown(() => photoDir.deleteSync(recursive: true));
      final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
      final one = File('${photoDir.path}/one.jpg')..writeAsBytesSync(png);
      final two = File('${photoDir.path}/two.jpg')..writeAsBytesSync(png);
      final store = await composeStore();
      addTearDown(store.dispose);
      await tester.runAsync(() => store.drafts.save('account-1', ComposeDraft(
        body: 'Yolda yarım kalan bir an',
        kind: PostKind.journey,
        anonymous: true,
        images: [two.path, one.path],
        travel: TravelDraft()..enabled = true..transport = 'train'..destination = 'Eskişehir',
      )));

      await tester.pumpWidget(host(store, const ComposePage()));
      await tester.pumpAndSettle();
      await real(tester, 600);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('draft-resume')));
      await tester.pump();
      await real(tester, 300);
      expect(tester.widget<TextField>(find.byKey(const Key('post-text'))).controller!.text, 'Yolda yarım kalan bir an');
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.any((s) => s.value), isTrue, reason: 'The anonymous toggle came back on.');
      expect(find.textContaining('Eskişehir'), findsWidgets, reason: 'Travel fields are back.');
      await tester.pumpWidget(const SizedBox.shrink());
      await real(tester, 200);

      // Sil.
      await tester.pumpWidget(host(store, const ComposePage()));
      await tester.pumpAndSettle();
      await real(tester, 600);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('draft-discard')));
      await tester.pump();
      await real(tester, 300);
      expect(tester.widget<TextField>(find.byKey(const Key('post-text'))).controller!.text, isEmpty);
      expect(File('${root.path}/compose_drafts/account-1/draft.json').existsSync(), isFalse);
      expect(Directory('${root.path}/compose_drafts/account-1').existsSync(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Taking a while to answer "Kaydedilmiş bir taslağın var" never wipes the saved draft (regression)', (tester) async {
      size(tester, 390, 1200);
      final store = await composeStore();
      addTearDown(store.dispose);
      await tester.runAsync(() => store.drafts.save('account-1', ComposeDraft(body: 'Yarım kalan cümle', kind: PostKind.confession)));
      await tester.pumpWidget(host(store, const ComposePage()));
      await tester.pumpAndSettle();
      await real(tester, 600);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-dialog')), findsOneWidget);
      // The user reads the dialog for several seconds: the empty composer behind it must not overwrite / clear the draft.
      await tester.pump(const Duration(seconds: 5));
      await real(tester, 600);
      expect(File('${root.path}/compose_drafts/account-1/draft.json').existsSync(), isTrue, reason: 'Still stored while the question is open.');
      await tester.tap(find.byKey(const Key('draft-resume')));
      await tester.pump();
      await real(tester, 300);
      expect(tester.widget<TextField>(find.byKey(const Key('post-text'))).controller!.text, 'Yarım kalan cümle');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Opening the composer and leaving without touching anything never creates or clears a draft', (tester) async {
      size(tester, 390, 1000);
      final store = await composeStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const ComposePage()));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await real(tester, 300);
      expect(File('${root.path}/compose_drafts/account-1/draft.json').existsSync(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await real(tester, 300);
      expect(File('${root.path}/compose_drafts/account-1/draft.json').existsSync(), isFalse);
    });

    testWidgets('A successful publish clears the draft; the next composer opens without the prompt', (tester) async {
      size(tester, 390, 1200);
      final log = <String>[];
      final store = await composeStore(log: log);
      addTearDown(store.dispose);
      // The composer sits on top of another page, as in the app (publishing pops it).
      await tester.pumpWidget(host(store, Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ComposePage())),
        child: const Text('compose'),
      )))));
      await tester.tap(find.text('compose'));
      await tester.pumpAndSettle();
      await real(tester, 900);
      await tester.enterText(find.byKey(const Key('post-text')), 'Yayınlanacak bir anı');
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await real(tester, 900);
      expect(File('${root.path}/compose_drafts/account-1/draft.json').existsSync(), isTrue);

      final publish = find.byKey(const Key('publish-post'));
      await tester.ensureVisible(publish);
      await tester.tap(publish);
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byKey(const Key('publish-post')).evaluate().isEmpty) break;
      }
      expect(log.any((entry) => entry == 'POST /api/v1/posts'), isTrue);
      expect(File('${root.path}/compose_drafts/account-1/draft.json').existsSync(), isFalse, reason: 'The published post leaves no draft.');

      await tester.tap(find.text('compose'));
      await tester.pumpAndSettle();
      await real(tester, 600);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-dialog')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Another account never sees the draft, and a corrupt draft file opens a clean composer', (tester) async {
      size(tester, 390, 1000);
      final demo = await composeStore(id: 1);
      addTearDown(demo.dispose);
      await tester.runAsync(() => demo.drafts.save('account-1', ComposeDraft(body: 'Demo taslağı')));

      final elif = await composeStore(id: 2);
      addTearDown(elif.dispose);
      await tester.pumpWidget(host(elif, const ComposePage()));
      await tester.pumpAndSettle();
      await real(tester, 600);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-dialog')), findsNothing, reason: 'Demo\'s draft stays private to Demo.');
      expect(tester.widget<TextField>(find.byKey(const Key('post-text'))).controller!.text, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());

      // Corrupt file for Elif: ignored, no crash.
      final dir = Directory('${root.path}/compose_drafts/account-2')..createSync(recursive: true);
      File('${dir.path}/draft.json').writeAsStringSync('{truncated');
      await tester.pumpWidget(host(elif, const ComposePage()));
      await tester.pumpAndSettle();
      await real(tester, 600);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('draft-dialog')), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('post-text'))).controller!.text, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());

      // Demo still finds its own.
      await tester.pumpWidget(host(demo, const ComposePage()));
      await tester.pumpAndSettle();
      await real(tester, 600);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-dialog')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('Deleting the account removes the local draft with its photos', () async {
      final store = await connected((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
        return ok(null);
      }, drafts: newDrafts());
      final photoDir = await Directory.systemTemp.createTemp('senmiydin_pick_');
      final image = File('${photoDir.path}/x.jpg')..writeAsBytesSync([1]);
      await store.drafts.save('account-1', ComposeDraft(body: 'silinecek', images: [image.path]));
      expect(Directory('${root.path}/compose_drafts/account-1/media').listSync().length, 1);
      await store.eraseAccount('Parola1234');
      expect(Directory('${root.path}/compose_drafts/account-1').existsSync(), isFalse);
      store.dispose();
      await photoDir.delete(recursive: true);
    });
  });
}
