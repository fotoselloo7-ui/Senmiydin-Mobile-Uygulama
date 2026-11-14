import 'dart:io';

import 'package:flutter/material.dart' hide Text;

import 'translated_text.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_locale.dart';
import '../core/theme.dart';
import 'common.dart';
import 'map_attribution.dart';

/// What the "+" button offers in a chat.
enum ChatAttachment { photo, camera, location }

/// How a location is chosen for a location message.
enum ChatLocationSource { current, map }

/// Frequently used emoji; no emoji package, the system keyboard stays available for everything else.
const chatEmoji = [
  '😀',
  '😂',
  '😊',
  '😍',
  '🥰',
  '😘',
  '😉',
  '😎',
  '🤗',
  '🤔',
  '😅',
  '😢',
  '😭',
  '😮',
  '😴',
  '🙄',
  '👍',
  '👏',
  '🙌',
  '🙏',
  '💪',
  '👋',
  '🤝',
  '✌️',
  '❤️',
  '💙',
  '💜',
  '🔥',
  '✨',
  '🎉',
  '🌊',
  '☀️',
  '🌙',
  '⭐',
  '☕',
  '🍀',
  '🌸',
  '🎶',
  '📍',
  '👀',
];

/// Inserts [emoji] at the current cursor (or replaces the selection) of [controller].
void insertAtCursor(TextEditingController controller, String emoji) {
  final value = controller.value;
  final selection = value.selection;
  final start = selection.isValid ? selection.start : value.text.length;
  final end = selection.isValid ? selection.end : value.text.length;
  final text = value.text.replaceRange(start, end, emoji);
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: start + emoji.length),
  );
}

Future<ChatAttachment?> showChatAttachmentSheet(BuildContext context) {
  final text = context.l10n;
  return showModalBottomSheet<ChatAttachment>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Row(
          children: [
            for (final (kind, icon, label) in [
              (
                ChatAttachment.photo,
                Icons.image_outlined,
                text.chatAttachPhoto,
              ),
              (
                ChatAttachment.camera,
                Icons.camera_alt_outlined,
                text.chatAttachCamera,
              ),
              (
                ChatAttachment.location,
                Icons.location_on_outlined,
                text.chatAttachLocation,
              ),
            ])
              Expanded(
                child: InkWell(
                  key: ValueKey('attach-${kind.name}'),
                  borderRadius: AppShape.rounded,
                  onTap: () => Navigator.pop(sheet, kind),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIconBox(icon: icon),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: AppTypography.metadata.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> showChatEmojiSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
          child: Semantics(
            label: context.l10n.chatEmoji,
            child: GridView.count(
              key: const Key('emoji-grid'),
              shrinkWrap: true,
              crossAxisCount: 8,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (final emoji in chatEmoji)
                  InkResponse(
                    onTap: () => Navigator.pop(sheet, emoji),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

Future<ChatLocationSource?> showChatLocationSourceSheet(BuildContext context) {
  final text = context.l10n;
  return showModalBottomSheet<ChatLocationSource>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              key: const Key('location-current'),
              leading: const Icon(Icons.my_location, color: AppColors.blue),
              title: Text(text.chatSendCurrentLocation),
              onTap: () => Navigator.pop(sheet, ChatLocationSource.current),
            ),
            ListTile(
              key: const Key('location-map'),
              leading: const Icon(Icons.map_outlined, color: AppColors.blue),
              title: Text(text.chatPickOnMap),
              onTap: () => Navigator.pop(sheet, ChatLocationSource.map),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(text.chatLocationHint, style: AppTypography.metadata),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pick a point by moving the map under a fixed pin. Returns the centre; the server snaps it to its approximate grid.
class PickLocationPage extends StatefulWidget {
  const PickLocationPage({super.key, this.initial});
  final LatLng? initial;
  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  late LatLng picked = widget.initial ?? const LatLng(39, 35);

  @override
  Widget build(BuildContext context) {
    final text = context.l10n;
    return AppPage(
      title: text.chatPickOnMap,
      child: Column(
        children: [
          Padding(
            padding: Space.page,
            child: Text(text.chatLocationHint, style: AppTypography.metadata),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: picked,
                    initialZoom: widget.initial == null ? 5 : 14,
                    minZoom: 4,
                    maxZoom: 17,
                    backgroundColor: AppColors.pale,
                    onPositionChanged: (camera, _) => picked = camera.center,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tileUrl,
                      userAgentPackageName: 'com.senmiydin.app',
                      panBuffer: 0,
                    ),
                    const MapAttribution(),
                  ],
                ),
                IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 44,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: Space.page,
              child: PrimaryButton(
                text.chatAttachLocation,
                icon: Icons.send_rounded,
                onPressed: () => Navigator.pop(context, picked),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A real thumbnail of the picked photo with a remove button (shown above the input before sending).
class PendingPhoto extends StatelessWidget {
  const PendingPhoto({
    super.key,
    required this.file,
    required this.onRemove,
    required this.removeTooltip,
    required this.label,
  });
  final XFile file;
  final VoidCallback? onRemove;
  final String removeTooltip, label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(file.path),
            key: const Key('pending-photo'),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 56,
              height: 56,
              child: Icon(Icons.image_outlined),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTypography.secondaryBody)),
        IconButton(
          tooltip: removeTooltip,
          onPressed: onRemove,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

/// The compact bottom bar: [ + ] [ emoji ] [ input ] [ send ].
class ChatComposerBar extends StatelessWidget {
  const ChatComposerBar({
    super.key,
    required this.controller,
    required this.busy,
    required this.canSend,
    required this.onAttach,
    required this.onEmoji,
    required this.onSend,
    required this.onChanged,
  });
  final TextEditingController controller;
  final bool busy, canSend;
  final VoidCallback onAttach, onEmoji, onSend;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          key: const Key('chat-attach'),
          tooltip: text.chatAttach,
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: AppColors.blue,
          onPressed: busy ? null : onAttach,
        ),
        IconButton(
          key: const Key('chat-emoji'),
          tooltip: text.chatEmoji,
          icon: const Icon(Icons.emoji_emotions_outlined),
          color: AppColors.blue,
          onPressed: busy ? null : onEmoji,
        ),
        Expanded(
          child: TextField(
            key: const Key('chat-input'),
            controller: controller,
            enabled: !busy,
            minLines: 1,
            maxLines: 5,
            maxLength: 2000,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: text.chatWriteHint,
              counterText: '',
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: text.chatSendTooltip,
          onPressed: busy || !canSend ? null : onSend,
          icon: busy
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
        ),
      ],
    );
  }
}
