import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/core/theme.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/screens/home.dart' show AppBottomNav;
import 'package:senmiydin/widgets/chat_composer.dart';
import 'package:senmiydin/widgets/common.dart' show Avatar;
import 'package:senmiydin/widgets/social.dart';

import 'post_card_touch_test.dart' show feedPost, host, screen;
import 'support/chat_harness.dart' show loadAppFont, realWait;
import 'memories_test.dart' show shapedPhoto;

/// WCAG contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  final hi = a.computeLuminance() > b.computeLuminance() ? a : b;
  final lo = identical(hi, a) ? b : a;
  return (hi.computeLuminance() + .05) / (lo.computeLuminance() + .05);
}

BoxDecoration surfaceOf(WidgetTester tester) {
  final root = tester.widget<Container>(
    find.descendant(of: find.byType(PostCard), matching: find.byType(Container)).first,
  );
  return root.decoration! as BoxDecoration;
}

Future<void> pumpCard(WidgetTester tester, AppStore store, Post post, {double width = 390, double height = 1200, double scale = 1}) async {
  screen(tester, width, height);
  await tester.pumpWidget(const SizedBox.shrink()); // a fresh app: the first page of a route is kept otherwise
  await tester.pumpWidget(
    host(
      store,
      Scaffold(
        body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: PostCard(post))),
      ),
      scale: scale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFont);
  setUp(() => AppLocale.debugSet(const Locale('tr')));
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  group('Post cards have the shape of their content', () {
    testWidgets('A short text-only post sits on a soft wash with the normal body size; a long text is plain', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);

      final short = feedPost(store, id: 's', text: 'Bugün hava çok güzel.');
      await pumpCard(tester, store, short);
      var surface = surfaceOf(tester);
      expect(surface.gradient, isA<LinearGradient>(), reason: 'The statement wears the soft blue wash.');
      expect((surface.gradient! as LinearGradient).colors, [Colors.white, AppColors.surfaceBlue]);
      expect(tester.widget<Text>(find.text(short.text)).style!.fontSize, 16, reason: 'A short post is not set larger than the others.');
      expect(tester.widget<Text>(find.text(short.text)).style!.fontWeight, FontWeight.w500);

      final medium = feedPost(store, id: 'm', text: 'Sahilde yürürken fark ettim ki en güzel anlar planlanmadan geliyor.');
      await pumpCard(tester, store, medium);
      expect(surfaceOf(tester).gradient, isA<LinearGradient>());
      expect(tester.widget<Text>(find.text(medium.text)).style!.fontSize, 16);

      final long = feedPost(store, id: 'l', text: 'Uzun bir paylaşım. ' * 12);
      await pumpCard(tester, store, long);
      surface = surfaceOf(tester);
      expect(surface.gradient, isNull, reason: 'A long text stays on plain white.');
      expect(surface.color, Colors.white);
      expect(tester.widget<Text>(find.text(long.text)).style!.fontSize, 16);
    });

    testWidgets('One radius, the system shadow and a hairline on every surface', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      for (final post in [
        feedPost(store, id: 'a', text: 'Kısa.'),
        feedPost(store, id: 'b', text: 'Uzun bir paylaşım. ' * 12),
        feedPost(store, id: 'c', text: 'Fotoğraflı.', images: const ['assets/images/coast.jpg']),
      ]) {
        await pumpCard(tester, store, post);
        final surface = surfaceOf(tester);
        expect(surface.borderRadius, AppShape.largeRounded, reason: post.text);
        expect(surface.boxShadow, AppShape.shadow, reason: 'The system’s own soft shadow: ${post.text}');
        expect(surface.border, isNotNull, reason: 'A hairline keeps the edge on white.');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('A photo runs edge to edge of the card; the text keeps its inset', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      final post = feedPost(store, id: 'p', text: 'Sahilde gün batımı.', images: const ['assets/images/coast.jpg', 'assets/images/sunset.jpg']);
      await pumpCard(tester, store, post);
      expect(surfaceOf(tester).gradient, isNull, reason: 'A photo post is white: the photo is the colour.');
      final card = tester.getRect(find.byType(PostCard));
      final photo = tester.getRect(find.descendant(of: find.byType(PostCard), matching: find.byType(PageView)));
      expect(photo.left, card.left + 1, reason: 'Edge to edge: only the card’s 1 dp hairline is left of it.');
      expect(photo.right, card.right - 1);
      expect(tester.getRect(find.text(post.text)).left, closeTo(card.left + 16, 1), reason: 'The text keeps its 16 dp inset.');
      expect(find.text('1/2'), findsOneWidget, reason: 'The counter stays.');
      // Square corners on the photo itself: the card's rounded clip shapes it.
      expect(tester.widget<Container>(find.descendant(of: find.byType(PostCard), matching: find.byType(Container)).first).clipBehavior, Clip.antiAlias);
    });

    testWidgets('A tall photo is still capped and whole at the full width', (tester) async {
      final path = await shapedPhoto(tester, 90, 160);
      final store = AppStore();
      addTearDown(store.dispose);
      final post = feedPost(store, id: 't', text: 'Dikey.', images: [path]);
      await pumpCard(tester, store, post, width: 390, height: 800);
      await realWait(tester, 300);
      await tester.pumpAndSettle();
      final box = tester.getSize(find.descendant(of: find.byType(PostCard), matching: find.byType(PageView)));
      expect(box.width, closeTo(390 - 32 - 2, 1), reason: 'The card’s full width, less its hairline.');
      expect(box.height, lessThanOrEqualTo(800 * .62 + .5));
      expect(find.descendant(of: find.byType(PageView), matching: find.byType(Image)).evaluate().map((e) => (e.widget as Image).fit).toSet(), {BoxFit.cover, BoxFit.contain},
          reason: 'The photo is whole (contain); the side bands carry its own soft colours (cover, blurred).');
      expect(find.descendant(of: find.byType(PageView), matching: find.byType(ImageFiltered)), findsOneWidget);
      File(path).deleteSync();
    });

    testWidgets('A photo that fills its box needs no backdrop', (tester) async {
      final path = await shapedPhoto(tester, 80, 100);
      final store = AppStore();
      addTearDown(store.dispose);
      await pumpCard(tester, store, feedPost(store, id: 'f', text: 'Dolu.', images: [path]));
      await realWait(tester, 300);
      await tester.pumpAndSettle();
      expect(find.byType(ImageFiltered), findsNothing);
      File(path).deleteSync();
    });

    testWidgets('An encounter story wears the encounter surface and a small heart sits between the two photos', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      final story = Post(
        id: 'st',
        authorId: store.people[1].id,
        text: 'Karşılaştık.',
        storyTitle: 'İkinci merhaba',
        storyStatus: 'published',
        encounterConfirmed: true,
        storyParticipants: [store.me, store.people.first],
        remote: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      await pumpCard(tester, store, story);
      final surface = surfaceOf(tester);
      expect(surface.gradient, AppShape.encounterSurfaceGradient);
      expect(find.descendant(of: find.byType(EncounterAvatars), matching: find.byIcon(Icons.favorite_rounded)), findsOneWidget);
      // The quiet label keeps a readable contrast on white (4.5:1).
      final label = tester.widget<Text>(find.text('Karşılaşıldı'));
      expect(contrast(label.style!.color!, Colors.white), greaterThanOrEqualTo(4.5));
      expect(contrast(label.style!.color!, const Color(0xFFFFF4F8)), greaterThanOrEqualTo(4.3), reason: 'and on the pink end of the surface.');
    });

    testWidgets('A pending encounter request shows as a chip to the right of the name, on the same line', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      final post = Post(
        id: 'pending',
        authorId: store.me.id,
        text: 'Alanya sahilinde selamlaştığımız o akşamı hatırlıyorum.',
        encounterRequestId: '7',
        encounterRequestStatus: 'pending',
        remote: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await pumpCard(tester, store, post);
      final name = tester.getRect(find.text(store.me.name));
      final chip = tester.getRect(find.text('Onay bekliyor'));
      expect(chip.left, greaterThan(name.right), reason: 'chip is to the right of the name');
      expect((chip.center.dy - name.center.dy).abs(), lessThan(4), reason: 'same line as the name');
    });

    testWidgets('The avatar is 44 dp with a soft shadow', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      await pumpCard(tester, store, feedPost(store, id: 'a', text: 'Merhaba.'));
      expect(tester.getSize(find.byType(Avatar).first), const Size(44, 44));
    });

    testWidgets('The heart of the footer pops when a like turns on, and only then', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      final liked = feedPost(store, id: 'liked', text: 'Zaten beğenilmiş.', liked: true, likes: 2);
      await pumpCard(tester, store, liked);
      double scale() => tester
          .widget<ScaleTransition>(find.descendant(of: find.byTooltip('Beğen'), matching: find.byType(ScaleTransition)).first)
          .scale
          .value;
      expect(scale(), 1.0, reason: 'No pop on first build of a post that is already liked.');
      await tester.tap(find.byTooltip('Beğen')); // un-like
      await tester.pumpAndSettle();
      expect(scale(), 1.0);
      await tester.tap(find.byTooltip('Beğen')); // like
      await tester.pump(); // the rebuild starts the pop
      await tester.pump(const Duration(milliseconds: 90));
      expect(scale(), greaterThan(1.05), reason: 'The icon grows when it turns on.');
      await tester.pumpAndSettle();
      expect(scale(), 1.0, reason: 'and settles back.');
    });
  });

  group('Bottom navigation', () {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('The open tab has a wide pill behind its icon, the label under it, at ${width.toInt()} dp', (tester) async {
        screen(tester, width, 800);
        final store = AppStore();
        addTearDown(store.dispose);
        await tester.pumpWidget(host(store, Scaffold(bottomNavigationBar: AppBottomNav(selected: 1, unread: 2, onChanged: (_) {}))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final tab = tester.getRect(find.byKey(const Key('nav-1')));
        final pill = tester.getRect(find.descendant(of: find.byKey(const Key('nav-1')), matching: find.byKey(const Key('nav-indicator'))));
        final label = tester.getRect(find.text('Harita'));
        final icon = tester.getRect(find.descendant(of: find.byKey(const Key('nav-1')), matching: find.byIcon(Icons.location_on_rounded)));
        expect(pill.width, greaterThanOrEqualTo(48), reason: 'Room around the icon, not a slab hugging it.');
        expect(pill.width - icon.width, greaterThanOrEqualTo(20), reason: 'At least 10 dp of air each side of the icon.');
        expect(pill.left, greaterThanOrEqualTo(tab.left));
        expect(pill.right, lessThanOrEqualTo(tab.right));
        expect(label.top, greaterThanOrEqualTo(pill.bottom), reason: 'The label is under the pill, not inside it.');
        // Only the open tab is filled.
        Color? fill(int i) => (tester
            .widget<AnimatedContainer>(find.descendant(of: find.byKey(Key('nav-$i')), matching: find.byKey(const Key('nav-indicator'))))
            .decoration as BoxDecoration?)
            ?.color;
        expect(fill(1), isNot(Colors.transparent));
        expect(fill(0), Colors.transparent);
        // Press, hover and focus are drawn inside the pill shape.
        final ink = tester.widget<InkWell>(find.descendant(of: find.byKey(const Key('nav-1')), matching: find.byType(InkWell)));
        expect(ink.customBorder, isA<StadiumBorder>());
        expect(ink.hoverColor, isNotNull);
      });
    }

    testWidgets('A tap anywhere on a tab, the pill or the label, selects it once', (tester) async {
      screen(tester, 390, 800);
      final store = AppStore();
      addTearDown(store.dispose);
      final taps = <int>[];
      await tester.pumpWidget(host(store, Scaffold(bottomNavigationBar: AppBottomNav(selected: 0, onChanged: taps.add))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Harita'));
      await tester.tap(find.descendant(of: find.byKey(const Key('nav-1')), matching: find.byIcon(Icons.location_on_outlined)));
      await tester.tap(find.byKey(const Key('nav-4')));
      expect(taps, [1, 1, 4]);
    });
  });

  group('Message composer', () {
    Future<void> pumpBar(WidgetTester tester, {double width = 390, double scale = 1, bool canSend = false, bool withMic = true}) async {
      screen(tester, width, 800);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(const SizedBox.shrink()); // a fresh app each time
      await tester.pumpWidget(
        host(
          store,
          Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: ChatComposerBar(
                  controller: TextEditingController(),
                  busy: false,
                  canSend: canSend,
                  onAttach: () {},
                  onEmoji: () {},
                  onSend: () {},
                  onChanged: () {},
                  onMic: withMic ? () {} : null,
                ),
              ),
            ),
          ),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
    }

    Color? iconColor(WidgetTester tester, Key key) {
      final icon = find.descendant(of: find.byKey(key), matching: find.byType(Icon));
      return IconTheme.of(tester.element(icon)).color;
    }

    testWidgets('The voice and the send buttons carry white icons on the main colour', (tester) async {
      await pumpBar(tester);
      expect(iconColor(tester, const Key('chat-mic')), Colors.white);
      final mic = tester.widget<IconButton>(find.byKey(const Key('chat-mic')));
      expect(mic.style!.backgroundColor!.resolve({}), AppColors.primary);
      expect(mic.style!.foregroundColor!.resolve({}), Colors.white);
      await pumpBar(tester, canSend: true);
      expect(find.byKey(const Key('chat-mic')), findsNothing);
      expect(iconColor(tester, const Key('chat-send')), Colors.white);
      expect(tester.getSize(find.byKey(const Key('chat-send'))).shortestSide, greaterThanOrEqualTo(44));
    });

    testWidgets('The two tools sit close together and the input is a slim, long pill', (tester) async {
      await pumpBar(tester);
      final attach = tester.getRect(find.byKey(const Key('chat-attach')));
      final emoji = tester.getRect(find.byKey(const Key('chat-emoji')));
      final input = tester.getRect(find.byKey(const Key('chat-input')));
      final mic = tester.getRect(find.byKey(const Key('chat-mic')));
      expect(attach.width, 40);
      expect(emoji.left - attach.right, lessThanOrEqualTo(1), reason: 'The two targets touch.');
      // And so do the icons, almost: the glyphs face each other inside their targets.
      Rect glyph(String key) => tester.getRect(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Icon)));
      expect(glyph('chat-emoji').left - glyph('chat-attach').right, lessThanOrEqualTo(10), reason: 'Close: 8 dp between the two icons.');
      expect(input.left - emoji.right, lessThanOrEqualTo(6));
      expect(mic.left - input.right, lessThanOrEqualTo(10));
      // Long: it takes what the tools and the round button leave.
      expect(input.width, greaterThanOrEqualTo(390 - 16 - 80 - 48 - 4 - 8 - 2));
      // Slim: one line is a pill under 50 dp tall, rounded all the way.
      expect(input.height, lessThanOrEqualTo(50));
      final decoration = tester.widget<TextField>(find.byKey(const Key('chat-input'))).decoration!;
      final border = decoration.enabledBorder! as OutlineInputBorder;
      expect(border.borderRadius.topLeft.x, greaterThanOrEqualTo(22));
      expect(decoration.fillColor, Colors.white, reason: 'White so it reads on every chat backdrop.');
      expect(border.borderSide.color, AppColors.border, reason: 'A hairline outline until focused.');
      expect((decoration.focusedBorder! as OutlineInputBorder).borderSide.color, AppColors.primary);
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('The bar fits ${width.toInt()} dp at 1.5x text', (tester) async {
        await pumpBar(tester, width: width, scale: 1.5);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.byKey(const Key('chat-mic'))).right, lessThanOrEqualTo(width));
        expect(tester.getRect(find.byKey(const Key('chat-input'))).width, greaterThan(120));
      });
    }

    test('Every round blue action uses the one style: white on the main colour', () {
      final style = AppButtons.filledIcon;
      expect(style.foregroundColor!.resolve({}), Colors.white);
      expect(style.backgroundColor!.resolve({}), AppColors.primary);
    });
  });
}
