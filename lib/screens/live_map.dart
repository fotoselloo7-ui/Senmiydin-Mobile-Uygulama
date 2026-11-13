import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/location_api.dart';
import '../widgets/common.dart';
import '../widgets/location_ui.dart';

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
  static const attribution = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: 'OpenStreetMap contributors',
  );
  static const attributionUrl = String.fromEnvironment(
    'MAP_ATTRIBUTION_URL',
    defaultValue: 'https://www.openstreetmap.org/copyright',
  );

  final mapController = MapController();
  bool posts = true, tileUnavailable = false;
  int tileRevision = 0;
  Object? query;
  Future<LocationResults<MapPostPoint>>? request;
  Timer? debounce;

  @override
  void dispose() {
    debounce?.cancel();
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
    if (query != key) requestData(store, key);

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
                      '${store.city} · Yaklaşık konumlar',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Haritayı yenile',
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
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => posts = false),
                icon: const Icon(Icons.people_outline),
                label: Text(
                  'İnsanlar',
                  style: TextStyle(
                    color: posts ? AppColors.muted : AppColors.blue,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => posts = true),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(
                  'Paylaşımlar',
                  style: TextStyle(
                    color: posts ? AppColors.blue : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: AppShape.rounded,
              child: FutureBuilder(
                future: request,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting ||
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
                      snapshot.data ?? const LocationResults<MapPostPoint>([]);
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

  Widget map(AppStore store, List<MapPostPoint> points) {
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
        (points.isEmpty
            ? const LatLng(39, 35)
            : LatLng(points.first.latitude, points.first.longitude));
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
            own == null && points.isEmpty,
          )),
          options: MapOptions(
            initialCenter: center,
            initialZoom: own == null && points.isEmpty
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
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.navy,
                  textStyle: AppTypography.metadata,
                ),
                onPressed: () => launchUrl(
                  Uri.parse(attributionUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text('© $attribution', textAlign: TextAlign.right),
              ),
            ),
          ],
        ),
        if (tileUnavailable)
          Positioned(
            left: Space.md,
            right: 76,
            bottom: 54,
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
                      tooltip: 'Haritayı tekrar yükle',
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
          bottom: 44,
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
        if (!posts)
          Positioned(
            top: 8,
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
        else if (points.isEmpty)
          const Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: InfoNote('Bu alanda konum eklenmiş paylaşım bulunamadı.'),
          ),
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
