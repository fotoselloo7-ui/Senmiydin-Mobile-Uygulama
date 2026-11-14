import '../core/app_locale.dart';
import 'account_api.dart';
import 'models.dart';
import 'social_api.dart';

/// One marker = all active notes at one server-side approximate grid point.
class MapNoteMarker {
  const MapNoteMarker({
    required this.group,
    required this.latitude,
    required this.longitude,
    required this.count,
    required this.newestAt,
    this.meters,
  });

  MapNoteMarker.fromJson(Map<String, dynamic> json)
    : group = json['group'] as String,
      latitude = (json['latitude'] as num).toDouble(),
      longitude = (json['longitude'] as num).toDouble(),
      count = json['count'] as int,
      newestAt = DateTime.parse(json['newest_at'] as String),
      meters = json['distance_meters'] as int?;

  final String group;
  final double latitude, longitude;
  final int count;
  final DateTime newestAt;
  final int? meters;
}

class MapNoteMarkers {
  const MapNoteMarkers(this.items, {this.locationRequired = false});
  final List<MapNoteMarker> items;
  final bool locationRequired;
}

/// A public digital letter. Anonymous notes carry no author at all.
class MapNoteItem {
  MapNoteItem.fromJson(
    Map<String, dynamic> json,
    Person Function(Map<String, dynamic>) person,
  ) : id = json['id'] as int,
      body = json['body'] as String,
      anonymous = json['is_anonymous'] == true,
      mine = json['mine'] == true,
      author = json['author'] == null
          ? null
          : person(json['author'] as Map<String, dynamic>),
      placeLabel = json['place_label'] as String? ?? '',
      group = json['group'] as String,
      latitude = (json['latitude'] as num).toDouble(),
      longitude = (json['longitude'] as num).toDouble(),
      replyCount = json['reply_count'] as int? ?? 0,
      canReply = json['can_reply'] == true,
      createdAt = DateTime.parse(json['created_at'] as String),
      expiresAt = DateTime.parse(json['expires_at'] as String),
      occurredAt = DateTime.parse(
        (json['occurred_at'] ?? json['created_at']) as String,
      ),
      republished = json['republished'] == true,
      state = json['state'] as String? ?? 'active',
      hasLiveRepost = json['has_live_repost'] == true,
      canRepost = json['can_repost'] == true,
      archivedAt = json['archived_at'] == null
          ? null
          : DateTime.parse(json['archived_at'] as String);

  MapNoteItem._(MapNoteItem other, this.replyCount)
    : id = other.id,
      body = other.body,
      anonymous = other.anonymous,
      mine = other.mine,
      author = other.author,
      placeLabel = other.placeLabel,
      group = other.group,
      latitude = other.latitude,
      longitude = other.longitude,
      canReply = other.canReply,
      createdAt = other.createdAt,
      expiresAt = other.expiresAt,
      occurredAt = other.occurredAt,
      republished = other.republished,
      state = other.state,
      hasLiveRepost = other.hasLiveRepost,
      canRepost = other.canRepost,
      archivedAt = other.archivedAt;

  MapNoteItem withReplyCount(int count) => MapNoteItem._(this, count);

  final int id, replyCount;
  final String body, placeLabel, group;
  final bool anonymous, mine, canReply;
  final Person? author;
  final double latitude, longitude;

  /// createdAt = when this publication went public; expiresAt = createdAt + 7 days.
  /// occurredAt = the letter's real date. A re-publication keeps it while createdAt / expiresAt start over.
  final DateTime createdAt, expiresAt, occurredAt;
  final bool republished;

  /// Mektuplarım only: active (public now), archived (taken off the map), expired (its public days are over).
  final String state;
  final bool hasLiveRepost, canRepost;
  final DateTime? archivedAt;

  bool get isActive => state == 'active';

  /// "2 gün kaldı", "5 saat kaldı", "Birazdan kalkacak" (active letters only).
  String remaining({DateTime? now}) {
    final left = expiresAt.difference(now ?? DateTime.now());
    if (left.inDays >= 1) return trf('{0} gün kaldı', [left.inDays]);
    if (left.inHours >= 1) return trf('{0} saat kaldı', [left.inHours]);
    return left.isNegative ? 'Süresi doldu' : 'Birazdan kalkacak';
  }
}

