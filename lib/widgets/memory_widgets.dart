import 'package:flutter/material.dart' hide Text;

import '../core/app_locale.dart';
import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../data/memories_api.dart';
import 'common.dart';
import 'media_viewer.dart';
import 'social.dart';
import 'social_page.dart';
import 'translated_text.dart';

/// Arguments of the memory form route: a new empty memory, one made from a map note / post, or an edit.
class MemoryFormArgs {
  const MemoryFormArgs({this.edit, this.prefill, this.sourceId});
  final MemoryItem? edit;
  final MemoryPrefill? prefill;
  final int? sourceId;
}

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// "14 Ağustos 2026": the day a memory happened (a memory is about a day, not a minute).
String memoryDate(DateTime value) {
  final day = value.toLocal();
  return '${day.day} ${tr(_months[day.month - 1])} ${day.year}';
}

IconData memoryVisibilityIcon(MemoryVisibility value) => switch (value) {
  MemoryVisibility.private => Icons.lock_outline_rounded,
  MemoryVisibility.followers => Icons.people_outline_rounded,
  MemoryVisibility.public => Icons.public_rounded,
  MemoryVisibility.area => Icons.place_outlined,
};

String memoryVisibilityHint(MemoryVisibility value) => switch (value) {
  MemoryVisibility.private => 'Yalnızca sen görürsün.',
  MemoryVisibility.followers => 'Seni takip edenler görür.',
  MemoryVisibility.public => 'SenMiydin’deki herkes görür.',
  MemoryVisibility.area =>
    'Bu bölgede olan kişiler görür. Kesin konumun paylaşılmaz.',
};

/// A small status pill (visibility, hidden). One line that scales down instead of wrapping.
class MemoryPill extends StatelessWidget {
  const MemoryPill(
    this.label,
    this.icon, {
    super.key,
    this.color = AppColors.brandPurple,
    this.background = AppColors.surfaceLilac,
  });
  final String label;
  final IconData icon;
  final Color color, background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppShape.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The four visibility choices as a list (used by the form, the quick sheet and the privacy setting).
class MemoryVisibilityList extends StatelessWidget {
  const MemoryVisibilityList({
    super.key,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });
  final MemoryVisibility value;
  final ValueChanged<MemoryVisibility> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final item in MemoryVisibility.values)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Material(
            color: item == value
                ? AppColors.surfaceSelectedLilac
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppShape.small),
            child: InkWell(
              key: Key('memory-visibility-${item.value}'),
              borderRadius: BorderRadius.circular(AppShape.small),
              onTap: () => onChanged(item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppShape.small),
                  border: Border.all(
                    color: item == value
                        ? AppColors.brandLilac
                        : AppColors.line,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      memoryVisibilityIcon(item),
                      size: 22,
                      color: item == value
                          ? AppColors.brandPurple
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // One line that scales down rather than dropping a lone word to the next line.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          if (!dense)
                            Text(
                              memoryVisibilityHint(item),
                              style: AppTypography.metadata,
                            ),
                        ],
                      ),
                    ),
                    if (item == value)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AppColors.brandPurple,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// A bottom sheet with the four choices; returns the picked one (null when dismissed).
Future<MemoryVisibility?> chooseMemoryVisibility(
  BuildContext context,
  MemoryVisibility current, {
  String title = 'Anı kimlere görünsün?',
}) => showModalBottomSheet<MemoryVisibility>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.section),
          const SizedBox(height: Space.md),
          MemoryVisibilityList(
            value: current,
            onChanged: (value) => Navigator.pop(sheet, value),
          ),
        ],
      ),
    ),
  ),
);

/// Opens the form for a memory made from one of your own map notes / posts. When the source already has a memory it
/// opens that one instead (no copy is ever made twice).
Future<void> addSourceToMemories(
  BuildContext context, {
  required String sourceType,
  required int sourceId,
}) async {
  final store = StoreScope.of(context);
  final api = store.memories;
  if (api == null) return;
  final MemoryPrefillResult result;
  try {
    result = await api.prefill(sourceType, sourceId);
  } on ApiFailure catch (failure) {
    if (context.mounted) toast(context, failure.detail);
    return;
  } catch (_) {
    if (context.mounted) toast(context, 'Bir sorun oluştu. Tekrar dene.');
    return;
  }
  if (!context.mounted) return;
  final existing = result.existing;
  if (existing != null) {
    toast(context, 'Bu içerik zaten Anılarında.');
    await openPage(context, '/memory', existing.id);
    return;
  }
  final prefill = result.prefill;
  if (prefill == null) return;
  final saved = await openPage<MemoryItem>(
    context,
    '/memory-form',
    MemoryFormArgs(prefill: prefill, sourceId: sourceId),
  );
  if (saved != null) {
    store.memoriesChanged();
    store.mapNotesChanged();
    if (context.mounted) toast(context, 'Anı kaydedildi.');
  }
}

