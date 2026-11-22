import '../data/post_context.dart';
import 'post_context.dart';

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart' hide Text;

import 'translated_text.dart';

import 'package:flutter/services.dart';

import 'share_sheet.dart';

import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../data/models.dart';
import 'collections.dart';
import 'comments_sheet.dart';
import 'common.dart';
import 'content_touch.dart';
import 'media_viewer.dart';
import 'memory_widgets.dart';
import 'social_page.dart';
import '../core/app_locale.dart';

ImageProvider socialImageProvider(AppStore store, String path) {
  final uri = Uri.tryParse(path);
  if (uri?.scheme == 'https' || uri?.scheme == 'http') {
    return NetworkImage(path, headers: store.mediaHeaders(path));
  }
  if (path.startsWith('assets/')) return AssetImage(path);
  return FileImage(File(path));
}

Widget socialMediaImage(
  AppStore store,
  String path, {
  required BoxFit fit,
  double? width,
  double? height,
}) {
  final provider = socialImageProvider(store, path);
  return Image(
    image: provider,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, _, _) => SizedBox(
      width: width,
      height: height,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
      ),
    ),
  );
}

class ImageCarousel extends StatefulWidget {
  const ImageCarousel(
    this.images, {
    super.key,
    this.height = 215,
    this.adaptive = true,
    this.maxHeight,
    this.radius = 14,
    this.onTap,
    this.onDoubleTap,
  });
  final List<String> images;

  /// Corner radius of the photo box.
  final double radius;

  /// A tap on a photo (its index). Without it a tap opens the full-screen viewer.
  final ValueChanged<int>? onTap;

  /// A double tap on a photo: the carousel plays the heart over the box and calls this. A swipe never counts as a tap.
  final VoidCallback? onDoubleTap;

  /// Upper limit of an adaptive box: a tall photo stays whole (centred, with soft side margins) instead of filling the screen.
  final double? maxHeight;

  /// Fixed height when [adaptive] is false (compact previews), and the height used until the first photo's size is
  /// known.
  final double height;

  /// Photos are shown whole, in the shape they were uploaded: the box takes the first photo's aspect ratio (limited to
  /// the 9:16 vertical to 1.91:1 landscape range) and every photo is fitted inside it without cropping.
  final bool adaptive;
  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

/// Narrowest (9:16 vertical) and widest (1.91:1 landscape) box a post photo gets; 4:5 and 16:9 sit in between.
const double kPostMinAspect = 9 / 16;
const double kPostMaxAspect = 1.91;

class _ImageCarouselState extends State<ImageCarousel> {
  int index = 0;
  // Each mounted gallery owns its page; route storage can otherwise restore another post's page.
  final controller = PageController(keepPage: false);
  final _burst = HeartBurstController();
  double? _aspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  String? _measured;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measureFirst();
  }

  @override
  void didUpdateWidget(covariant ImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _measureFirst();
  }