/// The signed-in user's private "new letters near you" summary.
class MapNoteUnread {
  const MapNoteUnread(
    this.count, {
    this.locationRequired = false,
    this.enabled = true,
  });
  MapNoteUnread.fromJson(Map<String, dynamic> json)
    : count = json['count'] as int? ?? 0,
      locationRequired = json['location_required'] == true,
      enabled = json['enabled'] != false;
  final int count;
  final bool locationRequired, enabled;
  bool get visible => enabled && !locationRequired && count > 0;
}

class MapNoteReplyItem {
  MapNoteReplyItem.fromJson(
    Map<String, dynamic> json,
    Person Function(Map<String, dynamic>) person,
  ) : id = json['id'] as int,
      body = json['body'] as String,
      anonymous = json['is_anonymous'] == true,
      mine = json['mine'] == true,
      fromNoteAuthor = json['from_note_author'] == true,
      author = json['author'] == null
          ? null
          : person(json['author'] as Map<String, dynamic>),
      createdAt = DateTime.parse(json['created_at'] as String);

  final int id;
  final String body;
  final bool anonymous, mine, fromNoteAuthor;
  final Person? author;
  final DateTime createdAt;
}

class MapNotePointResult {
  const MapNotePointResult(
    this.items,
    this.nextPage,
    this.count,
    this.placeLabel,
  );
  final List<MapNoteItem> items;
  final int? nextPage;
  final int count;
  final String placeLabel;
}

class MapNoteDetail {
  const MapNoteDetail(this.note, this.replies);
  final MapNoteItem note;
  final SocialPage<MapNoteReplyItem> replies;
}

/// Thrown by the UI layer when a note is gone (expired, removed, blocked): the server answers 404.
const mapNoteUnavailable = 'Bu not artık kullanılamıyor.';

class MapNotesApi {
  MapNotesApi(this.client, this.person);
  final ApiClient client;

  /// Registers an author with the store so that profile navigation resolves it.
  final Person Function(Map<String, dynamic>) person;

  Future<MapNoteMarkers> markers({
    required int cityId,
    int? radius,
    bool useLocation = true,
  }) async {
    final data = await client.send(
      'GET',
      'map/notes',
      authenticated: true,
      query: {
        'city_id': '$cityId',
        if (radius != null) 'radius': '$radius',
        if (!useLocation) 'use_location': '0',
      },
    ) as Map<String, dynamic>;
    return MapNoteMarkers(
      (data['items'] as List)
          .cast<Map<String, dynamic>>()
          .map(MapNoteMarker.fromJson)
          .toList(),
      locationRequired: data['location_required'] == true,
    );
  }

  Future<MapNotePointResult> point(String group, int page) async {
    final data = await client.send(
      'GET',
      'map/notes/$group',
      authenticated: true,
      query: {'page': '$page'},
    ) as Map<String, dynamic>;
    return MapNotePointResult(
      (data['items'] as List)
          .cast<Map<String, dynamic>>()
          .map((item) => MapNoteItem.fromJson(item, person))
          .toList(),
      data['next_page'] as int?,
      data['count'] as int? ?? 0,
      data['place_label'] as String? ?? '',
    );
  }

  Future<MapNoteDetail> detail(int id) async {
    final data = await client.send(
      'GET',
      'map-notes/$id',
      authenticated: true,
    ) as Map<String, dynamic>;
    final replies = data['replies'] as Map<String, dynamic>;
    return MapNoteDetail(
      MapNoteItem.fromJson(data['note'] as Map<String, dynamic>, person),
      SocialPage(
        (replies['items'] as List)
            .cast<Map<String, dynamic>>()
            .map((item) => MapNoteReplyItem.fromJson(item, person))
            .toList(),
        replies['next_page'] as int?,
      ),
    );
  }

  Future<SocialPage<MapNoteReplyItem>> replies(int id, int page) async {
    final data = await client.send(
      'GET',
      'map-notes/$id/replies',
      authenticated: true,
      query: {'page': '$page'},
    ) as Map<String, dynamic>;
    return SocialPage(
      (data['items'] as List)
          .cast<Map<String, dynamic>>()
          .map((item) => MapNoteReplyItem.fromJson(item, person))
          .toList(),
      data['next_page'] as int?,
    );
  }

