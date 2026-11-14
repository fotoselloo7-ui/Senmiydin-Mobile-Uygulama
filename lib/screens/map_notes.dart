import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../widgets/translated_text.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../data/map_notes_api.dart';
import '../data/social_api.dart';
import '../widgets/account_action.dart';
import '../widgets/common.dart';
import '../widgets/map_attribution.dart';
import '../widgets/map_note_widgets.dart';
import '../widgets/social_page.dart';
import '../core/app_locale.dart';

/// "Bu noktaya bırakılan notlar": every active note at one approximate point, newest first.
class MapNotePointPage extends StatefulWidget {
  const MapNotePointPage(this.group, {super.key, this.label = ''});
  final String group;
  final String label;
  @override
  State<MapNotePointPage> createState() => _MapNotePointPageState();
}

class _MapNotePointPageState extends State<MapNotePointPage> {
  int count = 0;
  String place = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppPage(
      title: 'Bu noktaya bırakılan notlar',
      child: PagedContent<MapNoteItem>(
        id: (note) => note.id,
        fetch: (page) async {
          final result = await store.mapNotes!.point(widget.group, page);
          if (mounted &&
              (result.count != count || result.placeLabel != place)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  count = result.count;
                  place = result.placeLabel;
                });
              }
            });
          }
          return SocialPage(result.items, result.nextPage);
        },
        builder: (context, notes, footer, refresh) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: Space.page,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Text(
                  count == 0
                      ? (place.isEmpty ? widget.label : place)
                      : trf('{0} · {1} not', [place.isEmpty ? widget.label : place, count]),
                  textAlign: TextAlign.center,
                  style: AppTypography.secondaryBody,
                ),
              ),
              if (notes.isEmpty && footer == null)
                const EmptyState(
                  'Bu noktada artık not yok.',
                  'Notların süresi 7 gün sonra dolar.',
                  icon: Icons.mail_outline_rounded,
                ),
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: MapNoteLetter(
                    note,
                    showPlace: false,
                    onTap: () async {
                      await openPage(context, '/map-note', note.id);
                      if (context.mounted) await refresh();
                    },
                  ),
                ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// A single letter with its public reply thread (oldest first) and the reply composer.
class MapNoteDetailPage extends StatefulWidget {
  const MapNoteDetailPage(this.noteId, {super.key, this.mine = false});
  final int noteId;

  /// Opened from Mektuplarım: the owner's private view (also for archived letters and their old thread).
  final bool mine;
  @override
  State<MapNoteDetailPage> createState() => _MapNoteDetailPageState();
}

