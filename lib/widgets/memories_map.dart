import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../core/app_locale.dart';
import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/memories_api.dart';
import 'common.dart';
import 'map_attribution.dart';
import 'memory_widgets.dart';
import 'social.dart';
import 'translated_text.dart';

/// The server hands out at most this many pins per request; a full answer switches the map to viewport requests.
const memoryMapPinCap = 500;

/// The Anılar of a person on one OpenStreetMap: a small photo marker per memory at its approximate point, a preview when
/// one is tapped, "N Anı" clusters when zoomed out, and (for the owner) the Tümü · Görünür · Gizli filter, "+ Anı" and
/// the memories without a place. Who may see which memory is decided by the server only; this widget draws what it gets.
class MemoriesMap extends StatefulWidget {
  const MemoriesMap({
    super.key,
    required this.username,
    required this.own,
    this.refreshVersion = 0,
  }) : area = false;

  /// The Harita page's Anılar tab: the memories of everybody in the viewer's own area (city / radius), with the same
  /// pins, clusters and preview. No owner controls; the server decides who may see which memory.
  const MemoriesMap.area({super.key})
    : username = '',
      own = false,
      refreshVersion = 0,
      area = true;
  final String username;
  final bool own, area;
  final int refreshVersion;

  @override
  State<MemoriesMap> createState() => _MemoriesMapState();
}

class _MemoriesMapState extends State<MemoriesMap> {
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const filters = [
    ('all', 'Tümü'),
    ('visible', 'Görünür'),
    ('hidden', 'Gizli'),
  ];

  final controller = MapController();
  MapCamera? camera;
  Timer? redraw;
  bool ready = false, fitPending = false, tileUnavailable = false;
  bool loading = true, capped = false, firstFit = true;
  int tileRevision = 0, token = 0;
  Object? loadedKey;
  String filter = 'all';
  List<MemoryPin> pins = const [];
  List<MemoryItem> unlocated = const [];
  int unlocatedCount = 0;
  int? selectedId, focusId;
  String? error;

  MemoryPin? get selected {
    for (final pin in pins) {
      if (pin.id == selectedId) return pin;
    }
    return null;
  }

  @override
  void dispose() {
    redraw?.cancel();
    controller.dispose();
    super.dispose();
  }

  List<double>? paddedBounds() {
    final view = camera?.visibleBounds;
    if (view == null) return null;
    final dLat = (view.north - view.south) * .25;
    final dLng = (view.east - view.west) * .25;
    return [
      math.max(-90, view.south - dLat),
      math.max(-180, view.west - dLng),
      math.min(90, view.north + dLat),
      math.min(180, view.east + dLng),
    ];
  }

