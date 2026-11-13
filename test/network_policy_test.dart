import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/core/service_availability.dart';

class PendingHttpClient extends http.BaseClient {
  final response = Completer<http.StreamedResponse>();
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      response.future;
  @override
  void close() {
    closed = true;
  }
}

void main() {
  test('Disposing API client waits for its active request and rejects new requests', () async {
    final transport = PendingHttpClient();
    final client = ApiClient(httpClient: transport);
    final request = client.send('GET', 'cities');
    client.dispose();
    expect(transport.closed, false);
    transport.response.complete(
      http.StreamedResponse(
        Stream.value(utf8.encode('{"success":true,"data":[]}')),
        200,
      ),
    );
    expect(await request, isEmpty);
    expect(transport.closed, true);
    await expectLater(client.send('GET', 'cities'), throwsA(isA<ApiFailure>()));
  });

  test(
    '401 clears secure storage and reports the ended session once',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      var ended = 0, calls = 0;
      final client = ApiClient(
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('{"success":false}', 401);
        }),
      );
      client.onUnauthorized = () => ended++;
      await client.saveToken('test-session');
      await expectLater(
        client.send('GET', 'auth/me', authenticated: true),
        throwsA(
          isA<ApiFailure>().having((e) => e.status, 'expired status', 401),
        ),
      );
      expect(await client.restoreToken(), false);
      expect(ended, 1);
      expect(calls, 1);
      client.dispose();
    },
  );
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'HTTP errors are bounded, mutations are never automatically repeated',
    () async {
      for (final status in [403, 404, 422, 429, 500, 503]) {
        var calls = 0;
        final client = ApiClient(
          httpClient: MockClient((_) async {
            calls++;
            return http.Response(
              status >= 500
                  ? '{"secret":"SQL path /private/server"}'
                  : '{"success":false,"message":"İşlem kullanılamıyor."}',
              status,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        await expectLater(
          client.send('POST', 'posts', body: {'body': 'one write'}),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.message.contains('/private'),
              'private error hidden',
              false,
            ),
          ),
        );
        expect(calls, 1);
        client.dispose();
      }
    },
  );
  test('Network unavailability is friendly and missing provider configuration is safe', () async {
    final client = ApiClient(
      httpClient: MockClient(
        (_) async => throw const SocketException('private network detail'),
      ),
    );
    await expectLater(
      client.send('GET', 'cities'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'friendly message',
          contains('bağlantı'),
        ),
      ),
    );
    expect(ServiceAvailability.social('Google'), false);
    expect(ServiceAvailability.social('Apple'), false);
    expect(ServiceAvailability.push, false);
    expect(
      ServiceAvailability.store(Uri.parse('https://example.com'), 'android'),
      false,
    );
    client.dispose();
  });
}
