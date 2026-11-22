import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:senmiydin/core/photo_optimizer.dart';

/// A noisy photo-like picture: noise keeps PNG / JPEG big, like a real camera shot.
img.Image noisy(int width, int height, {int channels = 3}) {
  final random = math.Random(7);
  final image = img.Image(width: width, height: height, numChannels: channels);
  for (final pixel in image) {
    pixel
      ..r = (pixel.x * 255 ~/ width + random.nextInt(60)).clamp(0, 255)
      ..g = (pixel.y * 255 ~/ height + random.nextInt(60)).clamp(0, 255)
      ..b = random.nextInt(255);
    if (channels == 4) pixel.a = 128;
  }
  return image;
}

void main() {
  group('Photos have no size limit for the person', () {
    test('A large PNG becomes a JPEG under the target, within 2048 px', () {
      final png = Uint8List.fromList(img.encodePng(noisy(3000, 2000)));
      expect(png.length, greaterThan(5 * 1024 * 1024), reason: 'the input is bigger than the old 5 MB limit');
      final out = optimizePhotoBytes(png)!;
      expect(out.length, lessThanOrEqualTo(kUploadTargetBytes));
      final decoded = img.decodeJpg(out)!;
      expect(math.max(decoded.width, decoded.height), lessThanOrEqualTo(kUploadEdge));
      expect(decoded.width / decoded.height, closeTo(1.5, .01), reason: 'the shape is kept');
    });

    test('A tall photo is scaled by its height', () {
      final png = Uint8List.fromList(img.encodePng(noisy(1500, 3200)));
      final decoded = img.decodeJpg(optimizePhotoBytes(png)!)!;
      expect(decoded.height, kUploadEdge);
      expect(decoded.width, lessThan(kUploadEdge));
    });

    test('A well-sized JPEG is left alone (no second compression)', () {
      final jpeg = Uint8List.fromList(img.encodeJpg(noisy(900, 600), quality: 70));
      expect(jpeg.length, lessThan(kUploadTargetBytes));
      expect(optimizePhotoBytes(jpeg), isNull);
    });

    test('A heavy JPEG within 2048 px is compressed under the target', () {
      final jpeg = Uint8List.fromList(img.encodeJpg(noisy(2000, 1600), quality: 100));
      expect(jpeg.length, greaterThan(kUploadTargetBytes));
      final out = optimizePhotoBytes(jpeg)!;
      expect(out.length, lessThanOrEqualTo(kUploadTargetBytes));
    });

    test('Transparency is flattened onto white', () {
      final png = Uint8List.fromList(img.encodePng(img.Image(width: 400, height: 300, numChannels: 4)));
      final out = img.decodeJpg(optimizePhotoBytes(png)!)!;
      final pixel = out.getPixel(200, 150);
      expect(pixel.r, greaterThan(240));
      expect(pixel.g, greaterThan(240));
      expect(pixel.b, greaterThan(240));
    });

    test('Something that is not an image is returned untouched', () async {
      expect(optimizePhotoBytes(Uint8List.fromList([1, 2, 3, 4])), isNull);
      final file = XFile.fromData(Uint8List.fromList([1, 2, 3, 4]), name: 'x.bin');
      expect(identical(await optimizeUploadPhoto(file), file), isTrue);
    });

    test('The uploaded file is a named JPEG', () async {
      final png = Uint8List.fromList(img.encodePng(noisy(2600, 1800)));
      final file = await optimizeUploadPhoto(XFile.fromData(png, name: 'shot.png', mimeType: 'image/png'));
      expect(file.name, endsWith('.jpg'), reason: 'the multipart part keeps a real file name');
      expect(file.mimeType, 'image/jpeg');
      expect(await file.length(), lessThanOrEqualTo(kUploadTargetBytes));
    });
  });
}