  Future<void> load(AppStore store, {List<double>? bounds}) async {
    final mine = ++token;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = widget.area
          ? MemoryMapData((await store.loadMemoriesAround()).pins, const [], 0)
          : await store.memories!.map(
              widget.username,
              filter: widget.own ? filter : 'all',
              bounds: bounds,
            );
      if (!mounted || mine != token) return;
      if (bounds == null) capped = data.pins.length >= memoryMapPinCap;
      final focus = focusId ?? store.memoryFocusId;
      store.memoryFocusId = null;
      setState(() {
        pins = data.pins;
        unlocated = data.unlocated;
        unlocatedCount = data.unlocatedCount;
        loading = false;
        if (selectedId != null && !pins.any((p) => p.id == selectedId)) {
          selectedId = null;
        }
      });
      if (bounds == null) {
        final target = focus == null
            ? null
            : pins.where((p) => p.id == focus).firstOrNull;
        if (target != null) {
          focusId = null;
          setState(() => selectedId = target.id);
          moveTo(target.point, 14.5);
        } else if (firstFit) {
          fitAll();
        }
        firstFit = false;
      }
    } on ApiFailure catch (failure) {
      if (!mounted || mine != token) return;
      setState(() {
        error = failure.detail;
        loading = false;
      });
    } catch (_) {
      if (!mounted || mine != token) return;
      setState(() {
        error = 'Bir sorun oluştu. Tekrar dene.';
        loading = false;
      });
    }
  }

  void moveTo(LatLng point, double zoom) {
    if (!ready) return;
    controller.move(point, math.max(zoom, camera?.zoom ?? 0));
  }

  /// First view: every pin in frame (a single one in close), else the device area, else the country.
  void fitAll() {
    if (!ready) {
      fitPending = true;
      return;
    }
    if (pins.isEmpty) {
      final location = StoreScope.of(context).location;
      final position = location != null && location.allowed
          ? location.position
          : null;
      controller.move(
        position == null
            ? const LatLng(39, 35)
            : LatLng(position.latitude, position.longitude),
        position == null ? 5.5 : 11,
      );
    } else if (pins.map((pin) => pin.point).toSet().length == 1) {
      controller.move(pins.first.point, 14);
    } else {
      controller.fitCamera(
        CameraFit.coordinates(
          coordinates: [for (final pin in pins) pin.point],
          padding: const EdgeInsets.fromLTRB(56, 110, 56, 140),
          maxZoom: 14,
        ),
      );
    }
  }

  void positionChanged(MapCamera next, bool _) {
    camera = next;
    redraw?.cancel();
    redraw = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {});
      if (capped) load(StoreScope.of(context), bounds: paddedBounds());
    });
  }

  /// Selects a pin and, when the preview card would cover it, glides the map so the pin sits in the upper part of the view.
  void select(MemoryPin pin) {
    setState(() => selectedId = pin.id);
    final view = camera;
    if (view == null || !ready) return;
    final at = view.latLngToScreenOffset(pin.point);
    final size = view.nonRotatedSize;
    final wanted = size.height * .3;
    if (at.dy > size.height * .46 || at.dy < size.height * .12) {
      final target = view.screenOffsetToLatLng(
        Offset(
          size.width / 2 + (at.dx - size.width / 2),
          size.height / 2 + (at.dy - wanted),
        ),
      );
      controller.move(target, view.zoom);
    }
  }

  Future<void> openMemory(MemoryPin pin) async {
    await openPage(context, '/memory', pin.id);
  }

  Future<void> add() async {
    final view = camera;
    // Zoomed far out the map's middle is rarely a useful start: begin at the newest memory instead (a close view).
    final far = view == null || view.zoom < 11;
    final start = far && pins.isNotEmpty ? pins.first.point : view?.center;
    // The flow saves the memory, remembers it for the next load and tells the store, which reloads this map.
    await startMemoryCreation(
      context,
      center: start,
      zoom: far ? 14 : view.zoom,
    );
  }

  void zoomTo(List<MemoryPin> group) {
    final spread = group.map((pin) => pin.point).toSet().length;
    if (spread < 2 || (camera?.zoom ?? 0) >= 16) {
      showGroup(group);
      return;
    }
    controller.fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final pin in group) pin.point],
        padding: const EdgeInsets.all(72),
        maxZoom: 17,
      ),
    );
  }

  Future<void> showGroup(List<MemoryPin> group) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * .7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          children: [
            Text(trf('{0} Anı', [group.length]), style: AppTypography.section),
            const SizedBox(height: Space.sm),
            for (final pin in group)
              _PinRow(
                pin,
                onTap: () {
                  Navigator.pop(sheet);
                  openMemory(pin);
                },
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> showUnlocated() {
    final store = StoreScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .85,
          ),
          child: ListView(
            key: const Key('memory-unlocated-sheet'),
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
            children: [
              Text('Konumsuz Anılar', style: AppTypography.section),
              const SizedBox(height: 2),
              Text(
                'Bu anılar haritada görünmez; bir yer seçersen haritaya eklenir.',
                style: AppTypography.metadata,
              ),
              const SizedBox(height: Space.md),
              for (final item in unlocated)
                MemoryCard(
                  item,
                  onChanged: () {
                    if (Navigator.canPop(sheet)) Navigator.pop(sheet);
                    store.memoriesChanged();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Singles stay single; pins closer than ~78 px (and everything on one point) become a counted cluster.
  (List<MemoryPin>, List<List<MemoryPin>>) arrange() {
    final view = camera;
    if (view == null) return (const [], const []);
    final bounds = paddedBounds()!;
    final inView = [
      for (final pin in pins)
        if (pin.id != selectedId &&
            pin.point.latitude >= bounds[0] &&
            pin.point.longitude >= bounds[1] &&
            pin.point.latitude <= bounds[2] &&
            pin.point.longitude <= bounds[3])
          pin,
    ];
    // Greedy distance clustering on the screen scale: a pin joins the first group whose centre is within ~74 px.
    final cell = 74 * 360 / (256 * math.pow(2, view.zoom));
    final cosLat = math.max(.2, math.cos(view.center.latitude * math.pi / 180));
    final centres = <(double, double)>[];
    final buckets = <int, List<MemoryPin>>{};
    for (final pin in inView) {
      var at = -1;
      for (var g = 0; g < centres.length; g++) {
        final dx = pin.point.longitude - centres[g].$2;
        final dy = (pin.point.latitude - centres[g].$1) / cosLat;
        if (dx * dx + dy * dy < cell * cell) {
          at = g;
          break;
        }
      }
      if (at < 0) {
        centres.add((pin.point.latitude, pin.point.longitude));
        buckets[centres.length - 1] = [pin];
      } else {
        final members = buckets[at]!..add(pin);
        var lat = 0.0, lng = 0.0;
        for (final member in members) {
          lat += member.point.latitude;
          lng += member.point.longitude;
        }
        centres[at] = (lat / members.length, lng / members.length);
      }
    }
    final singles = <MemoryPin>[];
    final groups = <List<MemoryPin>>[];
    for (final group in buckets.values) {
      if (group.length == 1) {
        singles.add(group.first);
      } else {
        groups.add(group);
      }
    }
    return (singles, groups);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final key = (
      widget.username,
      widget.own ? filter : 'all',
      store.memoriesVersion,
      widget.refreshVersion,
      widget.area
          ? (store.city, store.radiusMeters, store.locationVersion)
          : null,
    );
    // A new area (city / radius) is a new first view; a plain reload keeps the camera.
    if (widget.area &&
        loadedKey != null &&
        key.$5 != (loadedKey! as dynamic).$5) {
      firstFit = true;
    }
    if (loadedKey != key) {
      loadedKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load(store);
      });
    }
    final (singles, groups) = arrange();
    final current = selected;
    final ordered = [...singles]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return Stack(
      children: [
        FlutterMap(
          key: const Key('memories-map'),
          mapController: controller,
          options: MapOptions(
            initialCenter: const LatLng(39, 35),
            initialZoom: 5.5,
            minZoom: 4,
            maxZoom: 17,
            backgroundColor: AppColors.pale,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              ready = true;
              camera = controller.camera;
              if (fitPending) {
                fitPending = false;
                fitAll();
              }
              if (mounted) setState(() {});
            },
            onPositionChanged: positionChanged,
            onTap: (_, _) {
              if (selectedId != null) setState(() => selectedId = null);
            },
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
            MarkerLayer(
              markers: [
                for (final group in groups)
                  Marker(
                    point: _centroid(group),
                    width: 64,
                    height: 64,
                    child: _ClusterPin(
                      key: ValueKey('memory-cluster-${group.first.id}'),
                      count: group.length,
                      onTap: () => zoomTo(group),
                    ),
                  ),
                for (final pin in ordered)
                  Marker(
                    point: pin.point,
                    width: 86,
                    height: 88,
                    alignment: Alignment.topCenter,
                    child: _MemoryPin(
                      key: ValueKey('memory-pin-${pin.id}'),
                      pin,
                      selected: false,
                      onTap: () => select(pin),
                    ),
                  ),
                if (current != null)
                  Marker(
                    point: current.point,
                    width: 86,
                    height: 88,
                    alignment: Alignment.topCenter,
                    child: _MemoryPin(
                      key: ValueKey('memory-pin-${current.id}'),
                      current,
                      selected: true,
                      onTap: () => openMemory(current),
                    ),
                  ),
              ],
            ),
            const MapAttribution(),
          ],
        ),
        if (loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              key: Key('memories-map-loading'),
              minHeight: 3,
              color: AppColors.brandPurple,
              backgroundColor: AppColors.surfaceLilac,
            ),
          ),
        Positioned(
          top: MapAttribution.clearance,
          left: Space.sm,
          right: Space.sm,
          child: _hud(
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.start,
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                if (widget.own) _filterChips(),
                if (unlocatedCount > 0) _unlocatedButton(),
              ],
            ),
          ),
        ),
        if (error != null)
          Positioned(
            top: MapAttribution.clearance + 44,
            left: Space.sm,
            right: Space.sm,
            child: Material(
              borderRadius: AppShape.rounded,
              child: InlineState(
                icon: Icons.wifi_off_outlined,
                title: 'Anılar yüklenemedi',
                description: error,
                actionLabel: 'Tekrar Dene',
                onAction: () => load(store),
              ),
            ),
          )
        else if (!loading && pins.isEmpty)
          Positioned(
            top: MapAttribution.clearance + 44,
            left: Space.sm,
            right: Space.sm,
            child: InfoNote(
              key: const Key('memories-map-empty'),
              widget.area
                  ? 'Bu bölgede henüz paylaşılmış bir anı yok.'
                  : !widget.own
                  ? 'Henüz haritada paylaşılmış bir anı yok.'
                  : filter == 'all'
                  ? 'Haritada henüz bir anın yok. İlk anını eklemek için “+ Anı”ya dokun.'
                  : 'Bu filtreye uyan bir anı yok.',
              icon: Icons.auto_stories_outlined,
            ),
          ),
        if (tileUnavailable)
          Positioned(
            left: Space.sm,
            right: Space.sm,
            bottom: 176,
            child: Material(
              color: Colors.white,
              borderRadius: AppShape.rounded,
              child: Padding(
                padding: const EdgeInsets.only(left: Space.md),
                child: Row(
                  children: [
                    Expanded(
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
          left: Space.md,
          right: Space.md,
          bottom: Space.md,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _hud(_controls(store)),
              ),
              if (current != null) ...[
                const SizedBox(height: Space.sm),
                _PreviewCard(
                  current,
                  own: widget.own,
                  showAuthor: widget.area,
                  onOpen: () => openMemory(current),
                  onClose: () => setState(() => selectedId = null),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The floating controls are compact HUD, not reading text: they follow the text size up to 1.2x so they never crowd the map.
  Widget _hud(Widget child) =>
      MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2, child: child);

  LatLng _centroid(List<MemoryPin> group) {
    var lat = 0.0, lng = 0.0;
    for (final pin in group) {
      lat += pin.point.latitude;
      lng += pin.point.longitude;
    }
    return LatLng(lat / group.length, lng / group.length);
  }

  Widget _filterChips() => Container(
    key: const Key('memory-filter'),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(AppShape.pill),
      boxShadow: [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: .16),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in filters)
            GestureDetector(
              key: Key('memory-filter-$value'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (filter == value) return;
                setState(() {
                  filter = value;
                  selectedId = null;
                  firstFit = true;
                });
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 34, minWidth: 48),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: filter == value ? AppColors.brandPurple : null,
                  borderRadius: BorderRadius.circular(AppShape.pill),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: filter == value ? Colors.white : AppColors.navy,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _unlocatedButton() => Material(
    color: Colors.white.withValues(alpha: .94),
    elevation: 2,
    shadowColor: AppColors.navy.withValues(alpha: .3),
    borderRadius: BorderRadius.circular(AppShape.pill),
    child: InkWell(
      key: const Key('memory-unlocated'),
      borderRadius: BorderRadius.circular(AppShape.pill),
      onTap: showUnlocated,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_outlined,
                size: 17,
                color: AppColors.brandPurple,
              ),
              const SizedBox(width: 6),
              Text(
                'Konumsuz Anılar',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.brandPurple,
                  borderRadius: BorderRadius.circular(AppShape.pill),
                ),
                child: Text(
                  '$unlocatedCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _controls(AppStore store) {
    final location = store.location;
    final position = location != null && location.allowed
        ? location.position
        : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          child: IconButton(
            key: const Key('memories-map-locate'),
            tooltip: position == null
                ? tr('Cihaz konumunu kontrol et')
                : tr('Bulunduğum bölgeye dön'),
            color: AppColors.action,
            icon: const Icon(Icons.my_location_outlined),
            onPressed: position == null
                ? location?.activateFromUi
                : () => controller.move(
                    LatLng(position.latitude, position.longitude),
                    13,
                  ),
          ),
        ),
        if (widget.own) ...[
          const SizedBox(width: Space.sm),
          Semantics(
            button: true,
            label: tr('Anı Ekle'),
            excludeSemantics: true,
            child: Material(
              color: AppColors.brandPurple,
              elevation: 4,
              shadowColor: AppColors.brandPurple.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(AppShape.pill),
              child: InkWell(
                key: const Key('memory-add'),
                borderRadius: BorderRadius.circular(AppShape.pill),
                onTap: add,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 22, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Anı',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

const _pinShadow = [
  BoxShadow(color: Color(0x59000000), blurRadius: 7, offset: Offset(0, 3)),
];

/// A white-bordered circle with a small tip: a memory on the map. Cover photo when it has one, the memory icon when it
/// does not; the pin grows when selected and a multi-photo memory carries its photo count.
class _MemoryPin extends StatelessWidget {
  const _MemoryPin(
    this.pin, {
    super.key,
    required this.selected,
    required this.onTap,
  });
  final MemoryPin pin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final size = selected ? 72.0 : 58.0;
    final edge = selected ? AppColors.brandPurple : Colors.white;
    final Widget face = pin.hasPhoto
        ? socialMediaImage(
            store,
            pin.coverThumb,
            fit: BoxFit.cover,
            width: size,
            height: size,
          )
        : DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.brandPurple],
              ),
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: size * .46,
            ),
          );
    return Semantics(
      button: true,
      label: '${tr('Anı')}, ${memoryDate(pin.occurredAt)}, ${pin.placeLabel}',
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Opacity(
            opacity: pin.hidden ? .72 : 1,
            child: SizedBox(
              width: size + 14,
              height: size + 10,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    bottom: 0,
                    child: CustomPaint(
                      size: const Size(16, 12),
                      painter: _TipPainter(edge),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: edge, width: 3),
                        boxShadow: _pinShadow,
                      ),
                      child: ClipOval(child: face),
                    ),
                  ),
                  if (pin.mediaCount > 1)
                    Positioned(
                      top: -2,
                      right: 0,
                      child: Container(
                        key: Key('memory-pin-count-${pin.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPurple,
                          borderRadius: BorderRadius.circular(AppShape.pill),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '${pin.mediaCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (pin.hidden)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.navy,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.visibility_off_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TipPainter extends CustomPainter {
  const _TipPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TipPainter old) => old.color != color;
}

/// "5 Anı": several memories close together at this zoom. A tap zooms into them.
class _ClusterPin extends StatelessWidget {
  const _ClusterPin({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: trf('{0} Anı', [count]),
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: _pinShadow,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.brandPurple],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Anı',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The small card over the map for the selected memory: photo, date, approximate place, a line or two of the text and,
/// for the owner only, the visibility. Tapping the card (or "Anıyı Aç") opens the memory itself.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard(
    this.pin, {
    required this.own,
    this.showAuthor = false,
    required this.onOpen,
    required this.onClose,
  });
  final MemoryPin pin;
  final bool own, showAuthor;
  final VoidCallback onOpen, onClose;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final visibility = pin.visibility;
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: AppColors.navy.withValues(alpha: .4),
      borderRadius: AppShape.rounded,
      child: InkWell(
        key: const Key('memory-preview'),
        borderRadius: AppShape.rounded,
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: pin.hasPhoto
                            ? socialMediaImage(
                                store,
                                pin.coverThumb,
                                fit: BoxFit.cover,
                                width: 76,
                                height: 76,
                              )
                            : const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary,
                                      AppColors.brandPurple,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.auto_stories_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                      ),
                    ),
                    if (pin.mediaCount > 1)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: .72),
                            borderRadius: BorderRadius.circular(AppShape.pill),
                          ),
                          child: Text(
                            '1/${pin.mediaCount}',
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
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            memoryDate(pin.occurredAt),
                            key: const Key('memory-preview-date'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cardTitle,
                          ),
                        ),
                        InkResponse(
                          key: const Key('memory-preview-close'),
                          onTap: onClose,
                          radius: 18,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              semanticLabel: tr('Kapat'),
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showAuthor && !pin.mine && pin.authorName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 15,
                              color: AppColors.brandLilac,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                pin.authorUsername.isEmpty
                                    ? pin.authorName
                                    : '${pin.authorName} · @${pin.authorUsername}',
                                key: const Key('memory-preview-author'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.metadata.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (pin.placeLabel.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: AppColors.brandLilac,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              pin.placeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.metadata,
                            ),
                          ),
                        ],
                      ),
                    if (pin.excerpt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          pin.excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(height: 1.35),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        if (own && visibility != null)
                          MemoryPill(
                            visibility.label,
                            memoryVisibilityIcon(visibility),
                            key: const Key('memory-preview-visibility'),
                          ),
                        if (own && pin.hidden)
                          const MemoryPill(
                            'Gizli',
                            Icons.visibility_off_outlined,
                            color: AppColors.textSecondary,
                            background: AppColors.surfaceSecondary,
                          ),
                        TextButton(
                          key: const Key('memory-preview-open'),
                          onPressed: onOpen,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.brandPurple,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Anıyı Aç',
                            maxLines: 1,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One memory of a stack that shares a point: thumbnail, date and the first words.
class _PinRow extends StatelessWidget {
  const _PinRow(this.pin, {required this.onTap});
  final MemoryPin pin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return InkWell(
      key: Key('memory-group-${pin.id}'),
      borderRadius: BorderRadius.circular(AppShape.small),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: pin.hasPhoto
                    ? socialMediaImage(
                        store,
                        pin.coverThumb,
                        fit: BoxFit.cover,
                        width: 56,
                        height: 56,
                      )
                    : const ColoredBox(
                        color: AppColors.surfaceLilac,
                        child: Icon(
                          Icons.auto_stories_rounded,
                          color: AppColors.brandPurple,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memoryDate(pin.occurredAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle,
                  ),
                  if (pin.excerpt.isNotEmpty)
                    Text(
                      pin.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metadata,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
