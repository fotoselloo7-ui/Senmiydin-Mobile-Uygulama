import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';

/// Longest edge of an uploaded photo. Larger photos are scaled down; nobody is ever told "too big".
const int kUploadEdge = 2048;

/// A photo is brought under this size before it is uploaded: it is far inside every server and mobile-network limit and
/// still looks sharp at 2048 px.
const int kUploadTargetBytes = 1536 * 1024;

/// Prepares any photo the person picked for upload: upright, at most [kUploadEdge] px on the long edge, flattened on white
/// when it has transparency, and a JPEG of at most about [kUploadTargetBytes]. There is no size or format limit for the
/// person: a 20 MB camera photo or a PNG screenshot just becomes a lighter JPEG. A photo this device cannot decode is
/// returned unchanged (the server still validates it).
Future<XFile> optimizeUploadPhoto(XFile file) async {
  try {
    final bytes = await file.readAsBytes();
    final optimized = await compute(optimizePhotoBytes, bytes);
    if (optimized == null) return file;
    // A real file (not an in-memory XFile) so the multipart part keeps a file name the server recognises as an upload.
    final dir = await _scratchDirectory();
    final out = File(
      '${dir.path}/upload_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(optimized, flush: true);
    return XFile(out.path, name: 'photo.jpg', mimeType: 'image/jpeg');
  } catch (_) {
    return file;
  }
}

/// The pure part of [optimizeUploadPhoto]. Returns `null` when the photo is already fine as it is (a JPEG / WebP within
/// the edge and the size target, upright) or cannot be decoded, so a well-sized photo is never re-compressed.
Uint8List? optimizePhotoBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final orientation = decoded.exif.imageIfd.hasOrientation
      ? decoded.exif.imageIfd.orientation
      : 1;
  final format = img.findFormatForData(bytes);
  final alreadyFine =
      bytes.length <= kUploadTargetBytes &&
      math.max(decoded.width, decoded.height) <= kUploadEdge &&
      orientation == 1 &&
      (format == img.ImageFormat.jpg || format == img.ImageFormat.webp);
  if (alreadyFine) return null;

  var image = img.bakeOrientation(decoded);
  final longest = math.max(image.width, image.height);
  if (longest > kUploadEdge) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? kUploadEdge : null,
      height: image.height > image.width ? kUploadEdge : null,
      interpolation: img.Interpolation.average,
    );
  }
  if (image.hasAlpha) {
    final flat = img.Image(width: image.width, height: image.height);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, image);
    image = flat;
  }

  var quality = 86;
  var jpeg = img.encodeJpg(image, quality: quality);
  while (jpeg.length > kUploadTargetBytes && quality > 62) {
    quality -= 8;
    jpeg = img.encodeJpg(image, quality: quality);
  }
  while (jpeg.length > kUploadTargetBytes && image.width > 640) {
    image = img.copyResize(
      image,
      width: (image.width * .8).round(),
      interpolation: img.Interpolation.average,
    );
    jpeg = img.encodeJpg(image, quality: 72);
  }
  return jpeg;
}

Future<Directory> _scratchDirectory() async {
  try {
    return await getTemporaryDirectory();
  } catch (_) {
    return Directory.systemTemp;
  }
}