/// Menu actions of a memory, shared by the card and the detail page.
Future<void> runMemoryAction(
  BuildContext context,
  MemoryItem item,
  String action, {
  bool detail = false,
  VoidCallback? onChanged,
}) async {
  final store = StoreScope.of(context);
  final api = store.memories!;
  switch (action) {
    case 'edit':
      final saved = await openPage<MemoryItem>(
        context,
        '/memory-form',
        MemoryFormArgs(edit: item),
      );
      if (saved != null) {
        store.memoriesChanged();
        onChanged?.call();
      }
    case 'hide' || 'show':
      await socialAction(context, () async {
        await api.setHidden(item.id, action == 'hide');
        store.memoriesChanged();
        onChanged?.call();
        if (context.mounted) {
          toast(
            context,
            action == 'hide' ? 'Anı gizlendi.' : 'Anı tekrar görünür.',
          );
        }
      });
    case 'visibility':
      final chosen = await chooseMemoryVisibility(
        context,
        item.visibility ?? MemoryVisibility.private,
      );
      if (chosen == null || chosen == item.visibility || !context.mounted) {
        return;
      }
      await socialAction(context, () async {
        await api.setVisibility(item.id, chosen);
        store.memoriesChanged();
        onChanged?.call();
        if (context.mounted) toast(context, 'Görünürlük güncellendi.');
      });
    case 'delete':
      final confirmed = await confirmAction(
        context,
        title: tr('Anı silinsin mi?'),
        message:
            'Anı ve fotoğrafları kalıcı olarak silinir. Paylaşımın veya Harita Notun etkilenmez.',
        action: 'Sil',
      );
      if (!confirmed || !context.mounted) return;
      await socialAction(context, () async {
        await api.delete(item.id);
        store.memoriesChanged();
        store.mapNotesChanged();
        onChanged?.call();
        if (!context.mounted) return;
        if (detail) Navigator.pop(context);
        toast(context, 'Anı silindi.');
      });
    case 'report':
      await openPage(
        context,
        '/report',
        ReportTarget('memory', item.id, 'Anı'),
      );
  }
}

List<PopupMenuEntry<String>> memoryMenuItems(MemoryItem item) => item.mine
    ? [
        const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
        PopupMenuItem(
          value: item.hidden ? 'show' : 'hide',
          child: Text(item.hidden ? 'Tekrar Göster' : 'Gizle'),
        ),
        const PopupMenuItem(
          value: 'visibility',
          child: Text('Görünürlüğü Değiştir'),
        ),
        const PopupMenuItem(value: 'delete', child: Text('Sil')),
      ]
    : const [PopupMenuItem(value: 'report', child: Text('Şikâyet Et'))];

/// The photos of a memory in a compact box: one preview, or a horizontal pager with a `1/5` counter. The list loads
/// the small thumbnails; a tap opens the shared full screen viewer with the full photos (pinch zoom included).
class MemoryPhotos extends StatefulWidget {
  const MemoryPhotos(this.media, {super.key});
  final List<MemoryMediaItem> media;

  @override
  State<MemoryPhotos> createState() => _MemoryPhotosState();
}

