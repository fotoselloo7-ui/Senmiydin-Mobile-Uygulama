import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/app_locale.dart';
import '../core/theme.dart';
import 'translated_text.dart';

/// The three shapes every SenMiydin photo can be cut to (posts, memories, map notes, any later media field).
enum CropRatio {
  vertical('9:16', 'Dikey', 9 / 16),
  portrait('4:5', 'Portre', 4 / 5),
  landscape('16:9', 'Yatay', 16 / 9);

  const CropRatio(this.label, this.name, this.value);

  /// "9:16".
  final String label;

  /// "Dikey" (Turkish source string, translated when shown).
  final String name;

  /// width / height.
  final double value;

  /// The ratio nearest to a photo of this size, so confirming right away cuts as little as possible.
  static CropRatio closest(double width, double height) {
    final shape = width / height;
    var best = CropRatio.portrait;
    var distance = double.infinity;
    for (final ratio in values) {
      final gap = (math.log(shape) - math.log(ratio.value)).abs();
      if (gap < distance) {
        distance = gap;
        best = ratio;
      }
    }
    return best;
  }
}

/// Longest edge of a cropped photo that is uploaded (the server accepts up to 2048 px and 5 MB).
const int kCropOutputEdge = 1440;

/// The pure maths of the crop frame: a fixed frame (the chosen ratio) looks at an image through a zoom ([scale] = frame
/// pixels per image pixel) and a [center] (the image point in the middle of the frame). Kept free of widgets so it is
/// testable on its own.
class CropGeometry {
  const CropGeometry({
    required this.imageWidth,
    required this.imageHeight,
    required this.frame,
  });

  final double imageWidth, imageHeight;
  final Size frame;

  /// Smallest zoom that still covers the frame (no empty edge) and the largest one allowed.
  double get minScale =>
      math.max(frame.width / imageWidth, frame.height / imageHeight);
  double get maxScale => minScale * 6;

  double clampScale(double scale) => scale.clamp(minScale, maxScale);

  /// Keeps the frame fully inside the image.
  Offset clampCenter(double scale, Offset center) {
    final halfWidth = frame.width / scale / 2;
    final halfHeight = frame.height / scale / 2;
    return Offset(
      center.dx.clamp(halfWidth, math.max(halfWidth, imageWidth - halfWidth)),
      center.dy.clamp(
        halfHeight,
        math.max(halfHeight, imageHeight - halfHeight),
      ),
    );
  }

  Offset get initialCenter => Offset(imageWidth / 2, imageHeight / 2);

  /// The part of the image the frame shows.
  Rect source(double scale, Offset center) => Rect.fromCenter(
    center: center,
    width: frame.width / scale,
    height: frame.height / scale,
  );

  /// Output size of a crop of [ratio]: [kCropOutputEdge] on the long edge, never larger than the source itself.
  static Size outputSize(CropRatio ratio, Rect source) {
    final baseWidth = ratio.value < 1
        ? kCropOutputEdge * ratio.value
        : kCropOutputEdge.toDouble();
    final baseHeight = ratio.value < 1
        ? kCropOutputEdge.toDouble()
        : kCropOutputEdge / ratio.value;
    final shrink = math.min(1.0, source.width / baseWidth);
    return Size(
      math.max(1, (baseWidth * shrink).roundToDouble()),
      math.max(1, (baseHeight * shrink).roundToDouble()),
    );
  }
}

/// Cuts [source] out of [image] and encodes it. PNG is the only encoder `dart:ui` has; the server re-encodes every
/// upload to a metadata-free JPEG anyway. The output is scaled down until it fits well inside the 5 MB upload limit.
Future<Uint8List> renderCrop(
  ui.Image image,
  Rect source,
  Size output,
) async {
  var size = output;
  for (var attempt = 0; attempt < 4; attempt++) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white, // a photo has no transparency
    );
    canvas.drawImageRect(
      image,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    picture.dispose();
    final bytes = data!.buffer.asUint8List();
    if (bytes.length <= 4 * 1024 * 1024) return bytes;
    size = Size(
      math.max(1, (size.width * .75).roundToDouble()),
      math.max(1, (size.height * .75).roundToDouble()),
    );
  }
  throw StateError('crop too large');
}

Future<Directory> _scratchDirectory() async {
  try {
    return await getTemporaryDirectory();
  } catch (_) {
    return Directory.systemTemp;
  }
}

/// Opens the shared crop screen for [file]: three ratios (9:16, 4:5, 16:9), a live preview you can move and zoom.
///
/// Returns the cropped photo, or `null` when the person cancels. A photo the device cannot decode is returned as it is,
/// so the crop step can never stop an upload that would otherwise work (the server still validates and re-encodes it).
Future<XFile?> cropPhoto(
  BuildContext context,
  XFile file, {
  CropRatio? initial,
  int position = 1,
  int total = 1,
}) => Navigator.of(context, rootNavigator: true).push<XFile>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => MediaCropPage(
      file: file,
      initial: initial,
      position: position,
      total: total,
    ),
  ),
);

/// [cropPhoto] for several photos in a row ("Fotoğraf 2/3"); a cancelled one is left out.
Future<List<XFile>> cropPhotos(
  BuildContext context,
  List<XFile> files, {
  CropRatio? initial,
}) async {
  final result = <XFile>[];
  for (final (index, file) in files.indexed) {
    if (!context.mounted) break;
    final cropped = await cropPhoto(
      context,
      file,
      initial: initial,
      position: index + 1,
      total: files.length,
    );
    if (cropped != null) result.add(cropped);
  }
  return result;
}

class MediaCropPage extends StatefulWidget {
  const MediaCropPage({
    super.key,
    required this.file,
    this.initial,
    this.position = 1,
    this.total = 1,
  });
  final XFile file;
  final CropRatio? initial;
  final int position, total;

