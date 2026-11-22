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
enum ChatAttachment { photo, camera, location, gift }

/// How a location is chosen for a location message.
enum ChatLocationSource { current, map }

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
              (ChatAttachment.gift, Icons.card_giftcard_rounded, tr('Hediye')),
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

/// The compact bottom bar: [ + ][ emoji ] [ slim input ] ( send | mic ).
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
    this.onMic,
    this.focusNode,
    this.emojiOpen = false,
  });
  final TextEditingController controller;
  final bool busy, canSend;
  final VoidCallback onAttach, onEmoji, onSend;
  final VoidCallback onChanged;

  /// Starts a voice message; shown in place of "send" while there is nothing to send.
  final VoidCallback? onMic;
  final FocusNode? focusNode;
  final bool emojiOpen;

  @override
  Widget build(BuildContext context) {
    final text = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // The two tools sit close together so the input gets the room.
        _ComposerTool(
          key: const Key('chat-attach'),
          tooltip: text.chatAttach,
          icon: Icons.add_circle_outline_rounded,
          alignment: Alignment.centerRight,
          onPressed: busy ? null : onAttach,
        ),
        _ComposerTool(
          key: const Key('chat-emoji'),
          tooltip: text.chatEmoji,
          icon: emojiOpen
              ? Icons.keyboard_rounded
              : Icons.emoji_emotions_outlined,
          alignment: Alignment.centerLeft,
          onPressed: busy ? null : onEmoji,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            key: const Key('chat-input'),
            controller: controller,
            focusNode: focusNode,
            enabled: !busy,
            minLines: 1,
            maxLines: 5,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 15, height: 1.3),
            onChanged: (_) => onChanged(),
            decoration: composerInputDecoration(text.chatWriteHint),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        if (!canSend && !busy && onMic != null)
          IconButton.filled(
            key: const Key('chat-mic'),
            tooltip: tr('Sesli mesaj kaydet'),
            style: AppButtons.filledIcon,
            onPressed: onMic,
            icon: const Icon(Icons.mic_rounded),
          )
        else
          IconButton.filled(
            key: const Key('chat-send'),
            tooltip: text.chatSendTooltip,
            style: AppButtons.filledIcon,
            onPressed: busy || !canSend ? null : onSend,
            icon: busy
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
      ],
    );
  }
}

/// The slim, long pill the message is typed into: a soft fill, no border until it is focused, rounded all the way.
InputDecoration composerInputDecoration(String hint) {
  const radius = BorderRadius.all(Radius.circular(24));
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: radius,
    borderSide: color == Colors.transparent
        ? BorderSide.none
        : BorderSide(color: color, width: width),
  );
  return InputDecoration(
    hintText: hint,
    counterText: '',
    isDense: true,
    filled: true,
    // White with a hairline so the pill reads on any chat backdrop colour.
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    border: border(AppColors.border, 1),
    enabledBorder: border(AppColors.border, 1),
    disabledBorder: border(Colors.transparent, 0),
    focusedBorder: border(AppColors.primary, 1.3),
  );
}

/// One of the two small tools left of the input (attach, emoji): a 40 x 44 target whose icon sits on the side facing the
/// other tool, so the two icons are almost touching while each keeps its full touch target.
class _ComposerTool extends StatelessWidget {
  const _ComposerTool({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.alignment,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final AlignmentGeometry alignment;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    icon: Icon(icon),
    color: AppColors.blue,
    onPressed: onPressed,
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    iconSize: 24,
    style: IconButton.styleFrom(
      minimumSize: const Size(40, 44),
      fixedSize: const Size(40, 44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}
