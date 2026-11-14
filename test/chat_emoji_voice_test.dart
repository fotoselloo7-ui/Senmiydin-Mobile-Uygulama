import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/voice_service.dart';
import 'package:senmiydin/screens/direct_chat.dart';
import 'package:senmiydin/widgets/emoji_panel.dart';

import 'global_release_test.dart' show ok;
import 'support/chat_harness.dart';
import 'support/fake_voice.dart';

void main() {
  setUpAll(loadAppFont);

  Finder tabs() => find.descendant(
    of: find.byType(EmojiPicker),
    matching: find.byType(Tab),
  );

  // ------------------------------------------------------------------------------- emoji
  group('Emoji panel', () {
    testWidgets('The icon opens a panel with categories and search; the icon closes it again', (tester) async {
      await openChat(tester);
      expect(find.byKey(const Key('emoji-panel')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-emoji')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsOneWidget);
      expect(find.byType(EmojiPicker), findsOneWidget);
      expect(tabs().evaluate().length, greaterThanOrEqualTo(8), reason: 'Recents + the emoji categories (incl. flags).');
      expect(find.byIcon(Icons.search), findsWidgets, reason: 'Search lives in the bottom action bar.');
      await tester.tap(find.byKey(const Key('chat-emoji')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsNothing);
    });

    testWidgets('Picking emoji inserts at the cursor, backspace removes a whole emoji and the send button appears', (tester) async {
      await openChat(tester);
      await tester.enterText(find.byKey(const Key('chat-input')), 'ab');
      final field = tester.widget<TextField>(find.byKey(const Key('chat-input')));
      field.controller!.selection = const TextSelection.collapsed(offset: 1);
      await tester.tap(find.byKey(const Key('chat-emoji')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😀'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😃'));
      await tester.pumpAndSettle();
      expect(field.controller!.text, 'a😀😃b');
      expect(find.byTooltip('Mesajı gönder'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.backspace));
      await tester.pumpAndSettle();
      expect(field.controller!.text, 'a😀b');
    });

    testWidgets('A picked emoji shows up in the Recents tab and changing category keeps the panel open', (tester) async {
      await openChat(tester);
      await tester.tap(find.byKey(const Key('chat-emoji')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😂'));
      await tester.pumpAndSettle();
      await tester.tap(tabs().first);
      await tester.pumpAndSettle();
      expect(find.text('😂'), findsWidgets);
      await tester.tap(tabs().at(3));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsOneWidget);
    });

    testWidgets('A tap on the conversation closes the panel and it can be reopened', (tester) async {
      await openChat(tester, messages: [chatMessage(5, 'text', body: 'Selam')]);
      await tester.tap(find.byKey(const Key('chat-emoji')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsOneWidget);
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-emoji')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsOneWidget);
    });

    testWidgets('Android back closes the panel first; the chat stays', (tester) async {
      await openChat(tester);
      await tester.tap(find.byKey(const Key('chat-emoji')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsNothing);
      expect(find.byType(DirectChatPage), findsOneWidget);
    });

    testWidgets('Focusing the input (keyboard) and opening the attachment menu close the panel', (tester) async {
      await openChat(tester);
      await tester.tap(find.byKey(const Key('chat-emoji')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-input')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-emoji')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-attach')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsNothing);
      expect(find.byKey(const ValueKey('attach-gift')), findsOneWidget);
    });

    testWidgets('Leaving the chat with the panel open leaves nothing behind', (tester) async {
      await openChat(tester);
      await tester.tap(find.byKey(const Key('chat-emoji')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-panel')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('The panel fits ${width.toInt()} px wide screens and 1.5x text without overflow', (tester) async {
        await openChat(tester, width: width, scale: 1.5);
        await tester.tap(find.byKey(const Key('chat-emoji')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final panel = tester.getRect(find.byKey(const Key('emoji-panel')));
        expect(panel.width, width);
        expect(panel.height, lessThanOrEqualTo(300));
        expect(tester.getRect(find.byKey(const Key('chat-input'))).right, lessThanOrEqualTo(width));
        expect(tester.getSize(find.byKey(const Key('chat-emoji'))).shortestSide, greaterThanOrEqualTo(40), reason: 'Touch target.');
      });
    }

    test('deleteBeforeCursor removes a whole skin-tone emoji at once and is safe on empty text', () {
      final controller = TextEditingController(text: 'a👍🏽');
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      deleteBeforeCursor(controller);
      expect(controller.text, 'a');
      deleteBeforeCursor(controller);
      expect(controller.text, '');
      deleteBeforeCursor(controller);
      expect(controller.text, '');
    });
  });

  // ------------------------------------------------------------------------------- voice
  group('Voice messages', () {
    Future<FakeVoice> voice(
      WidgetTester tester, {
      bool granted = true,
      bool failToStart = false,
      List<http.Request>? sent,
      Future<http.Response> Function(http.Request)? onSend,
      List<Map<String, dynamic>>? messages,
    }) async {
      final fake = FakeVoice(granted: granted, failToStart: failToStart);
      await openChat(tester, sent: sent, onSend: onSend, messages: messages);
      return fake;
    }

    Future<void> record(WidgetTester tester, FakeVoice fake, Duration length) async {
      await tester.tap(find.byKey(const Key('chat-mic')));
      await tester.pumpAndSettle();
      if (find.byKey(const Key('mic-explain-continue')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('mic-explain-continue')));
        await tester.pump();
      }
      await realWait(tester, 60);
      fake.advance(length);
      await tester.pump(const Duration(milliseconds: 250));
    }

    testWidgets('The first use explains, asks nothing before consent and then records', (tester) async {
      final fake = await voice(tester);
      expect(find.byKey(const Key('chat-mic')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-mic')));
      await tester.pumpAndSettle();
      expect(find.text('Mikrofon izni'), findsOneWidget);
      expect(find.textContaining('reklam veya başka bir amaçla kullanılmaz'), findsOneWidget);
      expect(fake.recorder.permissionRequests, 0);
      await tester.tap(find.byKey(const Key('mic-explain-continue')));
      await tester.pump();
      await realWait(tester, 60);
      expect(fake.recorder.permissionRequests, 1);
      expect(fake.recorder.starts, 1);
      expect(find.byKey(const Key('voice-stop')), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice-cancel')));
      await realWait(tester, 90);
    });

    testWidgets('A refusal is remembered: no permission loop and no second dialog', (tester) async {
      final fake = await voice(tester, granted: false);
      await tester.tap(find.byKey(const Key('chat-mic')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mic-explain-continue')));
      await tester.pump();
      await realWait(tester, 60);
      expect(fake.recorder.permissionRequests, 1);
      expect(fake.recorder.starts, 0);
      expect(find.textContaining('Mikrofon izni verilmedi'), findsOneWidget);
      for (var i = 0; i < 12 && find.byType(SnackBar).evaluate().isNotEmpty; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.byKey(const Key('chat-mic')));
      await tester.pump();
      expect(find.text('Mikrofon izni'), findsNothing);
      expect(fake.recorder.permissionRequests, 1);
      expect(find.textContaining('Mikrofon izni kapalı'), findsOneWidget);
    });

    testWidgets('Cancelling the explanation starts nothing', (tester) async {
      final fake = await voice(tester);
      await tester.tap(find.byKey(const Key('chat-mic')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mic-explain-cancel')));
      await tester.pumpAndSettle();
      expect(fake.recorder.permissionRequests, 0);
      expect(find.byKey(const Key('voice-stop')), findsNothing);
    });

    testWidgets('A recorder that cannot start says so and leaves the composer usable', (tester) async {
      await voice(tester, failToStart: true);
      await tester.tap(find.byKey(const Key('chat-mic')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mic-explain-continue')));
      await tester.pump();
      await realWait(tester, 60);
      expect(find.textContaining('Kayıt başlatılamadı'), findsOneWidget);
      expect(find.byKey(const Key('chat-input')), findsOneWidget);
    });

    testWidgets('Recording counts 00:12, stops into a preview, plays it and can be cancelled (file deleted)', (tester) async {
      final fake = await voice(tester);
      await record(tester, fake, const Duration(seconds: 12));
      expect(find.text('00:12'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice-stop')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice-preview-play')), findsOneWidget);
      expect(find.byKey(const Key('voice-send')), findsOneWidget);
      expect(find.text('00:12'), findsOneWidget);
      final path = fake.recorder.path!;
      expect(File(path).existsSync(), isTrue);
      await tester.tap(find.byKey(const Key('voice-preview-play')));
      await tester.pumpAndSettle();
      expect(fake.player.played, [path]);
      await tester.tap(find.byKey(const Key('voice-cancel')));
      await realWait(tester, 90);
      expect(File(path).existsSync(), isFalse);
      expect(find.byKey(const Key('chat-mic')), findsOneWidget);
    });

    testWidgets('A recording shorter than one second is thrown away and never sent', (tester) async {
      final sent = <http.Request>[];
      final fake = await voice(tester, sent: sent);
      await record(tester, fake, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('voice-stop')));
      await realWait(tester, 150);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('voice-send')), findsNothing);
      expect(find.textContaining('Kayıt çok kısaydı'), findsOneWidget);
      expect(File(fake.recorder.path!).existsSync(), isFalse);
      expect(sent, isEmpty);
    });

    testWidgets('The two-minute limit stops the recording by itself at 02:00', (tester) async {
      final fake = await voice(tester);
      await record(tester, fake, const Duration(minutes: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice-send')), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice-cancel')));
      await realWait(tester, 90);
    });

    testWidgets('Sending uploads the audio once, shows a voice bubble and removes the draft file', (tester) async {
      final sent = <http.Request>[];
      final fake = await voice(
        tester,
        sent: sent,
        onSend: (request) async => ok(sendResult(chatMessage(99, 'voice', mine: true, durationMs: 12000)), 201),
      );
      await record(tester, fake, const Duration(seconds: 12));
      await tester.tap(find.byKey(const Key('voice-stop')));
      await tester.pumpAndSettle();
      final path = fake.recorder.path!;
      await tester.tap(find.byKey(const Key('voice-send')));
      await realWaitFor(tester, find.byKey(const Key('voice-play-99')));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(sent.single.headers['content-type'], startsWith('multipart/form-data'));
      final body = bodyText(sent.single);
      expect(body, contains('name="audio"'));
      expect(body, contains('voice'));
      expect(find.byKey(const Key('voice-play-99')), findsOneWidget);
      expect(find.byKey(const Key('voice-duration-99')), findsOneWidget);
      expect(File(path).existsSync(), isFalse);
      expect(find.byKey(const Key('chat-mic')), findsOneWidget);
    });

    testWidgets('A failed send keeps the recording so the same request can be retried', (tester) async {
      var attempts = 0;
      final fake = await voice(
        tester,
        onSend: (request) async {
          attempts++;
          if (attempts == 1) {
            return http.Response('{"success":false,"message":"Ses kaydı çok büyük."}', 413, headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return ok(sendResult(chatMessage(99, 'voice', mine: true, durationMs: 5000)), 201);
        },
      );
      await record(tester, fake, const Duration(seconds: 5));
      await tester.tap(find.byKey(const Key('voice-stop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voice-send')));
      await realWait(tester, 300);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice-send')), findsOneWidget, reason: 'The preview is still there after a failure.');
      expect(File(fake.recorder.path!).existsSync(), isTrue);
      await tester.tap(find.byKey(const Key('voice-send')));
      await realWaitFor(tester, find.byKey(const Key('voice-play-99')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byKey(const Key('voice-play-99')), findsOneWidget);
    });

    testWidgets('Android back drops a running recording before the chat is left', (tester) async {
      final fake = await voice(tester);
      await record(tester, fake, const Duration(seconds: 3));
      expect(find.byKey(const Key('voice-stop')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await realWait(tester, 90);
      expect(find.byKey(const Key('voice-stop')), findsNothing);
      expect(fake.recorder.cancels, 1);
      expect(find.byType(DirectChatPage), findsOneWidget);
    });

    testWidgets('A voice bubble downloads once, plays, pauses, resumes and shows the length', (tester) async {
      final fake = await voice(tester, messages: [chatMessage(7, 'voice', durationMs: 12000)]);
      expect(find.byKey(const Key('voice-play-7')), findsOneWidget);
      expect(find.text('00:12'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice-play-7')));
      await realWait(tester, 90);
      expect(fake.downloads, [ApiClient.mediaUrl('/api/message-audio/7')]);
      expect(fake.player.played, hasLength(1));
      expect(find.byIcon(Icons.pause_circle_filled_rounded), findsOneWidget);
      fake.player.emitPosition(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('00:04'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice-play-7')));
      await tester.pump();
      expect(fake.player.pauses, 1);
      await tester.tap(find.byKey(const Key('voice-play-7')));
      await tester.pump();
      expect(fake.player.resumes, 1);
      expect(fake.downloads, hasLength(1));
      fake.player.finish();
      await tester.pump();
      expect(find.text('00:12'), findsOneWidget);
    });

    testWidgets('Only one voice message plays at a time', (tester) async {
      final fake = await voice(tester, messages: [chatMessage(7, 'voice', durationMs: 12000), chatMessage(8, 'voice', durationMs: 5000, mine: true)]);
      await tester.tap(find.byKey(const Key('voice-play-7')));
      await realWait(tester, 90);
      await tester.tap(find.byKey(const Key('voice-play-8')));
      await realWait(tester, 90);
      expect(fake.player.stops, greaterThanOrEqualTo(1), reason: 'Starting the second stops the first.');
      expect(fake.player.played, hasLength(2));
      expect(find.byIcon(Icons.pause_circle_filled_rounded), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('voice-play-8')), matching: find.byIcon(Icons.pause_circle_filled_rounded)), findsOneWidget);
    });

    testWidgets('A failed download shows a retry state and the next tap tries again', (tester) async {
      final fake = await voice(tester, messages: [chatMessage(7, 'voice', durationMs: 9000)]);
      var fail = true;
      final good = VoiceServices.download;
      VoiceServices.download = (url, headers) async {
        if (fail) throw const FileSystemException('offline');
        return good(url, headers);
      };
      await tester.tap(find.byKey(const Key('voice-play-7')));
      await realWait(tester, 90);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const Key('voice-play-7')));
      await realWait(tester, 90);
      expect(fake.player.played, hasLength(1));
      expect(find.byIcon(Icons.pause_circle_filled_rounded), findsOneWidget);
    });

    testWidgets('Leaving the conversation stops playback and releases both devices', (tester) async {
      final fake = await voice(tester, messages: [chatMessage(7, 'voice', durationMs: 9000)]);
      await tester.tap(find.byKey(const Key('voice-play-7')));
      await realWait(tester, 90);
      await tester.pumpWidget(const SizedBox());
      await realWait(tester, 90);
      expect(fake.player.disposed, isTrue);
      expect(fake.recorder.disposed, isTrue);
      expect(fake.player.stops, greaterThanOrEqualTo(1));
    });

    test('voiceClock formats mm:ss and the shared limits are two minutes / one second', () {
      expect(voiceClock(Duration.zero), '00:00');
      expect(voiceClock(const Duration(seconds: 12)), '00:12');
      expect(voiceClock(const Duration(minutes: 2)), '02:00');
      expect(voiceClock(const Duration(seconds: 75)), '01:15');
      expect(VoiceLimits.maxDuration, const Duration(minutes: 2));
      expect(VoiceLimits.minDuration, const Duration(seconds: 1));
    });
  });
}