  Future<MapNoteItem> create({
    required String body,
    required bool anonymous,
    required int cityId,
    required double latitude,
    required double longitude,
    required String requestId,
  }) async => MapNoteItem.fromJson(
    await client.send(
      'POST',
      'map-notes',
      authenticated: true,
      body: {
        'body': body,
        'is_anonymous': anonymous,
        'city_id': cityId,
        'latitude': latitude,
        'longitude': longitude,
        'request_id': requestId,
      },
    ) as Map<String, dynamic>,
    person,
  );

  /// "Kalıcı Sil": erases the letter, its replies and every personal access to it.
  Future<void> deleteNote(int id) async {
    await client.send('DELETE', 'map-notes/$id', authenticated: true);
  }

  /// Mektuplarım: scope is `active` (still public) or `archive` (expired or taken off the map). Private to the owner.
  Future<SocialPage<MapNoteItem>> mine(String scope, int page) async {
    final data = await client.send(
      'GET',
      'my/map-notes',
      authenticated: true,
      query: {'scope': scope, 'page': '$page'},
    ) as Map<String, dynamic>;
    return SocialPage(
      (data['items'] as List)
          .cast<Map<String, dynamic>>()
          .map((item) => MapNoteItem.fromJson(item, person))
          .toList(),
      data['next_page'] as int?,
    );
  }

  /// One of the owner's letters with its full historical thread (also after it left the public map).
  Future<MapNoteDetail> mineDetail(int id) async {
    final data = await client.send(
      'GET',
      'my/map-notes/$id',
      authenticated: true,
    ) as Map<String, dynamic>;
    final replies = data['replies'] as Map<String, dynamic>;
    return MapNoteDetail(
      MapNoteItem.fromJson(data['note'] as Map<String, dynamic>, person),
      SocialPage(
        (replies['items'] as List)
            .cast<Map<String, dynamic>>()
            .map((item) => MapNoteReplyItem.fromJson(item, person))
            .toList(),
        replies['next_page'] as int?,
      ),
    );
  }

  /// "Haritadan Kaldır": public visibility ends; the letter stays in Mektuplarım → Arşiv.
  Future<MapNoteItem> archive(int id) async => MapNoteItem.fromJson(
    await client.send('POST', 'map-notes/$id/archive', authenticated: true)
        as Map<String, dynamic>,
    person,
  );

  /// "Tekrar Paylaş": a new public publication (fresh 7 days) of an archived letter; its real date is kept.
  Future<MapNoteItem> repost(int id, {required String requestId}) async =>
      MapNoteItem.fromJson(
        await client.send(
          'POST',
          'map-notes/$id/repost',
          authenticated: true,
          body: {'request_id': requestId},
        ) as Map<String, dynamic>,
        person,
      );

  /// The reader really opened this letter (private, idempotent). Returns the new unread count.
  Future<MapNoteUnread> markRead(int id) async => MapNoteUnread.fromJson(
    await client.send('POST', 'map-notes/$id/read', authenticated: true)
        as Map<String, dynamic>,
  );

  Future<MapNoteUnread> unread() async => MapNoteUnread.fromJson(
    await client.send('GET', 'map/notes/unread', authenticated: true)
        as Map<String, dynamic>,
  );

  Future<MapNoteReplyItem> reply(
    int id,
    String body, {
    required bool anonymous,
    required String requestId,
  }) async => MapNoteReplyItem.fromJson(
    await client.send(
      'POST',
      'map-notes/$id/replies',
      authenticated: true,
      body: {'body': body, 'is_anonymous': anonymous, 'request_id': requestId},
    ) as Map<String, dynamic>,
    person,
  );

  Future<void> deleteReply(int id) async {
    await client.send('DELETE', 'map-note-replies/$id', authenticated: true);
  }
}

/// "Bugün · 14:32", "Dün · 22:18", "11 Kasım · 17:04" in the device's local time.
String mapNoteTime(DateTime value, {DateTime? now, bool withYear = false}) {
  final time = value.toLocal();
  final today = now ?? DateTime.now();
  final day = DateTime(time.year, time.month, time.day);
  final base = DateTime(today.year, today.month, today.day);
  final difference = base.difference(day).inDays;
  final clock =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  const months = [
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
  if (difference == 0) return trf('Bugün · {0}', [clock]);
  if (difference == 1) return trf('Dün · {0}', [clock]);
  final year = withYear || time.year != today.year ? ' ${time.year}' : '';
  return '${time.day} ${tr(months[time.month - 1])}$year · $clock';
}
