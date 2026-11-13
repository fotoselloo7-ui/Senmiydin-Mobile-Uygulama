import 'device_accounts.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/main.dart';
import 'package:senmiydin/widgets/social.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Photo-less encounter keeps avatars separate in featured and normal feed',
    (tester) async {
      Future<AppStore> login(String user, String namespace) async {
        final storage = FlutterSecureStorage(
          aOptions: AndroidOptions(storageNamespace: namespace),
        );
        await storage.delete(key: 'senmiydin.session.token');
        final store = AppStore(api: ApiClient(storage: storage));
        await store.signIn('login', {
          'identifier': user,
          'password': pixelPassword,
        });
        await store.location!.refresh();
        store.location!.configure(active: false, history: false);
        return store;
      }

      final writer = await login(
        pixelEncounterWriter,
        'senmiydin_plain_writer',
      );
      final reader = await login(
        pixelEncounterReader,
        'senmiydin_plain_reader',
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await writer.signOut();
        await reader.signOut();
        writer.dispose();
        reader.dispose();
      });
      final source = await writer.publishPost(
        body: 'Bir kahve molasında karşılaştık.',
        kind: PostKind.encounter,
        media: [],
        anonymous: false,
        cityWide: true,
        location: 'Alanya',
        requestId: const Uuid().v4(),
        targetId: 'account-${reader.account!.id}',
      );
      final requestId = source.encounterRequestId!;
      final entry = await reader.respondEncounter(requestId, 'accept');
      final story = await reader.publishPost(
        body: 'Kahve molasında yarım kalan merhabamızı tamamladık.',
        kind: PostKind.encounter,
        media: [],
        anonymous: false,
        cityWide: true,
        location: 'Alanya',
        requestId: const Uuid().v4(),
        encounterId: entry.encounterId,
        storyTitle: 'Kahve molasında yeniden',
      );
      await writer.reviewEncounterStory(
        await writer.loadEncounter(requestId),
        'approve',
      );
      final saved = await writer.loadPost(story.id);
      expect(saved.images, isEmpty);
      expect(saved.storyParticipants, hasLength(2));
      expect(saved.storyParticipants.every((p) => p.photo.isNotEmpty), true);
      await tester.pumpWidget(
        SenMiydinApp(store: writer, initialRoute: '/home'),
      );
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 160; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          if (finder.evaluate().isNotEmpty) {
            await tester.pumpAndSettle();
            return;
          }
        }
        fail('Missing $finder');
      }

      await waitFor(find.byType(PublishedEncounterCard));
      final featured = find.byWidgetPredicate(
        (w) => w is PublishedEncounterCard && w.post.id == story.id,
      );
      for (var i = 0; i < 20 && featured.evaluate().isEmpty; i++) {
        final pager = find
            .ancestor(
              of: find.byType(PublishedEncounterCard).first,
              matching: find.byType(PageView),
            )
            .first;
        await tester.ensureVisible(pager);
        await tester.dragFrom(
          tester.getTopLeft(pager) + const Offset(170, 22),
          const Offset(-310, 0),
        );
        await tester.pumpAndSettle();
      }
      await waitFor(featured);
      void check(Finder card) {
        expect(
          find.descendant(of: card, matching: find.byType(EncounterAvatars)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.text('Karşılaşıldı ✓')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.text(story.storyTitle!)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.text(story.text)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.byType(ImageCarousel)),
          findsNothing,
        );
        expect(
          find.descendant(of: card, matching: find.text('1/2')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.byTooltip('Sonraki fotoğraf'),
          ),
          findsNothing,
        );
      }

      check(featured);
      expect(tester.getSize(featured).height, lessThan(180));
      final feed = find.byWidgetPredicate(
        (w) => w is PostCard && w.post.id == story.id,
      );
      if (feed.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          feed,
          190,
          scrollable: find
              .descendant(
                of: find.byKey(const PageStorageKey('home-feed')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      check(feed);
      expect(tester.takeException(), isNull);
      debugPrint(
        'Photo-less story: real API media empty; featured and feed contain avatars and text only.',
      );
    },
    skip: pixelPassword.isEmpty,
  );
}
