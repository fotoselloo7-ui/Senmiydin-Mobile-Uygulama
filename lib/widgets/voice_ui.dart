import 'package:flutter/material.dart' hide Text;

import '../core/app_locale.dart';
import '../core/theme.dart';
import '../data/voice_service.dart';
import 'translated_text.dart';

/// Replaces the normal composer while a voice message is being recorded or previewed:
/// recording  → [ delete ] ● 00:12  [ stop ]
/// preview    → [ delete ] ▶ ━━━━ 00:12  [ send ]
/// Nothing is sent before the preview step, so a slip of the finger never sends a recording.
class VoiceDraftBar extends StatelessWidget {
  const VoiceDraftBar({
    super.key,
    required this.recorder,
    required this.playback,
    required this.onSend,
    required this.onStop,
    required this.busy,
  });

  final VoiceRecordingController recorder;
  final VoicePlayback playback;
  final VoidCallback onSend;

  /// Stops the recording (the screen explains when it was too short to keep).
  final VoidCallback onStop;
  final bool busy;

  static const draftKey = 'voice-draft';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([recorder, playback]),
      builder: (context, _) {
        final recording = recorder.recording;
        final total = recorder.elapsed;
        final state = playback.stateOf(draftKey);
        final position = playback.positionOf(draftKey);
        final progress = total.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceBlue,
            borderRadius: AppShape.largeRounded,
            border: Border.all(color: const Color(0xFFD6E4F7)),
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('voice-cancel'),
                tooltip: tr('Kaydı iptal et'),
                onPressed: busy ? null : () => recorder.discard(),
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.red,
              ),
              if (recording) ...[
                const _RecordingDot(),
                const SizedBox(width: 8),
                Text(
                  voiceClock(total),
                  key: const Key('voice-clock'),
                  style: AppTypography.secondaryBody.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('Ses kaydediliyor…'),
                    style: AppTypography.metadata,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton.filled(
                  key: const Key('voice-stop'),
                  tooltip: tr('Durdur'),
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded),
                ),
              ] else ...[
                IconButton(
                  key: const Key('voice-preview-play'),
                  tooltip: state == VoiceItemState.playing
                      ? tr('Duraklat')
                      : tr('Dinle'),
                  onPressed: recorder.path == null
                      ? null
                      : () => playback.toggle(
                          draftKey,
                          () async => recorder.path!,
                        ),
                  icon: Icon(
                    state == VoiceItemState.playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    size: 34,
                  ),
                  color: AppColors.blue,
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  voiceClock(total),
                  key: const Key('voice-clock'),
                  style: AppTypography.metadata.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  key: const Key('voice-send'),
                  tooltip: context.l10n.chatSendTooltip,
                  onPressed: busy ? null : onSend,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RecordingDot extends StatefulWidget {
  const _RecordingDot();
  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    controller.dispose();
    return super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: .35, end: 1.0).animate(controller),
    child: Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: AppColors.red,
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// The inside of a voice message bubble: play / pause, progress and the length.
class VoiceBubbleBody extends StatelessWidget {
  const VoiceBubbleBody({
    super.key,
    required this.messageId,
    required this.duration,
    required this.color,
    required this.playback,
    required this.onToggle,
  });

  final int messageId;
  final Duration duration;
  final Color color;
  final VoicePlayback playback;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final state = playback.stateOf(messageId);
        final position = playback.positionOf(messageId);
        final progress = duration.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              );
        final shown =
            state == VoiceItemState.playing || state == VoiceItemState.paused
            ? position
            : duration;
        return Semantics(
          label: tr('Sesli mesaj'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: state == VoiceItemState.loading
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: color,
                          ),
                        )
                      : IconButton(
                          key: Key('voice-play-$messageId'),
                          padding: EdgeInsets.zero,
                          tooltip: state == VoiceItemState.playing
                              ? tr('Duraklat')
                              : tr('Dinle'),
                          onPressed: onToggle,
                          icon: Icon(
                            state == VoiceItemState.playing
                                ? Icons.pause_circle_filled_rounded
                                : state == VoiceItemState.failed
                                ? Icons.error_outline_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 36,
                            color: color,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      key: Key('voice-progress-$messageId'),
                      value: progress,
                      minHeight: 5,
                      color: color,
                      backgroundColor: color.withValues(alpha: .28),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  voiceClock(shown),
                  key: Key('voice-duration-$messageId'),
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// First-use explanation before the system microphone prompt. True when the person agrees to continue.
Future<bool> showMicrophoneExplanation(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.mic_rounded, color: AppColors.blue, size: 32),
      title: Text(tr('Mikrofon izni')),
      content: Text(
        tr(
          'Sesli mesaj kaydetmek için mikrofona ihtiyaç var. Kayıt yalnız sen göndermeyi seçersen karşı tarafa iletilir; reklam veya başka bir amaçla kullanılmaz.',
        ),
      ),
      actions: [
        TextButton(
          key: const Key('mic-explain-cancel'),
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(tr('Vazgeç')),
        ),
        FilledButton(
          key: const Key('mic-explain-continue'),
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(tr('Devam Et')),
        ),
      ],
    ),
  );
  return accepted == true;
}
