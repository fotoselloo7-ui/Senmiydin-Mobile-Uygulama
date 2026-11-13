import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/screens/encounters.dart';
import 'package:senmiydin/widgets/social.dart';

const _requester = {'id': 1, 'name': 'Deniz', 'username': 'deniz'};
const _target = {'id': 2, 'name': 'Elif', 'username': 'elif'};

Map<String, Object?> _entry({int? revision, bool outgoing = false}) => {
  'id': 5,
  'status': revision == null ? 'pending' : 'accepted',
  'outgoing': outgoing,
  'requester': _requester,
  'target': _target,
  'created_at': '2026-01-01T12:00:00Z',
  'source': _post(6),
  'encounter_id': revision == null ? null : 7,
  'story': revision == null ? null : _post(8, revision: revision),
};

Map<String, Object?> _post(int id, {int? revision}) => {
  'id': id,
  'author': _requester,
  'body': revision == null ? 'Sahilde yürüdük.' : 'İkinci yürüyüş.',
  'type': 'encounter',
  'city': {'name': 'Alanya'},
  'media': [],
  'visibility': 'city',
  'likes_count': 0,
  'comments_count': 0,
  'comments_enabled': true,
  'created_at': '2026-01-01T12:00:00Z',
  if (revision != null) ...{
    'story_revision': revision,
    'story_title': 'İkinci merhaba',
    'story_status': 'pending',
  },
};

http.Response _ok(Object data) => http.Response.bytes(
  utf8.encode(jsonEncode({'success': true, 'data': data})),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Story review sends the revision from the opened request', () async {
    var revision = 1;
    final client = ApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/encounter-requests/5')) {
          return _ok(_entry(revision: revision));
        }
        if (request.url.path.endsWith('/encounter-requests/pending-count')) {
          return _ok({'count': 0});
        }
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/encounters/7/story/approve'));
        expect(jsonDecode(request.body), {'revision': 1});
        return http.Response.bytes(
          utf8.encode(jsonEncode({'message': 'İçerik güncellendi.'})),
          409,
        );
      }),
    );
    final store = AppStore(api: client);
    addTearDown(store.dispose);
    await client.saveToken('test-session');
    final opened = await store.loadEncounter('5');
    revision = 2;
    expect((await store.loadEncounter('5')).storyRevision, 2);
    await expectLater(
      store.reviewEncounterStory(opened, 'approve'),
      throwsA(
        isA<ApiFailure>().having((failure) => failure.status, 'status', 409),
      ),
    );
  });

  for (final outgoing in [false, true]) {
    testWidgets(
      outgoing
          ? 'Sender can cancel a pending request'
          : 'Recipient can accept or reject a pending request',
      (tester) async {
        final client = ApiClient(
          httpClient: MockClient(
            (request) async => _ok(_entry(outgoing: outgoing)),
          ),
        );
        await client.saveToken('test-session');
        final store = AppStore(api: client);
        addTearDown(store.dispose);
        await tester.pumpWidget(
          StoreScope(
            store: store,
            child: const MaterialApp(home: LiveEncounterPage('5')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sahilde yürüdük.'), findsOneWidget);
        expect(
          find.text('Karşılaşmayı Onayla'),
          outgoing ? findsNothing : findsOneWidget,
        );
        expect(find.text('Reddet'), outgoing ? findsNothing : findsOneWidget);
        expect(
          find.text('İsteği İptal Et'),
          outgoing ? findsOneWidget : findsNothing,
        );
        expect(find.text('Karşılaşıldı ✓'), findsNothing);
        final entry = await store.loadEncounter('5');
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: EncounterInboxRow(entry))),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Onay bekliyor'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Published card puts both participants and the story above photos',
    (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      final story = Post(
        id: 'story',
        authorId: store.me.id,
        text: 'Sahilde yürüdük.',
        storyTitle: 'İkinci merhaba',
        storyStatus: 'published',
        storyParticipants: [store.me, store.people.first],
        images: const ['assets/images/coast.jpg', 'assets/images/sunset.jpg'],
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            home: Scaffold(body: PublishedEncounterCard(story)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EncounterAvatars), findsOneWidget);
      expect(find.text('Karşılaşıldı ✓'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ImageCarousel)).dy,
        greaterThan(tester.getBottomLeft(find.text(story.text)).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
