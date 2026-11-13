import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/core/api_config.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/screens/direct_chat.dart';
import 'package:senmiydin/screens/live_notifications.dart';

http.Response result(Object? data) => http.Response.bytes(
  utf8.encode(jsonEncode({'success': true, 'data': data})),
  200,
);

const peer = {'id': 2, 'name': 'Elif', 'username': 'elifdemo'};
const message = {
  'id': 50,
  'body': 'Sahilde görüşelim.',
  'type': 'text',
  'mine': false,
  'created_at': '2026-11-06T10:00:00Z',
  'read_at': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Conversation history uses a bounded cursor and reads only through the received message', () async {
    final paths = <String>[];
    final client = ApiClient(
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer local-test');
        paths.add(request.url.pathSegments.last);
        if (request.method == 'GET') {
          expect(request.url.queryParameters, {'before': '90'});
          return result({
            'items': [message],
            'has_more': true,
          });
        }
        expect(jsonDecode(request.body), {'through': 50});
        return result(null);
      }),
    );
    await client.saveToken('local-test');
    final store = AppStore(api: client);
    addTearDown(store.dispose);
    final page = await store.communication!.messages(9, before: 90);
    expect(page.more, true);
    expect(page.items.single.body, 'Sahilde görüşelim.');
    expect(page.items.single.read, false);
    await store.communication!.readMessages(9, page.items.single.id);
    expect(paths, ['messages', 'read']);
    expect(client.mediaHeaders('${ApiConfig.base}/message-images/50'), {
      'Authorization': 'Bearer local-test',
    });
    expect(
      client.mediaHeaders('https://example.test/api/v1/message-images/50'),
      isEmpty,
    );
  });

  testWidgets(
    'Incoming request row shows the real message and its unread count',
    (tester) async {
      final client = ApiClient(
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['requests'], '1');
          return result({
            'items': [
              {
                'id': 9,
                'status': 'pending',
                'peer': peer,
                'outgoing': false,
                'unread': 2,
                'last_message': message,
              },
            ],
            'next_page': null,
          });
        }),
      );
      await client.saveToken('local-test');
      final store = AppStore(api: client);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(
            home: Scaffold(body: DirectConversationList(true, '')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Elif'), findsOneWidget);
      expect(find.text('Gelen istek · Sahilde görüşelim.'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Open chat removes a message after moderation on the next poll', (
    tester,
  ) async {
    var removed = false;
    final client = ApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/messages')) {
          return result({
            'items': [
              if (!removed)
                {...message, 'id': 51, 'body': 'İncelenen mesaj', 'mine': true},
              {...message, 'mine': true},
            ],
            'has_more': false,
          });
        }
        return result({
          'id': 9,
          'peer': peer,
          'status': 'active',
          'outgoing': true,
          'can_send': true,
        });
      }),
    );
    await client.saveToken('local-test');
    final store = AppStore(api: client);
    addTearDown(store.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: DirectChatPage('9')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('İncelenen mesaj'), findsOneWidget);
    removed = true;
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('İncelenen mesaj'), findsNothing);
    expect(find.text('Sahilde görüşelim.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Notification center loads server rows and marks them read', (
    tester,
  ) async {
    var read = false;
    final client = ApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'PUT') {
          expect(request.url.path, endsWith('/notifications/read'));
          read = true;
          return result(null);
        }
        return result({
          'items': [
            {
              'id': 8,
              'type': 'like',
              'route': '/post',
              'entity_id': 42,
              'actor': peer,
              'text': 'Paylaşımın beğenildi.',
              'read': read,
              'created_at': '2026-11-06T10:00:00Z',
            },
          ],
          'next_page': null,
        });
      }),
    );
    await client.saveToken('local-test');
    final store = AppStore(api: client);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: LiveNotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Paylaşımın beğenildi.'), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsOneWidget);
    await tester.tap(find.byTooltip('Tümünü okundu işaretle'));
    await tester.pumpAndSettle();
    expect(read, true);
    expect(find.byIcon(Icons.circle), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
