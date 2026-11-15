import '../data/post_context.dart';
import 'post_context.dart';

import 'dart:io';

import 'package:flutter/material.dart' hide Text;

import 'translated_text.dart';

import 'package:flutter/services.dart';
import 'share_sheet.dart';

import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../data/models.dart';
import '../data/location_api.dart';
import 'collections.dart';
import 'comments_sheet.dart';
import 'common.dart';
import 'media_viewer.dart';
import 'social_page.dart';
import '../core/app_locale.dart';

Widget socialMediaImage(
  AppStore store,
  String path, {
  required BoxFit fit,
  double? width,
  double? height,
}) {
  final uri = Uri.tryParse(path);
  final ImageProvider provider;
  if (uri?.scheme == 'https' || uri?.scheme == 'http') {
    provider = NetworkImage(path, headers: store.mediaHeaders(path));
  } else if (path.startsWith('assets/')) {
    provider = AssetImage(path);
  } else {
    provider = FileImage(File(path));
  }
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
  const ImageCarousel(this.images, {super.key, this.height = 215});
  final List<String> images;
  final double height;
  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int index = 0;
  // Each mounted gallery owns its page; route storage can otherwise restore another post's page.
  final controller = PageController(keepPage: false);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => index = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () async {
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
                  child: socialMediaImage(
                    StoreScope.of(context),
                    widget.images[i],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: widget.height,
                  ),
                ),
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
                margin: const EdgeInsets.symmetric(horizontal: 3),
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
    return Container(
      margin: const EdgeInsets.only(bottom: Space.md),
      padding: const EdgeInsets.fromLTRB(Space.md, 14, Space.md, 6),
      decoration: AppShape.card(
        elevated: true,
        borderColor: const Color(0xFFE2ECF7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (pair.isNotEmpty)
                EncounterAvatars(pair, size: 42, interactive: canInteract)
              else
                Avatar(
                  author,
                  size: 42,
                  onTap: author == null || preview
                      ? null
                      : () => openPage(context, '/profile', author.id),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: author == null || preview
                      ? null
                      : () => openPage(context, '/profile', author.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pair.isEmpty
                            ? author?.name ?? 'Anonim'
                            : pair.map((person) => person.name).join(' & '),
                        maxLines: pair.isEmpty ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.2,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Badge and metadata share one wrapping line: they flow onto a second line instead of colliding.
                      Wrap(
                        spacing: 6,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (post.encounterConfirmed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE4ED),
                                borderRadius: BorderRadius.circular(
                                  AppShape.pill,
                                ),
                                border: Border.all(
                                  color: const Color(0xFFFBCFE8),
                                ),
                              ),
                              child: const Text(
                                'Karşılaşıldı ✓',
                                style: TextStyle(
                                  color: AppColors.encounterPink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          Text(
                            [
                              post.time,
                              post.locationLabel ?? post.city,
                              if (post.distanceMeters case final meters?)
                                locationDistance(meters),
                              if (!store.connected && !post.remote)
                                '${post.distance.toStringAsFixed(1).replaceAll('.', ',')} km',
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                    if (post.remote && post.mine && !post.jointStory)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Düzenle'),
                      ),
                    if (post.remote && (post.mine || canWithdraw))
                      const PopupMenuItem(value: 'delete', child: Text('Sil')),
                    if (post.remote && post.saved)
                      const PopupMenuItem(
                        value: 'collection',
                        child: Text('Koleksiyona Ekle'),
                      ),
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
          const SizedBox(height: 10),
          if (post.encounterRequestId case final request?)
            TextButton(
              onPressed: () => openPage(context, '/encounter', request),
              child: Text(switch (post.encounterRequestStatus) {
                'rejected' => 'Reddedildi',
                'cancelled' => 'İptal edildi',
                _ => 'Onay bekliyor',
              }),
            ),
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
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          if (post.travel != null) TravelSummary(post.travel!),
          InkWell(
            onTap: detail || preview
                ? null
                : () => openPage(context, '/post', post.id),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              height: 1.25,
                              color: AppColors.navy,
                            ),
                      ),
                    ),
                  Text(
                    post.text,
                    style: TextStyle(
                      // A short text-only post gets a larger, airier body so the card never looks empty.
                      fontSize: post.images.isEmpty && post.text.length <= 90
                          ? 17
                          : 15.5,
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
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Text(
                post.kind.label,
                style: const TextStyle(
                  color: AppColors.action,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          PostMediaView(post),
          if (post.remote && post.text.isEmpty && !detail && !preview)
            TextButton(
              onPressed: () => openPage(context, '/post', post.id),
              child: const Text('Paylaşımı Gör'),
            ),
          if (canInteract)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFEAF1F9)),
            ),
          if (canInteract)
            Row(
              children: [
                _PostAction(
                  icon: post.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${post.likes}',
                  color: post.liked
                      ? AppColors.encounterPink
                      : const Color(0xFF334766),
                  tooltip: tr('Beğen'),
                  onTap: () => post.remote
                      ? socialAction(context, () => store.react(post, 'like'))
                      : store.like(post),
                ),
                _PostAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.displayedCommentCount}',
                  color: const Color(0xFF334766),
                  tooltip: tr('Yorumlar'),
                  onTap: () => showCommentsSheet(context, post),
                ),
                _PostAction(
                  icon: Icons.near_me_outlined,
                  color: const Color(0xFF334766),
                  tooltip: tr('Paylaş'),
                  onTap: () => sharePost(context, post),
                ),
                const Spacer(),
                _PostAction(
                  icon: post.saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  tooltip: post.saved ? tr('Kaydı kaldır') : tr('Kaydet'),
                  color: post.saved
                      ? AppColors.primary
                      : const Color(0xFF334766),
                  onTap: () => post.remote
                      ? socialAction(context, () => store.react(post, 'save'))
                      : store.save(post),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.label,
    this.color = AppColors.muted,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final String? label;
  final Color color;
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
        borderRadius: AppShape.control,
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
                Icon(icon, color: color, size: 22),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
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
                          fontWeight: FontWeight.w800,
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
  });
  final List<Person> people;
  final double size;
  final bool interactive;

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
        if (size >= 50)
          Positioned(
            bottom: 0,
            left: size * .62,
            child: Container(
              width: 22,
              height: 22,
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
              child: const Icon(
                Icons.favorite_rounded,
                size: 12,
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
                            fontWeight: FontWeight.w800,
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
                          .map((person) => person.name)
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
          PostMediaView(post, height: compact ? 156 : 215),
        ],
      ],
    ),
  );
}

/// Only actual post/story attachments belong here; identity avatars stay in headers.
class PostMediaView extends StatelessWidget {
  const PostMediaView(this.post, {super.key, this.height = 215});
  final Post post;
  final double height;
  @override
  Widget build(BuildContext context) => post.images.isEmpty
      ? const SizedBox.shrink()
      : ImageCarousel(post.images, height: height);
}
