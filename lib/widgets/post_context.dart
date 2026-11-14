import '../core/navigation.dart';

import 'package:flutter/material.dart' hide Text;

import 'translated_text.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme.dart';
import '../data/app_store.dart';
import '../data/post_context.dart';
import '../data/social_api.dart';
import '../widgets/account_action.dart';
import 'common.dart';
import 'map_attribution.dart';
import '../core/app_locale.dart';

Future<DateTime?> selectContextTime(
  BuildContext context, {
  DateTime? initial,
  bool future = false,
}) async {
  final now = DateTime.now();
  final first = now.subtract(const Duration(days: 7));
  final last = future ? now.add(const Duration(days: 365)) : now;
  final selected = (initial ?? now).isBefore(first) ? now : (initial ?? now);
  final date = await showDatePicker(
    context: context,
    initialDate: selected.isAfter(last) ? last : selected,
    firstDate: first,
    lastDate: last,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(selected),
  );
  if (time == null) return null;
  final result = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  return !future && result.isAfter(now) ? now : result;
}

class OccurredTimeField extends StatelessWidget {
  const OccurredTimeField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  @override
  Widget build(BuildContext context) => SettingsRow(
    'Ne zaman oldu?',
    Icons.schedule,
    subtitle: value == null ? 'Şimdi' : contextDate(value!),
    onTap: () => showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final label in [
              'Şimdi',
              'Az önce',
              'Bugün',
              'Tarih / saat seç',
            ])
              ListTile(
                title: Text(label),
                onTap: () async {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  if (label == 'Tarih / saat seç') {
                    final time = await selectContextTime(
                      context,
                      initial: value,
                    );
                    if (time != null) onChanged(time);
                  } else {
                    onChanged(switch (label) {
                      'Az önce' => now.subtract(const Duration(minutes: 15)),
                      'Bugün' => DateTime(now.year, now.month, now.day),
                      _ => null,
                    });
                  }
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class PostPlaceField extends StatelessWidget {
  const PostPlaceField({
    super.key,
    required this.value,
    required this.city,
    required this.onChanged,
  });
  final PostPlaceSelection? value;
  final String city;
  final ValueChanged<PostPlaceSelection?> onChanged;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return SettingsRow(
      'Haritada yer seç',
      Icons.add_location_alt_outlined,
      subtitle: value?.label ?? 'İsteğe bağlı yaklaşık bir nokta seç',
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Şu an bulunduğum yer'),
                leading: const Icon(Icons.my_location),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (store.location?.synced != true) {
                    await store.location?.activateFromUi();
                  }
                  if (store.location?.synced == true &&
                      store.activeCity != null) {
                    onChanged(
                      PostPlaceSelection(
                        'current',
                        city: store.activeCity!.name,
                        label:
                            trf('{0} · Şu anki yaklaşık bölge', [store.activeCity!.name]),
                      ),
                    );
                  } else if (context.mounted) {
                    toast(
                      context,
                      'Konum hazır değil. Manuel şehir veya haritadan yer seçebilirsin.',
                    );
                  }
                },
              ),
              ListTile(
                key: const Key('historical-place-option'),
                title: const Text('Geçtiğim yerlerden seç'),
                subtitle: Text(
                  store.account?.locationHistoryEnabled == true
                      ? 'Son 7 gün · yaklaşık bölge ve saat'
                      : 'Önce ayarlardan Geçtiğim Yerler özelliğini aç.',
                ),
                enabled: store.account?.locationHistoryEnabled == true,
                onTap: () async {
                  Navigator.pop(ctx);
                  final selected = await Navigator.push<HistoricalPlace>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HistoricalPlacesPage(),
                    ),
                  );
                  if (selected != null) {
                    onChanged(
                      PostPlaceSelection(
                        'history',
                        historyId: selected.id,
                        recordedAt: selected.recordedAt,
                        city: selected.city,
                        label:
                            '${selected.label} · ${contextDate(selected.recordedAt)}',
                      ),
                    );
                  }
                },
              ),
              ListTile(
                title: const Text('Haritadan yaklaşık yer seç'),
                leading: const Icon(Icons.map_outlined),
                onTap: () async {
                  Navigator.pop(ctx);
                  final selected = await Navigator.push<PostPlaceSelection>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ApproximatePlacePage(city: city),
                    ),
                  );
                  if (selected != null) onChanged(selected);
                },
              ),
              ListTile(
                title: const Text('Yer ekleme'),
                onTap: () {
                  Navigator.pop(ctx);
                  onChanged(null);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoricalPlacesPage extends StatefulWidget {
  const HistoricalPlacesPage({super.key});
  @override
  State<HistoricalPlacesPage> createState() => _HistoricalPlacesPageState();
}

class _HistoricalPlacesPageState extends State<HistoricalPlacesPage>
    with AccountAction<HistoricalPlacesPage> {
  final places = <HistoricalPlace>[];
  int? next = 1;
  bool loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => load());
    }
  }

  Future<void> load() => runAccountAction(() async {
    final SocialPage<HistoricalPlace> page = await StoreScope.of(context)
        .loadHistoricalPlaces(next ?? 1);
    if (!mounted) return;
    setState(() {
      places.addAll(page.items);
      next = page.nextPage;
    });
  });
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Geçtiğim yerler',
    child: ListView(
      padding: Space.page,
      children: [
        const InfoNote(
          'Yalnızca kendi yaklaşık bölgelerin gösterilir. Başkalarının geçmişi paylaşılmaz.',
        ),
        if (places.isEmpty && !busy)
          const Text('Henüz kayıtlı bir bölgen yok.'),
        for (final place in places)
          ListTile(
            key: ValueKey(('history-place', place.id)),
            leading: const Icon(Icons.location_on_outlined),
            title: Text(place.label),
            subtitle: Text(contextDate(place.recordedAt)),
            onTap: () => Navigator.pop(context, place),
          ),
        if (next != null)
          SecondaryButton(
            busy ? 'Yükleniyor…' : 'Daha fazla',
            onPressed: busy ? null : load,
          ),
      ],
    ),
  );
}

