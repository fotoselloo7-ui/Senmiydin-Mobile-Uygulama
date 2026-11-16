import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;

import '../core/theme.dart';

/// 1080 × 1920 for Stories and 1080 × 1350 for every other target (both are 3x the logical sizes below).
enum ShareCardFormat {
  story(Size(360, 640)),
  portrait(Size(360, 450));

  const ShareCardFormat(this.logicalSize);
  final Size logicalSize;
  static const pixelRatio = 3.0;
  Size get pixels =>
      Size(logicalSize.width * pixelRatio, logicalSize.height * pixelRatio);
}

enum ShareCardKind { post, encounter, mapNote }

/// Everything a card shows. All of it is already public: it is built from what the app is allowed to show anybody,
/// and an anonymous item carries no name, no avatar and no handle at all.
class ShareCardData {
  const ShareCardData({
    required this.kind,
    required this.kindLabel,
    required this.body,
    required this.dateLabel,
    required this.placeLabel,
    required this.url,
    required this.cta,
    required this.continueLabel,
    required this.logo,
    this.anonymous = false,
    this.anonymousLabel = 'Anonim',
    this.authorName,
    this.handle,
    this.avatar,
    this.pairNames,
    this.pairAvatars = const [],
    this.badge,
    this.photo,
  });

  final ShareCardKind kind;
  final String kindLabel, body, dateLabel, placeLabel, url, cta, continueLabel;
  final String anonymousLabel;
  final bool anonymous;

  /// Null for anonymous items.
  final String? authorName, handle;
  final ui.Image? avatar;
  final String? pairNames;
  final List<ui.Image> pairAvatars;

  /// "Karşılaşıldı ✓" on a confirmed, published encounter story.
  final String? badge;

  /// The post's first photo (never a collage); null for text-only items.
  final ui.Image? photo;
  final ui.Image logo;
}

/// The text size for [text] in a column [width] x [height]: the biggest of a few steps that fits, so a short post reads
/// big and a long one stays readable. [truncated] means even the smallest step does not fit and the text is cut.
({double size, int maxLines, bool truncated}) fitShareText(
  String text,
  double width,
  double height,
) {
  const steps = [30.0, 26.0, 22.0, 19.0, 17.0, 15.0];
  for (final size in steps) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _body(size)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    if (painter.height <= height) {
      return (size: size, maxLines: 1000, truncated: false);
    }
  }
  const smallest = 15.0;
  final lines = math.max(2, (height / (smallest * 1.45)).floor());
  return (size: smallest, maxLines: lines, truncated: true);
}

TextStyle _body(double size) => TextStyle(
  fontFamily: 'NunitoSans',
  fontSize: size,
  height: 1.45,
  fontWeight: FontWeight.w600,
  color: AppColors.navy,
);

/// The shareable card. It is drawn off-screen into a PNG (see ShareService) and never shown as a page, so it uses
/// plain widgets only (no inherited theme, no localizations, no network images).
class ShareCardView extends StatelessWidget {
  const ShareCardView({super.key, required this.data, required this.format});

  final ShareCardData data;
  final ShareCardFormat format;

  bool get story => format == ShareCardFormat.story;

