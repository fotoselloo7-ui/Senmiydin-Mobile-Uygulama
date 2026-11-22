import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Colour of the messages the user sends. Always paired with white text, so every option keeps
/// at least a 4.5:1 contrast (checked in test/chat_theme_test.dart).
class ChatSentTone {
  const ChatSentTone(this.id, this.label, this.from, this.to);
  final String id, label;
  final Color from, to;
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [from, to],
  );
}

/// Colour of the messages the other person sends. `text` is the readable ink for this fill.
class ChatReceivedTone {
  const ChatReceivedTone(
    this.id,
    this.label,
    this.from,
    this.to,
    this.text, {
    this.border,
  });
  final String id, label;
  final Color from, to, text;
  final Color? border;
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [from, to],
  );
}

/// Conversation background: a soft top-to-bottom wash.
class ChatBackdrop {
  const ChatBackdrop(this.id, this.label, this.top, this.bottom);
  final String id, label;
  final Color top, bottom;
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [top, bottom],
  );
}

/// A ready-made combination, shown as a one-tap start in the picker.
class ChatPreset {
  const ChatPreset(
    this.id,
    this.label,
    this.sent,
    this.received,
    this.backdrop,
  );
  final String id, label, sent, received, backdrop;
}

abstract final class ChatPalette {
  /// The app button blue, a hair deeper so white text keeps 4.5:1 on it.
  static const _buttonBlue = Color(0xFF0672DE);

  static const sent = <ChatSentTone>[
    // The logo lilac: deep purple into the brighter lilac, still 4.5:1 under white text.
    ChatSentTone('lilac', 'Lila', AppColors.brandPurple, Color(0xFF9333EA)),
    ChatSentTone('blue', 'Mavi', AppColors.primaryHover, _buttonBlue),
    ChatSentTone('rose', 'Gül', Color(0xFFBE123C), Color(0xFFD6204F)),
    ChatSentTone('green', 'Yeşil', Color(0xFF0B6B4D), Color(0xFF0F7F5C)),
    ChatSentTone('amber', 'Kehribar', Color(0xFFA9500A), Color(0xFFB05A0C)),
    ChatSentTone('graphite', 'Grafit', Color(0xFF1B2A4A), Color(0xFF34466E)),
  ];

  static const received = <ChatReceivedTone>[
    // The blue of the app buttons.
    ChatReceivedTone(
      'blue',
      'Mavi',
      AppColors.primaryHover,
      _buttonBlue,
      Colors.white,
    ),
    ChatReceivedTone(
      'sky',
      'Gökyüzü',
      Color(0xFFEAF3FF),
      Color(0xFFDDECFF),
      AppColors.navy,
      border: Color(0xFFC9DDF6),
    ),
    ChatReceivedTone(
      'lilac-soft',
      'Lila sis',
      Color(0xFFF6EFFF),
      Color(0xFFEDE1FF),
      AppColors.navy,
      border: Color(0xFFDCC7F7),
    ),
    ChatReceivedTone(
      'white',
      'Beyaz',
      Colors.white,
      Colors.white,
      AppColors.navy,
      border: Color(0xFFE3E8F0),
    ),
    ChatReceivedTone(
      'mint',
      'Nane',
      Color(0xFFE9F8F1),
      Color(0xFFD9F1E6),
      AppColors.navy,
      border: Color(0xFFBFE5D3),
    ),
    ChatReceivedTone(
      'cream',
      'Krem',
      Color(0xFFFFF6E8),
      Color(0xFFFCEBD0),
      AppColors.navy,
      border: Color(0xFFF2DDB8),
    ),
  ];

  static const backdrops = <ChatBackdrop>[
    ChatBackdrop('mist', 'Lila sis', Color(0xFFFBF7FF), Color(0xFFF1F6FF)),
    ChatBackdrop('white', 'Beyaz', Colors.white, Colors.white),
    ChatBackdrop('sky', 'Gökyüzü', Color(0xFFF1F8FF), Color(0xFFE4F1FF)),
    ChatBackdrop('mint', 'Nane', Color(0xFFF3FBF7), Color(0xFFE5F5EC)),
    ChatBackdrop('cream', 'Krem', Color(0xFFFFFBF3), Color(0xFFFFF1DC)),
    ChatBackdrop('rose', 'Pembe sis', Color(0xFFFFF7FA), Color(0xFFFFE9F0)),
  ];

