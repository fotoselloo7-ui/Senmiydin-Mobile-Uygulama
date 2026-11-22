import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/core/chat_theme.dart';
import 'package:senmiydin/core/theme.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/widgets/chat_theme_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'post_card_touch_test.dart' show host, screen;
import 'support/chat_harness.dart'
    show chatMessage, loadAppFont, openChat, realWait;

double contrast(Color a, Color b) {
  final hi = a.computeLuminance() > b.computeLuminance() ? a : b;
  final lo = identical(hi, a) ? b : a;
  return (hi.computeLuminance() + .05) / (lo.computeLuminance() + .05);
}

BoxDecoration bubbleDecoration(WidgetTester tester, int index) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(ChatBubbleSurface).at(index),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return box.decoration as BoxDecoration;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFont);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.debugSet(const Locale('tr'));
  });
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  group('Chat theme palette', () {
    test('The default is the logo lilac for sent and the button blue for received', () {
      const theme = ChatTheme.defaults;
      expect(theme.sent.from, AppColors.brandPurple);
      expect(theme.received.from, AppColors.primaryHover);
      expect(theme.received.to, const Color(0xFF0672DE));
    });

    test('Every sent colour keeps white text readable at both ends (4.5:1)', () {
      for (final tone in ChatPalette.sent) {
        expect(contrast(Colors.white, tone.from), greaterThanOrEqualTo(4.5), reason: '${tone.id} start');
        expect(contrast(Colors.white, tone.to), greaterThanOrEqualTo(4.5), reason: '${tone.id} end');
      }
    });

    test('Every received colour keeps its own text readable at both ends (4.5:1)', () {
      for (final tone in ChatPalette.received) {
        expect(contrast(tone.text, tone.from), greaterThanOrEqualTo(4.5), reason: '${tone.id} start');
        expect(contrast(tone.text, tone.to), greaterThanOrEqualTo(4.5), reason: '${tone.id} end');
      }
    });

    test('Every ready-made theme points at colours that exist', () {
      for (final preset in ChatPalette.presets) {
        expect(ChatPalette.sentById(preset.sent).id, preset.sent);
        expect(ChatPalette.receivedById(preset.received).id, preset.received);
        expect(ChatPalette.backdropById(preset.backdrop).id, preset.backdrop);
      }
    });
  });

  group('Saving', () {
    test('A choice survives a restart and belongs to its own account', () async {
      final first = ChatThemeController();
      await first.ensureLoaded('7');
      await first.update(const ChatTheme(sentId: 'green', receivedId: 'mint', backdropId: 'mint'));

      final again = ChatThemeController();
      await again.ensureLoaded('7');
      expect(again.theme.sentId, 'green');
      expect(again.theme.receivedId, 'mint');
      expect(again.theme.backdropId, 'mint');

      final other = ChatThemeController();
      await other.ensureLoaded('8');
      expect(other.theme, ChatTheme.defaults, reason: 'another account starts with the default');
    });

    test('Resetting forgets the stored choice', () async {
      final controller = ChatThemeController();
      await controller.ensureLoaded('7');
      await controller.update(const ChatTheme(sentId: 'rose'));
      await controller.reset();
      final again = ChatThemeController();
      await again.ensureLoaded('7');
      expect(again.theme, ChatTheme.defaults);
    });

    test('An unknown stored value falls back to the default colour', () async {
      SharedPreferences.setMockInitialValues({'chat_theme.7': 'nope|nope|nope'});
      final controller = ChatThemeController();
      await controller.ensureLoaded('7');
      expect(controller.theme, ChatTheme.defaults);
    });
  });

  group('Picker', () {
    testWidgets('A swatch changes the live preview and "Varsayılana dön" brings the default back', (tester) async {
      screen(tester, 390, 900);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host(store, Scaffold(body: ChatThemeSheet(controller: store.chatTheme))));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat-theme-preview')), findsOneWidget);
      expect(store.chatTheme.theme, ChatTheme.defaults);

      await tester.tap(find.byKey(const Key('chat-sent-green')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-received-white')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('chat-backdrop-cream')));
      await tester.tap(find.byKey(const Key('chat-backdrop-cream')));
      await tester.pumpAndSettle();
      expect(store.chatTheme.theme.sentId, 'green');
      expect(store.chatTheme.theme.receivedId, 'white');
      expect(store.chatTheme.theme.backdropId, 'cream');

      final preview = tester.widget<DecoratedBox>(find.byKey(const Key('chat-theme-preview')));
      expect((preview.decoration as BoxDecoration).gradient, ChatPalette.backdropById('cream').gradient);

      await tester.ensureVisible(find.byKey(const Key('chat-theme-reset')));
      await tester.tap(find.byKey(const Key('chat-theme-reset')));
      await tester.pumpAndSettle();
      expect(store.chatTheme.theme, ChatTheme.defaults);
    });

    testWidgets('A ready-made theme sets all three colours at once', (tester) async {
      screen(tester, 390, 900);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host(store, Scaffold(body: ChatThemeSheet(controller: store.chatTheme))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-preset-sunset')));
      await tester.pumpAndSettle();
      expect(store.chatTheme.theme, const ChatTheme(sentId: 'rose', receivedId: 'cream', backdropId: 'cream'));
    });

    testWidgets('Colour choices are 44 dp touch targets and the sheet fits 320 dp at 1.5x text', (tester) async {
      screen(tester, 320, 900);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host(store, Scaffold(body: ChatThemeSheet(controller: store.chatTheme)), scale: 1.5));
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byKey(const Key('chat-sent-lilac')));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    });
  });

  group('Conversation', () {
    testWidgets('Sent bubbles are lilac, received ones are the button blue, on the soft backdrop', (tester) async {
      await openChat(tester, messages: [
        chatMessage(2, 'text', body: 'Yazdım', mine: true),
        chatMessage(1, 'text', body: 'Geldi'),
      ]);
      expect(find.byType(ChatBubbleSurface), findsNWidgets(2));
      // Newest first in the reversed list: the sent message is the first bubble.
      expect(bubbleDecoration(tester, 0).gradient, ChatPalette.sentById('lilac').gradient);
      expect(bubbleDecoration(tester, 1).gradient, ChatPalette.receivedById('blue').gradient);
      expect(find.byKey(const Key('chat-backdrop')), findsOneWidget);
      final received = tester.widget<Text>(find.text('Geldi'));
      expect(received.style!.color, Colors.white);
    });

    testWidgets('A new theme from the menu recolours the open conversation at once', (tester) async {
      final store = await openChat(tester, messages: [chatMessage(1, 'text', body: 'Geldi')]);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-theme-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-received-white')));
      await tester.pumpAndSettle();
      expect(store.chatTheme.theme.receivedId, 'white');
      await realWait(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(bubbleDecoration(tester, 0).gradient, ChatPalette.receivedById('white').gradient);
      final text = tester.widget<Text>(find.text('Geldi'));
      expect(text.style!.color, AppColors.navy);
    });
  });
}