class ApproximatePlacePage extends StatefulWidget {
  const ApproximatePlacePage({super.key, required this.city});
  final String city;
  @override
  State<ApproximatePlacePage> createState() => _ApproximatePlacePageState();
}

class _ApproximatePlacePageState extends State<ApproximatePlacePage> {
  LatLng? chosen;
  @override
  Widget build(BuildContext context) {
    final position = StoreScope.of(context).location?.position;
    final center = position == null
        ? const LatLng(39.1, 35.2)
        : LatLng(position.latitude, position.longitude);
    return AppPage(
      title: tr('Yaklaşık yer seç'),
      child: Column(
        children: [
          const Padding(
            padding: Space.page,
            child: InfoNote(
              'Haritaya dokun. Seçtiğin nokta yaklaşıklaştırılır; açık adres paylaşılmaz. Yer başka şehirdeyse paylaşım şehrini de değiştir.',
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: position == null ? 5 : 12,
                onTap: (_, point) => setState(() => chosen = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: const String.fromEnvironment(
                    'MAP_TILE_URL',
                    defaultValue:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  userAgentPackageName: 'com.senmiydin.app',
                ),
                if (chosen != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: chosen!,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.blue,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                const MapAttribution(),
              ],
            ),
          ),
          Padding(
            padding: Space.page,
            child: PrimaryButton(
              'Bu yaklaşık yeri seç',
              onPressed: chosen == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      PostPlaceSelection(
                        'map',
                        latitude: chosen!.latitude,
                        longitude: chosen!.longitude,
                        city: widget.city,
                        label: trf('{0} · Haritadan yaklaşık bölge', [widget.city]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class TravelFields extends StatelessWidget {
  const TravelFields({
    super.key,
    required this.draft,
    required this.city,
    required this.onChanged,
  });
  final TravelDraft draft;
  final String city;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      PreferenceRow('Yolculuk bilgilerini ekle', draft.enabled, (v) {
        draft.enabled = v;
        onChanged();
      }, subtitle: 'İsteğe bağlı · Ek bir gruba katılman gerekmez.'),
      if (draft.enabled) ...[
        DropdownButtonFormField<String>(
          key: const Key('travel-transport'),
          initialValue: draft.transport,
          decoration: InputDecoration(labelText: tr('Ulaşım türü')),
          items: transportLabels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              draft.transport = v;
              onChanged();
            }
          },
        ),
        SettingsRow(
          'Kalkış',
          Icons.trip_origin,
          subtitle: draft.origin ?? city,
          onTap: () async {
            final v = await chooseCity(context, draft.origin ?? city);
            if (v != null) {
              draft.origin = v;
              onChanged();
            }
          },
        ),
        SettingsRow(
          'Varış',
          Icons.place_outlined,
          subtitle: draft.destination ?? 'Şehir seç',
          onTap: () async {
            final v = await chooseCity(context, draft.destination ?? city);
            if (v != null) {
              draft.destination = v;
              onChanged();
            }
          },
        ),
        SettingsRow(
          'Yaklaşık kalkış zamanı',
          Icons.schedule,
          subtitle: draft.departureAt == null
              ? 'İsteğe bağlı'
              : contextDate(draft.departureAt!),
          onTap: () async {
            final v = await selectContextTime(
              context,
              initial: draft.departureAt,
              future: true,
            );
            if (v != null) {
              draft.departureAt = v;
              onChanged();
            }
          },
        ),
        for (final item in [
          (
            'Firma / işletmeci',
            draft.operatorName,
            80,
            (String v) => draft.operatorName = v,
          ),
          (
            'Sefer / araç kodu',
            draft.serviceCode,
            40,
            (String v) => draft.serviceCode = v,
          ),
          (
            'Plaka / araç tanımlayıcısı (isteğe bağlı)',
            draft.vehicleIdentifier,
            40,
            (String v) => draft.vehicleIdentifier = v,
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: TextFormField(
              initialValue: item.$2,
              maxLength: item.$3,
              decoration: InputDecoration(labelText: item.$1),
              onChanged: (v) {
                item.$4(v);
                onChanged();
              },
            ),
          ),
        PreferenceRow(
          'Yolculuk detaylarını paylaşımda göster',
          draft.isPublic,
          (v) {
            draft.isPublic = v;
            onChanged();
          },
          subtitle: 'Açarsan firma, sefer ve araç bilgisi gönderini görenlere açık olur. Canlı araç takibi yapılmaz.',
        ),
      ],
    ],
  );
}

class TravelSummary extends StatelessWidget {
  const TravelSummary(this.details, {super.key});
  final TravelDetails details;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(Space.sm),
    margin: const EdgeInsets.only(bottom: Space.sm),
    decoration: AppShape.card(color: AppColors.pale),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            transportLabels[details.transport] ?? 'Yolculuk',
            if (details.operatorName.isNotEmpty) details.operatorName,
          ].join(' · '),
          style: AppTypography.metadata.copyWith(color: AppColors.action),
        ),
        const SizedBox(height: Space.xs),
        Text(
          '${details.origin.name} → ${details.destination.name}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (details.departureAt != null)
          Text(
            contextDate(details.departureAt!),
            style: AppTypography.metadata,
          ),
        if (details.serviceCode.isNotEmpty ||
            details.vehicleIdentifier.isNotEmpty)
          Text(
            [
              details.serviceCode,
              details.vehicleIdentifier,
            ].where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
      ],
    ),
  );
}
