
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/review_prompt.dart';
import 'package:senmiydin/screens/home.dart';
import 'package:senmiydin/widgets/review_invite.dart';

import 'global_release_test.dart' show account, host, ok;
import 'support/chat_harness.dart' show loadAppFont;

class MemoryReviewState implements ReviewStateStore {
  final values = <String, int>{};
  @override
  Future<int?> readInt(String key) async => values[key];
  @override
  Future<void> writeInt(String key, int value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class FakeReviewPlatform implements ReviewPlatform {
  FakeReviewPlatform({
    this.available = true,
    this.failRequest = false,
    this.failOpen = false,
    this.hasStoreUrl = true,
  });
  bool available, failRequest, failOpen, hasStoreUrl;
  int requests = 0, opens = 0;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<void> requestReview() async {
    requests++;
    if (failRequest) throw StateError('suppressed by the platform');
  }

  @override
  Future<bool> openStoreListing() async {
    opens++;
    if (failOpen) throw StateError('no browser');
    return hasStoreUrl;
  }
}

void main() {
  setUpAll(loadAppFont);
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  final start = DateTime(2026, 11, 15, 12);
  late DateTime now;
  late MemoryReviewState state;
  late FakeReviewPlatform platform;
  late ReviewPrompt prompt;
  setUp(() {
    now = start;
    state = MemoryReviewState();
    platform = FakeReviewPlatform();
    prompt = ReviewPrompt(state: state, platform: platform, clock: () => now);
  });

  Future<void> actions(Object user, int count) async {
    for (var i = 0; i < count; i++) {
      await prompt.recordAction(user);
    }
  }

  group('When the invitation may appear', () {
    test('A brand new account is never invited, however busy it is', () async {
      await actions(1, 10);
      expect(await prompt.isEligible(1, now.subtract(const Duration(hours: 20))), isFalse);
      expect(await prompt.isEligible(1, now.subtract(const Duration(days: 2, hours: 23))), isFalse);
    });

    test('An old account with too few meaningful actions is not invited', () async {
      await actions(1, ReviewPrompt.minimumActions - 1);
      expect(await prompt.isEligible(1, now.subtract(const Duration(days: 30))), isFalse);
    });

    test('A 3-day-old account with enough actions is invited; an unknown creation date never is', () async {
      await actions(1, ReviewPrompt.minimumActions);
      expect(await prompt.isEligible(1, now.subtract(const Duration(days: 3))), isTrue);
      expect(await prompt.isEligible(1, null), isFalse);
    });

    test('After the invitation is shown: still hidden at 6 days, eligible again at 7 days', () async {
      final created = now.subtract(const Duration(days: 60));
      await actions(1, 5);
      expect(await prompt.isEligible(1, created), isTrue);
      await prompt.markShown(1);
      now = start.add(const Duration(days: 6, hours: 23));
      final nextSession = ReviewPrompt(state: state, platform: platform, clock: () => now);
      expect(await nextSession.isEligible(1, created), isFalse);
      now = start.add(const Duration(days: 7));
      expect(await nextSession.isEligible(1, created), isTrue);
    });

    test('Once per session: even after the cooldown the same session does not ask twice', () async {
      final created = now.subtract(const Duration(days: 60));
      await actions(1, 5);
      await prompt.markShown(1);
      now = start.add(const Duration(days: 8));
      expect(await prompt.isEligible(1, created), isFalse);
    });

    test('State never leaks between accounts', () async {
      final created = now.subtract(const Duration(days: 60));
      await actions(1, 5);
      await prompt.markShown(1);
      expect(await prompt.isEligible(2, created), isFalse, reason: 'Account 2 has no actions of its own.');
      await actions(2, 3);
      expect(await prompt.isEligible(2, created), isTrue, reason: 'Account 1 being asked does not start account 2’s cooldown.');
      expect(state.values.keys, everyElement(startsWith('review.')));
    });

    test('Deleting an account forgets its bookkeeping', () async {
      await actions(7, 4);
      await prompt.markShown(7);
      await prompt.forget(7);
      expect(state.values.keys.where((key) => key.contains('.7.')), isEmpty);
    });
  });

  group('Rate', () {
    test('Everybody gets the same official request when it is available', () async {
      await prompt.rate();
      expect(platform.requests, 1);
      expect(platform.opens, 0);
    });

    test('When the official API is not available the real store page is the fallback', () async {
      platform.available = false;
      await prompt.rate();
      expect(platform.requests, 0);
      expect(platform.opens, 1);
    });

    test('A suppressed or failing official request never throws and falls back quietly', () async {
      platform.failRequest = true;
      await prompt.rate();
      expect(platform.requests, 1);
      expect(platform.opens, 1);
    });

    test('Without a real store address nothing happens and nothing breaks; a failing browser is quiet too', () async {
      platform
        ..available = false
        ..hasStoreUrl = false;
      await prompt.rate();
      platform.failOpen = true;
      await prompt.rate();
      expect(platform.opens, 2);
    });

    test('The real platform wrapper has no fake link: without a configured https address it opens nothing', () async {
      expect(await OfficialReviewPlatform().openStoreListing(), isFalse);
    });
  });

  group('The invitation in the app', () {
    Future<(AppStore, FakeReviewPlatform, MemoryReviewState)> signedIn({
      DateTime? createdAt,
      String? userName,
    }) async {
      FlutterSecureStorage.setMockInitialValues({});
      final memory = MemoryReviewState();
      final fake = FakeReviewPlatform();
      final store = AppStore(
        api: ApiClient(
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/auth/login')) {
              return ok({
                'token': 't',
                'user': {
                  ...account(),
                  'created_at': (createdAt ?? DateTime.now().subtract(const Duration(days: 40))).toUtc().toIso8601String(),
                },
              });
            }
            return http.Response('{"success":true,"data":{"items":[],"next_page":null}}', 200, headers: {'content-type': 'application/json'});
          }),
        ),
        reviews: ReviewPrompt(state: memory, platform: fake),
      );
      await store.signIn('login', {'identifier': 'demo', 'password': 'x'});
      return (store, fake, memory);
    }

    test('The third meaningful action of an old account makes the invitation due; a new account never gets one', () async {
      final (store, _, _) = await signedIn();
      addTearDown(store.dispose);
      await store.noteMeaningfulAction();
      await store.noteMeaningfulAction();
      expect(store.reviewInviteReady, isFalse);
      await store.noteMeaningfulAction();
      expect(store.reviewInviteReady, isTrue);

      final (fresh, _, _) = await signedIn(createdAt: DateTime.now().subtract(const Duration(hours: 5)));
      addTearDown(fresh.dispose);
      for (var i = 0; i < 6; i++) {
        await fresh.noteMeaningfulAction();
      }
      expect(fresh.reviewInviteReady, isFalse);
    });

    testWidgets('Turkish card: title, text and both buttons; Değerlendir asks the official review once and starts the cooldown', (tester) async {
      final (store, fake, memory) = await signedIn();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        host(
          store,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(onPressed: () => showReviewInvite(context, store), child: const Text('aç')),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.text("SenMiydin?'i değerlendir"), findsOneWidget);
      expect(find.text('Uygulamayı kullanmaktan memnunsan görüşün bize çok yardımcı olur.'), findsOneWidget);
      expect(find.text('Değerlendir'), findsOneWidget);
      expect(find.text('Şimdi Değil'), findsOneWidget);
      expect(find.textContaining('sevdin'), findsNothing, reason: 'No "did you like it?" gate: the same button for everybody.');
      await tester.tap(find.byKey(const Key('review-rate')));
      await tester.pumpAndSettle();
      expect(fake.requests, 1);
      expect(memory.values.keys.any((key) => key.endsWith('.last_prompt_at')), isTrue);
      expect(find.byKey(const Key('review-title')), findsNothing);
    });

    testWidgets('English card; Not Now (and swiping it away) never calls the review API but still starts the cooldown', (tester) async {
      AppLocale.debugSet(const Locale('en'));
      final (store, fake, memory) = await signedIn();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        host(
          store,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(onPressed: () => showReviewInvite(context, store), child: const Text('open')),
              ),
            ),
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Rate SenMiydin?'), findsOneWidget);
      expect(find.text("If you're enjoying SenMiydin?, your rating would really help us."), findsOneWidget);
      expect(find.text('Rate App'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);
      await tester.tap(find.byKey(const Key('review-not-now')));
      await tester.pumpAndSettle();
      expect(fake.requests, 0);
      expect(fake.opens, 0);
      expect(memory.values.keys.any((key) => key.endsWith('.last_prompt_at')), isTrue);
    });

    testWidgets('A platform that suppresses the review sheet shows the person nothing wrong', (tester) async {
      final (store, fake, _) = await signedIn();
      addTearDown(store.dispose);
      fake.failRequest = true;
      await tester.pumpWidget(
        host(
          store,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(onPressed: () => showReviewInvite(context, store), child: const Text('aç')),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review-rate')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('On the home screen the invitation appears about 1.6 s after a due action, never at launch, and only once', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (store, fake, _) = await signedIn();
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const HomeShell()));
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('review-title')), findsNothing, reason: 'Opening the app never asks.');
      for (var i = 0; i < ReviewPrompt.minimumActions; i++) {
        await tester.runAsync(store.noteMeaningfulAction);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(const Key('review-title')), findsNothing, reason: 'A short delay first.');
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('review-title')), findsOneWidget);
      await tester.tap(find.byKey(const Key('review-not-now')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('review-title')), findsNothing);
      expect(fake.requests, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('While another page is on top (the post that was just commented on) the invitation waits and appears once Home is back', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (store, _, _) = await signedIn();
      addTearDown(store.dispose);
      await tester.pumpWidget(host(store, const HomeShell()));
      await tester.pump(const Duration(seconds: 2));
      final navigator = Navigator.of(tester.element(find.byType(HomeShell)));
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('açık sayfa')))));
      await tester.pumpAndSettle();
      for (var i = 0; i < ReviewPrompt.minimumActions; i++) {
        await tester.runAsync(store.noteMeaningfulAction);
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const Key('review-title')), findsNothing, reason: 'Never on top of what the person is doing.');
      navigator.pop();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('review-title')), findsOneWidget);
      await tester.tap(find.byKey(const Key('review-not-now')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('The card fits ${width.toInt()} px wide at 1.5x text', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (store, _, _) = await signedIn();
        addTearDown(store.dispose);
        await tester.pumpWidget(
          host(
            store,
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(onPressed: () => showReviewInvite(context, store), child: const Text('aç')),
                ),
              ),
            ),
            scale: 1.5,
          ),
        );
        await tester.tap(find.text('aç'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('review-rate')), findsOneWidget);
      });
    }
  });
}