  @override
  Widget build(BuildContext context) {
    final size = format.logicalSize;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF1EAFF),
                    Color(0xFFEAF3FF),
                    Color(0xFFFFFFFF),
                  ],
                  stops: [0, .55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            right: -70,
            top: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandLilac.withValues(alpha: .12),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                26,
                story ? 60 : 24,
                26,
                story ? 52 : 20,
              ),
              child: Column(
                children: [
                  RawImage(
                    image: data.logo,
                    height: story ? 46 : 36,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  SizedBox(height: story ? 30 : 14),
                  Expanded(child: _card()),
                  SizedBox(height: story ? 28 : 14),
                  _footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    final letter = data.kind == ShareCardKind.mapNote;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, story ? 22 : 18, 22, story ? 20 : 16),
      decoration: BoxDecoration(
        color: letter ? const Color(0xFFFFFBF5) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: letter ? AppColors.borderLilac : AppColors.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPurple.withValues(alpha: .10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Header (optional chip + author) and the meta line take a fixed amount; the photo and the text share the rest.
          final header = (_showChip ? 40.0 : 0.0) + 64.0;
          const footer = 40.0;
          var room = constraints.maxHeight - header - footer;
          // The photo keeps its own shape (never cropped): as wide as the card allows, but no taller than its share
          // of the free space; a tall photo is then centred at a narrower width.
          final photo = data.photo;
          final photoAspect = photo == null || photo.height == 0
              ? 1.0
              : photo.width / photo.height;
          final photoHeight = photo == null
              ? 0.0
              : math.min(width / photoAspect, room * (story ? .70 : .55));
          final photoWidth = photoHeight * photoAspect;
          room -= photoHeight == 0 ? 0 : photoHeight + 16;
          final fit = fitShareText(data.body, width, room - 24);
          final cut = fit.truncated;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showChip) ...[_chip(), const SizedBox(height: 12)],
              _author(),
              const SizedBox(height: 16),
              if (data.photo != null) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: photoWidth,
                      height: photoHeight,
                      child: RawImage(
                        image: data.photo,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: ClipRect(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (data.body.isNotEmpty)
                          material.Text(
                            data.body,
                            maxLines: fit.maxLines,
                            overflow: TextOverflow.ellipsis,
                            style: _body(fit.size),
                          ),
                        if (cut)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: material.Text(
                              data.continueLabel,
                              style: const TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandPurple,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _meta(),
            ],
          );
        },
      ),
    );
  }

  bool get _showChip =>
      data.badge != null || data.kind == ShareCardKind.mapNote;

  Widget _chip() {
    final encounter = data.badge != null;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: data.kind == ShareCardKind.mapNote
                ? AppColors.surfaceLilac
                : AppColors.surfaceBlue,
            borderRadius: BorderRadius.circular(99),
          ),
          child: material.Text(
            data.kindLabel.toUpperCase(),
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 11,
              letterSpacing: .8,
              fontWeight: FontWeight.w900,
              color: data.kind == ShareCardKind.mapNote
                  ? AppColors.brandPurple
                  : AppColors.blue,
            ),
          ),
        ),
        if (encounter) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF2F8),
              border: Border.all(color: const Color(0xFFFBCFE8)),
              borderRadius: BorderRadius.circular(99),
            ),
            child: material.Text(
              '${data.badge} ✓',
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.encounterPink,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _avatar(ui.Image? image, double size) => ClipOval(
    child: SizedBox(
      width: size,
      height: size,
      child: image == null
          ? Container(
              color: AppColors.surfaceLilac,
              child: Icon(
                Icons.person_rounded,
                size: size * .6,
                color: AppColors.brandLilac,
              ),
            )
          : RawImage(image: image, fit: BoxFit.cover),
    ),
  );

  Widget _author() {
    if (data.anonymous) {
      return Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.surfaceLilac,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.visibility_off_rounded,
              size: 20,
              color: AppColors.brandLilac,
            ),
          ),
          const SizedBox(width: 10),
          material.Text(
            data.anonymousLabel,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
        ],
      );
    }
    if (data.pairNames != null) {
      return Row(
        children: [
          SizedBox(
            width: 38.0 + 26.0 * (data.pairAvatars.length.clamp(1, 2) - 1),
            height: 38,
            child: Stack(
              children: [
                for (var i = 0; i < data.pairAvatars.length.clamp(0, 2); i++)
                  Positioned(
                    left: i * 26.0,
                    child: _ring(_avatar(data.pairAvatars[i], 38)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: material.Text(
              data.pairNames!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        _avatar(data.avatar, 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              material.Text(
                data.authorName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              if (data.handle != null)
                material.Text(
                  '@${data.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ring(Widget child) => Container(
    padding: const EdgeInsets.all(2),
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: child,
  );

  Widget _meta() => material.Text(
    [
      data.placeLabel,
      data.dateLabel,
    ].where((part) => part.isNotEmpty).join(' · '),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontFamily: 'NunitoSans',
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
    ),
  );

  Widget _footer() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: story ? 48 : 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppShape.blueGradient,
            borderRadius: BorderRadius.circular(99),
          ),
          child: material.Text(
            data.cta,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: story ? 10 : 6),
        material.Text(
          data.url.replaceFirst('https://', ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}
