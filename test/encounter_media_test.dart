import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/widgets/common.dart';
import 'package:senmiydin/widgets/social.dart';
import 'package:senmiydin/screens/home.dart';

void main() {
  for (final featured in [true, false]) {
    for (final hasPhotos in [false, true]) {
      testWidgets(
        '${featured ? "Featured" : "Feed"} encounter: ${hasPhotos ? "real media only" : "avatars without media"}',
        (tester) async {
          final store = AppStore();
          addTearDown(store.dispose);
          final photos = hasPhotos
              ? ['assets/images/coast.jpg', 'assets/images/sunset.jpg']
              : <String>[];
          final post = Post(
            id: 'story',
            authorId: store.me.id,
            text: 'Deniz kenarında yürürken yeniden karşılaştık.',
            storyTitle: 'Sahilde ikinci merhaba',
            storyStatus: 'published',
            encounterConfirmed: true,
            storyParticipants: [store.me, store.people.first],
            images: photos,
          );
          await tester.pumpWidget(
            StoreScope(
              store: store,
              child: MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: featured
                        ? PublishedEncounterCard(post, compact: true)
                        : PostCard(post),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(EncounterAvatars), findsOneWidget);
          final avatars = find.descendant(
            of: find.byType(EncounterAvatars),
            matching: find.byType(Avatar),
          );
          expect(avatars, findsNWidgets(2));
          for (final element in avatars.evaluate()) {
            expect(
              tester.getSize(find.byWidget(element.widget)).height,
              lessThanOrEqualTo(54),
            );
          }
          expect(find.text('Karşılaşıldı ✓'), findsOneWidget);
          expect(find.text(post.storyTitle!), findsOneWidget);
          expect(find.text(post.text), findsOneWidget);
          expect(
            find.byType(ImageCarousel),
            hasPhotos ? findsOneWidget : findsNothing,
          );
          expect(find.text('1/2'), hasPhotos ? findsOneWidget : findsNothing);
          expect(find.text('1/1'), findsNothing);
          for (final label in ['Önceki fotoğraf', 'Sonraki fotoğraf']) {
            expect(
              find.byTooltip(label),
              hasPhotos ? findsOneWidget : findsNothing,
            );
          }
          if (hasPhotos) {
            final carousel = tester.widget<ImageCarousel>(
              find.byType(ImageCarousel),
            );
            expect(carousel.images, photos);
            expect(carousel.images, isNot(contains(store.me.photo)));
            expect(carousel.images, isNot(contains(store.people.first.photo)));
            await tester.drag(
              find.byType(ImageCarousel),
              const Offset(-500, 0),
            );
            await tester.pumpAndSettle();
            expect(find.text('2/2'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'Featured pager shrinks when changing to a story without photos',
    (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      Post story(String id, List<String> images) => Post(
        id: id,
        authorId: store.me.id,
        text: 'Deniz kenarında yeniden karşılaştık.',
        storyTitle: 'İkinci merhaba',
        storyStatus: 'published',
        storyParticipants: [store.me, store.people.first],
        images: images,
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            home: Scaffold(
              body: FeaturedEncounterCarousel(
                published: [
                  story('photos', [
                    'assets/images/coast.jpg',
                    'assets/images/sunset.jpg',
                  ]),
                  story('plain', []),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pager = find.byType(PageView).first;
      final withPhotos = tester.getSize(pager).height;
      await tester.dragFrom(
        tester.getTopLeft(pager) + const Offset(400, 25),
        const Offset(-700, 0),
      );
      await tester.pumpAndSettle();
      final withoutPhotos = tester.getSize(pager).height;
      expect(withoutPhotos, lessThan(withPhotos - 100));
      expect(withoutPhotos, lessThan(160));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('Device fixture text keeps uniqueness outside public content', () {
    final files = Directory('integration_test')
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') && !f.path.contains('.sync-conflict-'),
        );
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('millisecondsSinceEpoch')),
        reason: file.path,
      );
      expect(
        source,
        isNot(
          matches(
            RegExp(
              r'(storyTitle|storyBody|ownText|otherText|photoText)\s*=\s*.*\$(suffix|stamp|run|uuid)',
            ),
          ),
        ),
        reason: file.path,
      );
      if (file.path.endsWith('encounter_test.dart') ||
          file.path.endsWith('social_test.dart')) {
        expect(
          source,
          isNot(contains("'user_0.jpg'")),
          reason: 'Gallery must use scene photos',
        );
        expect(source, isNot(contains("'user_1.jpg'")));
      }
    }
  });
}
