import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/communication_api.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/data/post_context.dart';
import 'package:senmiydin/data/social_api.dart';
import 'package:senmiydin/screens/compose.dart';
import 'package:senmiydin/screens/live_notifications.dart';
import 'package:senmiydin/widgets/post_context.dart';
import 'package:senmiydin/widgets/social.dart';

import 'location_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Manual active city survives session restore when device permission is denied', () async {
    final device = fixtures.TestLocationDevice();
    final api = fixtures.mockApi(
      (request) async => fixtures.ok(
        request.method == 'GET'
            ? {
                ...fixtures.profile(true),
                'active_city': {'id': 2, 'name': 'Ankara'},
                'active_city_source': 'manual',
              }
            : {},
      ),
    );
    await api.saveToken('restored-test-session');
    final store = AppStore(api: api, locationDevice: device);
    addTearDown(() async {
      store.dispose();
      await device.updatesController.close();
    });
    expect(await store.restoreAccount(), '/home');
    await store.location!.refresh();
    expect(store.city, 'Ankara');
    expect(store.activeCity!.name, 'Ankara');
    expect(store.account!.city.name, 'Alanya');
  });

  test('An unread response completing after store disposal does not update disposed state', () async {
    final response = Completer<Map<String, Object?>>();
    final device = fixtures.TestLocationDevice();
    final api = fixtures.mockApi((request) async {
      if (request.url.path.endsWith('/login')) {
        return fixtures.ok({
          'token': 'test-session',
          'user': fixtures.profile(true),
        });
      }
      if (request.url.path.endsWith('/location')) return fixtures.ok({});
      return fixtures.ok(await response.future);
    });
    final store = AppStore(api: api, locationDevice: device);
    await store.signIn('login', {});
    await store.location!.refresh();
    final work = store.refreshUnread();
    store.dispose();
    response.complete({'messages': 4, 'notifications': 6});
    expect(await work, false);
    await device.updatesController.close();
  });

  test('Active city follows device while profile city stays unchanged; manual choice uses API', () async {
    final device = fixtures.TestLocationDevice();
    final api = fixtures.mockApi((request) async {
      if (request.url.path.endsWith('/login')) {
        return fixtures.ok({
          'token': 'test-session',
          'user': fixtures.profile(true),
        });
      }
      if (request.url.path.endsWith('/cities')) {
        return fixtures.ok([
          {'id': 1, 'name': 'Alanya'},
          {'id': 2, 'name': 'Ankara'},
        ]);
      }
      if (request.url.path.endsWith('/active-city')) {
        expect(jsonDecode(request.body)['city_id'], 2);
        return fixtures.ok({
          'city': {'id': 2, 'name': 'Ankara'},
        });
      }
      if (request.url.path.endsWith('/location')) {
        return fixtures.ok({
          'city': {'id': 1, 'name': 'Alanya'},
        });
      }
      return fixtures.ok({'messages': 0, 'notifications': 0});
    });
    final store = AppStore(api: api, locationDevice: device);
    addTearDown(() async {
      store.dispose();
      await device.updatesController.close();
    });
    await store.signIn('login', {});
    await store.setCity('Ankara');
    expect(store.city, 'Ankara');
    expect(store.account!.city.name, 'Alanya');
    await store.location!.activateFromUi();
    expect(store.city, 'Alanya');
    expect(store.account!.city.name, 'Alanya');
  });

  test('Unknown reverse geocoding result preserves manual fallback without crashing', () async {
    final device = fixtures.TestLocationDevice();
    final api = fixtures.mockApi((request) async {
      if (request.url.path.endsWith('/login')) {
        return fixtures.ok({
          'token': 'test-session',
          'user': fixtures.profile(true),
        });
      }
      if (request.url.path.endsWith('/location')) {
        return fixtures.ok({'city': null, 'manual_city_required': true});
      }
      return fixtures.ok({'messages': 0, 'notifications': 0});
    });
    final store = AppStore(api: api, locationDevice: device);
    addTearDown(() async {
      store.dispose();
      await device.updatesController.close();
    });
    await store.signIn('login', {});
    await store.location!.activateFromUi();
    expect(store.activeCity, isNull);
    expect(store.manualCityRequired, true);
    expect(store.location!.position, isNotNull);
    expect(store.location!.synced, true);
  });

  testWidgets(
    'Historical place selector lists only approximate place/time and returns selection',
    (tester) async {
      final device = fixtures.TestLocationDevice();
      final api = fixtures.mockApi((request) async {
        if (request.url.path.endsWith('/login')) {
          return fixtures.ok({
            'token': 'test-session',
            'user': {
              ...fixtures.profile(true),
              'location_history_enabled': true,
            },
          });
        }
        if (request.url.path.endsWith('/location-history')) {
          return fixtures.ok({
            'items': [
              {
                'id': 7,
                'city_id': 3,
                'city_name': 'İstanbul',
                'label': 'İstanbul · Yaklaşık bölge',
                'recorded_at': '2026-11-08T11:00:00Z',
              },
            ],
            'next_page': null,
          });
        }
        return fixtures.ok({'messages': 0, 'notifications': 0});
      });
      final store = AppStore(api: api, locationDevice: device);
      addTearDown(() async {
        store.dispose();
        await device.updatesController.close();
      });
      await store.signIn('login', {});
      HistoricalPlace? chosen;
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  chosen = await Navigator.push<HistoricalPlace>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HistoricalPlacesPage(),
                    ),
                  );
                },
                child: const Text('Yer seç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Yer seç'));
      await tester.pumpAndSettle();
      expect(find.text('İstanbul · Yaklaşık bölge'), findsOneWidget);
      expect(find.textContaining('41.0'), findsNothing);
      await tester.tap(find.text('İstanbul · Yaklaşık bölge'));
      await tester.pumpAndSettle();
      expect(chosen?.id, 7);
      expect(PostPlaceSelection('history', historyId: chosen!.id).toJson(), {
        'location_source': 'history',
        'history_id': 7,
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Occurred time selector offers quick choices and preserves separate occurrence time',
    (tester) async {
      DateTime? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OccurredTimeField(
              value: null,
              onChanged: (v) => selected = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ne zaman oldu?'));
      await tester.pumpAndSettle();
      expect(find.text('Tarih / saat seç'), findsOneWidget);
      await tester.tap(find.text('Az önce'));
      await tester.pumpAndSettle();
      expect(
        DateTime.now().difference(selected!).inMinutes,
        inInclusiveRange(14, 16),
      );
    },
  );

  testWidgets(
    'Travel fields appear only for Yolculuk and open progressively in approved form',
    (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: ComposePage()),
        ),
      );
      expect(find.text('Yolculuk bilgilerini ekle'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Yolculuk'),
        220,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('Yolculuk'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Yolculuk bilgilerini ekle'),
        220,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Firma / işletmeci'), findsNothing);
      await tester.tap(find.text('Yolculuk bilgilerini ekle'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('travel-transport')),
        220,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Otobüs'), findsOneWidget);
      await tester.tap(find.byKey(const Key('travel-transport')));
      await tester.pumpAndSettle();
      expect(find.text('Tren'), findsOneWidget);
      expect(find.text('Uçak'), findsOneWidget);
      expect(find.text('Feribot'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Travel card shows Pamukkale route and optional vehicle without confirmed encounter label',
    (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      final details = TravelDetails(
        transport: 'bus',
        origin: const CatalogItem(2, 'Ankara'),
        destination: const CatalogItem(3, 'Erzincan'),
        operatorName: 'Pamukkale',
        vehicleIdentifier: '07 NM 365',
        isPublic: true,
      );
      final post = Post(
        id: 'travel-test',
        authorId: store.me.id,
        text: 'Bir sonraki molada kahve?',
        kind: PostKind.journey,
        travel: details,
        matchHint: 'Geçtiğin bir bölgeden',
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PostCard(post, preview: true)),
            ),
          ),
        ),
      );
      expect(find.text('Otobüs · Pamukkale'), findsOneWidget);
      expect(find.text('Ankara → Erzincan'), findsOneWidget);
      expect(find.text('07 NM 365'), findsOneWidget);
      expect(find.text('Karşılaşıldı ✓'), findsNothing);
      expect(find.text('Geçtiğin bir bölgeden'), findsOneWidget);
    },
  );

  testWidgets(
    'Location match notification navigates to post instead of confirmed encounter',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final item = InboxNotification({
        'id': 1,
        'type': 'location_match',
        'route': '/post',
        'entity_id': 9,
        'actor': null,
        'text': 'Birine denk gelmiş olabilirsin',
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      }, socialPerson);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const SizedBox.shrink(),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Text('Gönderi ${settings.arguments}'),
          ),
        ),
      );
      final pending = routeInboxNotification(navigator.currentState!, item);
      await tester.pumpAndSettle();
      expect(find.text('Gönderi 9'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await pending;
    },
  );

  test(
    'Travel upload retains nested request fields with and without media',
    () {
      final details = TravelDetails(
        transport: 'bus',
        origin: const CatalogItem(2, 'Ankara'),
        destination: const CatalogItem(3, 'Erzincan'),
        operatorName: 'Pamukkale',
        vehicleIdentifier: '07 NM 365',
      );
      final body = {
        'travel': details.toJson(),
        'occurred_at': '2026-11-08T11:20:00Z',
      };
      final fields = multipartFields(body);
      expect(fields['travel[transport_type]'], 'bus');
      expect(fields['travel[vehicle_identifier]'], '07 NM 365');
      expect(fields['travel[is_public]'], '0');
      expect(fields['occurred_at'], '2026-11-08T11:20:00Z');
    },
  );
}
