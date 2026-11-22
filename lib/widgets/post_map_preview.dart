import 'package:flutter/material.dart' hide Text;

import '../core/app_locale.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import 'common.dart';
import 'media_viewer.dart';
import 'social.dart';
import 'translated_text.dart';

/// The compact preview that sits at the bottom of the map when a post is opened from the feed or from a map marker:
/// avatar, name, time, the first lines of the text and (when there is one) a small photo that opens the full-screen
/// viewer. It never covers more than a strip of the map; the map behind it stays usable.
class PostMapPreview extends StatelessWidget {
  const PostMapPreview({super.key, required this.post, required this.onClose});

  final Post post;
  final VoidCallback onClose;

  static const photoSize = 72.0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final author = post.anonymous ? null : store.person(post.authorId);
    final pair = post.storyParticipants;
    final name = pair.isNotEmpty
        ? pair
              .map((person) => person.name.trim().split(RegExp(r'\s+')).first)
              .join(' & ')
        : author?.name ?? 'Anonim';
    return Material(
      key: const Key('post-map-preview'),
      color: Colors.white,
      elevation: 6,
      shadowColor: AppColors.navy.withValues(alpha: .28),
      borderRadius: AppShape.rounded,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pair.isNotEmpty)
                  EncounterAvatars(pair, size: 34)
                else
                  Avatar(author, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          height: 1.25,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        post.time,
                        key: const Key('post-map-preview-time'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('post-map-preview-close'),
                  tooltip: tr('Kapat'),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.muted,
                  onPressed: onClose,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      post.text,
                      key: const Key('post-map-preview-text'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  if (post.images.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    _PreviewPhoto(post),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small photo of the preview. A tap opens the app's own full-screen viewer (zoom, swipe), nothing new.
class _PreviewPhoto extends StatelessWidget {
  const _PreviewPhoto(this.post);
  final Post post;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final extra = post.images.length - 1;
    return Semantics(
      button: true,
      label: tr('Fotoğrafı büyüt'),
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('post-map-preview-photo'),
        onTap: () => showMediaViewer(context, post.images),
        child: ClipRRect(
          borderRadius: AppShape.control,
          child: SizedBox.square(
            dimension: PostMapPreview.photoSize,
            child: Stack(
              fit: StackFit.expand,
              children: [
                socialMediaImage(
                  store,
                  post.images.first,
                  fit: BoxFit.cover,
                  width: PostMapPreview.photoSize,
                  height: PostMapPreview.photoSize,
                ),
                if (extra > 0)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(AppShape.pill),
                      ),
                      child: Text(
                        '+$extra',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The preview while its post is still loading (a tap on a map marker only knows the post's id), or when it could not be
/// loaded.
class PostMapPreviewPlaceholder extends StatelessWidget {
  const PostMapPreviewPlaceholder({
    super.key,
    required this.failed,
    required this.onRetry,
    required this.onClose,
  });

  final bool failed;
  final VoidCallback onRetry, onClose;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('post-map-preview-placeholder'),
    color: Colors.white,
    elevation: 6,
    shadowColor: AppColors.navy.withValues(alpha: .28),
    borderRadius: AppShape.rounded,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      child: Row(
        children: [
          if (failed)
            const Icon(
              Icons.wifi_off_outlined,
              size: 20,
              color: AppColors.muted,
            )
          else
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              failed ? 'Paylaşım yüklenemedi.' : 'Paylaşım yükleniyor…',
              style: AppTypography.metadata,
            ),
          ),
          if (failed)
            TextButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
          IconButton(
            tooltip: tr('Kapat'),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.muted,
            onPressed: onClose,
          ),
        ],
      ),
    ),
  );
}