class _MemoryPhotosState extends State<MemoryPhotos> {
  // Each mounted gallery owns its page (no restored state from another memory).
  final controller = PageController(keepPage: false);
  int index = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> open(int at) async {
    final next = await showMediaViewer(
      context,
      [for (final item in widget.media) item.url],
      initialIndex: at,
    );
    if (next != null && next != index && mounted && controller.hasClients) {
      controller.jumpToPage(next);
      setState(() => index = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final media = widget.media;
    if (media.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        // The box follows the first photo's own shape (4:5 portrait … 1.91:1 landscape); nothing is cut off.
        final aspect = media.first.aspect.clamp(4 / 5, kPostMaxAspect);
        final height = box.maxWidth / aspect;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppShape.small),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              children: [
                PageView.builder(
                  key: const Key('memory-photos'),
                  controller: controller,
                  itemCount: media.length,
                  onPageChanged: (value) => setState(() => index = value),
                  itemBuilder: (_, i) => GestureDetector(
                    key: Key('memory-photo-$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => open(i),
                    child: ColoredBox(
                      color: AppColors.surfaceSecondary,
                      child: socialMediaImage(
                        store,
                        media[i].thumbUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: height,
                      ),
                    ),
                  ),
                ),
                if (media.length > 1)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      key: const Key('memory-photo-counter'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: .7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${index + 1}/${media.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A compact memory card: date, approximate place, short text, small photo preview with a counter, the visibility (owner
/// only) and a three-dot menu.
class MemoryCard extends StatelessWidget {
  const MemoryCard(this.item, {super.key, this.onChanged});
  final MemoryItem item;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final visibility = item.visibility;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.md),
      decoration: AppShape.card(
        elevated: true,
        borderColor: AppColors.borderLilac.withValues(alpha: .8),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: AppShape.rounded,
        child: InkWell(
          key: Key('memory-card-${item.id}'),
          borderRadius: AppShape.rounded,
          onTap: () async {
            await openPage(context, '/memory', item.id);
            onChanged?.call();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, 4, Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppIconBox(
                      icon: Icons.auto_stories_outlined,
                      size: AppDimensions.iconSM,
                      containerSize: AppDimensions.iconContainerSM,
                      color: AppColors.brandPurple,
                      backgroundColor: AppColors.surfaceLilac,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        memoryDate(item.occurredAt),
                        key: Key('memory-date-${item.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cardTitle,
                      ),
                    ),
                    PopupMenuButton<String>(
                      key: Key('memory-menu-${item.id}'),
                      tooltip: tr('Anı seçenekleri'),
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      iconColor: AppColors.muted,
                      onSelected: (action) => runMemoryAction(
                        context,
                        item,
                        action,
                        onChanged: onChanged,
                      ),
                      itemBuilder: (_) => memoryMenuItems(item),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: Space.md, top: 2),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.area.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: AppColors.brandLilac,
                            ),
                            const SizedBox(width: 3),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * .55,
                              ),
                              child: Text(
                                item.area,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.metadata,
                              ),
                            ),
                          ],
                        ),
                      if (item.mine && visibility != null)
                        MemoryPill(
                          visibility.label,
                          memoryVisibilityIcon(visibility),
                          key: Key('memory-visibility-${item.id}'),
                        ),
                      if (item.mine && item.hidden)
                        MemoryPill(
                          'Gizli',
                          Icons.visibility_off_outlined,
                          key: Key('memory-hidden-${item.id}'),
                          color: AppColors.textSecondary,
                          background: AppColors.surfaceSecondary,
                        ),
                    ],
                  ),
                ),
                if (item.body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: Space.sm,
                      right: Space.md,
                    ),
                    child: Text(
                      item.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(height: 1.45),
                    ),
                  ),
                if (item.media.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: Space.sm,
                      right: Space.md,
                    ),
                    child: MemoryPhotos(item.media),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The profile's Anılar tab: a person's memories newest event first, 20 per page, with "+ Anı Ekle" for the owner.
class MemoriesSection extends StatelessWidget {
  const MemoriesSection({
    super.key,
    required this.username,
    required this.own,
    this.refreshVersion = 0,
  });
  final String username;
  final bool own;
  final int refreshVersion;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return PagedContent<MemoryItem>(
      key: ValueKey((username, 'Anılar', store.memoriesVersion, refreshVersion)),
      fetch: (page) => store.memories!.list(username, page),
      id: (item) => item.id,
      builder: (context, items, footer, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (own)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: SecondaryButton(
                '+ Anı Ekle',
                tonal: true,
                key: const Key('memory-add'),
                onPressed: () async {
                  final saved = await openPage<MemoryItem>(
                    context,
                    '/memory-form',
                    const MemoryFormArgs(),
                  );
                  if (saved != null) store.memoriesChanged();
                },
              ),
            ),
          if (items.isEmpty && footer == null)
            EmptyState(
              own ? 'Henüz bir anın yok.' : 'Henüz paylaşılmış bir anı yok.',
              own
                  ? 'Önemli anlarını fotoğraflarıyla burada sakla.'
                  : 'Paylaşılan anılar burada görünür.',
              icon: Icons.auto_stories_outlined,
            ),
          for (final item in items) MemoryCard(item, key: ValueKey(item.id)),
          ?footer,
        ],
      ),
    );
  }
}
