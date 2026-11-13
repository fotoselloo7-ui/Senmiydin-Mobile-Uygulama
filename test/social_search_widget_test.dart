import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/screens/discovery.dart';
import 'package:senmiydin/widgets/social.dart';

void main() {
  testWidgets('The search tabs query the API for people and post text', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final requested = <(String?, String?)>[];
    final client = ApiClient(
      httpClient: MockClient((request) async {
        final query = request.url.queryParameters;
        final type = query['type'];
        final text = query['q'];
        if (type != null) requested.add((type, text));
        final data = switch ((type, text)) {
          ('users', 'deniz') => {
            'items': [
              {
                'id': 12,
                'name': 'Deniz K.',
                'username': 'deniz',
                'city': {'name': 'Alanya'},
              },
            ],
            'next_page': null,
          },
          ('posts', 'Kıyıda karşılaştık') => {
            'items': [
              {
                'id': 32,
                'body': 'Kıyıda karşılaştık',
                'type': 'moment',
                'city': {'name': 'Alanya'},
                'is_anonymous': true,
                'author': null,
                'comments_enabled': true,
                'visibility': 'city',
                'likes_count': 0,
                'comments_count': 0,
                'media': [],
                'created_at': '2026-01-01T12:00:00Z',
              },
            ],
            'next_page': null,
          },
          (null, null) => [
            {'id': 1, 'name': 'Alanya'},
          ],
          _ => {'items': [], 'next_page': null},
        };
        return http.Response(
          jsonEncode({'success': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final store = AppStore(api: client);
    addTearDown(store.dispose);
    await client.saveToken('test-token');
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: SearchPage()),
      ),
    );
    final field = find.byKey(const Key('global-search'));
    await tester.enterText(field, 'deniz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Deniz K.'), findsOneWidget);
    final posts = find.widgetWithText(ChoiceChip, 'Paylaşımlar');
    await tester.tap(posts);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(posts).selected, true);
    await tester.enterText(field, 'Kıyıda karşılaştık');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(requested, contains(('posts', 'Kıyıda karşılaştık')));
    expect(
      find.descendant(
        of: find.byType(PostCard),
        matching: find.text('Kıyıda karşılaştık'),
      ),
      findsOneWidget,
    );
    expect(find.text('Anonim'), findsOneWidget);
  });
}