  static const presets = <ChatPreset>[
    ChatPreset('senmiydin', 'SenMiydin', 'lilac', 'blue', 'mist'),
    ChatPreset('ocean', 'Okyanus', 'blue', 'sky', 'sky'),
    ChatPreset('sunset', 'Gün batımı', 'rose', 'cream', 'cream'),
    ChatPreset('forest', 'Orman', 'green', 'mint', 'mint'),
    ChatPreset('graphite', 'Grafit', 'graphite', 'white', 'white'),
  ];

  static ChatSentTone sentById(String? id) =>
      sent.firstWhere((t) => t.id == id, orElse: () => sent.first);
  static ChatReceivedTone receivedById(String? id) =>
      received.firstWhere((t) => t.id == id, orElse: () => received.first);
  static ChatBackdrop backdropById(String? id) =>
      backdrops.firstWhere((t) => t.id == id, orElse: () => backdrops.first);
}

/// What one account picked for its conversations.
@immutable
class ChatTheme {
  const ChatTheme({
    this.sentId = 'lilac',
    this.receivedId = 'blue',
    this.backdropId = 'mist',
  });
  final String sentId, receivedId, backdropId;

  static const defaults = ChatTheme();

  ChatSentTone get sent => ChatPalette.sentById(sentId);
  ChatReceivedTone get received => ChatPalette.receivedById(receivedId);
  ChatBackdrop get backdrop => ChatPalette.backdropById(backdropId);

  /// Text colour for a bubble: white on the sent colour, the tone's own ink on received.
  Color textFor({required bool mine}) => mine ? Colors.white : received.text;

  ChatTheme copyWith({
    String? sentId,
    String? receivedId,
    String? backdropId,
  }) => ChatTheme(
    sentId: sentId ?? this.sentId,
    receivedId: receivedId ?? this.receivedId,
    backdropId: backdropId ?? this.backdropId,
  );

  @override
  bool operator ==(Object other) =>
      other is ChatTheme &&
      other.sentId == sentId &&
      other.receivedId == receivedId &&
      other.backdropId == backdropId;
  @override
  int get hashCode => Object.hash(sentId, receivedId, backdropId);
}

/// Holds the signed-in account's chat theme and keeps it on the device, one entry per account.
class ChatThemeController extends ChangeNotifier {
  ChatTheme _theme = ChatTheme.defaults;
  String? _account;
  ChatTheme get theme => _theme;

  static String _key(String account) => 'chat_theme.$account';

  /// Loads the stored theme of [account]; a different account never sees another's choice.
  Future<void> ensureLoaded(String account) async {
    if (_account == account) return;
    _account = account;
    var next = ChatTheme.defaults;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _key(account),
      );
      final parts = raw?.split('|');
      if (parts != null && parts.length == 3) {
        next = ChatTheme(
          sentId: ChatPalette.sentById(parts[0]).id,
          receivedId: ChatPalette.receivedById(parts[1]).id,
          backdropId: ChatPalette.backdropById(parts[2]).id,
        );
      }
    } catch (_) {
      // No storage (tests, web preview): keep the defaults.
    }
    if (_account != account) return;
    if (next != _theme) {
      _theme = next;
      notifyListeners();
    }
  }

  Future<void> update(ChatTheme next) async {
    if (next == _theme) return;
    _theme = next;
    notifyListeners();
    final account = _account;
    if (account == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (next == ChatTheme.defaults) {
        await prefs.remove(_key(account));
      } else {
        await prefs.setString(
          _key(account),
          '${next.sentId}|${next.receivedId}|${next.backdropId}',
        );
      }
    } catch (_) {
      // The choice still applies for this session.
    }
  }

  Future<void> reset() => update(ChatTheme.defaults);
}
