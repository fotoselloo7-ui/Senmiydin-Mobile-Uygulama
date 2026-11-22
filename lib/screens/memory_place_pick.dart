import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_locale.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import '../widgets/map_attribution.dart';
import '../widgets/memory_photo_pick.dart';
import '../widgets/memory_widgets.dart';
import '../widgets/translated_text.dart';

/// "Anı Ekle", step one: the map under a fixed centre pin. The person drags the map until the pin stands where the
/// memory happened; the approximate place name follows the pin. `→` goes on (photo sheet first when [MemoryPickArgs.photoStep]).
/// Only the pin's position leaves this screen, and the server rounds it to its coarse grid before storing anything.
class MemoryPlacePickPage extends StatefulWidget {
  const MemoryPlacePickPage(this.args, {super.key});
  final MemoryPickArgs args;

  @override
  State<MemoryPlacePickPage> createState() => _MemoryPlacePickPageState();
}

class _MemoryPlacePickPageState extends State<MemoryPlacePickPage> {
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  final controller = MapController();
  Timer? settle;
  late LatLng centre;
  bool moving = false, tileUnavailable = false, busy = false;
  int lookup = 0, tileRevision = 0;
  String? label;
  LatLng? labelAt;

  @override
  void initState() {
    super.initState();
    centre = widget.args.center ?? const LatLng(39, 35);
    label = widget.args.label;
    labelAt = widget.args.label == null ? null : centre;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Without a given spot the map starts on the device area when the person allowed it (checked once).
    if (widget.args.center == null && !_triedDevice) {
      _triedDevice = true;
      final location = StoreScope.of(context).location;
      final position = location != null && location.allowed
          ? location.position
          : null;
      if (position != null) {
        centre = LatLng(position.latitude, position.longitude);
        _startZoom = 14;
      }
    }
  }

  bool _triedDevice = false;
  double? _startZoom;

  @override
  void dispose() {
    settle?.cancel();
    controller.dispose();
    super.dispose();
  }

  void changed(MapCamera camera, bool byGesture) {
    centre = camera.center;
    settle?.cancel();
    if (!moving || byGesture) {
      setState(() => moving = true);
    } else {
      setState(() {});
    }
    settle = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => moving = false);
      resolve(StoreScope.of(context), centre);
    });
  }

  Future<void> resolve(AppStore store, LatLng at) async {
    final mine = ++lookup;
    final name = await store.placeLabelAt(at.latitude, at.longitude);
    if (!mounted || mine != lookup) return;
    setState(() {
      label = name;
      labelAt = at;
    });
  }

  /// The name only counts while the pin still stands where it was looked up.
  String get currentLabel {
    final at = labelAt;
    if (label == null || at == null) return '';
    return (at.latitude - centre.latitude).abs() < .002 &&
            (at.longitude - centre.longitude).abs() < .002
        ? label!
        : '';
  }

  Future<void> next() async {
    if (busy) return;
    final point = controller.camera.center;
    final name = currentLabel;
    if (!widget.args.photoStep) {
      Navigator.pop(context, MemoryPickResult(point, name, const []));
      return;
    }
    setState(() => busy = true);
    try {
      final choice = await showMemoryPhotoSheet(context, allowSkip: true);
      if (choice == null || !mounted) return;
      final photos = await pickMemoryPhotos(context, choice, room: 5);
      if (!mounted) return;
      // A cancelled picker / crop keeps the person here: nothing is lost, the pin can still be moved.
      if (choice != MemoryPhotoChoice.skip && photos.isEmpty) return;
      Navigator.pop(context, MemoryPickResult(point, name, photos));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final location = store.location;
    final position = location != null && location.allowed
        ? location.position
        : null;
    final shown = currentLabel;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            FlutterMap(
              key: const Key('memory-pick-map'),
              mapController: controller,
              options: MapOptions(
                initialCenter: centre,
                initialZoom: widget.args.zoom ?? _startZoom ?? 5.5,
                minZoom: 4,
                maxZoom: 18,
                backgroundColor: AppColors.pale,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () {
                  if (widget.args.label == null) {
                    resolve(store, controller.camera.center);
                  }
                },
                onPositionChanged: changed,
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
                const MapAttribution(),
              ],
            ),
            // The fixed centre pin: its tip is the middle of the map, and it lifts a little while the map moves.
            IgnorePointer(
              child: Center(
                child: SizedBox(
                  key: const Key('memory-pick-pin'),
                  width: 58,
                  height: 58,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 140),
                    offset: Offset(0, moving ? -.68 : -.5),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 58,
                      color: AppColors.brandPurple,
                      shadows: [
                        Shadow(color: Color(0x66000000), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  key: const Key('memory-pick-crosshair'),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandPurple,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.sm,
                  MapAttribution.clearance + 2,
                  Space.sm,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 3,
                          child: IconButton(
                            key: const Key('memory-pick-back'),
                            tooltip: tr('Geri'),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: AppColors.navy,
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Material(
                            color: Colors.white,
                            elevation: 3,
                            borderRadius: AppShape.rounded,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.md,
                                vertical: 9,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.args.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.cardTitle,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.place_outlined,
                                        size: 15,
                                        color: AppColors.brandLilac,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          moving
                                              ? tr('Yer aranıyor…')
                                              : shown.isEmpty
                                              ? tr('Seçilen nokta')
                                              : shown,
                                          key: const Key('memory-pick-label'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.metadata,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (tileUnavailable)
              Positioned(
                left: Space.md,
                right: Space.md,
                bottom: 160,
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
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(
                          key: const Key('memory-pick-locate'),
                          tooltip: position == null
                              ? tr('Cihaz konumunu kontrol et')
                              : tr('Bulunduğum bölgeye dön'),
                          color: AppColors.action,
                          icon: const Icon(Icons.my_location_outlined),
                          onPressed: position == null
                              ? location?.activateFromUi
                              : () => controller.move(
                                  LatLng(position.latitude, position.longitude),
                                  15,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.white.withValues(alpha: .95),
                            elevation: 2,
                            borderRadius: AppShape.rounded,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.md,
                                vertical: 10,
                              ),
                              child: Text(
                                'Haritayı kaydırarak anının yaşandığı noktayı seç. Anı tam o noktaya bırakılır; kimlerin göreceğini sen seçersin.',
                                key: const Key('memory-pick-hint'),
                                style: AppTypography.metadata,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Semantics(
                          button: true,
                          label: widget.args.photoStep
                              ? tr('Devam')
                              : tr('Bu yeri seç'),
                          excludeSemantics: true,
                          child: Material(
                            color: AppColors.brandPurple,
                            shape: const CircleBorder(),
                            elevation: 5,
                            shadowColor: AppColors.brandPurple.withValues(
                              alpha: .5,
                            ),
                            child: InkWell(
                              key: const Key('memory-pick-next'),
                              customBorder: const CircleBorder(),
                              onTap: busy ? null : next,
                              child: SizedBox(
                                width: 60,
                                height: 60,
                                child: Icon(
                                  widget.args.photoStep
                                      ? Icons.arrow_forward_rounded
                                      : Icons.check_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
