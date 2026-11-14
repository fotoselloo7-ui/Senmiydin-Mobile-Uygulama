import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import '../widgets/translated_text.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/location_api.dart';
import '../data/map_notes_api.dart';
import '../widgets/common.dart';
import '../widgets/location_ui.dart';
import '../widgets/map_attribution.dart';
import '../widgets/map_note_widgets.dart';
import '../core/app_locale.dart';

enum _MapMode { people, posts, notes }

class LiveMapContent extends StatefulWidget {
  const LiveMapContent({super.key});
  @override
  State<LiveMapContent> createState() => _LiveMapContentState();
}

class _LiveMapContentState extends State<LiveMapContent> {
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  final mapController = MapController();
  _MapMode mode = _MapMode.posts;
  bool tileUnavailable = false;
  bool get posts => mode == _MapMode.posts;
  int tileRevision = 0;
  Object? query, noteQuery;
  Future<LocationResults<MapPostPoint>>? request;

  // Map notes live in plain state (not in a FutureBuilder) so the FlutterMap is never unmounted while the markers
  // refresh: the camera must survive every reload. Responses are matched by token, newest request wins.
  List<MapNoteMarker> noteMarkers = const [];
  bool noteLoading = false,
      noteLocationRequired = false,
      needsInitialFocus = true;
  String? noteError, highlightGroup;
  int noteToken = 0;
  Timer? highlightTimer;
  Timer? debounce;
  bool consumedHomeRequest = false;