  void _measureFirst() {
    if (!widget.adaptive || widget.images.isEmpty) return;
    final first = widget.images.first;
    if (_measured == first) return;
    _measured = first;
    _stopListening();
    final provider = socialImageProvider(StoreScope.of(context), first);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (!mounted || w <= 0 || h <= 0) return;
      final aspect = (w / h).clamp(kPostMinAspect, kPostMaxAspect);
      if (aspect != _aspect) setState(() => _aspect = aspect);
    }, onError: (_, _) {});
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _stopListening() {
    final stream = _stream, listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      final aspect = _aspect;
      final natural = aspect == null ? null : width / aspect;
      final boxHeight = widget.adaptive && natural != null
          ? natural.clamp(0.0, widget.maxHeight ?? double.infinity)
          : widget.height;
      // A tall photo in a capped box leaves bands at its sides: they take the photo's own colours instead of flat grey.
      final capped =
          widget.adaptive && natural != null && boxHeight < natural - 1;
      return _carousel(context, boxHeight, ambient: capped);
    },
  );

  Widget _carousel(
    BuildContext context,
    double boxHeight, {
    bool ambient = false,
  }) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: SizedBox(
          height: boxHeight,
          width: double.infinity,
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => index = i),
                itemBuilder: (_, i) => GestureDetector(
                  onDoubleTap: widget.onDoubleTap == null
                      ? null
                      : () {
                          _burst.play();
                          widget.onDoubleTap!();
                        },
                  onTap: () async {
                    if (widget.onTap case final custom?) {
                      custom(i);
                      return;
                    }
                    final next = await showMediaViewer(
                      context,
                      widget.images,
                      initialIndex: i,
                    );
                    if (next != null && next != index && mounted) {
                      controller.jumpToPage(next);
                      setState(() => index = next);
                    }
                  },
                  child: ColoredBox(
                    color: AppColors.surfaceSecondary,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (ambient) _Ambient(widget.images[i]),
                        socialMediaImage(
                          StoreScope.of(context),
                          widget.images[i],
                          // Adaptive galleries never crop: each photo is shown whole inside the box.
                          fit: widget.adaptive ? BoxFit.contain : BoxFit.cover,
                          width: double.infinity,
                          height: boxHeight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.onDoubleTap != null)
                Positioned.fill(
                  child: Center(child: HeartBurst(controller: _burst)),
                ),
              if (widget.images.length > 1) ...[
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: .7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${index + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      carouselArrow(
                        Icons.chevron_left,
                        () => controller.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                      ),
                      carouselArrow(
                        Icons.chevron_right,
                        () => controller.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      if (widget.images.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.images.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == i ? AppColors.blue : AppColors.line,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
    ],
  );
  Widget carouselArrow(IconData icon, VoidCallback action) => IconButton(
    tooltip: icon == Icons.chevron_left
        ? tr('Önceki fotoğraf')
        : tr('Sonraki fotoğraf'),
    onPressed: action,
    icon: CircleAvatar(
      radius: 13,
      backgroundColor: AppColors.navy.withValues(alpha: .45),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

/// What a tap on a post's content does. Never a separate post page: a post with a place opens the map on its
/// approximate point (with a compact preview of the post), any other post with photos opens its photo in the viewer, and
/// a plain text post has nothing to open. On the post's own detail page only the photo opens.
Future<void> openPostContent(
  BuildContext context,
  Post post, {
  int image = 0,
  bool detail = false,
}) async {
  if (!detail && post.mapPoint != null) {
    showPostOnMap(context, post);
    return;
  }
  if (post.images.isNotEmpty) {
    await showMediaViewer(context, post.images, initialIndex: image);
  }
}

/// Opens the app's own map on the post's approximate point; the map shows the post in a compact preview.
void showPostOnMap(BuildContext context, Post post) {
  if (post.mapPoint == null) return;
  StoreScope.of(context).mapPostFocus = post;
  openPage(context, '/map');
}

/// A double tap on a post: like it. A post that is already liked stays liked; taking a like back is the heart button's job.
Future<void> likeFromDoubleTap(
  BuildContext context,
  AppStore store,
  Post post,
) async {
  if (post.liked) return;
  HapticFeedback.lightImpact();
  if (post.remote) {
    await socialAction(context, () => store.react(post, 'like'));
  } else {
    store.like(post);
  }
}

/// The photo's own colours, enlarged and soft, behind a photo that does not fill its box. It is the very same image (the
/// cache serves it, nothing is downloaded twice) and is never read out.
class _Ambient extends StatelessWidget {
  const _Ambient(this.path);
  final String path;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 24,
          sigmaY: 24,
          tileMode: TileMode.mirror,
        ),
        child: SizedBox.expand(
          child: socialMediaImage(
            StoreScope.of(context),
            path,
            fit: BoxFit.cover,
          ),
        ),
      ),
    ),
  );
}

/// What a post is as far as its card is concerned. The surface follows it, so a feed is not one box repeated: a short
/// text-only post sits on a soft wash, a photo post is the photo (full width), an encounter story wears the soft encounter surface,
/// everything else stays plain white.
enum _PostKind { statement, photo, story, plain }

/// The accent of an encounter story's label: the encounter pink pulled a little towards the navy so the small text keeps
/// a readable contrast (4.5:1) on white and on the soft surfaces.
final _storyInk = Color.lerp(AppColors.encounterPink, AppColors.navy, .2)!;

/// The surface of a post card: one radius, a hairline and the system's soft shadow.
BoxDecoration _postSurface(_PostKind kind) => switch (kind) {
  _PostKind.story => AppShape.encounterCard().copyWith(
    borderRadius: AppShape.largeRounded,
  ),
  _PostKind.statement =>
    AppShape.card(
      borderColor: const Color(0xFFD6E4F7),
      elevated: true,
    ).copyWith(
      borderRadius: AppShape.largeRounded,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, AppColors.surfaceBlue],
      ),
    ),
  _ => AppShape.card(
    borderColor: const Color(0xFFEAF0F7),
    elevated: true,
  ).copyWith(borderRadius: AppShape.largeRounded),
};

