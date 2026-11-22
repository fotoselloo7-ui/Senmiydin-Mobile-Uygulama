import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'account_api.dart';
import 'models.dart';
import 'social_api.dart';

/// Who may see a memory. The server decides; the app only shows and chooses.
enum MemoryVisibility {
  private('private', 'Sadece Ben'),
  followers('followers', 'Takipçilerim'),
  public('public', 'Herkes'),
  area('area', 'Bu Bölgedekiler');

  const MemoryVisibility(this.value, this.label);
  final String value, label;

  static MemoryVisibility? parse(Object? value) {
    for (final item in values) {
      if (item.value == value) return item;
    }
    return null;
  }
}

/// A photo of a memory. [url] is the full photo (viewer), [thumbUrl] the small one the profile list loads.
class MemoryMediaItem {
  const MemoryMediaItem({
    required this.id,
    required this.url,
    required this.thumbUrl,
    this.width = 0,
    this.height = 0,
  });

  factory MemoryMediaItem.fromJson(Map<String, dynamic> json) =>
      MemoryMediaItem(
        id: json['id'] as int,
        url: ApiClient.mediaUrl(json['url'] as String?),
        thumbUrl: ApiClient.mediaUrl(
          (json['thumb_url'] ?? json['url']) as String?,
        ),
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
      );

  final int id, width, height;
  final String url, thumbUrl;

  /// Width / height; 4:5 when the server did not say.
  double get aspect => width > 0 && height > 0 ? width / height : 4 / 5;
}

/// A memory (Anı). Never carries a coordinate: only the approximate place label the server chose to show.
class MemoryItem {
  MemoryItem.fromJson(
    Map<String, dynamic> json,
    Person Function(Map<String, dynamic>) person,
  ) : id = json['id'] as int,
      mine = json['mine'] == true,
      author = json['author'] is Map<String, dynamic>
          ? person(json['author'] as Map<String, dynamic>)
          : null,
      body = json['body'] as String? ?? '',
      occurredAt = DateTime.parse(json['occurred_at'] as String).toLocal(),
      city = json['city'] is Map<String, dynamic>
          ? CatalogItem.fromJson(json['city'] as Map<String, dynamic>)
          : null,
      place = PlaceSummary.maybe(json['place']),
      placeLabel = json['place_label'] as String?,
      mapArea = json['map_area'] is Map<String, dynamic>
          ? MemoryMapArea.fromJson(json['map_area'] as Map<String, dynamic>)
          : null,
      visibility = MemoryVisibility.parse(json['visibility']),
      hidden = json['is_hidden'] == true,
      sourceType = json['source_type'] as String?,
      media = [
        for (final item in (json['media'] as List? ?? const []))
          MemoryMediaItem.fromJson(item as Map<String, dynamic>),
      ],
      createdAt = DateTime.parse(json['created_at'] as String).toLocal();

  final int id;
  final bool mine, hidden;
  final Person? author;
  final String body;
  final DateTime occurredAt, createdAt;
  final CatalogItem? city;
  final PlaceSummary? place;
  final String? placeLabel, sourceType;

  /// The coarse area for "Haritada Gör" (null: no place, no action).
  final MemoryMapArea? mapArea;

  /// Only the owner is told these.
  final MemoryVisibility? visibility;
  final List<MemoryMediaItem> media;

  /// The place to show on a card ("Kestel"); empty when the memory has none.
  String get area =>
      memoryPlaceName(placeLabel ?? place?.label ?? city?.name ?? '');
}

/// Older memories carry a "· Yaklaşık bölge" tail from the time places were approximate: it is not shown, a memory sits
/// where it was left.
String memoryPlaceName(String label) => label.replaceFirst(
  RegExp(r'\s*·\s*(Yaklaşık bölge|Approximate area)$'),
  '',
);

/// A coarse area on the map: a centre rounded to about a kilometre and a radius. Never a person's own position.
class MemoryMapArea {
  const MemoryMapArea(this.center, this.radiusMeters);
  factory MemoryMapArea.fromJson(Map<String, dynamic> json) => MemoryMapArea(
    LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble()),
    (json['radius_m'] as num?)?.toInt() ?? 1500,
  );
  final LatLng center;
  final int radiusMeters;
}

/// One memory as a pin on the Anılar map: the cover thumbnail, a coarse point and a short excerpt. Never the whole memory.
class MemoryPin {
  MemoryPin.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      point = LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      occurredAt = DateTime.parse(json['occurred_at'] as String).toLocal(),
      placeLabel = memoryPlaceName(json['place_label'] as String? ?? ''),
      excerpt = json['excerpt'] as String? ?? '',
      mediaCount = (json['media_count'] as num?)?.toInt() ?? 0,
      coverThumb = json['cover_thumb'] == null
          ? ''
          : ApiClient.mediaUrl(json['cover_thumb'] as String?),
      mine = json['mine'] == true,
      visibility = MemoryVisibility.parse(json['visibility']),
      hidden = json['is_hidden'] == true,
      authorName = (json['author'] as Map?)?['name'] as String? ?? '',
      authorUsername = (json['author'] as Map?)?['username'] as String? ?? '',
      authorPhoto = ApiClient.mediaUrl(
        (json['author'] as Map?)?['avatar'] as String?,
      ),
      authorId = '${(json['author'] as Map?)?['id'] ?? ''}',
      distanceMeters = (json['distance_meters'] as num?)?.toInt();

