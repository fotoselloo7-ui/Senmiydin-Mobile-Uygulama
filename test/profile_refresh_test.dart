import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/screens/profile.dart';

void main() {
  testWidgets('An open own profile displays saved changes without reopening', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    Map<String, Object?> profile(String name) => {
      'id': 1,
      'name': name,
      'username': 'pixel',
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
          data = {'token': 'test-token', 'user': profile('Önceki Ad')};
        } else if (path.endsWith('/profile') && request.method == 'PUT') {
          data = profile('Güncel Ad');
        } else if (path.endsWith('/users/pixel')) {
          data = profile('Önceki Ad');
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
      'identifier': 'pixel',
      'password': 'test-password',
    });
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(body: ProfileContent(personId: store.me.id)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Önceki Ad'), findsOneWidget);
    await store.saveAccountProfile({'name': 'Güncel Ad'});
    await tester.pumpAndSettle();
    expect(find.text('Güncel Ad'), findsOneWidget);
    expect(find.text('Önceki Ad'), findsNothing);
  });
}