  /// An approximate point another screen asked this map to show ("Haritada Aç" in a chat, "Haritada Gör" in an
  /// announcement). Shown with a pin; the camera moves there once.
  LatLng? focusPoint;
  bool moveToFocus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!consumedHomeRequest) {
      consumedHomeRequest = true;
      // The Home card "Yakınında N yeni mektup var" opens the map straight in its Notlar view.
      final store = StoreScope.of(context);
      if (store.mapFocus case final focus?) {
        store.mapFocus = null;
        focusPoint = focus;
        moveToFocus = true;
      }
      if (store.openMapInNotes && store.mapNotes != null) {
        store.openMapInNotes = false;
        mode = _MapMode.notes;
      }
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    highlightTimer?.cancel();
    mapController.dispose();
    super.dispose();
  }

  void requestData(AppStore store, Object key) {
    query = key;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          request = store.loadMap();
        });
      }
    });
  }

  void requestNotes(AppStore store, Object key) {
    noteQuery = key;
    final token = ++noteToken;
    noteLoading = true;
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 250),
      () => loadNotes(store, token),
    );
  }

  Future<void> loadNotes(AppStore store, int token) async {
    if (!mounted || token != noteToken) return;
    try {
      final data = await store.loadMapNotes();
      // A newer request (or a fresh create) owns the screen.
      if (!mounted || token != noteToken) return;
      setState(() {
        noteMarkers = data.items;
        noteLocationRequired = data.locationRequired;
        noteError = null;
        noteLoading = false;
      });
    } on ApiFailure catch (error) {
      if (mounted && token == noteToken) {
        setState(() {
          noteError = error.detail;
          noteLoading = false;
        });
      }
    } catch (_) {
      if (mounted && token == noteToken) {
        setState(() {
          noteError = 'Bir sorun oluştu. Tekrar dene.';
          noteLoading = false;
        });
      }
    }
  }

  /// "Buraya Not Bırak": the composer returns the server's authoritative note, never its own guess.
  Future<void> leaveNote() async {
    final camera = mapController.camera;
    final created = await openPage<MapNoteItem>(context, '/map-note-compose', (
      camera.center,
      camera.zoom,
    ));
    if (!mounted || created == null) return;
    final store = StoreScope.of(context);
    final target = LatLng(created.latitude, created.longitude);
    noteToken++; // anything still in flight was requested before this note existed
    final index = noteMarkers.indexWhere((m) => m.group == created.group);
    final existing = index < 0 ? null : noteMarkers[index];
    final marker = MapNoteMarker(
      group: created.group,
      latitude: created.latitude,
      longitude: created.longitude,
      count: (existing?.count ?? 0) + 1,
      newestAt: created.createdAt,
    );
    highlightTimer?.cancel();
    setState(() {
      mode = _MapMode.notes;
      noteLocationRequired = false;
      noteError = null;
      noteMarkers = [
        marker,
        for (final (i, m) in noteMarkers.indexed)
          if (i != index) m,
      ];
      highlightGroup = created.group;
    });
    mapController.move(target, math.max(mapController.camera.zoom, 14));
    highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => highlightGroup = null);
    });
    store.mapNotesChanged(); // reload the real markers; the optimistic one above is replaced, not duplicated
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final key = (
      store.city,
      store.radiusMeters,
      store.filter.sort,
      store.locationVersion,
      store.postsVersion,
      store.location?.synced,
    );
    if (mode == _MapMode.notes) {
      final noteKey = (
        store.city,
        store.radiusMeters,
        store.locationVersion,
        store.mapNotesVersion,
        store.location?.synced,
      );
      if (noteQuery != noteKey) requestNotes(store, noteKey);
    } else if (query != key) {
      requestData(store, key);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Şehrinde bir iz bul.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${store.city} · ${tr('Yaklaşık konumlar')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('Haritayı yenile'),
                onPressed: () => setState(() {
                  query = null;
                  tileUnavailable = false;
                  tileRevision++;
                }),
                icon: const Icon(Icons.refresh, color: AppColors.action),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ChoicePills(
            options: const ['Tüm şehir', '5 km', '10 km', '25 km'],
            value: store.filter.range,
            onChanged: (value) {
              store.applyFilter(
                store.filter.copy()
                  ..range = value
                  ..nearbyOnly = false,
              );
              if (value != 'Tüm şehir' && store.location?.synced != true) {
                unawaited(store.location?.activateFromUi());
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // The three tabs shrink a little on very narrow screens instead of being cut off.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => mode = _MapMode.people),
                  icon: const Icon(Icons.people_outline),
                  label: Text(
                    'İnsanlar',
                    style: TextStyle(
                      color: mode == _MapMode.people
                          ? AppColors.blue
                          : AppColors.muted,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => mode = _MapMode.posts),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    'Paylaşımlar',
                    style: TextStyle(
                      color: posts ? AppColors.blue : AppColors.muted,
                    ),
                  ),
                ),
                if (store.mapNotes != null)
                  TextButton.icon(
                    key: const Key('map-notes-tab'),
                    onPressed: () => setState(() {
                      mode = _MapMode.notes;
                      noteQuery = null;
                      needsInitialFocus = true;
                    }),
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Notlar',
                          style: TextStyle(
                            color: mode == _MapMode.notes
                                ? AppColors.brandPurple
                                : AppColors.muted,
                          ),
                        ),
                        // Private count of unopened letters near the user (never visible to anyone else).
                        if (store.nearbyNotesEnabled &&
                            store.nearbyUnread.visible)
                          Container(
                            key: const Key('notes-unread-badge'),
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPurple,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${store.nearbyUnread.count} yeni',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: AppShape.rounded,
              child: mode == _MapMode.notes
                  ? notesView(store)
                  : FutureBuilder(
                      future: request,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting ||
                            request == null) {
                          return const Padding(
                            padding: Space.page,
                            child: LoadingState(
                              key: Key('map-loading'),
                              label: 'Harita yükleniyor',
                            ),
                          );
                        }
                        final error = snapshot.error;
                        if (error != null) {
                          return EmptyState(
                            error is ApiFailure
                                ? error.detail
                                : 'Harita yüklenemedi.',
                            'Tekrar deneyebilirsin.',
                            action: SecondaryButton(
                              'Tekrar Dene',
                              onPressed: () => setState(() => query = null),
                            ),
                          );
                        }
                        final data =
                            snapshot.data ??
                            const LocationResults<MapPostPoint>([]);
                        if (data.permissionRequired) {
                          return EmptyState(
                            'Mesafe filtresi için cihaz konumu gerekli.',
                            store.location!.state.message,
                            action: SecondaryButton(
                              'Konumu Kontrol Et',
                              onPressed: store.location!.activateFromUi,
                            ),
                          );
                        }
                        return map(store, data.items);
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget notesView(AppStore store) {
    if (noteLocationRequired) {
      return EmptyState(
        'Mesafe filtresi için cihaz konumu gerekli.',
        store.location!.state.message,
        action: SecondaryButton(
          'Konumu Kontrol Et',
          onPressed: store.location!.activateFromUi,
        ),
      );
    }
    // The map stays mounted for loading, errors and refreshes, so the camera (and the new note) never disappear.
    return map(store, const [], notes: noteMarkers);
  }

  void openNotePoint(MapNoteMarker marker) {
    openPage(context, '/map-notes', (marker.group, marker.count));
  }

  Widget map(
    AppStore store,
    List<MapPostPoint> points, {
    List<MapNoteMarker> notes = const [],
  }) {
    final empty = points.isEmpty && notes.isEmpty;
    final location = store.location!;
    final position = location.allowed ? location.position : null;
    final own =
        position != null &&
            (store.activeCity?.name ?? store.account?.city.name) == store.city
        ? LatLng(
            (position.latitude * 200).round() / 200,
            (position.longitude * 200).round() / 200,
          )
        : null;
    final center =
        own ??
        (empty
            ? const LatLng(39, 35)
            : points.isEmpty
            ? LatLng(notes.first.latitude, notes.first.longitude)
            : LatLng(points.first.latitude, points.first.longitude));
    if (mode == _MapMode.notes && needsInitialFocus && !noteLoading) {
      // First load of this view: without a device position the map would sit on the country view (z5).
      needsInitialFocus = false;
      if (own == null && notes.isNotEmpty) {
        final first = LatLng(notes.first.latitude, notes.first.longitude);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) mapController.move(first, 12);
        });
      }
    }
    if (moveToFocus && focusPoint != null) {
      moveToFocus = false;
      needsInitialFocus = false;
      final target = focusPoint!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mapController.move(target, 15);
      });
    }
    final groups = <(double, double), List<MapPostPoint>>{};
    for (final point in points) {
      (groups[(point.latitude, point.longitude)] ??= []).add(point);
    }
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          key: ValueKey((
            store.city,
            store.radiusMeters,
            mode == _MapMode.notes ? false : own == null && empty,
          )),
          options: MapOptions(
            initialCenter: center,
            initialZoom: own == null && empty
                ? 5
                : switch (store.radiusMeters) {
                    5000 => 12,
                    10000 => 11,
                    25000 => 10,
                    _ => 12,
                  },
            minZoom: 4,
            maxZoom: 17,
            backgroundColor: AppColors.pale,
          ),
          children: [
            TileLayer(
              key: ValueKey(tileRevision),
              errorTileCallback: (_, _, _) {
                if (!mounted || tileUnavailable) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !tileUnavailable) {
                    setState(() => tileUnavailable = true);
                  }
                });
              },
              evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
              urlTemplate: tileUrl,
              userAgentPackageName: 'com.senmiydin.app',
              panBuffer: 0,
            ),
            if (focusPoint case final focus?)
              MarkerLayer(
                markers: [
                  Marker(
                    point: focus,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on_rounded,
                      key: Key('map-focus-pin'),
                      size: 44,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (posts)
                  for (final group in groups.entries)
                    Marker(
                      point: LatLng(group.key.$1, group.key.$2),
                      width: AppDimensions.touch,
                      height: AppDimensions.touch,
                      child: IconButton(
                        key: ValueKey('map-post-${group.value.first.id}'),
                        tooltip: 'Haritadaki paylaşım',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.blue,
                        ),
                        icon: group.value.length == 1
                            ? const Icon(Icons.location_on)
                            : Text(
                                '${group.value.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                        onPressed: () => openGroup(group.value),
                      ),
                    ),
                if (mode == _MapMode.notes)
                  for (final note in notes)
                    Marker(
                      point: LatLng(note.latitude, note.longitude),
                      width: AppDimensions.touch,
                      height: AppDimensions.touch,
                      child: MapNotePin(
                        key: ValueKey('map-note-${note.group}'),
                        count: note.count,
                        highlighted: note.group == highlightGroup,
                        onPressed: () => openNotePoint(note),
                      ),
                    ),
                if (own != null)
                  Marker(
                    point: own,
                    width: 42,
                    height: 42,
                    child: const Tooltip(
                      message: 'Yaklaşık konumun',
                      child: CircleAvatar(
                        backgroundColor: AppColors.action,
                        child: Icon(Icons.my_location, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const MapAttribution(),
          ],
        ),
        if (tileUnavailable)
          Positioned(
            left: Space.md,
            right: 76,
            // Above the note button in notes mode, beside the location button otherwise.
            bottom: mode == _MapMode.notes ? 84 : Space.md,
            child: Material(
              color: Colors.white,
              borderRadius: AppShape.rounded,
              child: Padding(
                padding: const EdgeInsets.only(left: Space.md),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Harita görselleri yüklenemedi.',
                        style: AppTypography.metadata,
                      ),
                    ),
                    IconButton(
                      tooltip: tr('Haritayı tekrar yükle'),
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(() {
                        tileUnavailable = false;
                        tileRevision++;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          right: Space.md,
          bottom: Space.md,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: IconButton(
              tooltip: own == null
                  ? 'Cihaz konumunu kontrol et'
                  : 'Bulunduğum bölgeye dön',
              color: AppColors.action,
              icon: const Icon(Icons.my_location_outlined),
              onPressed: own == null
                  ? location.activateFromUi
                  : () => mapController.move(own, 13),
            ),
          ),
        ),
        if (mode == _MapMode.people)
          Positioned(
            top: MapAttribution.clearance,
            left: 8,
            right: 8,
            child: NearbyResults(
              limit: 12,
              builder: (context, people, status, retry) => Material(
                borderRadius: AppShape.rounded,
                child: status != null
                    ? TextButton(onPressed: retry, child: Text(status))
                    : SizedBox(
                        height:
                            84 +
                            28 *
                                (MediaQuery.textScalerOf(context).scale(1) - 1),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          children: [
                            for (final entry in people)
                              Padding(
                                padding: const EdgeInsets.all(5),
                                child: Column(
                                  children: [
                                    Avatar(
                                      entry.person,
                                      size: 35,
                                      onTap: () => openPage(
                                        context,
                                        '/profile',
                                        entry.person.id,
                                      ),
                                    ),
                                    Text(
                                      locationDistance(entry.meters),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          )
        else if (mode == _MapMode.posts && points.isEmpty)
          const Positioned(
            top: MapAttribution.clearance,
            left: 8,
            right: 8,
            child: InfoNote('Bu alanda konum eklenmiş paylaşım bulunamadı.'),
          )
        else if (mode == _MapMode.notes) ...[
          if (noteError != null)
            Positioned(
              top: MapAttribution.clearance,
              left: 8,
              right: 8,
              child: Material(
                borderRadius: AppShape.rounded,
                child: InlineState(
                  icon: Icons.wifi_off_outlined,
                  title: 'Notlar yüklenemedi',
                  description: noteError,
                  actionLabel: 'Tekrar Dene',
                  onAction: () => setState(() => noteQuery = null),
                ),
              ),
            )
          else if (noteLoading && notes.isEmpty)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                key: Key('map-notes-loading'),
                minHeight: 3,
                color: AppColors.brandPurple,
                backgroundColor: AppColors.surfaceLilac,
              ),
            )
          else if (notes.isEmpty)
            const Positioned(
              top: MapAttribution.clearance,
              left: 8,
              right: 8,
              child: InfoNote(
                'Bu bölgede henüz bir not yok. İlk notu sen bırakabilirsin.',
              ),
            ),
          Positioned(
            left: Space.md,
            right: 76,
            bottom: Space.md,
            child: FilledButton.icon(
              key: const Key('leave-map-note'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.mail_outline_rounded, size: 19),
              label: const Text(
                'Buraya Not Bırak',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: leaveNote,
            ),
          ),
        ],
      ],
    );
  }

  void openGroup(List<MapPostPoint> points) {
    if (points.length == 1) {
      openPage(context, '/post', points.first.id);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: Space.page,
          children: [
            for (final (index, point) in points.indexed)
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text('Paylaşım ${index + 1}'),
                subtitle: point.meters == null
                    ? null
                    : Text(locationDistance(point.meters!)),
                onTap: () {
                  Navigator.pop(sheet);
                  openPage(context, '/post', point.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}
