import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../core/app_locale.dart';
import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/memories_api.dart';
import '../widgets/account_action.dart';
import '../widgets/common.dart';
import '../widgets/media_crop.dart';
import '../widgets/memory_widgets.dart';
import '../widgets/social.dart';
import '../widgets/translated_text.dart';

/// One memory in full: date, approximate place, text and the photo gallery. The owner can edit, hide / show, change the
/// visibility and delete it; everyone else can report it.
class MemoryDetailPage extends StatefulWidget {
  const MemoryDetailPage(this.id, {super.key});
  final int id;

  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends State<MemoryDetailPage> {
  MemoryItem? item;
  bool loading = true, gone = false;
  String? error;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  Future<void> load() async {
    if (error != null || !loading) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final fresh = await StoreScope.of(context).memories!.detail(widget.id);
      if (!mounted) return;
      setState(() {
        item = fresh;
        loading = false;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        loading = false;
        gone = failure.status == 404;
        error = gone ? null : failure.detail;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Bir sorun oluştu. Tekrar dene.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = item;
    return AppPage(
      title: tr('Anı'),
      actions: [
        if (current != null)
          PopupMenuButton<String>(
            key: const Key('memory-detail-menu'),
            tooltip: tr('Anı seçenekleri'),
            onSelected: (action) => runMemoryAction(
              context,
              current,
              action,
              detail: true,
              onChanged: load,
            ),
            itemBuilder: (_) => memoryMenuItems(current),
          )
        else
          const SizedBox(width: 48),
      ],
      child: current != null
          ? _content(context, current)
          : loading
          ? const LoadingState()
          : ListView(
              padding: Space.page,
              children: [
                gone
                    ? const EmptyState(
                        'Bu anı artık kullanılamıyor.',
                        'Silinmiş veya sana kapatılmış olabilir.',
                        icon: Icons.auto_stories_outlined,
                      )
                    : InlineState(
                        icon: Icons.wifi_off_outlined,
                        title: tr('Anı yüklenemedi'),
                        description: error ?? '',
                        actionLabel: 'Tekrar Dene',
                        onAction: load,
                      ),
              ],
            ),
    );
  }

  Widget _content(BuildContext context, MemoryItem memory) {
    final store = StoreScope.of(context);
    final visibility = memory.visibility;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: Space.page,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            key: const Key('memory-detail-header'),
            padding: const EdgeInsets.all(Space.lg),
            decoration: AppShape.encounterCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memoryDate(memory.occurredAt),
                  key: const Key('memory-detail-date'),
                  style: AppTypography.pageTitle,
                ),
                if (memory.area.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 17,
                        color: AppColors.brandPurple,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          memory.area,
                          key: const Key('memory-detail-place'),
                          style: AppTypography.secondaryBody,
                        ),
                      ),
                    ],
                  ),
                ],
                if (memory.mine && visibility != null) ...[
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      MemoryPill(
                        visibility.label,
                        memoryVisibilityIcon(visibility),
                        key: const Key('memory-detail-visibility'),
                      ),
                      if (memory.hidden)
                        const MemoryPill(
                          'Gizli',
                          Icons.visibility_off_outlined,
                          key: Key('memory-detail-hidden'),
                          color: AppColors.textSecondary,
                          background: Colors.white,
                        ),
                    ],
                  ),
                ],
                if (!memory.mine && memory.author != null) ...[
                  const SizedBox(height: Space.md),
                  InkWell(
                    onTap: () =>
                        openPage(context, '/profile', memory.author!.id),
                    child: Row(
                      children: [
                        Avatar(memory.author, size: 32),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            memory.author!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cardTitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (memory.body.isNotEmpty) ...[
            const SizedBox(height: Space.lg),
            Text(
              memory.body,
              key: const Key('memory-detail-body'),
              style: AppTypography.body.copyWith(fontSize: 16.5, height: 1.55),
            ),
          ],
          if (memory.media.isNotEmpty) ...[
            const SizedBox(height: Space.lg),
            // The shared gallery: every photo whole, in the shape it was cut to, with the 1/5 counter and the full viewer.
            ImageCarousel(
              [for (final photo in memory.media) photo.url],
              key: ValueKey('memory-gallery-${memory.id}'),
            ),
          ],
          if (memory.mine && memory.sourceType != null) ...[
            const SizedBox(height: Space.md),
            Row(
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    memory.sourceType == 'map_note'
                        ? 'Bir Harita Notundan oluşturuldu'
                        : 'Bir gönderiden oluşturuldu',
                    style: AppTypography.metadata,
                  ),
                ),
              ],
            ),
          ],
          if (memory.mine) ...[
            const SizedBox(height: Space.xl),
            PrimaryButton(
              'Düzenle',
              icon: Icons.edit_outlined,
              key: const Key('memory-edit'),
              onPressed: () =>
                  runMemoryAction(context, memory, 'edit', onChanged: load),
            ),
            const SizedBox(height: Space.sm),
            SecondaryButton(
              memory.hidden ? 'Tekrar Göster' : 'Gizle',
              icon: memory.hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              key: const Key('memory-hide'),
              onPressed: () => runMemoryAction(
                context,
                memory,
                memory.hidden ? 'show' : 'hide',
                onChanged: load,
              ),
            ),
            const SizedBox(height: Space.sm),
            SecondaryButton(
              'Görünürlüğü Değiştir',
              icon: Icons.lock_outline_rounded,
              key: const Key('memory-change-visibility'),
              onPressed: () => runMemoryAction(
                context,
                memory,
                'visibility',
                onChanged: load,
              ),
            ),
            const SizedBox(height: Space.sm),
            DestructiveButton(
              'Sil',
              key: const Key('memory-delete'),
              onPressed: () => runMemoryAction(
                context,
                memory,
                'delete',
                detail: true,
              ),
            ),
          ] else if (store.connected) ...[
            const SizedBox(height: Space.xl),
            SecondaryButton(
              'Şikâyet Et',
              icon: Icons.flag_outlined,
              onPressed: () => runMemoryAction(context, memory, 'report'),
            ),
          ],
        ],
      ),
    );
  }
}

