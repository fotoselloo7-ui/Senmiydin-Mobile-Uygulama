import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_locale.dart';
import '../core/navigation.dart';
import '../core/theme.dart';
import 'media_crop.dart';
import 'translated_text.dart';

/// What the person chose in the "Fotoğraf Ekle" sheet.
enum MemoryPhotoChoice { camera, gallery, skip }

/// The one "Fotoğraf Ekle" bottom sheet of the memory flows: take a photo, pick from the gallery and (while a new memory
/// is being started) carry on without any photo. Returns null when it is dismissed.
Future<MemoryPhotoChoice?> showMemoryPhotoSheet(
  BuildContext context, {
  bool allowSkip = false,
}) => showModalBottomSheet<MemoryPhotoChoice>(
  context: context,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xs),
            child: Text(
              'Fotoğraf Ekle',
              key: const Key('memory-photo-sheet-title'),
              style: AppTypography.section,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: Text(
              'Bir anıya en fazla 5 fotoğraf ekleyebilirsin.',
              style: AppTypography.metadata,
            ),
          ),
          ListTile(
            key: const Key('memory-photo-camera'),
            leading: const Icon(Icons.camera_alt_outlined),
            title: Text(tr('Fotoğraf Çek')),
            onTap: () => Navigator.pop(sheet, MemoryPhotoChoice.camera),
          ),
          ListTile(
            key: const Key('memory-photo-gallery'),
            leading: const Icon(Icons.image_outlined),
            title: Text(tr('Galeriden Seç')),
            onTap: () => Navigator.pop(sheet, MemoryPhotoChoice.gallery),
          ),
          if (allowSkip)
            ListTile(
              key: const Key('memory-photo-skip'),
              leading: const Icon(Icons.auto_stories_outlined),
              title: Text(tr('Fotoğrafsız Devam Et')),
              onTap: () => Navigator.pop(sheet, MemoryPhotoChoice.skip),
            ),
        ],
      ),
    ),
  ),
);

/// Picks up to [room] photos from the camera or the gallery and sends every one through the shared 9:16 / 4:5 / 16:9
/// crop step. Empty when nothing was picked or the crop was cancelled.
Future<List<XFile>> pickMemoryPhotos(
  BuildContext context,
  MemoryPhotoChoice choice, {
  required int room,
  ImagePicker? picker,
}) async {
  if (choice == MemoryPhotoChoice.skip || room <= 0) return const [];
  final source = choice == MemoryPhotoChoice.camera
      ? ImageSource.camera
      : ImageSource.gallery;
  final images = picker ?? ImagePicker();
  try {
    final List<XFile> picked;
    if (source == ImageSource.camera || room == 1) {
      final one = await images.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
      picked = one == null ? [] : [one];
    } else {
      picked = await images.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
        limit: room,
      );
    }
    if (picked.isEmpty || !context.mounted) return const [];
    return await cropPhotos(context, picked.take(room).toList());
  } on PlatformException {
    if (context.mounted) toast(context, 'Fotoğraf seçilemedi. Tekrar dene.');
    return const [];
  }
}
