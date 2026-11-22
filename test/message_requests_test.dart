import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/screens/messages.dart';

import 'support/chat_harness.dart' show loadAppFont;

http.Response ok(Object? data) => http.Response(
  jsonEncode({'success': true, 'message': '', 'data': data}),
  200,
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
  'age_band': 'adult',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFont);
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  Future<AppStore> signedIn(int requests, List<String> log, {int delayMs = 0}) async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = AppStore(
      api: ApiClient(
        httpClient: MockClient((request) async {
          final path = request.url.path.replaceFirst('/api/v1', '');
          log.add(path);
          if (path.endsWith('/auth/login')) return ok({'token': 't', 'user': account()});
          if (path == '/unread-counts') {
            if (delayMs > 0) await Future<void>.delayed(Duration(milliseconds: delayMs));
            return ok({'messages': requests, 'requests': requests, 'notifications': 0});
          }
          return ok({'items': [], 'next_page': null});
        }),
      ),
    );
    await store.signIn('login', {'identifier': 'demo', 'password': 'x'});
    return store;
  }

  Widget host(AppStore store) => StoreScope(
    store: store,
    child: MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: AppLocale.supported,
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      home: const Scaffold(body: MessagesContent()),
    ),
  );

  testWidgets('A stranger’s first message is announced where the person looks: a badge on İstekler and a banner under Sohbetler', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = await signedIn(2, []);
    addTearDown(store.dispose);
    await store.refreshUnread();
    expect(store.pendingRequests, 2);
    await tester.pumpWidget(host(store));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('messages-requests-banner')), findsOneWidget);
    expect(find.text('2 mesaj isteğin var'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('messages-tab-1')), matching: find.text('2')), findsOneWidget);
    expect(find.byKey(const ValueKey('messages-tab-badge-0')), findsNothing);

    await tester.tap(find.byKey(const Key('messages-requests-banner')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('messages-requests-banner')), findsNothing, reason: 'Already on İstekler.');
    expect(find.byKey(const ValueKey('messages-tab-badge-1')), findsOneWidget);
  });

  testWidgets('Without requests there is no banner and no badge', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = await signedIn(0, []);
    addTearDown(store.dispose);
    await store.refreshUnread();
    await tester.pumpWidget(host(store));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('messages-requests-banner')), findsNothing);
    expect(find.byKey(const ValueKey('messages-tab-badge-1')), findsNothing);
  });

  test('Overlapping unread refreshes share one request and neither counts as a failure', () async {
    final log = <String>[];
    final store = await signedIn(1, log, delayMs: 60);
    addTearDown(store.dispose);
    final before = log.where((p) => p == '/unread-counts').length;
    final both = await Future.wait([store.refreshUnread(), store.refreshUnread(), store.refreshUnread()]);
    expect(both, [true, true, true], reason: 'An overlapping call must not report failure (it would slow the poller down).');
    expect(log.where((p) => p == '/unread-counts').length - before, 1);
  });
}
