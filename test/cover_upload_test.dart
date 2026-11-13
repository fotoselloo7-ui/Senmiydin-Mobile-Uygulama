import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/widgets/common.dart';

Map<String, Object?> _profile({String? cover}) => {
  'id': 1,
  'name': 'Pixel',
  'username': 'pixel',
  'city': {'id': 1, 'name': 'Alanya'},
  'avatar': null,
  'cover_image': cover,
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

void main() {
  test('Own cover is uploaded as a multipart "cover" file and can be removed', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final seen = <String>[];
    final client = ApiClient(
      httpClient: MockClient((request) async {
        final path = request.url.path;
        Object? data = {'items': [], 'next_page': null};
        if (path.endsWith('/auth/login')) {
          data = {'token': 'test-token', 'user': _profile()};
        } else if (path.endsWith('/profile/cover')) {
          seen.add(request.method);
          if (request.method == 'POST') {
            expect(request.headers['content-type'], startsWith('multipart/form-data'));
            expect(request.body, contains('name="cover"'));
            expect(request.body, isNot(contains('name="avatar"')));
            data = _profile(cover: '/api/v1/covers/${'a' * 8}-0000-0000-0000-${'b' * 12}.jpg');
          } else {
            data = _profile();
          }
        }
        return http.Response(
          jsonEncode({'success': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final store = AppStore(api: client);
    addTearDown(store.dispose);
    await store.signIn('login', {'identifier': 'pixel', 'password': 'test-password'});
    expect(store.account!.cover, isEmpty);

    await store.uploadCover(
      XFile.fromData(Uint8List.fromList(List<int>.generate(64, (i) => i)), name: 'cover.jpg', mimeType: 'image/jpeg'),
    );
    expect(store.account!.cover, contains('/covers/'));
    expect(store.me.cover, contains('/covers/'));

    await store.removeCover();
    expect(store.account!.cover, isEmpty);
    expect(seen, ['POST', 'DELETE']);
  });

  testWidgets('People rows never print another account\'s city', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserRow(Person(id: 'account-2', name: 'Ece Okur', handle: 'ece', city: 'Alanya', photo: '')),
        ),
      ),
    );
    expect(find.text('@ece'), findsOneWidget);
    expect(find.textContaining('Alanya'), findsNothing);
  });
}