  final int id, mediaCount;
  final LatLng point;
  final DateTime occurredAt;
  final String placeLabel, excerpt, coverThumb;

  /// Whose memory it is (only on the Harita page, where memories of many people share the map).
  final String authorName, authorUsername, authorPhoto, authorId;

  /// Rounded distance from the viewer's device (only when it is known); the server also sorts nearest first then.
  final int? distanceMeters;
  final bool mine, hidden;
  final MemoryVisibility? visibility;

  bool get hasPhoto => coverThumb.isNotEmpty;
}

/// The Anılar map of one person: the pins the viewer may see, and the memories that have no place at all.
class MemoryMapData {
  const MemoryMapData(this.pins, this.unlocated, this.unlocatedCount);
  final List<MemoryPin> pins;
  final List<MemoryItem> unlocated;
  final int unlocatedCount;
}

/// A photo of the source (a map note or post) a new memory is made from. It is copied by the server; the app only
/// shows it and sends back its [ref].
class MemorySourcePhoto {
  const MemorySourcePhoto(this.ref, this.url);
  final String ref, url;
}

/// What a new memory made from a map note / post starts with.
class MemoryPrefill {
  MemoryPrefill.fromJson(Map<String, dynamic> json)
    : sourceType = json['source_type'] as String,
      body = json['body'] as String? ?? '',
      occurredAt = DateTime.parse(json['occurred_at'] as String).toLocal(),
      city = json['city'] is Map<String, dynamic>
          ? CatalogItem.fromJson(json['city'] as Map<String, dynamic>)
          : null,
      place = PlaceSummary.maybe(json['place']),
      placeLabel = json['place_label'] as String?,
      hasPoint = json['has_point'] != false,
      visibility =
          MemoryVisibility.parse(json['visibility']) ??
          MemoryVisibility.private,
      photos = [
        for (final item in (json['media'] as List? ?? const []))
          MemorySourcePhoto(
            (item as Map<String, dynamic>)['ref'] as String,
            ApiClient.mediaUrl(item['url'] as String?),
          ),
      ];

  final String sourceType, body;
  final DateTime occurredAt;
  final CatalogItem? city;
  final PlaceSummary? place;
  final String? placeLabel;

  /// False for a post that only has a city: the app asks for a spot on the map first.
  final bool hasPoint;
  final MemoryVisibility visibility;
  final List<MemorySourcePhoto> photos;
}

/// The answer to "Anılarıma Ekle": the memory that already exists for the source, or the prefill for a new one.
class MemoryPrefillResult {
  const MemoryPrefillResult(this.existing, this.prefill);
  final MemoryItem? existing;
  final MemoryPrefill? prefill;
}

/// One photo slot of the memory form, in the order shown. The layout token tells the server what it is.
sealed class MemorySlot {
  const MemorySlot();
  String get key;
}

/// A photo the memory already has (editing).
class ExistingSlot extends MemorySlot {
  const ExistingSlot(this.media);
  final MemoryMediaItem media;
  @override
  String get key => 'm${media.id}';
}

/// A photo of the source note / post, copied by the server when the memory is saved.
class SourceSlot extends MemorySlot {
  const SourceSlot(this.photo);
  final MemorySourcePhoto photo;
  @override
  String get key => photo.ref;
}

/// A photo just picked (and cropped) on this device.
class FreshSlot extends MemorySlot {
  const FreshSlot(this.file);
  final XFile file;
  @override
  String get key => file.path;
}

class MemoriesApi {
  MemoriesApi(this.client, this.person);
  final ApiClient client;
  final Person Function(Map<String, dynamic>) person;

  MemoryItem _item(Object? json) =>
      MemoryItem.fromJson(json as Map<String, dynamic>, person);

  /// A person's memories, newest event first, 20 a page. Others only get what the visibility rules allow.
  Future<SocialPage<MemoryItem>> list(
    String username,
    int page, {
    String filter = 'all',
  }) async {
    final data = await client.send(
      'GET',
      'users/$username/memories',
      authenticated: true,
      query: {'page': '$page', if (filter != 'all') 'filter': filter},
    ) as Map<String, dynamic>;
    return SocialPage(
      (data['items'] as List).map(_item).toList(),
      data['next_page'] as int?,
    );
  }