  @override
  State<MediaCropPage> createState() => _MediaCropPageState();
}

class _MediaCropPageState extends State<MediaCropPage> {
  ui.Image? image;
  late CropRatio ratio;
  double scale = 1;
  Offset center = Offset.zero;
  bool saving = false;

  // Gesture start values.
  double _startScale = 1;
  Offset _startCenter = Offset.zero, _startFocal = Offset.zero;
  Size _frame = Size.zero;

  @override
  void initState() {
    super.initState();
    ratio = widget.initial ?? CropRatio.portrait;
    _decode();
  }

  @override
  void dispose() {
    image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        image = frame.image;
        if (widget.initial == null) {
          ratio = CropRatio.closest(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          );
        }
      });
    } catch (_) {
      // Not something this device can decode: hand the photo back untouched.
      if (mounted) Navigator.of(context).pop(widget.file);
    }
  }

  CropGeometry geometry(Size frame) => CropGeometry(
    imageWidth: image!.width.toDouble(),
    imageHeight: image!.height.toDouble(),
    frame: frame,
  );

  /// The largest frame of the chosen ratio that fits the free space.
  Size frameFor(BoxConstraints box) {
    final maxWidth = math.max(1.0, box.maxWidth - 32);
    final maxHeight = math.max(1.0, box.maxHeight - 24);
    var width = maxWidth;
    var height = width / ratio.value;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * ratio.value;
    }
    return Size(width, height);
  }

  void _fit(Size frame) {
    final g = geometry(frame);
    scale = g.clampScale(scale);
    center = g.clampCenter(scale, center == Offset.zero ? g.initialCenter : center);
  }

  void _select(CropRatio next) {
    if (next == ratio) return;
    setState(() {
      ratio = next;
      // A new shape starts from the whole photo again.
      scale = 0;
      center = Offset.zero;
    });
  }

  Future<void> _confirm() async {
    final picture = image;
    if (picture == null || saving) return;
    setState(() => saving = true);
    try {
      final g = geometry(_frame);
      final scaleNow = g.clampScale(scale <= 0 ? g.minScale : scale);
      final source = g.source(scaleNow, g.clampCenter(scaleNow, center));
      final bytes = await renderCrop(
        picture,
        source,
        CropGeometry.outputSize(ratio, source),
      );
      final directory = await _scratchDirectory();
      final file = File('${directory.path}/crop_${const Uuid().v4()}.png');
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) Navigator.of(context).pop(XFile(file.path));
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf kırpılamadı. Tekrar dene.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.total > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('crop-cancel'),
          tooltip: tr('Vazgeç'),
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          multiple
              ? trf('Fotoğraf {0} / {1}', [widget.position, widget.total])
              : 'Fotoğrafı Kırp',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: image == null
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : LayoutBuilder(
                      builder: (context, box) {
                        _frame = frameFor(box);
                        final g = geometry(_frame);
                        if (scale <= 0) scale = g.minScale;
                        _fit(_frame);
                        return Center(
                          child: GestureDetector(
                            key: const Key('crop-frame'),
                            onScaleStart: (details) {
                              _startScale = scale;
                              _startCenter = center;
                              _startFocal = details.localFocalPoint;
                            },
                            onScaleUpdate: (details) {
                              final next = g.clampScale(
                                _startScale * details.scale,
                              );
                              final half = Offset(
                                _frame.width / 2,
                                _frame.height / 2,
                              );
                              // The image point under the first touch stays under the fingers.
                              final anchor =
                                  _startCenter +
                                  (_startFocal - half) / _startScale;
                              final moved =
                                  anchor -
                                  (details.localFocalPoint - half) / next;
                              setState(() {
                                scale = next;
                                center = g.clampCenter(next, moved);
                              });
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppShape.compact,
                              ),
                              child: SizedBox(
                                width: _frame.width,
                                height: _frame.height,
                                child: CustomPaint(
                                  painter: _CropPainter(
                                    image!,
                                    g.source(scale, center),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            _Controls(
              ratio: ratio,
              onRatio: _select,
              busy: saving || image == null,
              onConfirm: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  const _CropPainter(this.image, this.source);
  final ui.Image image;
  final Rect source;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Rule-of-thirds guide.
    final guide = Paint()
      ..color = Colors.white.withValues(alpha: .35)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(size.width * i / 3, 0),
        Offset(size.width * i / 3, size.height),
        guide,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        guide,
      );
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .9),
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.source != source;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.ratio,
    required this.onRatio,
    required this.busy,
    required this.onConfirm,
  });
  final CropRatio ratio;
  final ValueChanged<CropRatio> onRatio;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppShape.large)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final (index, item) in CropRatio.values.indexed) ...[
              if (index > 0) const SizedBox(width: Space.sm),
              Expanded(
                child: _RatioTile(
                  item,
                  selected: item == ratio,
                  onTap: () => onRatio(item),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Space.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('crop-confirm'),
            onPressed: busy ? null : onConfirm,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Kullan', textAlign: TextAlign.center),
          ),
        ),
      ],
    ),
  );
}

/// "9:16" over "Dikey": two short lines that scale down together instead of wrapping.
class _RatioTile extends StatelessWidget {
  const _RatioTile(this.ratio, {required this.selected, required this.onTap});
  final CropRatio ratio;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${ratio.label} ${tr(ratio.name)}',
    excludeSemantics: true,
    child: InkWell(
      key: Key('crop-ratio-${ratio.label}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShape.small),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.action : AppColors.surface,
          borderRadius: BorderRadius.circular(AppShape.small),
          border: Border.all(
            color: selected ? AppColors.action : AppColors.line,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ratio.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.navy,
                ),
              ),
              Text(
                ratio.name,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