class _MapNoteDetailPageState extends State<MapNoteDetailPage>
    with AccountAction<MapNoteDetailPage> {
  MapNoteItem? note;
  final replies = <MapNoteReplyItem>[];
  int? nextPage;
  bool loading = true, unavailable = false, loadingMore = false;
  String? error;
  final text = TextEditingController();
  bool anonymousReply = false;
  bool sending = false;
  String? sendError;
  String requestId = const Uuid().v4();
  String repostRequestId = const Uuid().v4();

  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      unawaited(load());
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (!loading || error != null) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final store = StoreScope.of(context);
      final detail = widget.mine
          ? await store.mapNotes!.mineDetail(widget.noteId)
          : await store.mapNotes!.detail(widget.noteId);
      if (!mounted) return;
      // Opening the detail is the only thing that counts as reading (never a marker coming into view).
      if (!widget.mine && !detail.note.mine) {
        unawaited(store.markMapNoteRead(detail.note.id));
      }
      setState(() {
        note = detail.note;
        replies
          ..clear()
          ..addAll(detail.replies.items);
        nextPage = detail.replies.nextPage;
        loading = false;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        loading = false;
        unavailable = failure.status == 404;
        error = failure.status == 404 ? null : failure.detail;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Bir sorun oluştu. Tekrar dene.';
      });
    }
  }

  Future<void> loadMore() async {
    final page = nextPage;
    if (page == null || loadingMore) return;
    setState(() => loadingMore = true);
    try {
      final result = await StoreScope.of(context).mapNotes!
          .replies(widget.noteId, page);
      if (!mounted) return;
      setState(() {
        final seen = replies.map((r) => r.id).toSet();
        replies.addAll(result.items.where((r) => seen.add(r.id)));
        nextPage = result.nextPage;
        loadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loadingMore = false);
        toast(context, 'Yanıtlar yüklenemedi. Tekrar dene.');
      }
    }
  }

  Future<void> send() async {
    final body = text.text.trim();
    final current = note;
    if (body.isEmpty || sending || current == null) return;
    setState(() {
      sending = true;
      sendError = null;
    });
    try {
      final reply = await StoreScope.of(context).mapNotes!.reply(
        current.id,
        body,
        anonymous: ownerOfAnonymous(current) || anonymousReply,
        requestId: requestId,
      );
      if (!mounted) return;
      text.clear();
      requestId = const Uuid().v4();
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        sending = false;
        replies.add(reply);
        note = current.withReplyCount(current.replyCount + 1);
      });
    } on ApiFailure catch (failure) {
      // The text is kept so the reader can retry; the same request id keeps a retry idempotent.
      if (mounted) {
        setState(() {
          sending = false;
          sendError = failure.status == 404
              ? mapNoteUnavailable
              : failure.errors['body'] ?? failure.detail;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          sending = false;
          sendError = 'Yanıt gönderilemedi. Tekrar dene.';
        });
      }
    }
  }

  bool ownerOfAnonymous(MapNoteItem item) => item.mine && item.anonymous;

  /// "Haritadan Kaldır": the letter leaves the public map but stays in Mektuplarım → Arşiv.
  Future<void> archiveNote(MapNoteItem item) async {
    final store = StoreScope.of(context);
    final confirmed = await confirmAction(
      context,
      title: tr('Mektubu haritadan kaldıralım mı?'),
      message: 'Mektup herkese kapanır ve Mektuplarım → Arşiv’e taşınır. İstediğin zaman tekrar paylaşabilirsin.',
      action: 'Haritadan Kaldır',
    );
    if (!confirmed || !mounted) return;
    runAccountAction(() async {
      await store.mapNotes!.archive(item.id);
      store.mapNotesChanged();
      if (!mounted) return;
      toast(context, 'Mektup haritadan kaldırıldı. Mektuplarım → Arşiv’de.');
      if (widget.mine) {
        await load();
      } else {
        Navigator.pop(context, true);
      }
    });
  }

  /// "Tekrar Paylaş": a new public publication with a fresh 7 days; the letter's real date stays.
  Future<void> repostNote(MapNoteItem item) async {
    final store = StoreScope.of(context);
    runAccountAction(() async {
      await store.mapNotes!.repost(item.id, requestId: repostRequestId);
      repostRequestId = const Uuid().v4();
      store.mapNotesChanged();
      if (!mounted) return;
      toast(context, 'Mektubun yeniden haritada. Yeni 7 günü başladı.');
      await load();
    });
  }

  /// "Kalıcı Sil": letter, replies and every personal access are erased.
  Future<void> deleteNote(MapNoteItem item) async {
    final store = StoreScope.of(context);
    final confirmed = await confirmAction(
      context,
      title: 'Mektup kalıcı olarak silinsin mi?',
      message: 'Mektup, yanıtları ve arşivdeki kaydı tamamen silinir. Bu işlem geri alınamaz.',
      action: 'Kalıcı Sil',
    );
    if (!confirmed || !mounted) return;
    runAccountAction(() async {
      await store.mapNotes!.deleteNote(item.id);
      store.mapNotesChanged();
      if (mounted) {
        Navigator.pop(context, true);
        toast(context, 'Mektup kalıcı olarak silindi.');
      }
    });
  }

  Future<void> deleteReply(MapNoteReplyItem reply) async {
    final store = StoreScope.of(context);
    runAccountAction(() async {
      await store.mapNotes!.deleteReply(reply.id);
      if (mounted) {
        setState(() {
          replies.removeWhere((r) => r.id == reply.id);
          final current = note;
          if (current != null && current.replyCount > 0) {
            note = current.withReplyCount(current.replyCount - 1);
          }
        });
        toast(context, 'Yanıtın kaldırıldı.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = note;
    return AppPage(
      title: tr('Harita Notu'),
      child: loading
          ? const Padding(
              padding: Space.page,
              child: LoadingState(label: 'Not yükleniyor'),
            )
          : unavailable
          ? const EmptyState(
              mapNoteUnavailable,
              'Süresi dolmuş, silinmiş veya artık görüntülenemiyor olabilir.',
              icon: Icons.mail_outline_rounded,
            )
          : error != null || item == null
          ? Padding(
              padding: Space.page,
              child: InlineState(
                icon: Icons.wifi_off_outlined,
                title: 'Not yüklenemedi',
                description: error,
                actionLabel: 'Tekrar Dene',
                onAction: load,
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: Space.page,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        MapNoteLetter(
                          item,
                          actions: [
                            if (item.mine && item.isActive)
                              TextButton.icon(
                                key: const Key('archive-map-note'),
                                onPressed: busy
                                    ? null
                                    : () => archiveNote(item),
                                icon: const Icon(
                                  Icons.visibility_off_outlined,
                                  size: 18,
                                ),
                                label: const Text('Haritadan Kaldır'),
                              )
                            else if (item.mine) ...[
                              if (item.canRepost)
                                TextButton.icon(
                                  key: const Key('repost-map-note'),
                                  onPressed: busy
                                      ? null
                                      : () => repostNote(item),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Tekrar Paylaş'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.brandPurple,
                                  ),
                                )
                              else if (item.hasLiveRepost)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text(
                                    'Tekrar paylaşıldı · haritada',
                                    style: AppTypography.metadata,
                                  ),
                                ),
                              TextButton.icon(
                                key: const Key('delete-map-note'),
                                onPressed: busy ? null : () => deleteNote(item),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text('Kalıcı Sil'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                ),
                              ),
                            ] else
                              TextButton.icon(
                                key: const Key('report-map-note'),
                                onPressed: () => openPage(
                                  context,
                                  '/report',
                                  ReportTarget(
                                    'map_note',
                                    item.id,
                                    'Harita notu',
                                  ),
                                ),
                                icon: const Icon(Icons.flag_outlined, size: 18),
                                label: const Text('Şikâyet Et'),
                              ),
                          ],
                        ),
                        const SizedBox(height: Space.lg),
                        Text(
                          replies.isEmpty
                              ? 'Henüz yanıt yok'
                              : trf('{0} yanıt', [item.replyCount]),
                          style: AppTypography.section,
                        ),
                        const SizedBox(height: Space.sm),
                        if (replies.isEmpty)
                          InfoNote(
                            item.canReply
                                ? 'Bu nota ilk yanıtı sen yazabilirsin. Yanıtlar herkese açıktır.'
                                : 'Bu mektuba henüz yanıt gelmemiş.',
                          ),
                        for (final reply in replies)
                          MapNoteReplyTile(
                            reply,
                            onDelete: reply.mine
                                ? () => deleteReply(reply)
                                : null,
                            onReport: reply.mine
                                ? null
                                : () => openPage(
                                    context,
                                    '/report',
                                    ReportTarget(
                                      'map_note_reply',
                                      reply.id,
                                      'Not yanıtı',
                                    ),
                                  ),
                          ),
                        if (nextPage != null)
                          Center(
                            child: TextButton(
                              onPressed: loadingMore ? null : loadMore,
                              child: Text(
                                loadingMore
                                    ? 'Yükleniyor…'
                                    : 'Daha Fazla Yanıt Göster',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (item.canReply) composer(item),
              ],
            ),
    );
  }

  Widget composer(MapNoteItem item) => Material(
    color: Colors.white,
    elevation: 6,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ownerOfAnonymous(item))
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Not sahibi olarak yanıtlarsın; kimliğin görünmez.',
                  style: AppTypography.metadata,
                ),
              )
            else
              ChoicePills(
                options: const ['Açık yanıt', 'Anonim yanıt'],
                value: anonymousReply ? 'Anonim yanıt' : 'Açık yanıt',
                onChanged: (value) =>
                    setState(() => anonymousReply = value == 'Anonim yanıt'),
              ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('map-note-reply-field'),
                    controller: text,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: tr('Yanıtla…'),
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() => sendError = null),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('send-map-note-reply'),
                  tooltip: tr('Yanıtı gönder'),
                  onPressed: sending || text.text.trim().isEmpty ? null : send,
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                ),
              ],
            ),
            if (sendError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  trf('{0} Yazdığın metin korunur; tekrar deneyebilirsin.', [sendError]),
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// "Buraya Not Bırak": write a letter and pin it to an approximate point chosen on the map.
class MapNoteComposePage extends StatefulWidget {
  const MapNoteComposePage({super.key, this.center, this.zoom});
  final LatLng? center;
  final double? zoom;
  @override
  State<MapNoteComposePage> createState() => _MapNoteComposePageState();
}

class _MapNoteComposePageState extends State<MapNoteComposePage>
    with AccountAction<MapNoteComposePage> {
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  final text = TextEditingController();
  final controller = MapController();
  bool anonymous = false, sending = false;
  late LatLng picked = widget.center ?? const LatLng(39, 35);
  String? error;
  final requestId = const Uuid().v4();

  @override
  void dispose() {
    text.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> submit(AppStore store) async {
    final body = text.text.trim();
    if (body.isEmpty) {
      setState(() => error = 'Notunu yaz.');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      // The server snaps the point to its own grid and answers with the final coordinate; that answer, not
      // the local selection, is what the map shows next.
      final created = await store.mapNotes!.create(
        body: body,
        anonymous: anonymous,
        cityId: await store.cityId(store.city),
        latitude: picked.latitude,
        longitude: picked.longitude,
        requestId: requestId,
      );
      if (mounted) {
        Navigator.pop(context, created);
        toast(context, 'Notun haritaya bırakıldı.');
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          sending = false;
          error =
              failure.errors['latitude'] ??
              failure.errors['body'] ??
              failure.detail;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          sending = false;
          error = 'Not gönderilemedi. Tekrar dene.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppPage(
      title: tr('Buraya Not Bırak'),
      child: SingleChildScrollView(
        padding: Space.page,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Birini bulamadıysan, geçtiğiniz yere bir not bırak. Not 7 gün boyunca haritada herkese açık kalır.',
              style: AppTypography.secondaryBody,
            ),
            const SizedBox(height: Space.lg),
            Container(
              decoration: BoxDecoration(
                color: mapNotePaper,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderLilac),
              ),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: TextField(
                key: const Key('map-note-field'),
                controller: text,
                minLines: 5,
                maxLines: 9,
                maxLength: 700,
                decoration: InputDecoration(
                  hintText: tr('Notunu yaz…'),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: (_) => setState(() => error = null),
              ),
            ),
            const SizedBox(height: Space.md),
            ChoicePills(
              options: const ['Açık not', 'Anonim not'],
              value: anonymous ? 'Anonim not' : 'Açık not',
              onChanged: (value) =>
                  setState(() => anonymous = value == 'Anonim not'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: Space.md),
              child: Text(
                anonymous
                    ? 'Adın, kullanıcı adın ve profilin notta görünmez.'
                    : 'Adın ve profilin notta görünür.',
                style: AppTypography.metadata,
              ),
            ),
            const SectionHeader(
              'Yaklaşık yer',
              icon: Icons.location_on_outlined,
            ),
            const Text(
              'Haritayı kaydırarak mor noktayı notun yerine getir. Not, seçtiğin noktaya yakın yaklaşık bir bölgeye bırakılır; kesin adres paylaşılmaz.',
              style: AppTypography.metadata,
            ),
            const SizedBox(height: Space.sm),
            ClipRRect(
              borderRadius: AppShape.rounded,
              child: SizedBox(
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FlutterMap(
                      mapController: controller,
                      options: MapOptions(
                        initialCenter: picked,
                        initialZoom:
                            widget.zoom ?? (widget.center == null ? 5 : 14),
                        minZoom: 4,
                        maxZoom: 17,
                        backgroundColor: AppColors.pale,
                        onPositionChanged: (camera, _) {
                          picked = camera.center;
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: tileUrl,
                          userAgentPackageName: 'com.senmiydin.app',
                          panBuffer: 0,
                        ),
                        const MapAttribution(),
                      ],
                    ),
                    // The saved coordinate is exactly the map centre, so the target dot sits exactly there; the
                    // envelope is lifted above it and never moves the selection.
                    IgnorePointer(
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -26),
                            child: Icon(
                              Icons.mail_outline_rounded,
                              size: 34,
                              color: AppColors.brandPurple,
                              semanticLabel: tr('Seçilen yaklaşık yer'),
                            ),
                          ),
                          Container(
                            key: const Key('map-note-target'),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.brandPurple,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brandPurple.withValues(
                                    alpha: .35,
                                  ),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Text(
                  error!,
                  key: const Key('map-note-error'),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            PrimaryButton(
              sending ? 'Bırakılıyor…' : 'Notu Bırak',
              icon: Icons.mail_outline_rounded,
              onPressed: sending ? null : () => submit(store),
            ),
            const SizedBox(height: Space.xl),
          ],
        ),
      ),
    );
  }
}

/// "Mektuplarım": the owner's own letters. Aktif = still public (7 days), Arşiv = expired or taken off the map (private).
class MyLettersPage extends StatefulWidget {
  const MyLettersPage({super.key});
  @override
  State<MyLettersPage> createState() => _MyLettersPageState();
}

class _MyLettersPageState extends State<MyLettersPage> {
  String scope = 'Aktif';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final archive = scope == 'Arşiv';
    return AppPage(
      title: tr('Mektuplarım'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ChoicePills(
                options: const ['Aktif', 'Arşiv'],
                value: scope,
                onChanged: (value) => setState(() => scope = value),
              ),
            ),
          ),
          Expanded(
            child: PagedContent<MapNoteItem>(
              key: ValueKey((scope, store.mapNotesVersion)),
              fetch: (page) =>
                  store.mapNotes!.mine(archive ? 'archive' : 'active', page),
              id: (note) => note.id,
              builder: (context, notes, footer, refresh) => RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: Space.page,
                  children: [
                    Text(
                      archive
                          ? 'Süresi dolan veya haritadan kaldırdığın mektuplar burada yalnızca sana görünür.'
                          : 'Haritada herkese açık olan mektupların. Her biri bırakıldıktan 7 gün sonra haritadan kalkar.',
                      style: AppTypography.metadata,
                    ),
                    const SizedBox(height: Space.md),
                    if (notes.isEmpty && footer == null)
                      EmptyState(
                        archive
                            ? 'Arşivin henüz boş.'
                            : 'Haritada aktif mektubun yok.',
                        archive
                            ? 'Süresi dolan mektupların burada saklanır; istediğinde tekrar paylaşabilirsin.'
                            : 'Haritada bir yere not bıraktığında burada görünür.',
                        icon: Icons.mail_outline_rounded,
                      ),
                    for (final note in notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.md),
                        child: MyLetterCard(
                          note,
                          onTap: () async {
                            await openPage(context, '/my-letter', '${note.id}');
                            if (context.mounted) store.mapNotesChanged();
                          },
                        ),
                      ),
                    ?footer,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