/// New memory, memory made from a map note / post (prefilled, editable before saving) and the edit form. Saving a
/// memory only ever writes the memory: the post / map note it came from stays exactly as it is.
class MemoryFormPage extends StatefulWidget {
  const MemoryFormPage(this.args, {super.key});
  final MemoryFormArgs args;

  @override
  State<MemoryFormPage> createState() => _MemoryFormPageState();
}

class _MemoryFormPageState extends State<MemoryFormPage>
    with AccountAction<MemoryFormPage> {
  static const maxPhotos = 5;
  final text = TextEditingController();
  final picker = ImagePicker();
  final requestId = const Uuid().v4();
  late DateTime occurredAt;
  late MemoryVisibility visibility;
  ChosenPlace? place;
  String? areaLabel;
  bool placeChanged = false, started = false;
  List<MemorySlot> slots = [];
  String? error;

  MemoryItem? get editing => widget.args.edit;
  MemoryPrefill? get prefill => widget.args.prefill;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final memory = editing, source = prefill;
    if (memory != null) {
      text.text = memory.body;
      occurredAt = memory.occurredAt;
      visibility = memory.visibility ?? MemoryVisibility.private;
      place = memory.city == null
          ? null
          : ChosenPlace(memory.city!, place: memory.place);
      areaLabel = memory.area;
      slots = [for (final photo in memory.media) ExistingSlot(photo)];
    } else if (source != null) {
      text.text = source.body;
      occurredAt = source.occurredAt;
      visibility = source.visibility;
      place = source.city == null
          ? null
          : ChosenPlace(source.city!, place: source.place);
      areaLabel = source.placeLabel;
      slots = [
        for (final photo in source.photos.take(maxPhotos)) SourceSlot(photo),
      ];
    } else {
      final account = StoreScope.of(context).account;
      occurredAt = DateTime.now();
      place = account == null
          ? null
          : ChosenPlace(account.city, place: account.place);
      areaLabel = place?.label;
      final preferred =
          MemoryVisibility.parse(account?.memoryDefaultVisibility) ??
          MemoryVisibility.private;
      // "Bu Bölgedekiler" needs an area; without one a new memory starts private.
      visibility = preferred == MemoryVisibility.area && place == null
          ? MemoryVisibility.private
          : preferred;
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: occurredAt.isAfter(now) ? now : occurredAt,
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    var next = DateTime(
      picked.year,
      picked.month,
      picked.day,
      occurredAt.hour,
      occurredAt.minute,
    );
    if (next.isAfter(now)) next = now;
    setState(() => occurredAt = next);
  }

  Future<void> pickPlace() async {
    final chosen = await choosePlace(
      context,
      current: areaLabel,
      title: 'Anı nerede yaşandı?',
    );
    if (chosen == null || !mounted) return;
    setState(() {
      place = chosen;
      areaLabel = chosen.label;
      placeChanged = true;
    });
  }

  Future<void> addPhoto() async {
    final room = maxPhotos - slots.length;
    if (room <= 0) {
      toast(context, 'En fazla 5 fotoğraf ekleyebilirsin.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('memory-photo-gallery'),
              leading: const Icon(Icons.image_outlined),
              title: Text(tr('Galeriden Seç')),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
            ListTile(
              key: const Key('memory-photo-camera'),
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(tr('Fotoğraf Çek')),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final List<XFile> picked;
      if (source == ImageSource.camera || room == 1) {
        final one = await picker.pickImage(
          source: source,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 88,
        );
        picked = one == null ? [] : [one];
      } else {
        picked = await picker.pickMultiImage(
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 88,
          limit: room,
        );
      }
      if (picked.isEmpty || !mounted) return;
      // Every photo goes through the shared crop step (9:16 / 4:5 / 16:9) before it can be uploaded.
      final cropped = await cropPhotos(context, picked.take(room).toList());
      if (!mounted) return;
      setState(() {
        for (final file in cropped) {
          if (slots.length < maxPhotos) slots.add(FreshSlot(file));
        }
        error = null;
      });
    } on PlatformException {
      if (mounted) toast(context, 'Fotoğraf seçilemedi. Tekrar dene.');
    }
  }

  Future<void> save() async {
    final store = StoreScope.of(context);
    final body = text.text.trim();
    if (body.isEmpty && slots.isEmpty) {
      setState(() => error = 'Anı için bir metin yaz veya fotoğraf ekle.');
      return;
    }
    if (visibility == MemoryVisibility.area && place == null) {
      setState(() => error = 'Bu Bölgedekiler için bir yer seç.');
      return;
    }
    setState(() => error = null);
    await runAccountAction(() async {
      try {
        final api = store.memories!;
        final chosen = place;
        // Editing: the stored place is only replaced when a new one was picked.
        final sendPlace = editing == null || placeChanged;
        final saved = editing != null
            ? await api.update(
                editing!.id,
                body: body,
                occurredAt: occurredAt,
                visibility: visibility,
                slots: slots,
                placeId: sendPlace ? chosen?.placeId : null,
                cityId: sendPlace ? chosen?.city.id : null,
              )
            : await api.create(
                body: body,
                occurredAt: occurredAt,
                visibility: visibility,
                slots: slots,
                requestId: requestId,
                placeId: chosen?.placeId,
                cityId: chosen?.city.id,
                sourceType: prefill?.sourceType,
                sourceId: widget.args.sourceId,
              );
        if (mounted) Navigator.pop(context, saved);
      } on ApiFailure catch (failure) {
        if (!mounted) return;
        setState(
          () => error =
              failure.errors['body'] ??
              failure.errors['visibility'] ??
              failure.errors['media'] ??
              failure.errors['layout'] ??
              failure.errors['occurred_at'] ??
              failure.detail,
        );
      }
    });
  }

  Widget _photoTile(MemorySlot slot, int index) {
    const size = 88.0;
    final store = StoreScope.of(context);
    final Widget image = switch (slot) {
      ExistingSlot(:final media) => socialMediaImage(
        store,
        media.thumbUrl,
        fit: BoxFit.cover,
        width: size,
        height: size,
      ),
      SourceSlot(:final photo) => socialMediaImage(
        store,
        photo.url,
        fit: BoxFit.cover,
        width: size,
        height: size,
      ),
      FreshSlot(:final file) => Image.file(
        File(file.path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.image_outlined, color: AppColors.muted),
        ),
      ),
    };
    return Padding(
      key: ValueKey(slot.key),
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppShape.small),
                child: ColoredBox(
                  color: AppColors.surfaceSecondary,
                  child: image,
                ),
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: InkResponse(
                key: Key('memory-photo-remove-$index'),
                onTap: busy ? null : () => setState(() => slots.removeAt(index)),
                radius: 18,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: .72),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = editing != null;
    return AppPage(
      title: tr(isEdit ? 'Anıyı Düzenle' : 'Yeni Anı'),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The refusal sits right above the button the person just pressed (never off screen below the form).
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Text(
                error!,
                key: const Key('memory-error'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.red, fontSize: 13.5),
              ),
            ),
          PrimaryButton(
            isEdit ? 'Kaydet' : 'Anıyı Kaydet',
            key: const Key('memory-save'),
            icon: busy ? null : Icons.check_rounded,
            onPressed: busy ? null : save,
          ),
        ],
      ),
      child: ListView(
        padding: Space.page,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (prefill != null)
            const Padding(
              padding: EdgeInsets.only(bottom: Space.md),
              child: InfoNote(
                'Kaydetmeden önce her şeyi değiştirebilirsin. Kaynak içerik aynen kalır.',
                icon: Icons.auto_stories_outlined,
              ),
            ),
          TextField(
            key: const Key('memory-text'),
            controller: text,
            minLines: 4,
            maxLines: 9,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: tr('Anı'),
              hintText: tr('Bu anıyı neden saklamak istiyorsun?'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: Space.sm),
          SettingsRow(
            'Olay tarihi',
            Icons.event_outlined,
            subtitle: memoryDate(occurredAt),
            onTap: busy ? null : pickDate,
            key: const Key('memory-date-row'),
          ),
          SettingsRow(
            'Yaklaşık yer',
            Icons.location_on_outlined,
            subtitle: (areaLabel ?? '').isEmpty
                ? tr('Yer seç')
                : areaLabel,
            onTap: busy ? null : pickPlace,
            key: const Key('memory-place-row'),
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  trf('Fotoğraflar ({0}/{1})', [slots.length, maxPhotos]),
                  key: const Key('memory-photo-count'),
                  style: AppTypography.section,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The add tile stays put at the start, so it is never scrolled away by a full row of photos.
                if (slots.length < maxPhotos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      key: const Key('memory-add-photo'),
                      onTap: busy ? null : addPhoto,
                      borderRadius: BorderRadius.circular(AppShape.small),
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLilac,
                          borderRadius: BorderRadius.circular(AppShape.small),
                          border: Border.all(color: AppColors.borderLilac),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: AppColors.brandPurple,
                            ),
                            SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Fotoğraf Ekle',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ReorderableListView.builder(
                    key: const Key('memory-photo-list'),
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: true,
                    itemCount: slots.length,
                    onReorderItem: (from, to) => setState(() {
                      slots.insert(to, slots.removeAt(from));
                    }),
                    proxyDecorator: (child, _, _) =>
                        Material(color: Colors.transparent, child: child),
                    itemBuilder: (_, index) => _photoTile(slots[index], index),
                  ),
                ),
              ],
            ),
          ),
          if (slots.length > 1)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Sıralamak için bir fotoğrafı basılı tutup sürükle.',
                style: AppTypography.metadata,
              ),
            ),
          const SizedBox(height: Space.lg),
          const Text('Görünürlük', style: AppTypography.section),
          const SizedBox(height: Space.sm),
          MemoryVisibilityList(
            value: visibility,
            onChanged: busy ? (_) {} : (v) => setState(() => visibility = v),
          ),
          const SizedBox(height: Space.lg),
        ],
      ),
    );
  }
}
