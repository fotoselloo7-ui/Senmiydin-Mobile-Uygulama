import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart' hide Text;

import '../core/app_locale.dart';
import '../core/theme.dart';
import 'translated_text.dart';

/// Removes the character (grapheme cluster, so emoji with skin tones or joiners go in one piece) before the cursor, or
/// the selection when there is one.
void deleteBeforeCursor(TextEditingController controller) {
  final value = controller.value;
  final selection = value.selection;
  if (!selection.isValid || value.text.isEmpty) return;
  if (!selection.isCollapsed) {
    controller.value = TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, ''),
      selection: TextSelection.collapsed(offset: selection.start),
    );
    return;
  }
  if (selection.start == 0) return;
  final before = value.text.substring(0, selection.start).characters;
  final remaining = before.skipLast(1).toString();
  controller.value = TextEditingValue(
    text: remaining + value.text.substring(selection.start),
    selection: TextSelection.collapsed(offset: remaining.length),
  );
}

/// The emoji panel under the chat composer: categories, recents, search, skin tones (all from the open-source
/// `emoji_picker_flutter` package), styled with the app's own colours. It is a plain panel, not a modal sheet, so a tap on
/// the conversation, the back button or the keyboard can close it.
class EmojiPanel extends StatelessWidget {
  const EmojiPanel({
    super.key,
    required this.onEmoji,
    required this.onBackspace,
    this.height = 280,
  });

  final ValueChanged<String> onEmoji;
  final VoidCallback onBackspace;
  final double height;

  @override
  Widget build(BuildContext context) {
    // The Android compatibility probe needs the platform channel; widget tests skip it.
    final probe = !Platform.environment.containsKey('FLUTTER_TEST');
    return Material(
      key: const Key('emoji-panel'),
      color: Colors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: Semantics(
              label: context.l10n.chatEmoji,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) => onEmoji(emoji.emoji),
                onBackspacePressed: onBackspace,
                config: Config(
                  height: height,
                  checkPlatformCompatibility: probe,
                  locale: Locale(AppLocale.code),
                  emojiViewConfig: EmojiViewConfig(
                    columns: 8,
                    emojiSizeMax: 28,
                    backgroundColor: Colors.white,
                    noRecents: Text(
                      tr('Henüz son kullanılan emoji yok'),
                      style: AppTypography.metadata,
                    ),
                  ),
                  skinToneConfig: const SkinToneConfig(
                    dialogBackgroundColor: Colors.white,
                    indicatorColor: AppColors.blue,
                  ),
                  categoryViewConfig: const CategoryViewConfig(
                    tabBarHeight: 44,
                    // Opens on the faces, not on an empty "recent" list; Recents is one tap away.
                    initCategory: Category.SMILEYS,
                    backgroundColor: Colors.white,
                    indicatorColor: AppColors.blue,
                    iconColor: AppColors.muted,
                    iconColorSelected: AppColors.blue,
                    backspaceColor: AppColors.blue,
                    dividerColor: AppColors.border,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: Colors.white,
                    buttonColor: AppColors.pale,
                    buttonIconColor: AppColors.blue,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: Colors.white,
                    buttonIconColor: AppColors.blue,
                    hintText: tr('Emoji ara'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
