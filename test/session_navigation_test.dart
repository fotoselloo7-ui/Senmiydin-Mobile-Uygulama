import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/main.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('NunitoSans')
      ..addFont(rootBundle.load('assets/fonts/NunitoSans.ttf'));
    await font.load();
  });
  testWidgets('Ending a session removes the authenticated navigation stack', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    final profile = {
      'id': 1,
      'name': 'Ada',
      'username': 'ada',
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
    };
    final client = ApiClient(
      httpClient: MockClient((request) async {
        final path = request.url.path;
        final Object? data;
        if (path.endsWith('/auth/login')) {
          data = {'token': 'test-token', 'user': profile};
        } else if (path.endsWith('/auth/me')) {
          data = profile;
        } else if (path.endsWith('/unread-counts')) {
          data = {'messages': 0, 'notifications': 0};
        } else if (path.endsWith('/app-config')) {
          data = <String, Object?>{};
        } else if (path.endsWith('/cities')) {
          data = [
            {'id': 1, 'name': 'Alanya'},
          ];
        } else {
          data = {'items': [], 'next_page': null};
        }
        return http.Response(
          jsonEncode({'success': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final store = AppStore(api: client);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });
    await store.signIn('login', {
      'identifier': 'ada',
      'password': 'test-password',
    });
    await tester.pumpWidget(SenMiydinApp(store: store));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/settings');
    await tester.pumpAndSettle();
    expect(find.text('Ayarlar'), findsOneWidget);
    await store.signOut();
    await tester.pumpAndSettle();
    expect(find.text('E-posta veya kullanıcı adı'), findsOneWidget);
    expect(find.text('Ayarlar'), findsNothing);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      false,
    );
    expect(await client.restoreToken(), false);
  });
}
