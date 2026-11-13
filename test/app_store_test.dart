import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';

void main() {
  test('Mock content covers every social format and visibility is opt-in', () {
    final s = AppStore();
    expect(s.people.length, greaterThanOrEqualTo(10));
    expect(s.posts.length, greaterThanOrEqualTo(15));
    expect(s.posts.map((p) => p.kind).toSet(), containsAll(PostKind.values));
    expect(s.posts.any((p) => p.images.length > 1), isTrue);
    expect(s.posts.any((p) => p.images.length == 1), isTrue);
    expect(s.posts.any((p) => p.images.isEmpty), isTrue);
    expect(s.posts.any((p) => p.anonymous), isTrue);
    expect(
      s.nearbyPeople.every((p) => p.visible && !s.blocked.contains(p.id)),
      isTrue,
    );
    s.me.visible = false;
    expect(s.nearbyPeople.any((p) => p.id == s.me.id), isFalse);
  });
  test('Only approved encounters are featured; resolution is idempotent', () {
    final s = AppStore();
    final count = s.featured.length;
    final p = s.publish(
      text: 'Sahilde sen miydin?',
      kind: PostKind.encounter,
      images: [],
      anonymous: false,
      cityWide: true,
      taggedId: 'u1',
      location: 'Alanya',
    );
    final e = s.encounters.firstWhere((e) => e.postId == p.id);
    expect(e.status, EncounterStatus.pending);
    expect(s.featured.length, count);
    s.resolveEncounter(e, true);
    expect(s.featured.length, count + 1);
    s.resolveEncounter(e, false);
    expect(e.status, EncounterStatus.approved);
    expect(
      s.notices
          .where((n) => n.kind == NoticeKind.approved && n.encounterId == e.id)
          .length,
      1,
    );
  });
  test(
    'Rejection does not feature an encounter; anonymity strips participants',
    () {
      final s = AppStore();
      final e = s.encounters.firstWhere(
        (e) => e.status == EncounterStatus.pending,
      );
      s.resolveEncounter(e, false);
      expect(s.featured, isNot(contains(e)));
      final count = s.encounters.length;
      final p = s.publish(
        text: 'Anonim düşünce',
        kind: PostKind.encounter,
        images: [],
        anonymous: true,
        cityWide: true,
        taggedId: 'u1',
        location: 'Alanya',
      );
      expect(p.taggedId, isNull);
      expect(s.encounters.length, count);
    },
  );
  test('Filters combine city, radius, format, interests and sorting', () {
    final s = AppStore();
    s.applyFilter(
      FeedFilter()
        ..range = '5 km'
        ..content = 'Fotoğraflı'
        ..sort = 'En yakın'
        ..interests = {'Kahve'},
    );
    expect(s.feed, isNotEmpty);
    expect(
      s.feed.every(
        (p) => p.city == 'Alanya' && p.distance <= 5 && p.images.isNotEmpty,
      ),
      isTrue,
    );
    expect(
      s.feed.map((p) => p.distance),
      orderedEquals(s.feed.map((p) => p.distance).toList()..sort()),
    );
    s.setCity('Ankara');
    s.applyFilter(FeedFilter());
    expect(s.feed.length, 2);
    expect(s.feed.every((p) => p.kind == PostKind.journey), isTrue);
  });
  test(
    'Social actions, conversations and blocking share a consistent store',
    () {
      final s = AppStore(), p = s.posts.first;
      final likes = p.likes;
      s.like(p);
      s.like(p);
      expect(p.likes, likes);
      expect(p.liked, isFalse);
      s.save(p);
      expect(p.saved, isTrue);
      final c = s.post('p0').comments.length;
      s.comment(s.post('p0'), '  Merhaba!  ');
      expect(s.post('p0').comments.length, c + 1);
      expect(s.post('p0').comments.last.text, 'Merhaba!');
      s.send('u1', 'Merhaba');
      expect(s.conversation('u1').messages.last.text, 'Merhaba');
      s.block('u1');
      final before = s.conversation('u1').messages.length;
      s.send('u1', 'Gizli kalmalı');
      expect(s.conversation('u1').messages.length, before);
      expect(s.feed.any((p) => p.authorId == 'u1'), isFalse);
      expect(s.nearbyPeople.any((p) => p.id == 'u1'), isFalse);
      s.unblock('u1');
      expect(s.feed.any((p) => p.authorId == 'u1'), isTrue);
    },
  );
}