/// A post in a feed: who (avatar and name), what (text, photos), then the actions with the time at the far end. Where it
/// happened and how old it is are not part of the header.
///
/// The card has the shape of its content ([_PostKind]): a short text-only post is set large on a soft wash, photos run the
/// full width of the card, an encounter story sits on the encounter surface.
///
/// Touch: a tap on the content opens it where it belongs ([openPostContent]), a double tap likes it with a heart over the
/// content. The header (profile, ⋮) and the action buttons keep their own taps and never trigger the content's.
class PostCard extends StatelessWidget {
  const PostCard(
    this.post, {
    super.key,
    this.detail = false,
    this.preview = false,
  });
  final Post post;
  final bool detail, preview;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final author = post.anonymous ? null : store.person(post.authorId);
    final pair = post.storyParticipants;
    final canWithdraw = pair.any((person) => person.id == store.me.id);
    final canInteract = !preview && post.interactionsEnabled;
    final hasPhotos = post.images.isNotEmpty;
    // A tap on the text opens the map (a located post) or the photo; a text-only post, and the post page that already is
    // the post, have nothing to open. Without a handler the area has no single-tap wait either.
    final textOpens =
        canInteract && !detail && (hasPhotos || post.mapPoint != null);
    void like() => likeFromDoubleTap(context, store, post);
    final kind = pair.isNotEmpty
        ? _PostKind.story
        : hasPhotos
        ? _PostKind.photo
        : post.storyTitle == null && post.text.length <= 110
        ? _PostKind.statement
        : _PostKind.plain;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.lg),
      padding: const EdgeInsets.only(top: 16),
      decoration: _postSurface(kind),
      // The photos run to the card's edges; the card's corners clip them.
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: who, and the ⋮ menu. No place, no time.
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                if (pair.isNotEmpty)
                  EncounterAvatars(
                    pair,
                    size: 44,
                    interactive: canInteract,
                    badge: true,
                  )
                else
                  // A soft shadow lifts the photo off the card.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withValues(alpha: .12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Avatar(
                      author,
                      size: 44,
                      onTap: author == null || preview
                          ? null
                          : () => openPage(context, '/profile', author.id),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: author == null || preview
                        ? null
                        : () => openPage(context, '/profile', author.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                pair.isEmpty
                                    ? author?.name ?? 'Anonim'
                                    : pair
                                          .map(
                                            (person) => person.name
                                                .trim()
                                                .split(RegExp(r'\s+'))
                                                .first,
                                          )
                                          .join(' & '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  height: 1.25,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            // Pending / rejected request: a small chip next to the name that
                            // disappears once the other person confirms.
                            if (post.encounterRequestId case final request?) ...[
                              const SizedBox(width: 8),
                              _RequestStatusChip(
                                label: switch (post.encounterRequestStatus) {
                                  'rejected' => 'Reddedildi',
                                  'cancelled' => 'İptal edildi',
                                  _ => 'Onay bekliyor',
                                },
                                onTap: () =>
                                    openPage(context, '/encounter', request),
                              ),
                            ],
                          ],
                        ),
                        // The one quiet mark of an encounter story: small accent text, not a badge.
                        if (pair.isNotEmpty && post.encounterConfirmed)
                          Text(
                            'Karşılaşıldı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _storyInk,
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (canInteract)
                  PopupMenuButton<String>(
                    tooltip: tr('Paylaşım seçenekleri'),
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    iconColor: AppColors.muted,
                    onSelected: (v) async {
                      if (v == 'map') {
                        showPostOnMap(context, post);
                        return;
                      }
                      if (v == 'edit') {
                        await editPostText(context, store, post);
                        return;
                      }
                      if (v == 'delete') {
                        final confirmed = await confirmAction(
                          context,
                          title: tr('Paylaşım silinsin mi?'),
                          message:
                              'Paylaşım akıştan ve profilinden kaldırılacak.',
                          action: 'Sil',
                        );
                        if (!confirmed || !context.mounted) return;
                        await socialAction(context, () async {
                          await store.deletePost(post);
                          if (!context.mounted) return;
                          if (detail) Navigator.pop(context);
                          toast(context, 'Paylaşım silindi.');
                        });
                        return;
                      }
                      if (v == 'collection') {
                        await showAddToCollectionSheet(context, store, post);
                        return;
                      }
                      if (v == 'memory') {
                        await addSourceToMemories(
                          context,
                          sourceType: 'post',
                          sourceId: int.parse(post.id),
                        );
                        return;
                      }
                      if (v == 'report') {
                        openPage(
                          context,
                          '/report',
                          post.remote
                              ? ReportTarget(
                                  post.jointStory ? 'encounter_story' : 'post',
                                  int.parse(post.id),
                                  'Paylaşım',
                                )
                              : trf('Paylaşım {0}', [post.id]),
                        );
                      }
                      if (v == 'block' &&
                          await confirmAction(
                            context,
                            title: tr('Kullanıcı engellensin mi?'),
                            message: 'Bu kullanıcının paylaşımlarını ve mesajlarını görmezsin.',
                            action: 'Engelle',
                          )) {
                        if (!context.mounted) return;
                        await socialAction(context, () async {
                          await store.setRemoteBlock(post.authorId, true);
                          if (context.mounted) {
                            if (detail) Navigator.maybePop(context);
                            toast(context, 'Kullanıcı engellendi.');
                          }
                        });
                      }
                    },
                    itemBuilder: (_) => [
                      // The place is only here: the card itself shows no location.
                      if (post.mapPoint != null)
                        const PopupMenuItem(
                          value: 'map',
                          child: Text('Haritada Gör'),
                        ),
                      if (post.remote && post.mine && !post.jointStory)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Düzenle'),
                        ),
                      if (post.remote && (post.mine || canWithdraw))
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Sil'),
                        ),
                      if (post.remote && post.saved)
                        const PopupMenuItem(
                          value: 'collection',
                          child: Text('Koleksiyona Ekle'),
                        ),
                      if (post.remote &&
                          post.mine &&
                          !post.jointStory &&
                          store.memories != null)
                        const PopupMenuItem(
                          value: 'memory',
                          child: Text('Anılarıma Ekle'),
                        ),
                      if (!post.mine)
                        const PopupMenuItem(
                          value: 'report',
                          child: Text('Paylaşımı şikâyet et'),
                        ),
                      if (!post.mine &&
                          post.authorId != store.me.id &&
                          !post.anonymous)
                        const PopupMenuItem(
                          value: 'block',
                          child: Text('Kullanıcıyı engelle'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.matchHint != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Text(
                      post.matchHint!,
                      style: const TextStyle(
                        color: AppColors.action,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (post.occurredAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Text(
                      trf('Olay zamanı · {0}', [contextDate(post.occurredAt!)]),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (post.travel != null) TravelSummary(post.travel!),
                if (post.storyTitle != null || post.text.isNotEmpty)
                  DoubleTapHeart(
                    onTap: textOpens
                        ? () => openPostContent(context, post)
                        : null,
                    onLike: canInteract ? like : null,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post.storyTitle case final title?)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      height: 1.25,
                                      color: AppColors.navy,
                                    ),
                              ),
                            ),
                          Text(
                            post.text,
                            // One body size for every post, short or long: a short one is not shouted.
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (detail)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: Text(
                      post.kind.label,
                      style: const TextStyle(
                        color: AppColors.action,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!hasPhotos) const SizedBox(height: 8),
          if (hasPhotos)
            Padding(
              // The photo runs edge to edge of the card (the card clips its corners).
              padding: const EdgeInsets.only(top: 14),
              child: ImageCarousel(
                post.images,
                radius: 0,
                // Every photo stays whole in its own shape (9:16, 4:5, 16:9), but a tall one never fills the screen: the
                // box is capped and the photo sits centred in it.
                maxHeight: math.max(
                  320.0,
                  MediaQuery.sizeOf(context).height * .62,
                ),
                // A tap on a photo: the map for a located post, otherwise the viewer (on the post page always the viewer).
                onTap: canInteract
                    ? (index) => openPostContent(
                        context,
                        post,
                        image: index,
                        detail: detail,
                      )
                    : null,
                onDoubleTap: canInteract ? like : null,
              ),
            ),
          if (canInteract)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
              child: _PostFooter(post),
            )
          else if (!preview)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: _PostTime(post),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }
}

/// Like · comment · share on the left; the time and the bookmark on the right.
class _PostFooter extends StatelessWidget {
  const _PostFooter(this.post);
  final Post post;

  static const _ink = Color(0xFF334766);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Row(
      children: [
        _PostAction(
          icon: post.liked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: '${post.likes}',
          pop: post.liked,
          color: post.liked ? AppColors.encounterPink : _ink,
          tooltip: tr('Beğen'),
          onTap: () => post.remote
              ? socialAction(context, () => store.react(post, 'like'))
              : store.like(post),
        ),
        _PostAction(
          icon: Icons.chat_bubble_outline_rounded,
          label: '${post.displayedCommentCount}',
          color: _ink,
          tooltip: tr('Yorumlar'),
          onTap: () => showCommentsSheet(context, post),
        ),
        _PostAction(
          icon: Icons.near_me_outlined,
          color: _ink,
          tooltip: tr('Paylaş'),
          onTap: () => sharePost(context, post),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _PostTime(post),
          ),
        ),
        _PostAction(
          icon: post.saved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          tooltip: post.saved ? tr('Kaydı kaldır') : tr('Kaydet'),
          pop: post.saved,
          color: post.saved ? AppColors.primary : _ink,
          onTap: () => post.remote
              ? socialAction(context, () => store.react(post, 'save'))
              : store.save(post),
        ),
      ],
    );
  }
}

/// "17 sa önce": muted, small, one line. Where the room beside the actions is too narrow it reads "17 sa".
/// Small status chip for an encounter request that is not confirmed yet.
class _RequestStatusChip extends StatelessWidget {
  const _RequestStatusChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.primary.withValues(alpha: .08),
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _PostTime extends StatelessWidget {
  const _PostTime(this.post);
  final Post post;

  static const _style = TextStyle(
    color: AppColors.muted,
    fontSize: 12.5,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The actions took the whole row (huge text): nothing to fit the time into.
      if (constraints.maxWidth < 1) return const SizedBox.shrink();
      final full = post.time;
      final painter = TextPainter(
        // The very style the Text below resolves to (the theme's font included), so the measure is the real width.
        text: TextSpan(
          text: full,
          style: DefaultTextStyle.of(context).style.merge(_style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final fits = painter.width <= constraints.maxWidth;
      painter.dispose();
      return Align(
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            fits ? full : post.timeShort,
            key: Key('post-time-${post.id}'),
            maxLines: 1,
            softWrap: false,
            style: _style,
          ),
        ),
      );
    },
  );
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.label,
    this.color = AppColors.muted,
    this.pop = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final String? label;
  final Color color;

  /// The action is on (liked, saved): its icon pops once when it turns on.
  final bool pop;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    excludeFromSemantics: true,
    child: Semantics(
      label: label == null ? tooltip : '$tooltip, $label',
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.pill),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppDimensions.touch,
            minHeight: AppDimensions.touch,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Pop(
                  active: pop,
                  child: Icon(icon, color: color, size: 24),
                ),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A small spring on an icon at the moment it turns on (a like, a save): it grows a third and settles back. Nothing runs on
/// first build, while it is already on, or when the system asks for no animations.
class _Pop extends StatefulWidget {
  const _Pop({required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<_Pop> createState() => _PopState();
}

class _PopState extends State<_Pop> with SingleTickerProviderStateMixin {
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.32,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 38,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.32,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 62,
    ),
  ]);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void didUpdateWidget(covariant _Pop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        !oldWidget.active &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _controller.drive(_scale), child: widget.child);
}

Future<void> editPostText(
  BuildContext context,
  AppStore store,
  Post post,
) async {
  var text = post.text;
  final result = await showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Paylaşımı Düzenle'),
      content: TextFormField(
        initialValue: text,
        minLines: 2,
        maxLines: 5,
        maxLength: 1000,
        onChanged: (value) => text = value,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, text),
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
  if (result == null || !context.mounted) return;
  await socialAction(context, () => store.editPost(post, result));
}

Future<void> sharePost(BuildContext context, Post post) async {
  if (post.remote) {
    // Only public content may leave the app (the server decides and sends a link); everything else says so.
    final url = post.shareUrl;
    if (url == null) {
      toast(context, tr('Bu içerik uygulama dışında paylaşılamaz.'));
      return;
    }
    final store = StoreScope.of(context);
    await showShareSheet(
      context,
      url: url,
      build: (service) => service.postCard(post, store),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: Space.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paylaşımı gönder', style: Theme.of(ctx).textTheme.titleLarge),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: AppColors.blue),
              title: const Text('Metni kopyala'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: post.text));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  toast(context, 'Paylaşım metni kopyalandı.');
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.blue,
              ),
              title: const Text('Mesajla gönder'),
              onTap: () {
                Navigator.pop(ctx);
                openPage(context, '/share', post.id);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class EncounterCard extends StatelessWidget {
  const EncounterCard(this.encounter, {super.key, this.compact = false});
  final Encounter encounter;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), e = encounter;
    final from = store.person(e.fromId),
        to = store.person(e.toId),
        post = store.post(e.postId);
    final approved = e.status == EncounterStatus.approved;
    return InkWell(
      borderRadius: AppShape.rounded,
      onTap: () => openPage(context, '/encounter', e.id),
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: approved
            ? AppShape.encounterCard()
            : AppShape.card(color: AppColors.surface),
        child: Row(
          children: [
            SizedBox(
              width: compact ? 86 : 94,
              height: 58,
              child: Stack(
                children: [
                  Positioned(left: 0, child: Avatar(from, size: 54)),
                  Positioned(left: 33, child: Avatar(to, size: 54)),
                  Positioned(
                    bottom: 0,
                    left: 30,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: AppColors.encounterPink,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.encounterPink.withValues(
                              alpha: .28,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final badge = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: approved
                              ? const Color(0xFFFFE4ED)
                              : AppColors.surfaceBlue,
                          borderRadius: BorderRadius.circular(AppShape.pill),
                          border: Border.all(
                            color: approved
                                ? const Color(0xFFFBCFE8)
                                : const Color(0xFFD6E4F7),
                          ),
                        ),
                        child: Text(
                          approved ? 'Karşılaşıldı ✓' : e.status.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: approved
                                ? AppColors.encounterPink
                                : AppColors.muted,
                            fontWeight: FontWeight.w800,
                            fontSize: 9.5,
                          ),
                        ),
                      );
                      final titleWidget = Text(
                        approved ? e.title : 'Sen miydin?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.navy,
                          letterSpacing: -.2,
                        ),
                      );
                      if (constraints.maxWidth < 155 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.25) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            badge,
                            const SizedBox(height: 2),
                            titleWidget,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: titleWidget),
                          const SizedBox(width: 8),
                          badge,
                        ],
                      );
                    },
                  ),
                  Text(
                    '${from.name} & ${to.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475874),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    approved ? e.description : post.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (post.images.isNotEmpty && !compact) ...[
              const SizedBox(width: Space.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppShape.small),
                child: Image.asset(
                  post.images.first,
                  width: 58,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EncounterAvatars extends StatelessWidget {
  const EncounterAvatars(
    this.people, {
    super.key,
    this.size = 54,
    this.interactive = false,
    this.badge = false,
  });
  final List<Person> people;
  final double size;
  final bool interactive;

  /// Shows the small heart between the two photos also on a small pair (it always shows from size 50).
  final bool badge;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('encounter-avatars'),
    width: size * 1.65,
    height: size + 5,
    child: Stack(
      children: [
        for (final (index, person) in people.take(2).indexed)
          Positioned(
            left: index * size * .64,
            child: Avatar(
              person,
              size: size,
              onTap: interactive
                  ? () => openPage(context, '/profile', person.id)
                  : null,
            ),
          ),
        if (size >= 50 || badge)
          Positioned(
            bottom: 0,
            // Centred on the overlap of the two photos.
            left: size * .82 - (size >= 50 ? 11 : 9),
            child: Container(
              width: size >= 50 ? 22 : 18,
              height: size >= 50 ? 22 : 18,
              decoration: BoxDecoration(
                color: AppColors.encounterPink,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.encounterPink.withValues(alpha: .28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.favorite_rounded,
                size: size >= 50 ? 12 : 9.5,
                color: Colors.white,
              ),
            ),
          ),
      ],
    ),
  );
}

class PublishedEncounterCard extends StatelessWidget {
  const PublishedEncounterCard(this.post, {super.key, this.compact = false});
  final Post post;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.md),
    decoration: AppShape.encounterCard(),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => openPage(context, '/post', post.id),
          child: Row(
            children: [
              EncounterAvatars(post.storyParticipants),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final badge = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4ED),
                            borderRadius: BorderRadius.circular(AppShape.pill),
                            border: Border.all(color: const Color(0xFFFBCFE8)),
                          ),
                          child: const Text(
                            'Karşılaşıldı ✓',
                            maxLines: 1,
                            style: TextStyle(
                              color: AppColors.encounterPink,
                              fontWeight: FontWeight.w800,
                              fontSize: 9.5,
                            ),
                          ),
                        );
                        final titleWidget = Text(
                          post.storyTitle ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.navy,
                            letterSpacing: -.2,
                          ),
                        );
                        if (constraints.maxWidth < 155 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.25) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              badge,
                              const SizedBox(height: 2),
                              titleWidget,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: titleWidget),
                            const SizedBox(width: 8),
                            badge,
                          ],
                        );
                      },
                    ),
                    Text(
                      post.storyParticipants
                          .map(
                            (person) =>
                                person.name.trim().split(RegExp(r'\s+')).first,
                          )
                          .join(' & '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475874),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (post.images.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          PostMediaView(post, height: compact ? 156 : 215, adaptive: !compact),
        ],
      ],
    ),
  );
}

/// Only actual post/story attachments belong here; identity avatars stay in headers.
class PostMediaView extends StatelessWidget {
  const PostMediaView(
    this.post, {
    super.key,
    this.height = 215,
    this.adaptive = true,
  });
  final Post post;
  final double height;
  final bool adaptive;
  @override
  Widget build(BuildContext context) => post.images.isEmpty
      ? const SizedBox.shrink()
      : ImageCarousel(post.images, height: height, adaptive: adaptive);
}
