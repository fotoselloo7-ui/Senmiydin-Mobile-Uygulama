import 'package:flutter/material.dart' hide Text;

import '../core/chat_theme.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'translated_text.dart';

/// One message bubble: the sent / received colours, the rounded shape with a small tail corner and a
/// soft shadow. The conversation and the theme preview draw through this, so they never drift apart.
class ChatBubbleSurface extends StatelessWidget {
  const ChatBubbleSurface({
    super.key,
    required this.mine,
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 10, 14, 8),
  });
  final bool mine;
  final ChatTheme theme;
  final Widget child;
  final EdgeInsetsGeometry padding;

  static const _round = Radius.circular(20);
  static const _tail = Radius.circular(6);

  @override
  Widget build(BuildContext context) {
    final sent = theme.sent;
    final received = theme.received;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: mine ? sent.gradient : received.gradient,
        borderRadius: BorderRadius.only(
          topLeft: _round,
          topRight: _round,
          bottomLeft: mine ? _round : _tail,
          bottomRight: mine ? _tail : _round,
        ),
        border: !mine && received.border != null
            ? Border.all(color: received.border!)
            : null,
        boxShadow: [
          BoxShadow(
            color: (mine ? sent.from : received.border ?? received.from)
                .withValues(alpha: mine ? .26 : .22),
            blurRadius: mine ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The small rounded date label between two days of messages.
class ChatDayPill extends StatelessWidget {
  const ChatDayPill(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border.withValues(alpha: .8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: .4,
          ),
        ),
      ),
    ),
  );
}

/// The full-screen backdrop of a conversation.
class ChatBackdropView extends StatelessWidget {
  const ChatBackdropView({super.key, required this.theme, required this.child});
  final ChatTheme theme;
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('chat-backdrop'),
    decoration: BoxDecoration(gradient: theme.backdrop.gradient),
    child: child,
  );
}

/// Opens the chat theme picker (colours of both sides and the background) with a live preview.
Future<void> showChatThemeSheet(BuildContext context) {
  final store = StoreScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => ChatThemeSheet(controller: store.chatTheme),
  );
}

class ChatThemeSheet extends StatelessWidget {
  const ChatThemeSheet({super.key, required this.controller});
  final ChatThemeController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final theme = controller.theme;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sohbet Teması',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Seçimin yalnızca senin ekranında görünür.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _Preview(theme: theme),
            const SizedBox(height: 20),
            const _Label('Hazır temalar'),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: ChatPalette.presets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final preset = ChatPalette.presets[index];
                  final selected =
                      preset.sent == theme.sentId &&
                      preset.received == theme.receivedId &&
                      preset.backdrop == theme.backdropId;
                  return _PresetCard(
                    preset: preset,
                    selected: selected,
                    onTap: () => controller.update(
                      ChatTheme(
                        sentId: preset.sent,
                        receivedId: preset.received,
                        backdropId: preset.backdrop,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Gönderdiğim mesajlar'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tone in ChatPalette.sent)
                  _Swatch(
                    key: Key('chat-sent-${tone.id}'),
                    label: tone.label,
                    selected: tone.id == theme.sentId,
                    decoration: BoxDecoration(
                      gradient: tone.gradient,
                      shape: BoxShape.circle,
                    ),
                    checkColor: Colors.white,
                    onTap: () =>
                        controller.update(theme.copyWith(sentId: tone.id)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Gelen mesajlar'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tone in ChatPalette.received)
                  _Swatch(
                    key: Key('chat-received-${tone.id}'),
                    label: tone.label,
                    selected: tone.id == theme.receivedId,
                    decoration: BoxDecoration(
                      gradient: tone.gradient,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tone.border ?? Colors.transparent,
                      ),
                    ),
                    checkColor: tone.text,
                    onTap: () =>
                        controller.update(theme.copyWith(receivedId: tone.id)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Arka plan'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final backdrop in ChatPalette.backdrops)
                  _Swatch(
                    key: Key('chat-backdrop-${backdrop.id}'),
                    label: backdrop.label,
                    selected: backdrop.id == theme.backdropId,
                    decoration: BoxDecoration(
                      gradient: backdrop.gradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    checkColor: AppColors.navy,
                    onTap: () => controller.update(
                      theme.copyWith(backdropId: backdrop.id),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('chat-theme-reset'),
                onPressed: theme == ChatTheme.defaults
                    ? null
                    : controller.reset,
                icon: const Icon(Icons.restart_alt_rounded, size: 20),
                label: const Text('Varsayılana dön'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: .2,
      ),
    ),
  );
}

/// A tiny two-bubble conversation drawn with the picked colours.
class _Preview extends StatelessWidget {
  const _Preview({required this.theme});
  final ChatTheme theme;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: DecoratedBox(
      key: const Key('chat-theme-preview'),
      decoration: BoxDecoration(
        gradient: theme.backdrop.gradient,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ChatBubbleSurface(
                mine: false,
                theme: theme,
                child: Text(
                  'Sahilde görüşelim mi?',
                  style: TextStyle(
                    color: theme.textFor(mine: false),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ChatBubbleSurface(
                mine: true,
                theme: theme,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        'Olur, beşte oradayım.',
                        style: TextStyle(
                          color: theme.textFor(mine: true),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.done_all, size: 14, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });
  final ChatPreset preset;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme(
      sentId: preset.sent,
      receivedId: preset.received,
      backdropId: preset.backdrop,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: preset.label,
      child: InkWell(
        key: Key('chat-preset-${preset.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: 96,
          decoration: BoxDecoration(
            gradient: theme.backdrop.gradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _Mini(mine: false, theme: theme),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: _Mini(mine: true, theme: theme),
              ),
              const Spacer(),
              Text(
                preset.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.mine, required this.theme});
  final bool mine;
  final ChatTheme theme;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: mine ? theme.sent.gradient : theme.received.gradient,
      borderRadius: BorderRadius.circular(8),
      border: !mine && theme.received.border != null
          ? Border.all(color: theme.received.border!)
          : null,
    ),
    child: const SizedBox(width: 38, height: 14),
  );
}

/// A round colour choice with a 44 dp touch target.
class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.label,
    required this.selected,
    required this.decoration,
    required this.checkColor,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final BoxDecoration decoration;
  final Color checkColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Tooltip(
      message: label,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: DecoratedBox(
                decoration: decoration,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: selected
                      ? Icon(Icons.check_rounded, size: 18, color: checkColor)
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
