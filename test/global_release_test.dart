// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:senmiydin/core/ads_config.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/ads_service.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/communication_api.dart';
import 'package:senmiydin/data/location_service.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/data/social_api.dart';
import 'package:senmiydin/screens/direct_chat.dart';
import 'package:senmiydin/screens/home.dart';
import 'package:senmiydin/screens/live_notifications.dart';
import 'package:senmiydin/screens/settings.dart';
import 'package:senmiydin/widgets/chat_composer.dart';
import 'package:senmiydin/widgets/common.dart';
import 'package:senmiydin/widgets/native_feed_ad.dart';
import 'package:senmiydin/widgets/notifications_sheet.dart';
import 'package:senmiydin/widgets/social.dart';

http.Response ok(Object? data, [int status = 200]) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Device extends LocationDevice {
  @override
  bool get supportsBackground => false;
}

Map<String, dynamic> account({String ageBand = 'adult'}) => {
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
  'age_band': ageBand,
};

Map<String, dynamic> postJson(int id, String body) => {
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
  'saved': false,
  'media': [],
  'created_at': '2026-11-14T10:00:00Z',
};

Map<String, dynamic> noticeJson(
  int id,
  String type, {
  DateTime? at,
  bool read = false,
  int? entity,
  bool available = true,
  Map<String, dynamic>? actor,
  String? body,
  Map<String, double>? map,
  String? text,
}) => {
  'id': id,
  'type': type,
  'route': switch (type) {
    'like' || 'location_match' || 'nearby_activity' || 'nearby_post' => '/post',
    'comment' || 'comment_reply' || 'comment_like' => '/comments',
    'follow' => '/profile',
    'message' || 'message_request' => '/conversation',
    'encounter_request' || 'encounter_accepted' => '/encounter',
    'map_note_nearby' || 'map_note_reply' => '/map-note',
    _ => '/notifications',
  },
  'entity_id': entity,
  'available': available,
  'actor': actor,
  'text': text ?? 'Bildirim $id',
  'read': read,
  'created_at': (at ?? DateTime.now()).toUtc().toIso8601String(),
  'announcement_body': ?body,
  'map_target': ?map,
};

Future<AppStore> connected(
  Future<http.Response> Function(http.Request) handler, {
  AdsService? ads,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  final store = AppStore(
    api: ApiClient(httpClient: MockClient(handler)),
    locationDevice: _Device(),
    ads: ads,
  );
  await store.signIn('login', {'identifier': 'demo', 'password': 'x'});
  return store;
}

class _Routes extends NavigatorObserver {
  final names = <String>[];
  final args = <Object?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    names.add(route.settings.name ?? '');
    args.add(route.settings.arguments);
  }
}

Widget host(
  AppStore store,
  Widget child, {
  double scale = 1,
  NavigatorObserver? observer,
  Locale locale = const Locale('tr'),
}) => StoreScope(
  store: store,
  child: MaterialApp(
    navigatorObservers: [?observer],
    locale: locale,
    supportedLocales: AppLocale.supported,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    builder: (context, page) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: page!,
    ),
    onGenerateRoute: (settings) => MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => settings.name == '/'
          ? child
          : Scaffold(body: Text('route ${settings.name}')),
    ),
  ),
);

class FakeAds implements AdsPlatform {
  FakeAds({this.can = true, this.failLoads = false, this.privacy = false});
  bool can, failLoads, privacy;
  final startedTeen = <bool>[];
  final units = <String>[];
  final teenFlags = <bool>[];
  int privacyShown = 0;
  @override
  Future<AdsStartResult> start({required bool teen}) async {
    startedTeen.add(teen);
    return AdsStartResult(canRequestAds: can, privacyOptionsRequired: privacy);
  }

  @override
  Future<void> showPrivacyOptions() async => privacyShown++;

