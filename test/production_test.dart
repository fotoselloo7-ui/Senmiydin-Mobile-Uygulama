import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/version_policy.dart';
import 'package:senmiydin/screens/settings.dart';
import 'package:senmiydin/widgets/app_availability.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Version ordering is numeric and optional build metadata does not affect minimums', () {
    expect(VersionPolicy.compare('0.10.0', '0.9.9'), greaterThan(0));
    expect(VersionPolicy.compare('0.1.0+1', '0.1.0'), 0);
    expect(VersionPolicy.compare('invalid', '1.0.0'), isNull);
    expect(VersionPolicy.compare('1.0', '1.0.0'), isNull);
  });

  test('Version policy distinguishes required and suggested updates and ignores absent or untrusted stores', () {
    const url =
        'https://play.google.com/store/apps/details?id=com.senmiydin.app';
    expect(
      VersionPolicy.fromJson('0.1.0', 'android', {
        'minimum': '0.2.0',
        'latest': '0.3.0',
        'url': url,
      })!.required,
      true,
    );
    expect(
      VersionPolicy.fromJson('0.2.0', 'android', {
        'minimum': '0.2.0',
        'latest': '0.3.0',
        'url': url,
      })!.required,
      false,
    );
    expect(
      VersionPolicy.fromJson('0.3.0', 'android', {
        'minimum': '0.2.0',
        'latest': '0.3.0',
        'url': url,
      }),
      isNull,
    );
    expect(
      VersionPolicy.fromJson('0.1.0', 'android', {
        'minimum': '9.0.0',
        'url': '',
      }),
      isNull,
    );
    expect(
      VersionPolicy.fromJson('0.1.0', 'android', {
        'minimum': '9.0.0',
        'url': 'https://attacker.example',
      }),
      isNull,
    );
  });

  test(
    'Network and server failures never expose technical error details',
    () async {
      final offline = ApiClient(
        httpClient: MockClient(
          (_) async => throw const SocketException('private machine'),
        ),
      );
      addTearDown(offline.dispose);
      await expectLater(
        offline.send('GET', 'cities'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            isNot(contains('private machine')),
          ),
        ),
      );
      final broken = ApiClient(
        httpClient: MockClient(
          (_) async => http.Response('SQL password=secret /private/file', 500),
        ),
      );
      addTearDown(broken.dispose);
      await expectLater(
        broken.send('GET', 'cities'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            isNot(contains('secret')),
          ),
        ),
      );
    },
  );

  testWidgets(
    'Erasure form requires explicit confirmation and clears the local session after success',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var erased = false;
      final client = ApiClient(
        httpClient: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, endsWith('/auth/account'));
          expect(request.headers['authorization'], 'Bearer test-session');
          expect(jsonDecode(request.body), {
            'password': 'Account12345!',
            'confirmation': 'SİL',
          });
          erased = true;
          return http.Response(
            jsonEncode({'success': true, 'data': null}),
            200,
          );
        }),
      );
      await client.saveToken('test-session');
      final store = AppStore(api: client)..authenticated = true;
      addTearDown(store.dispose);
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            home: const DeleteAccountPage(),
            routes: {
              '/welcome': (_) => const Scaffold(body: Text('Oturum kapalı')),
            },
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('delete-account')))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextFormField), 'Account12345!');
      await tester.enterText(
        find.byKey(const Key('delete-confirmation')),
        'SİL',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('delete-account')));
      await tester.tap(find.byKey(const Key('delete-account')));
      await tester.pumpAndSettle();
      expect(erased, true);
      expect(await client.restoreToken(), false);
      expect(store.authenticated, false);
      expect(find.text('Oturum kapalı'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Maintenance and mandatory updates show clear gates while ordinary layout stays available',
    (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AppAvailability(
            store: store,
            child: const Scaffold(
              body: Column(children: [Text('Akış'), TextField()]),
            ),
          ),
        ),
      );
      expect(find.text('Akış'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Taslak metin');
      store.authenticated = true;
      store.maintenanceNotice = 'Kısa bir bakım yapıyoruz.';
      store.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Kısa bir ara'), findsOneWidget);
      expect(find.text('Akış'), findsNothing);
      store.maintenanceNotice = null;
      store.versionPolicy = VersionPolicy(
        '1.0.0',
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.senmiydin.app',
        ),
        required: true,
      );
      store.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Güncelleme gerekli'), findsOneWidget);
      expect(find.text('Daha Sonra'), findsNothing);
      store.versionPolicy = VersionPolicy(
        '1.0.0',
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.senmiydin.app',
        ),
        required: false,
      );
      store.refresh();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daha Sonra'));
      await tester.pumpAndSettle();
      expect(find.text('Taslak metin'), findsOneWidget);
      store.versionPolicy = VersionPolicy(
        '1.0.0',
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.senmiydin.app',
        ),
        required: true,
      );
      store.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Güncelleme gerekli'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
