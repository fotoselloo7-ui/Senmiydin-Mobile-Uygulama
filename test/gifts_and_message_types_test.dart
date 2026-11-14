import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/core/relative_time.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/communication_api.dart';
import 'package:senmiydin/data/encounter_api.dart';
import 'package:senmiydin/data/gifts.dart';
import 'package:senmiydin/data/map_notes_api.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/data/social_api.dart';
import 'package:senmiydin/screens/direct_chat.dart';
import 'package:senmiydin/widgets/social.dart';

import 'global_release_test.dart' show host, noticeJson, ok;
import 'support/chat_harness.dart';

void main() {
  setUpAll(loadAppFont);
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  Finder attachGift() => find.byKey(const ValueKey('attach-gift'));

  Future<void> openGiftSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('chat-attach')));
    await tester.pumpAndSettle();
    await tester.tap(attachGift());
    await tester.pumpAndSettle();
  }

  group('Gifts', () {
    testWidgets('The + menu offers Hediye and the sheet lists the eight free gifts with their art', (tester) async {
      await openChat(tester);
      await tester.tap(find.byKey(const Key('chat-attach')));
      await tester.pumpAndSettle();
      expect(find.text('Hediye'), findsOneWidget);
      expect(find.text('Fotoğraf'), findsOneWidget);
      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('Konum'), findsOneWidget);
      await tester.tap(attachGift());
      await tester.pumpAndSettle();
      expect(find.text('Bir hediye gönder'), findsOneWidget);
      expect(find.text('Hediyeler ücretsiz.'), findsOneWidget);
      for (final gift in giftCatalog) {
        expect(find.byKey(ValueKey('gift-${gift.$1}')), findsOneWidget, reason: gift.$1);
        expect(find.text(gift.$2), findsOneWidget);
      }
    });

    testWidgets('Choosing a gift sends only its slug; the bubble is a sober card and the sender reads "Hediye gönderdin."', (tester) async {
      final sent = <http.Request>[];
      await openChat(
        tester,
        sent: sent,
        onSend: (request) async => ok(sendResult(chatMessage(99, 'gift', mine: true, gift: {'slug': 'rose', 'name': 'Gül', 'asset': 'rose'})), 201),
      );
      await openGiftSheet(tester);
      await tester.tap(find.byKey(const ValueKey('gift-rose')));
      await tester.pumpAndSettle();
      await realWait(tester, 120);
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      final body = bodyText(sent.single);
      expect(body, contains('"gift":"rose"'));
      expect(body, isNot(contains('price')), reason: 'No coins or payments are involved.');
      expect(find.byKey(const Key('gift-card-rose')), findsOneWidget);
      expect(find.text('Gül'), findsOneWidget);
      expect(find.text('Hediye gönderdin.'), findsOneWidget);
    });

    testWidgets('A received gift reads "{name} sana bir hediye gönderdi."', (tester) async {
      await openChat(tester, messages: [chatMessage(4, 'gift', gift: {'slug': 'coffee', 'name': 'Kahve', 'asset': 'coffee'})]);
      expect(find.byKey(const Key('gift-card-coffee')), findsOneWidget);
      expect(find.text('Elif Test sana bir hediye gönderdi.'), findsOneWidget);
    });

    testWidgets('A gift the app has no art for falls back to the gift box instead of failing', (tester) async {
      await openChat(tester, messages: [chatMessage(4, 'gift', gift: {'slug': 'unicorn', 'name': 'Tek boynuzlu at', 'asset': 'unicorn'})]);
      expect(tester.takeException(), isNull);
      expect(find.text('Tek boynuzlu at'), findsOneWidget);
    });

    testWidgets('A catalog that fails to load offers a retry', (tester) async {
      await openChat(tester, giftsFail: true);
      await openGiftSheet(tester);
      expect(find.byKey(const Key('gift-retry')), findsOneWidget);
      expect(find.text('Hediyeler yüklenemedi. Tekrar dene.'), findsOneWidget);
    });

    testWidgets('English: the menu, the sheet, the names and the card sentences are English and the request carries the language', (tester) async {
      AppLocale.debugSet(const Locale('en'));
      final languages = <String>[];
      await openChat(
        tester,
        locale: const Locale('en'),
        giftLanguages: languages,
        messages: [chatMessage(4, 'gift', gift: {'slug': 'coffee', 'name': 'Coffee', 'asset': 'coffee'})],
      );
      expect(find.text('Elif Test sent you a gift.'), findsOneWidget);
      await openGiftSheet(tester);
      expect(find.text('Send a gift'), findsOneWidget);
      expect(find.text('Gifts are free.'), findsOneWidget);
      expect(find.text('Rose'), findsOneWidget);
      expect(languages, ['en']);
    });

    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('The gift sheet fits ${width.toInt()} px at 1.5x text', (tester) async {
        await openChat(tester, width: width, scale: 1.5);
        await openGiftSheet(tester);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.byKey(const Key('gift-grid'))).right, lessThanOrEqualTo(width));
      });
    }

    test('GiftItem keeps a paid future possible: free today, price and currency parsed when present', () {
      final free = GiftItem.fromJson({'slug': 'heart', 'name': 'Kalp', 'asset': 'heart'});
      expect(free.isFree, isTrue);
      final paid = GiftItem.fromJson({'slug': 'gold', 'name': 'Altın', 'asset': 'star', 'price_minor': 499, 'currency': 'TRY'});
      expect(paid.isFree, isFalse);
      expect(paid.priceMinor, 499);
      expect(paid.currency, 'TRY');
    });
  });

  group('Message types', () {
    test('Previews: Sesli mesaj / Hediye gönderdi in Turkish, Voice message / Sent a gift in English', () {
      final voice = DirectMessage(chatMessage(1, 'voice', durationMs: 4000));
      final gift = DirectMessage(chatMessage(2, 'gift', gift: {'slug': 'heart', 'name': 'Kalp', 'asset': 'heart'}));
      expect(voice.preview, 'Sesli mesaj');
      expect(gift.preview, 'Hediye gönderdi');
      AppLocale.debugSet(const Locale('en'));
      expect(voice.preview, 'Voice message');
      expect(gift.preview, 'Sent a gift');
    });

    test('A voice or gift row keeps its type while an unknown type is none of the known ones', () {
      expect(DirectMessage(chatMessage(1, 'voice', durationMs: 4000)).isVoice, isTrue);
      expect(DirectMessage(chatMessage(1, 'voice', durationMs: 4000)).durationMs, 4000);
      final unknown = DirectMessage(chatMessage(3, 'hologram'));
      expect([unknown.isVoice, unknown.isGift, unknown.isLocation], everyElement(isFalse));
      expect(unknown.image, isEmpty);
    });

    testWidgets('A conversation row previews each type', (tester) async {
      await openChat(tester);
      final store = StoreScope.of(tester.element(find.byType(DirectChatPage)));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoreScope(
              store: store,
              child: ListView(
                children: [
                  ConversationTile(peer: store.people[1], unread: 0, last: DirectMessage(chatMessage(1, 'voice', durationMs: 3000)), onTap: () {}),
                  ConversationTile(peer: store.people[2], unread: 0, last: DirectMessage(chatMessage(2, 'gift', gift: {'slug': 'star', 'name': 'Yıldız', 'asset': 'star'})), onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sesli mesaj'), findsOneWidget);
      expect(find.text('Hediye gönderdi'), findsOneWidget);
    });

    testWidgets('An unknown message type never crashes the chat and says it cannot be shown', (tester) async {
      await openChat(tester, messages: [chatMessage(3, 'hologram'), chatMessage(4, 'text', body: 'Merhaba', mine: true)]);
      expect(tester.takeException(), isNull);
      expect(find.text('Bu mesaj türü bu sürümde gösterilemiyor.'), findsOneWidget);
      expect(find.text('Merhaba'), findsOneWidget);
    });
  });

  group('Relative times keep the raw timestamp and follow the language', () {
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));

    test('relativeTime reads Turkish, then English from the same instant', () {
      final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));
      expect(relativeTime(threeHoursAgo), '3 sa önce');
      AppLocale.debugSet(const Locale('en'));
      expect(relativeTime(threeHoursAgo), '3 h ago');
      expect(relativeTime(DateTime.now()), 'Just now');
    });

    test('Post, comment, encounter, notification and map note labels re-format on a language switch', () {
      final post = Post(
        id: '1',
        authorId: 'account-1',
        text: 'Merhaba',
        createdAt: fiveMinutesAgo,
      );
      final comment = Comment('account-1', 'Selam', createdAt: fiveMinutesAgo);
      final notification = InboxNotification(noticeJson(1, 'like', at: fiveMinutesAgo), (json) => throw StateError('no actor'));
      expect(post.time, '5 dk önce');
      expect(comment.time, '5 dk önce');
      expect(notification.time, '5 dk önce');
      final note = fiveMinutesAgo;
      final turkishNote = mapNoteTime(note, now: note.add(const Duration(days: 3)));
      AppLocale.debugSet(const Locale('en'));
      expect(post.time, '5 min ago');
      expect(comment.time, '5 min ago');
      expect(notification.time, '5 min ago');
      expect(mapNoteTime(note, now: note.add(const Duration(days: 3))), isNot(turkishNote));
    });

    testWidgets('A PostCard that is already on screen re-formats its time when the language is switched live', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = AppStore();
      addTearDown(store.dispose);
      final post = Post(
        id: '1',
        authorId: store.people[1].id,
        text: 'Merhaba dünya',
        createdAt: fiveMinutesAgo,
      );
      await tester.pumpWidget(host(store, Scaffold(body: SingleChildScrollView(child: PostCard(post)))));
      await tester.pumpAndSettle();
      expect(find.textContaining('5 dk önce'), findsOneWidget);
      AppLocale.debugSet(const Locale('en'));
      await tester.pumpAndSettle();
      expect(find.textContaining('5 min ago'), findsOneWidget);
      expect(find.textContaining('dk önce'), findsNothing);
    });

    test('Items that were built before the language changed read in the new language (no stored text)', () {
      final entry = EncounterEntry(
        id: '1',
        status: 'pending',
        outgoing: false,
        requester: Person(id: 'account-2', name: 'Ece', handle: 'ece', photo: '', remote: true),
        target: Person(id: 'account-1', name: 'Demo', handle: 'demo', photo: '', remote: true),
        time: '5 dk önce',
        createdAt: fiveMinutesAgo,
      );
      expect(entry.time, '5 dk önce');
      AppLocale.debugSet(const Locale('en'));
      expect(entry.time, '5 min ago');
      expect(socialTime(fiveMinutesAgo.toUtc().toIso8601String()), '5 min ago');
    });
  });
}