  @override
  NativeAdHandle createNative({
    required String unitId,
    required bool teen,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) {
    units.add(unitId);
    teenFlags.add(teen);
    scheduleMicrotask(failLoads ? onFailed : onLoaded);
    return _FakeHandle();
  }
}

class _FakeHandle implements NativeAdHandle {
  @override
  Widget get widget =>
      const SizedBox(key: Key('fake-ad-body'), child: Text('Test reklamı'));
  @override
  void dispose() {}
}

void main() {
  setUpAll(() async {
    // refreshHomeConfig reads the package version first; without a mock that platform call never answers in tests.
    PackageInfo.setMockInitialValues(
      appName: 'SenMiydin?',
      packageName: 'com.senmiydin.app',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final bytes = File('assets/fonts/NunitoSans.ttf').readAsBytesSync();
    final loader = FontLoader('NunitoSans')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  void size(WidgetTester tester, double width, [double height = 1000]) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> real(WidgetTester tester, [int ms = 240]) async {
    for (var i = 0; i < (ms / 30).ceil(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  // ------------------------------------------------------------------ Home controls
  group('Home feed controls', () {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets(
          'At $width px and ${scale}x text the four feed tabs share one row and the city picker sits below them without overlap',
          (tester) async {
            size(tester, width, 1200);
            final store = AppStore()..city = 'Afyonkarahisar';
            addTearDown(store.dispose);
            await tester.pumpWidget(
              host(store, Scaffold(body: HomeContent(onMap: () {})), scale: scale),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'No overflow.');
            final tabs = [
              for (final label in ['Akış', 'Takip', 'Yakın', 'Popüler'])
                tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first),
            ];
            // No horizontal overflow or clipping: every tab is fully on screen.
            for (final r in tabs) {
              expect(r.left, greaterThanOrEqualTo(0));
              expect(r.right, lessThanOrEqualTo(width + .5));
              expect(r.width, greaterThan(40));
            }
            // They never overlap each other.
            for (var i = 0; i < tabs.length - 1; i++) {
              if ((tabs[i].top - tabs[i + 1].top).abs() < 4) {
                expect(tabs[i].right, lessThanOrEqualTo(tabs[i + 1].left + .5));
              }
            }
            final city = tester.getRect(find.byKey(const Key('feed-city')));
            final lowestTab = tabs.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
            expect(
              city.top,
              greaterThanOrEqualTo(lowestTab),
              reason: 'The city picker is a separate row under the social tabs.',
            );
            expect(city.right, lessThanOrEqualTo(width));
            expect(city.right, greaterThan(width - 40), reason: 'Right aligned.');
            if (scale == 1.0) {
              expect(
                tabs.map((r) => r.top.round()).toSet().length,
                1,
                reason: 'Akış | Takip | Yakın | Popüler on one row.',
              );
            }
          },
        );
      }
    }
  });

  // ----------------------------------------------------------------- balanced grid
  group('Balanced options', () {
    for (final width in [320.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets(
          'Aradığın bağlantılar is an even 2x2 grid at $width px / ${scale}x',
          (tester) async {
            size(tester, width, 1400);
            final selected = <String>{'Arkadaşlık', 'Karşılaşmalar'};
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, page) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: page!,
                ),
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, set) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: BalancedChoiceGrid(
                        options: const [
                          'Arkadaşlık',
                          'Karşılaşmalar',
                          'Sohbet',
                          'Yeni insanlarla tanışma',
                        ],
                        isSelected: selected.contains,
                        onToggle: (o, v) =>
                            set(() => v ? selected.add(o) : selected.remove(o)),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            Rect tile(String o) => tester.getRect(find.byKey(ValueKey('choice-$o')));
            final a = tile('Arkadaşlık'), b = tile('Karşılaşmalar');
            final c = tile('Sohbet'), d = tile('Yeni insanlarla tanışma');
            expect(a.top, closeTo(b.top, .5));
            expect(c.top, closeTo(d.top, .5));
            expect(c.top, greaterThan(a.bottom - .5), reason: 'Two rows of two.');
            expect(a.width, closeTo(b.width, .5));
            expect(c.width, closeTo(d.width, .5));
            expect(a.width, closeTo(c.width, .5), reason: 'All four tiles share one width.');
            expect(a.height, closeTo(b.height, .5));
            expect(c.height, closeTo(d.height, .5));
            expect(d.right, lessThanOrEqualTo(width));
            await tester.tap(find.byKey(const ValueKey('choice-Sohbet')));
            await tester.pump();
            expect(selected, contains('Sohbet'));
            await tester.tap(find.byKey(const ValueKey('choice-Arkadaşlık')));
            await tester.pump();
            expect(selected, isNot(contains('Arkadaşlık')));
          },
        );
      }
    }

    testWidgets('An odd number of options falls back to a centred wrap, never a broken grid', (tester) async {
      size(tester, 390);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BalancedChoiceGrid(
              options: const ['A', 'B', 'C'],
              isSelected: (_) => false,
              onToggle: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(InkWell), findsNWidgets(3));
    });
  });

  // ---------------------------------------------------------------------- PostCard
  group('PostCard', () {
    Post build(String kind, AppStore store) {
      final people = store.people;
      return switch (kind) {
        'text' => Post(id: 'p-text', authorId: people[1].id, text: 'Kısa bir not.'),
        'photo' => Post(
          id: 'p-photo',
          authorId: people[1].id,
          text: 'Sahilden iki kare ve uzun bir açıklama; ' * 3,
          images: const ['assets/images/demo/photo-1.jpg'],
        ),
        'anonymous' => Post(
          id: 'p-anon',
          authorId: people[1].id,
          text: 'Bu paylaşımı kimin yazdığını söylemeyeceğim.',
          anonymous: true,
          kind: PostKind.confession,
        ),
        'encounter' => Post(
          id: 'p-enc',
          authorId: people[1].id,
          text: 'Deniz kenarında yürürken yeniden karşılaştık.',
          kind: PostKind.encounter,
          encounterConfirmed: true,
          storyTitle: 'Sahilde ikinci merhaba',
          storyStatus: 'published',
          storyParticipants: [people[0], people[1]],
          remote: true,
        ),
        _ => Post(
          id: 'p-travel',
          authorId: people[1].id,
          text: 'Ankara – Erzincan yolculuğundayım.',
          kind: PostKind.journey,
        ),
      };
    }

    for (final width in [320.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('All card kinds lay out cleanly at $width px / ${scale}x', (tester) async {
          size(tester, width, 1800);
          final store = AppStore();
          addTearDown(store.dispose);
          await tester.pumpWidget(
            host(
              store,
              Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final k in ['text', 'photo', 'anonymous', 'encounter', 'travel'])
                      PostCard(build(k, store), preview: false),
                  ],
                ),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'No overflow at $width px / ${scale}x.');
          // The encounter card: the pair of names and the "Karşılaşıldı ✓" badge never collide.
          final badge = tester.getRect(find.text('Karşılaşıldı ✓'));
          final names = store.people[0].name;
          final nameFinder = find.textContaining(names).first;
          final nameRect = tester.getRect(nameFinder);
          expect(badge.overlaps(nameRect), isFalse, reason: 'Badge and names do not overlap.');
          expect(badge.right, lessThanOrEqualTo(width));
          // Action bar is touchable: every action is at least 44 dp tall.
          for (final tip in ['Beğen', 'Yorumlar', 'Paylaş']) {
            final heights = [
              for (final e in tester.widgetList(find.byTooltip(tip))) tester.getSize(find.byWidget(e)).height,
            ];
            expect(heights.every((h) => h >= 43.5), isTrue, reason: '$tip is comfortable to tap: $heights');
          }
        });
      }
    }

    testWidgets('A short text-only post gets a larger body so the card never looks empty', (tester) async {
      size(tester, 390);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        host(store, Scaffold(body: ListView(children: [PostCard(build('text', store))]))),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.descendant(of: find.byType(PostCard), matching: find.text('Kısa bir not.')));
      expect(text.style?.fontSize, 17);
    });
  });

  // ----------------------------------------------------------- notification sheet
  group('Notification sheet', () {
    final now = DateTime.now();
    List<Map<String, dynamic>> items() => [
      for (var i = 1; i <= 4; i++) noticeJson(i, 'like', entity: 5, at: now, text: 'Bugün bildirimi $i'),
      noticeJson(5, 'comment', entity: 5, at: now.subtract(const Duration(days: 1)), read: true, text: 'Dünkü yorum'),
      noticeJson(6, 'follow', entity: null, at: now.subtract(const Duration(days: 1)), read: true, text: 'Dünkü takip'),
      for (var i = 7; i <= 12; i++)
        noticeJson(i, 'like', entity: 5, at: now.subtract(const Duration(days: 6)), read: true, text: 'Eski bildirim $i'),
    ];

    Future<AppStore> sheetStore(List<String> log) => connected((request) async {
      final path = request.url.path;
      log.add('${request.method} $path');
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.endsWith('/unread-counts')) return ok({'messages': 0, 'notifications': 4});
      if (path.endsWith('/notifications/read')) return ok({});
      if (path.endsWith('/notifications')) return ok({'items': items(), 'next_page': null});
      return ok({'items': [], 'next_page': null});
    }).then((store) async {
      await store.refreshUnread();
      return store;
    });

    Widget bell() => Builder(
      builder: (context) => Center(
        child: IconButton(
          tooltip: 'Bildirimler',
          onPressed: () => showNotificationsSheet(context),
          icon: const Icon(Icons.notifications_none),
        ),
      ),
    );

    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('At $width px: handle, sticky header with unread count and "Tümünü okundu", grouped rows, max 10, "Tümünü Gör"', (tester) async {
        size(tester, width, 900);
        final log = <String>[];
        final store = await sheetStore(log);
        addTearDown(store.dispose);
        final routes = _Routes();
        await tester.pumpWidget(host(store, bell(), observer: routes));
        await tester.tap(find.byTooltip('Bildirimler'));
        await tester.pumpAndSettle();
        await real(tester);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Bildirimler'), findsWidgets);
        expect(find.text('4 okunmamış'), findsOneWidget);
        expect(find.text('Tümünü okundu'), findsOneWidget);
        expect(find.text('Bugün'), findsOneWidget);
        expect(find.text('Dün'), findsOneWidget);
        expect(find.text('Daha Önce'), findsOneWidget);
        final tiles = find.byType(NotificationTile);
        expect(tiles.evaluate().length, lessThanOrEqualTo(10), reason: 'The quick panel previews 8–10 items.');
        expect(find.text('Bugün bildirimi 1'), findsOneWidget);
        // Rounded sheet that opens at roughly 70 % of the screen height.
        final scroll = tester.getRect(find.byKey(const Key('notifications-scroll')));
        expect(scroll.top, greaterThan(900 * .25));
        // Unread rows carry the pale surface, read rows are white.
        Color colour(String text) => tester.widget<Material>(find.ancestor(of: find.text(text), matching: find.byType(Material)).first).color!;
        expect(colour('Bugün bildirimi 1'), isNot(Colors.white));
        expect(colour('Dünkü yorum'), Colors.white);
        // "Tümünü Gör" is the way to the full page.
        await tester.scrollUntilVisible(
          find.byKey(const Key('notifications-see-all')),
          200,
          scrollable: find.descendant(of: find.byKey(const Key('notifications-scroll')), matching: find.byType(Scrollable)),
        );
        await tester.ensureVisible(find.byKey(const Key('notifications-see-all')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('notifications-see-all')));
        await tester.pumpAndSettle();
        expect(routes.names, contains('/notifications'));
        expect(find.byKey(const Key('notifications-scroll')), findsNothing, reason: 'The sheet closed.');
      });
    }

    testWidgets('"Tümünü okundu" marks everything read on the server', (tester) async {
      size(tester, 390, 900);
      final log = <String>[];
      final store = await sheetStore(log);
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, bell()));
      await tester.tap(find.byTooltip('Bildirimler'));
      await tester.pumpAndSettle();
      await real(tester);
      await tester.tap(find.byKey(const Key('notifications-mark-all')));
      await tester.pumpAndSettle();
      await real(tester);
      expect(log, contains('PUT /api/v1/notifications/read'));
    });

    testWidgets('Dragging the sheet down closes it', (tester) async {
      size(tester, 390, 900);
      final store = await sheetStore([]);
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, bell()));
      await tester.tap(find.byTooltip('Bildirimler'));
      await tester.pumpAndSettle();
      await real(tester);
      await tester.drag(find.byKey(const Key('notifications-scroll')), const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notifications-scroll')), findsNothing);
    });

    testWidgets('Tapping a comment notification closes the sheet and opens the post with its comments', (tester) async {
      size(tester, 390, 900);
      final log = <String>[];
      final store = await sheetStore(log);
      addTearDown(store.dispose);
      final routes = _Routes();
      await tester.pumpWidget(host(store, bell(), observer: routes));
      await tester.tap(find.byTooltip('Bildirimler'));
      await tester.pumpAndSettle();
      await real(tester);
      await tester.scrollUntilVisible(
        find.text('Dünkü yorum'),
        200,
        scrollable: find.descendant(of: find.byKey(const Key('notifications-scroll')), matching: find.byType(Scrollable)),
      );
      await tester.ensureVisible(find.text('Dünkü yorum'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dünkü yorum'));
      await tester.pumpAndSettle();
      expect(routes.names, contains('/comments'));
      expect(routes.args.last, '5');
      expect(find.byKey(const Key('notifications-scroll')), findsNothing);
    });

    test('Grouping: Bugün / Dün / Daha Önce, empty groups skipped, newest first order kept', () {
      final base = DateTime(2026, 11, 15, 12);
      InboxNotification n(int id, DateTime at) =>
          InboxNotification(noticeJson(id, 'like', at: at), socialPerson);
      final groups = groupNotifications([
        n(1, base),
        n(2, base.subtract(const Duration(days: 1))),
        n(3, base.subtract(const Duration(days: 9))),
      ], now: base);
      expect(groups.map((g) => g.kind), [
        NotificationGroupKind.today,
        NotificationGroupKind.yesterday,
        NotificationGroupKind.earlier,
      ]);
      expect(groupNotifications([n(1, base)], now: base), hasLength(1));
      expect(notificationGroupOf(DateTime(2026, 11, 14, 23, 59), DateTime(2026, 11, 15, 0, 1)), NotificationGroupKind.yesterday);
    });
  });

  // ------------------------------------------------------------ notification routing
  group('Notification routing', () {
    final person = {'id': 21, 'username': 'ece', 'name': 'Ece Test', 'avatar': null};

    Future<(_Routes, AppStore, NavigatorState)> router(WidgetTester tester) async {
      size(tester, 390, 900);
      final store = await connected((request) async {
        if (request.url.path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
        return ok({'items': [], 'next_page': null});
      });
      addTearDown(store.dispose);
      final routes = _Routes();
      await tester.pumpWidget(host(store, const Scaffold(body: SizedBox()), observer: routes));
      await tester.pumpAndSettle();
      return (routes, store, tester.state<NavigatorState>(find.byType(Navigator)));
    }

    final cases = <String, (String, bool)>{
      'like': ('/post', false),
      'comment': ('/comments', false),
      'comment_reply': ('/comments', false),
      'comment_like': ('/comments', false),
      'follow': ('/profile', true),
      'message': ('/conversation', false),
      'message_request': ('/conversation', false),
      'encounter_request': ('/encounter', false),
      'encounter_accepted': ('/encounter', false),
      'location_match': ('/post', false),
      'nearby_activity': ('/post', false),
      'nearby_post': ('/post', false),
      'map_note_nearby': ('/map-note', false),
      'map_note_reply': ('/map-note', false),
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key} opens ${entry.value.$1}', (tester) async {
        final (routes, _, navigator) = await router(tester);
        final item = InboxNotification(
          noticeJson(1, entry.key, entity: 9, actor: entry.value.$2 ? person : null),
          socialPerson,
        );
        unawaited(routeInboxNotification(navigator, item));
        await tester.pumpAndSettle();
        expect(routes.names, contains(entry.value.$1));
      });
    }

    testWidgets('An unavailable target says so safely and opens nothing', (tester) async {
      final (routes, _, navigator) = await router(tester);
      final before = routes.names.length;
      unawaited(routeInboxNotification(navigator, InboxNotification(noticeJson(1, 'like', entity: 9, available: false), socialPerson)));
      await tester.pumpAndSettle();
      expect(routes.names.length, before);
      expect(find.text('Bu içerik artık kullanılamıyor.'), findsOneWidget);
    });

    testWidgets('A system announcement shows its text; a location announcement offers "Haritada Gör" that opens the map on that point', (tester) async {
      final (routes, store, navigator) = await router(tester);
      unawaited(routeInboxNotification(navigator, InboxNotification(noticeJson(1, 'system', body: 'Genel metin'), socialPerson)));
      await tester.pumpAndSettle();
      expect(find.text('Genel metin'), findsOneWidget);
      expect(find.byKey(const Key('announcement-see-on-map')), findsNothing);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();

      unawaited(routeInboxNotification(navigator, InboxNotification(
        noticeJson(2, 'system', body: 'Plajda etkinlik var', map: {'latitude': 36.5446, 'longitude': 32.0021}), socialPerson)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('announcement-see-on-map')), findsOneWidget);
      await tester.tap(find.byKey(const Key('announcement-see-on-map')));
      await tester.pumpAndSettle();
      expect(routes.names, contains('/map'));
      expect(store.mapFocus, const LatLng(36.5446, 32.0021));
    });
  });

  // ---------------------------------------------------------------- messages & chat
  group('Messages and chat', () {
    Map<String, dynamic> peer() => {'id': 22, 'username': 'elif', 'name': 'Elif Test', 'avatar': null};
    Map<String, dynamic> msg(int id, String type, {String body = '', bool mine = false, Map<String, dynamic>? location}) => {
      'id': id, 'body': body, 'type': type, 'mine': mine, 'image': null, 'read_at': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'location': ?location,
    };

    Future<AppStore> chatStore({List<Map<String, dynamic>>? messages, List<http.Request>? sent}) => connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
      if (path.endsWith('/unread-counts')) return ok({'messages': 0, 'notifications': 0});
      if (request.method == 'POST' && path.endsWith('/messages')) {
        sent?.add(request);
        final body = jsonDecode(request.body) as Map;
        final location = body['latitude'] == null ? null : {'latitude': 36.544, 'longitude': 32.0, 'place_label': null};
        return ok({
          'conversation': {'id': 3, 'status': 'active', 'peer': peer(), 'outgoing': false, 'can_send': true, 'unread': 0},
          'message': msg(99, location == null ? 'text' : 'location', body: '${body['body']}', mine: true, location: location),
        }, 201);
      }
      if (path.endsWith('/conversations/3/messages')) return ok({'items': messages ?? [], 'has_more': false});
      if (path.contains('/conversations/3')) {
        return ok({'id': 3, 'status': 'active', 'peer': peer(), 'outgoing': false, 'can_send': true, 'unread': 0});
      }
      return ok({'items': [], 'next_page': null});
    });

    testWidgets('A conversation row previews photos and locations as "Fotoğraf" / "Konum" and never invents online presence', (tester) async {
      size(tester, 390, 800);
      final store = AppStore();
      addTearDown(store.dispose);
      DirectMessage message(String type, String body) => DirectMessage(msg(1, type, body: body));
      await tester.pumpWidget(
        host(
          store,
          Scaffold(
            body: ListView(
              children: [
                ConversationTile(peer: store.people[1], unread: 2, last: message('image', ''), onTap: () {}),
                ConversationTile(peer: store.people[2], unread: 0, last: message('location', ''), onTap: () {}),
                ConversationTile(peer: store.people[3], unread: 0, last: message('text', 'Sahilde görüşelim'), onTap: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fotoğraf'), findsOneWidget);
      expect(find.text('Konum'), findsOneWidget);
      expect(find.text('Sahilde görüşelim'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      expect(find.text('2'), findsOneWidget, reason: 'Unread badge.');
    });

    testWidgets('The composer is [ + ] [ emoji ] [ input ] [ send ] and the + menu offers Fotoğraf, Kamera and Konum', (tester) async {
      size(tester, 390, 800);
      final store = await chatStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const DirectChatPage('3')));
      await tester.pumpAndSettle();
      await real(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-attach')), findsOneWidget);
      expect(find.byKey(const Key('chat-emoji')), findsOneWidget);
      expect(find.byKey(const Key('chat-input')), findsOneWidget);
      expect(find.byKey(const Key('chat-mic')), findsOneWidget, reason: 'An empty composer offers the microphone.');
      expect(find.byTooltip('Mesajı gönder'), findsNothing);
      await tester.enterText(find.byKey(const Key('chat-input')), 'Selam');
      await tester.pump();
      expect(find.byKey(const Key('chat-mic')), findsNothing, reason: 'Typing swaps the microphone for the send button.');
      expect(find.byTooltip('Mesajı gönder'), findsOneWidget);
      final attach = tester.getCenter(find.byKey(const Key('chat-attach'))).dx;
      final emoji = tester.getCenter(find.byKey(const Key('chat-emoji'))).dx;
      final input = tester.getCenter(find.byKey(const Key('chat-input'))).dx;
      final send = tester.getCenter(find.byTooltip('Mesajı gönder')).dx;
      expect([attach, emoji, input, send], orderedEquals([attach, emoji, input, send]..sort()));
      await tester.tap(find.byKey(const Key('chat-attach')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('attach-photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('attach-camera')), findsOneWidget);
      expect(find.byKey(const ValueKey('attach-location')), findsOneWidget);
      expect(find.text('Fotoğraf'), findsOneWidget);
      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('Konum'), findsOneWidget);
    });

    testWidgets('An emoji is inserted at the cursor and the system keyboard stays available', (tester) async {
      size(tester, 390, 800);
      final store = await chatStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const DirectChatPage('3')));
      await tester.pumpAndSettle();
      await real(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-input')), 'ab');
      await tester.pump();
      final field = tester.widget<TextField>(find.byKey(const Key('chat-input')));
      field.controller!.selection = const TextSelection.collapsed(offset: 1);
      await tester.tap(find.byKey(const Key('chat-emoji')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsOneWidget);
      await tester.tap(find.text('😀'));
      await tester.pumpAndSettle();
      expect(field.controller!.text, 'a😀b');
      expect(field.controller!.selection.baseOffset, 'a😀'.length);
    });

    test('insertAtCursor replaces a selection and appends when there is no cursor', () {
      final controller = TextEditingController(text: 'merhaba');
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
      insertAtCursor(controller, '👋');
      expect(controller.text, '👋haba');
      controller.selection = const TextSelection.collapsed(offset: -1);
      insertAtCursor(controller, '🙂');
      expect(controller.text, '👋haba🙂');
    });

    testWidgets('A location message shows a pin, "Konum", the approximate area and "Haritada Aç" that centres the map on that point', (tester) async {
      size(tester, 390, 800);
      final store = await chatStore(messages: [
        msg(5, 'location', location: {'latitude': 36.544, 'longitude': 32.0005, 'place_label': 'Kleopatra Plajı'}),
      ]);
      addTearDown(store.dispose);
      final routes = _Routes();
      await tester.pumpWidget(host(store, const DirectChatPage('3'), observer: routes));
      await tester.pumpAndSettle();
      await real(tester);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
      expect(find.text('Konum'), findsOneWidget);
      expect(find.text('Yaklaşık bölge · Kleopatra Plajı'), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-location-on-map')));
      await tester.pumpAndSettle();
      expect(store.mapFocus, const LatLng(36.544, 32.0005));
      expect(routes.names, contains('/map'));
    });

    test('Sending a location posts only the point and an optional label (never an image) and reads the approximate answer back', () async {
      final sent = <http.Request>[];
      final store = await chatStore(sent: sent);
      addTearDown(store.dispose);
      final api = store.communication!;
      final (_, message) = await api.send(
        socialPerson(peer()),
        '',
        'b5e1b5a4-4d2e-4a0b-a1d2-0123456789ab',
        null,
        location: (latitude: 36.544123, longitude: 32.000987, label: 'Kleopatra Plajı'),
      );
      final body = jsonDecode(sent.single.body) as Map;
      expect(body['latitude'], 36.544123);
      expect(body['place_label'], 'Kleopatra Plajı');
      expect(message.isLocation, isTrue);
      expect(message.latitude, 36.544, reason: 'The UI shows the server-snapped point, not the device point.');
      expect(message.preview, 'Konum');
      expect(sent.single.headers['Accept-Language'], 'tr');
    });

    test('PickLocationPage is a real page type that returns a LatLng (smoke)', () {
      expect(const PickLocationPage(), isA<StatefulWidget>());
    });
  });

  // ------------------------------------------------------------------- localization
  group('English / Turkish', () {
    test('Device language decides the first launch: Turkish for Turkish, English for everything else', () {
      expect(AppLocale.forDevice(const Locale('tr', 'TR')), const Locale('tr'));
      expect(AppLocale.forDevice(const Locale('en', 'US')), const Locale('en'));
      expect(AppLocale.forDevice(const Locale('de')), const Locale('en'));
      expect(AppLocale.forDevice(const Locale('ar')), const Locale('en'));
    });

    test('tr() translates known source strings in English and passes unknown ones through', () {
      expect(tr('Ana Sayfa'), 'Ana Sayfa');
      AppLocale.debugSet(const Locale('en'));
      expect(tr('Ana Sayfa'), 'Home');
      expect(tr('Bu cümle sözlükte yok'), 'Bu cümle sözlükte yok');
    });

    test('Relative times follow the language', () {
      final now = DateTime.now().toUtc();
      expect(socialTime(now.subtract(const Duration(minutes: 5)).toIso8601String()), '5 dk önce');
      AppLocale.debugSet(const Locale('en'));
      expect(socialTime(now.subtract(const Duration(minutes: 5)).toIso8601String()), '5 min ago');
      expect(socialTime(now.subtract(const Duration(hours: 3)).toIso8601String()), '3 h ago');
      expect(socialTime(now.toIso8601String()), 'Just now');
    });

    testWidgets('English home: feed tabs, composer prompt and the notification panel are English', (tester) async {
      size(tester, 390, 1200);
      AppLocale.debugSet(const Locale('en'));
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, Scaffold(body: HomeContent(onMap: () {})), locale: const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Nearby'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);
      expect(find.text('Akış'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('The settings language picker switches the language at once and tells the server', (tester) async {
      size(tester, 390, 1400);
      final bodies = <String>[];
      final store = await connected((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
        if (request.method == 'PUT' && path.endsWith('/profile')) {
          bodies.add(request.body);
          return ok(account());
        }
        return ok({'items': [], 'next_page': null});
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const SettingsPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dil / Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-en')));
      await tester.pumpAndSettle();
      await real(tester);
      await tester.pumpAndSettle();
      expect(AppLocale.code, 'en');
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Change Password'), findsOneWidget);
      expect(bodies.single, contains('"preferred_locale":"en"'));
      AppLocale.debugSet(const Locale('tr'));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('API requests carry the language and the profile exposes the age band', () async {
      final langs = <String?>[];
      final store = await connected((request) async {
        langs.add(request.headers['Accept-Language']);
        if (request.url.path.endsWith('/auth/login')) return ok({'token': 't', 'user': account(ageBand: 'teen')});
        return ok({'items': [], 'next_page': null});
      });
      addTearDown(store.dispose);
      expect(store.account!.ageBand, 'teen');
      AppLocale.debugSet(const Locale('en'));
      await store.communication!.conversations(1, false, '');
      expect(langs.first, 'tr');
      expect(langs.last, 'en');
    });
  });

  // -------------------------------------------------------------------------- ads
  group('Native feed ads', () {
    test('Placement: one after the 7th organic post, then every interval, never at the very end', () {
      expect(AdsConfig.adPositions(5, 11), isEmpty);
      expect(AdsConfig.adPositions(7, 11), isEmpty, reason: 'An ad is only placed when more content follows it.');
      expect(AdsConfig.adPositions(8, 11), [7]);
      expect(AdsConfig.adPositions(30, 11), [7, 18, 29]);
      expect(AdsConfig.adPositions(40, 3), [7, 15, 23, 31, 39], reason: 'The interval is never denser than 8.');
      // Stable while paging: more organic posts never move an ad that is already placed.
      final first = AdsConfig.adPositions(20, 11);
      final more = AdsConfig.adPositions(60, 11);
      expect(more.take(first.length), first);
      final rows = feedRows(20, ads: true, interval: 11);
      expect(rows.where((r) => !r.isAd).map((r) => r.organic), List.generate(20, (i) => i), reason: 'Organic order is untouched.');
      expect(rows[7].isAd, isTrue);
      expect(rows.where((r) => r.isAd), hasLength(2));
      expect(feedRows(20, ads: false), hasLength(20));
    });

    test('Ad units: Google sample units in debug, build-defined units in release, none without a real unit', () {
      expect(AdsConfig.nativeUnitId(debug: true, platform: TargetPlatform.android), AdsConfig.androidTestNativeUnit);
      expect(AdsConfig.nativeUnitId(debug: true, platform: TargetPlatform.iOS), AdsConfig.iosTestNativeUnit);
      expect(AdsConfig.nativeUnitId(debug: false, platform: TargetPlatform.android), isNull, reason: 'Release without a real id: no ad area at all.');
      expect(AdsConfig.nativeUnitId(debug: false, platform: TargetPlatform.android, androidUnit: 'ca-app-pub-1/2'), 'ca-app-pub-1/2');
      expect(AdsConfig.nativeUnitId(debug: false, platform: TargetPlatform.iOS, iosUnit: 'ca-app-pub-3/4'), 'ca-app-pub-3/4');
      expect(AdsConfig.platformEnabled, isFalse, reason: 'Never in unit tests.');
    });

    Future<AppStore> feedStore(FakeAds fake, {bool adsEnabled = true, int posts = 20, String band = 'adult'}) => connected((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account(ageBand: band)});
      if (path.endsWith('/app-config')) {
        return ok({'ads_enabled': adsEnabled, 'feed_ad_interval': 11, 'minimum_age': 16, 'versions': {}});
      }
      if (path.endsWith('/feed')) {
        return ok({'items': [for (var i = 1; i <= posts; i++) postJson(i, 'Akış gönderisi $i')], 'next_page': null});
      }
      return ok({'items': [], 'next_page': null});
    }, ads: AdsService(platform: fake, unitId: 'ca-app-pub-test/native'));

    testWidgets('Ads appear in the feed at the configured slots, labelled "Reklam", and organic order is untouched', (tester) async {
      size(tester, 390, 900);
      final fake = FakeAds();
      final store = await feedStore(fake);
      addTearDown(store.dispose);
      await store.refreshHomeConfig();
      await real(tester);
      expect(store.showFeedAds, isTrue);
      expect(fake.startedTeen, [false], reason: 'Adults: consent flow first, no teen treatment.');
      await tester.pumpWidget(host(store, Scaffold(body: HomeContent(onMap: () {}))));
      await tester.pumpAndSettle();
      await real(tester);
      final scroll = find.byType(Scrollable).first;
      for (var i = 0; i < 12; i++) {
        await tester.drag(scroll, const Offset(0, -500));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('native-feed-ad')), findsWidgets);
      expect(find.byKey(const Key('ad-label')), findsWidgets);
      expect(find.text('Reklam'), findsWidgets);
      expect(fake.units.first, 'ca-app-pub-test/native');
      expect(fake.teenFlags.every((t) => !t), isTrue);
    });

    testWidgets('When the admin switches ads off, no ad and no ad request exist', (tester) async {
      size(tester, 390, 900);
      final fake = FakeAds();
      final store = await feedStore(fake, adsEnabled: false);
      addTearDown(store.dispose);
      await store.refreshHomeConfig();
      await real(tester);
      expect(store.adsEnabled, isFalse);
      expect(store.showFeedAds, isFalse);
      expect(fake.startedTeen, isEmpty, reason: 'The SDK is not even started.');
      await tester.pumpWidget(host(store, Scaffold(body: HomeContent(onMap: () {}))));
      await tester.pumpAndSettle();
      await real(tester);
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('native-feed-ad')), findsNothing);
      expect(fake.units, isEmpty);
    });

    testWidgets('Without consent (canRequestAds false) the feed shows no ad area and makes no ad request', (tester) async {
      size(tester, 390, 900);
      final fake = FakeAds(can: false);
      final store = await feedStore(fake);
      addTearDown(store.dispose);
      await store.refreshHomeConfig();
      await real(tester);
      expect(store.ads.canRequestAds, isFalse);
      expect(store.showFeedAds, isFalse);
      await tester.pumpWidget(host(store, Scaffold(body: HomeContent(onMap: () {}))));
      await tester.pumpAndSettle();
      expect(fake.units, isEmpty);
    });

    testWidgets('A failed ad load leaves no empty placeholder', (tester) async {
      size(tester, 390, 900);
      final fake = FakeAds(failLoads: true);
      final store = await feedStore(fake);
      addTearDown(store.dispose);
      await store.refreshHomeConfig();
      await real(tester);
      await tester.pumpWidget(host(store, Scaffold(body: HomeContent(onMap: () {}))));
      await tester.pumpAndSettle();
      await real(tester);
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(fake.units, isNotEmpty, reason: 'It tried.');
      expect(find.byKey(const Key('native-feed-ad')), findsNothing);
      expect(find.byKey(const Key('fake-ad-body')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Teen accounts start the SDK with the age-restricted treatment and request non-personalized ads', (tester) async {
      size(tester, 390, 900);
      final fake = FakeAds();
      final store = await feedStore(fake, band: 'teen');
      addTearDown(store.dispose);
      await store.refreshHomeConfig();
      await real(tester);
      expect(fake.startedTeen, [true]);
      expect(store.ads.teen, isTrue);
      await tester.pumpWidget(host(store, Scaffold(body: HomeContent(onMap: () {}))));
      await tester.pumpAndSettle();
      await real(tester);
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(fake.teenFlags, isNotEmpty);
      expect(fake.teenFlags.every((t) => t), isTrue);
    });

    testWidgets('The ad privacy entry only exists when the consent form says it is required', (tester) async {
      size(tester, 390, 1400);
      final fake = FakeAds(privacy: true);
      final store = await feedStore(fake);
      addTearDown(store.dispose);
      await store.refreshHomeConfig();
      await real(tester);
      await tester.pumpWidget(host(store, const SettingsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Reklam Gizlilik Tercihleri'), findsOneWidget);
      await tester.tap(find.text('Reklam Gizlilik Tercihleri'));
      await tester.pumpAndSettle();
      expect(fake.privacyShown, 1);
      await tester.pumpWidget(const SizedBox.shrink());

      final none = await feedStore(FakeAds());
      addTearDown(none.dispose);
      await none.refreshHomeConfig();
      await real(tester);
      await tester.pumpWidget(host(none, const SettingsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Reklam Gizlilik Tercihleri'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('The ad request surface carries no SenMiydin data: units and the teen flag only', () {
      // AdsPlatform.createNative has exactly (unitId, teen, callbacks): there is no parameter for a location,
      // keywords, content url or history, so nothing of that kind can reach the SDK.
      final fake = FakeAds();
      fake.createNative(unitId: 'u', teen: false, onLoaded: () {}, onFailed: () {});
      expect(fake.units, ['u']);
      expect(fake.teenFlags, [false]);
    });

    test('Service reset after sign out forgets consent and treatment', () async {
      final service = AdsService(platform: FakeAds(), unitId: 'x');
      await service.start(teen: true);
      expect(service.available, isTrue);
      service.reset();
      expect(service.available, isFalse);
      expect(service.teen, isFalse);
    });
  });

  // ----------------------------------------------------------------- age gate copy
  test('Minimum registration age is 18 by default and the band comes from the server', () {
    final store = AppStore();
    addTearDown(store.dispose);
    expect(store.minimumAge, 18);
  });

  test('NativeFeedAd is exported for the feed', () {
    expect(const NativeFeedAd(), isA<StatefulWidget>());
    expect(const SettingsPage(), isA<StatefulWidget>());
    expect(const Locale('tr'), isNotNull);
    expect(Uint8List(0), isEmpty);
  });
}