  /// The map of a person's memories (same visibility rules as the list). [bounds] = south, west, north, east.
  Future<MemoryMapData> map(
    String username, {
    String filter = 'all',
    List<double>? bounds,
  }) async {
    final data = await client.send(
      'GET',
      'users/$username/memories/map',
      authenticated: true,
      query: {
        if (filter != 'all') 'filter': filter,
        if (bounds != null)
          'bounds': bounds.map((v) => v.toStringAsFixed(5)).join(','),
      },
    ) as Map<String, dynamic>;
    return MemoryMapData(
      [
        for (final item in (data['items'] as List))
          MemoryPin.fromJson(item as Map<String, dynamic>),
      ],
      [
        for (final item in (data['unlocated'] as List? ?? const []))
          _item(item),
      ],
      (data['unlocated_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// The Harita page's Anılar tab: the memories of everybody in the viewer's own area (city, or a radius around the device).
  /// Which memories come back is decided by the server's visibility rules only.
  Future<({List<MemoryPin> pins, bool locationRequired})> around({
    required int cityId,
    int? radius,
    bool useLocation = true,
  }) async {
    final data = await client.send(
      'GET',
      'map/memories',
      authenticated: true,
      query: {
        'city_id': '$cityId',
        'radius': ?(radius == null ? null : '$radius'),
        if (!useLocation) 'use_location': '0',
      },
    ) as Map<String, dynamic>;
    return (
      pins: [
        for (final item in (data['items'] as List))
          MemoryPin.fromJson(item as Map<String, dynamic>),
      ],
      locationRequired: data['location_required'] == true,
    );
  }

  Future<MemoryItem> detail(int id) async =>
      _item(await client.send('GET', 'memories/$id', authenticated: true));

  /// "Anılarıma Ekle": [sourceType] is `map_note` or `post`; the source is only read.
  Future<MemoryPrefillResult> prefill(String sourceType, int sourceId) async {
    final data = await client.send(
      'GET',
      'memories/prefill',
      authenticated: true,
      query: {'source_type': sourceType, 'source_id': '$sourceId'},
    ) as Map<String, dynamic>;
    return MemoryPrefillResult(
      data['existing'] == null ? null : _item(data['existing']),
      data['prefill'] == null
          ? null
          : MemoryPrefill.fromJson(data['prefill'] as Map<String, dynamic>),
    );
  }

  /// The layout tokens and the files of new photos, in the order of [slots].
  ({List<String> layout, List<XFile> files}) _layout(List<MemorySlot> slots) {
    final files = <XFile>[];
    final layout = <String>[];
    for (final slot in slots) {
      if (slot is FreshSlot) {
        layout.add('n${files.length}');
        files.add(slot.file);
      } else {
        layout.add(slot.key);
      }
    }
    return (layout: layout, files: files);
  }

  Map<String, Object?> _fields({
    required String body,
    required DateTime occurredAt,
    required MemoryVisibility visibility,
    int? placeId,
    int? cityId,
    LatLng? point,
    String? pointLabel,
    required List<String> layout,
  }) => {
    'body': body,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'visibility': visibility.value,
    if (point != null) ...{
      // A spot picked on the map: the server snaps it to its approximate grid and finds the area itself.
      'latitude': point.latitude,
      'longitude': point.longitude,
      if ((pointLabel ?? '').isNotEmpty) 'place_label': pointLabel,
    } else ...{
      'place_id': ?placeId,
      if (placeId == null) 'city_id': ?cityId,
    },
    'layout': layout,
  };

  Future<MemoryItem> create({
    required String body,
    required DateTime occurredAt,
    required MemoryVisibility visibility,
    required List<MemorySlot> slots,
    required String requestId,
    int? placeId,
    int? cityId,
    LatLng? point,
    String? pointLabel,
    String? sourceType,
    int? sourceId,
  }) async {
    final layout = _layout(slots);
    return _item(
      await client.send(
        'POST',
        'memories',
        authenticated: true,
        media: layout.files,
        body: {
          ..._fields(
            body: body,
            occurredAt: occurredAt,
            visibility: visibility,
            placeId: placeId,
            cityId: cityId,
            point: point,
            pointLabel: pointLabel,
            layout: layout.layout,
          ),
          'request_id': requestId,
          'source_type': ?sourceType,
          'source_id': ?sourceId,
        },
      ),
    );
  }

  /// Edits only the memory (never the post / map note it was made from).
  Future<MemoryItem> update(
    int id, {
    required String body,
    required DateTime occurredAt,
    required MemoryVisibility visibility,
    required List<MemorySlot> slots,
    int? placeId,
    int? cityId,
    LatLng? point,
    String? pointLabel,
  }) async {
    final layout = _layout(slots);
    return _item(
      await client.send(
        'POST',
        'memories/$id',
        authenticated: true,
        media: layout.files,
        body: _fields(
          body: body,
          occurredAt: occurredAt,
          visibility: visibility,
          placeId: placeId,
          cityId: cityId,
          point: point,
          pointLabel: pointLabel,
          layout: layout.layout,
        ),
      ),
    );
  }

  Future<MemoryItem> setHidden(int id, bool hidden) async => _item(
    await client.send(
      'POST',
      'memories/$id/${hidden ? 'hide' : 'unhide'}',
      authenticated: true,
    ),
  );

  Future<MemoryItem> setVisibility(int id, MemoryVisibility value) async =>
      _item(
        await client.send(
          'POST',
          'memories/$id',
          authenticated: true,
          body: {'visibility': value.value},
        ),
      );

  Future<void> delete(int id) async {
    await client.send('DELETE', 'memories/$id', authenticated: true);
  }
}
