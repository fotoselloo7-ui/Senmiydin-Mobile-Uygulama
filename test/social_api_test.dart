import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/core/api_config.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/social_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Social pagination preserves query text, page number, and authentication',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final client = ApiClient(
        httpClient: MockClient((request) async {
          expect(request.url.path, '${ApiConfig.base.path}/search');
          expect(request.url.queryParameters, {
            'q': '@deniz & ece',
            'type': 'users',
            'page': '2',
          });
          expect(request.headers['authorization'], 'Bearer session-token');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 42,
                    'username': 'deniz',
                    'name': 'Deniz',
                    'city': {'name': 'Alanya'},
                  },
                ],
                'next_page': 3,
              },
            }),
            200,
          );
        }),
      );
      addTearDown(client.dispose);
      await client.saveToken('session-token');

      final page = await SocialService(client)
          .page('search', 2, query: {'q': '@deniz & ece', 'type': 'users'});
      expect(page.map(socialPerson).items.single.city, 'Alanya');
      expect(page.nextPage, 3);
    },
  );

  test(
    'Only private post media from the configured API gets a bearer token',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final client = ApiClient(
        httpClient: MockClient((_) async => http.Response('', 500)),
      );
      addTearDown(client.dispose);
      await client.saveToken('session-token');
      final base = ApiConfig.base;
      expect(client.mediaHeaders('$base/post-media/2'), {
        'Authorization': 'Bearer session-token',
      });
      expect(client.mediaHeaders('$base/avatars/id.jpg'), isEmpty);
      expect(
        client.mediaHeaders('https://other.example/api/v1/post-media/2'),
        isEmpty,
      );
      await client.clearToken();
      expect(client.mediaHeaders('$base/post-media/2'), isEmpty);
    },
  );
}
