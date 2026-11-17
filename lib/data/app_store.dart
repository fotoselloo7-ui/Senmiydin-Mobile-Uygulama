import 'post_context.dart';
import '../core/ads_config.dart';
import '../core/app_locale.dart';
import 'ads_service.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/release_info.dart';
import 'version_policy.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'account_api.dart';
import 'review_prompt.dart';
import 'encounter_api.dart';
import 'communication_api.dart';
import 'push_client.dart';
import 'models.dart';
import 'location_api.dart';
import 'location_service.dart';
import 'compose_draft.dart';
import 'map_notes_api.dart';
import 'mock_data.dart';
import 'social_api.dart';

class AppStore extends ChangeNotifier {
  AppStore({
    ApiClient? api,
    LocationDevice? locationDevice,
    ComposeDraftStore? drafts,
    AdsService? ads,
    ReviewPrompt? reviews,
  }) : drafts = drafts ?? ComposeDraftStore(),
       reviews = reviews ?? ReviewPrompt(),
       ads = ads ?? AdsService(),
       _api = api,
       auth = api == null ? null : AuthService(api),
       _profiles = api == null ? null : ProfileService(api),
       _catalog = api == null ? null : CatalogService(api),
       _places = api == null ? null : PlaceService(api),
       _social = api == null ? null : SocialService(api) {
    api?.onUnauthorized = _clearAccount;
    if (api != null) {
      communication = CommunicationApi(api, _rememberPerson);
      mapNotes = MapNotesApi(api, _rememberPerson);
      push = PushClient(communication!, () => _account?.id);
      location = LocationService(
        device: locationDevice ?? const LocationDevice(),
        publish: _publishPosition,
        clear: _clearPosition,
      )..addListener(notifyListeners);
    }
  }

  /// Local, per-account composer drafts (private app storage, never uploaded).
  final ComposeDraftStore drafts;

  /// Native feed ads: consent, age treatment and availability. Never fed with any SenMiydin location data.
  final AdsService ads;

  /// Admin switch (`ads_enabled`) and the organic-posts-per-ad interval (`feed_ad_interval`) from /app-config.
  bool adsEnabled = true;
  int feedAdInterval = AdsConfig.defaultInterval;

  /// Whether Home feeds mix in native ads right now: signed in, switched on by the admin, consent given, unit present.
  bool get showFeedAds => connected && adsEnabled && ads.available;

  CommunicationApi? communication;
  MapNotesApi? mapNotes;

  /// Bumped when a note is created or removed so the map reloads its envelope markers.
  int mapNotesVersion = 0;
  PushClient? push;
  int unreadMessages = 0, unreadNotifications = 0, communicationVersion = 0;
  bool _loadingUnread = false;
  bool _loadingHomeConfig = false;
  bool nearbyModuleEnabled = true, featuredModuleEnabled = true;

  /// Small Home card "Yakınında N yeni mektup var" (admin module switch) and the private unread-near-me summary.
  bool nearbyNotesEnabled = true;
  MapNoteUnread nearbyUnread = const MapNoteUnread(0, locationRequired: true);

  /// Set by the Home card so the map opens straight in its Notlar view.
  bool openMapInNotes = false;

  /// One-shot request for the map screen to centre on an approximate point ("Haritada Aç" / "Haritada Gör").
  LatLng? mapFocus;

  /// Server-side minimum registration age (single config value); null until /app-config answered.
  int minimumAge = 16;
  String? maintenanceNotice;
  VersionPolicy? versionPolicy;
  (String, String)? homeAnnouncement;

  Future<void> refreshHomeConfig() async {
    if (!authenticated || _loadingHomeConfig || _social == null) return;
    _loadingHomeConfig = true;
    final accountId = _account?.id;
    try {
      final data = await _social.object('GET', 'app-config');
      if (_disposed || _account?.id != accountId) return;
      VersionPolicy? policy;
      try {
        final platform = defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android';
        final versions = data['versions'] as Map<String, dynamic>?;
        policy = VersionPolicy.fromJson(
          (await ReleaseInfo.package).version,
          platform,
          versions?[platform] as Map<String, dynamic>?,
        );
      } catch (_) {
        // Configuration and platform metadata will be retried on the next refresh.
      }
      if (_disposed || _account?.id != accountId) return;
      final nearby = data['nearby_enabled'] != false;
      final featured = data['featured_enabled'] != false;
      final notesModule = data['nearby_notes_enabled'] != false;
      minimumAge = (data['minimum_age'] as num?)?.toInt() ?? minimumAge;
      final adsOn = data['ads_enabled'] != false;
      final interval =
          (data['feed_ad_interval'] as num?)?.toInt() ??
          AdsConfig.defaultInterval;
      if (adsOn != adsEnabled || interval != feedAdInterval) {
        adsEnabled = adsOn;
        feedAdInterval = interval;
        notifyListeners();
      }
      if (adsOn) {
        // Consent first, SDK only afterwards; teen accounts get the age-restricted treatment.
        unawaited(ads.start(teen: _account?.ageBand == 'teen'));
      }
      final maintenance = data['maintenance_message'] as String?;
      final item = data['announcement'] as Map<String, dynamic>?;
      final announcement = item == null
          ? null
          : (item['title'] as String, item['body'] as String);
      if (nearby != nearbyModuleEnabled ||
          featured != featuredModuleEnabled ||
          notesModule != nearbyNotesEnabled ||
          maintenance != maintenanceNotice ||
          announcement != homeAnnouncement ||
          policy?.latest != versionPolicy?.latest ||
          policy?.required != versionPolicy?.required ||
          policy?.url != versionPolicy?.url) {
        nearbyModuleEnabled = nearby;
        featuredModuleEnabled = featured;
        nearbyNotesEnabled = notesModule;
        maintenanceNotice = maintenance;
        versionPolicy = policy;
        homeAnnouncement = announcement;
        notifyListeners();
      }
      unawaited(refreshNearbyUnread());
    } on ApiFailure {
      // Configuration is refreshed on the next foreground poll.
    } finally {
      _loadingHomeConfig = false;
    }
  }

  /// Switches the app language (tr / en), persists it on the device and, when signed in, on the account so the
  /// server can localize notification texts and push bodies. The server call is best effort.
  Future<void> setLanguage(String code) async {
    await AppLocale.set(Locale(code));
    notifyListeners();
    final social = _social;
    if (!authenticated || social == null) return;
    try {
      await social.object('PUT', 'profile', body: {'preferred_locale': code});
    } catch (_) {
      // The device choice already applies; the account preference syncs the next time the user changes it.
    }
  }

  /// Public config read (no account needed): the registration age gate, owned by the server.
  Future<void> loadMinimumAge() async {
    final api = _api;
    if (api == null) return;
    try {
      final data = await api.send('GET', 'app-config') as Map<String, dynamic>;
      final age = (data['minimum_age'] as num?)?.toInt();
      if (age != null && age != minimumAge && !_disposed) {
        minimumAge = age;
        notifyListeners();
      }
    } catch (_) {
      // The last known value (default 18) stays; the server still validates the date of birth.
    }
  }

  /// Private count of active letters near the user that were never opened. No location (or the module off) means nothing is shown.
  Future<void> refreshNearbyUnread() async {
    if (!authenticated || mapNotes == null || !nearbyNotesEnabled) {
      return;
    }
    // The server decides: without a recent location (no permission, or none shared yet) it answers location_required and no card is shown.
    final accountId = _account?.id;
    try {
      final result = await mapNotes!.unread();
      if (_disposed || _account?.id != accountId) return;
      _setUnread(result);
    } on ApiFailure {
      // Shown again after the next poll.
    }
  }

  void _setUnread(MapNoteUnread value) {
    if (value.count != nearbyUnread.count ||
        value.locationRequired != nearbyUnread.locationRequired ||
        value.enabled != nearbyUnread.enabled) {
      nearbyUnread = value;
      notifyListeners();
    }
  }

  /// The reader really opened a letter's detail page (never just saw its marker): idempotent, private.
  Future<void> markMapNoteRead(int id) async {
    try {
      _setUnread(await mapNotes!.markRead(id));
    } on ApiFailure {
      // Reading is best-effort; the count is corrected on the next refresh.
    }
  }

  bool _disposed = false;
  final ApiClient? _api;

  Future<bool> refreshUnread() async {
    if (!authenticated || _loadingUnread || communication == null) return false;
    _loadingUnread = true;
    try {
      final counts = await communication!.counts();
      if (_disposed) return false;
      final messages = counts['messages'] as int;
      final notifications = counts['notifications'] as int;
      if (messages != unreadMessages || notifications != unreadNotifications) {
        unreadMessages = messages;
        unreadNotifications = notifications;
        communicationVersion++;
        notifyListeners();
      }
      return true;
    } on ApiFailure {
      return false;
    } finally {
      _loadingUnread = false;
    }
  }

  void communicationChanged() {
    communicationVersion++;
    notifyListeners();
    unawaited(refreshUnread());
  }

  Future<void> setRemoteBlock(String id, bool value) async {
    if (communication == null || !id.startsWith('account-')) {
      value ? block(id) : unblock(id);
      return;
    }
    await communication!.block(id, value);
    if (value) {
      blocked.add(id);
    } else {
      blocked.remove(id);
    }
    _nearbyCache.clear();
    locationVersion++;
    postsVersion++;
    followsVersion++;
    encounterVersion++;
    communicationChanged();
  }

  final AuthService? auth;
  final ProfileService? _profiles;
  final CatalogService? _catalog;
  final PlaceService? _places;

  /// Areas met through the place picker, by name (most recent wins), so code that still works with area names
  /// (feeds, compose) can find their ids.
  final _knownCities = <String, CatalogItem>{};

  /// Interests picked during onboarding but not saved yet: kept when the person goes back a step and returns.
  Set<int>? draftInterests;
  final SocialService? _social;
  LocationService? location;
  CatalogItem? activeCity;
  int locationVersion = 0;
  bool _cityChosen = false;
  bool manualCityRequired = false;
  final _nearbyCache =
      <Object, (DateTime, Future<LocationResults<NearbyPerson>>)>{};

  Future<void> _publishPosition(Position position, bool historyOnly) async {
    final data = await _social!.object(
      'PUT',
      'location',
      body: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'history_only': historyOnly,
        'record_history': location?.historyAllowed == true,
      },
    );
    if (_disposed || historyOnly || _account == null) return;
    final resolved = data['city'] is Map<String, dynamic>
        ? CatalogItem.fromJson(data['city'] as Map<String, dynamic>)
        : null;
    if (resolved != null) {
      rememberCity(resolved);
      activeCity = resolved;
      _cityChosen = false;
      city = resolved.name;
    } else if (!_cityChosen) {
      activeCity = null;
    }
    manualCityRequired = data['manual_city_required'] == true && !_cityChosen;
    locationVersion++;
    _nearbyCache.clear();
  }

  Future<void> _clearPosition() async {
    await _social!.delete('location');
    if (_disposed || _account == null) return;
    if (!_cityChosen) {
      activeCity = null;
      city = account!.city.name;
    }
    locationVersion++;
    _nearbyCache.clear();
    notifyListeners();
  }

  int? get radiusMeters {
    if (filter.maxDistance.isFinite) return (filter.maxDistance * 1000).round();
    return filter.nearbyOnly ? 5000 : null;
  }

  Future<LocationResults<NearbyPerson>> loadNearby({
    int limit = 20,
    bool refresh = false,
  }) {
    if (location?.synced != true || location?.allowed != true) {
      return Future.value(const LocationResults([], permissionRequired: true));
    }
    final key = (city, radiusMeters, locationVersion, limit);
    final now = DateTime.now();
    final cached = _nearbyCache[key];
    if (!refresh &&
        cached != null &&
        now.difference(cached.$1) < const Duration(seconds: 20)) {
      return cached.$2;
    }
    final future = _loadNearby(city, radiusMeters ?? 10000, limit);
    _nearbyCache[key] = (now, future);
    return future;
  }

  Future<LocationResults<NearbyPerson>> _loadNearby(
    String city,
    int radius,
    int limit,
  ) async {
    final data = await _api!.send(
      'GET',
      'nearby/users',
      authenticated: true,
      query: {
        'city_id': '${await cityId(city)}',
        'radius': '$radius',
        'limit': '$limit',
      },
    ) as Map<String, dynamic>;
    return LocationResults(
      (data['items'] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (item) => NearbyPerson(
              _rememberPerson(item),
              item['distance_meters'] as int,
            ),
          )
          .where((entry) => !blocked.contains(entry.person.id))
          .toList(),
      permissionRequired: data['location_required'] == true,
    );
  }

  Future<LocationResults<MapPostPoint>> loadMap() async {
    final radius = radiusMeters;
    if (radius != null &&
        (location?.synced != true || location?.allowed != true)) {
      return const LocationResults([], permissionRequired: true);
    }
    final data = await _api!.send(
      'GET',
      'map/posts',
      authenticated: true,
      query: {
        'city_id': '${await cityId(city)}',
        if (radius != null) 'radius': '$radius',
        'sort': filter.sort == 'Popüler' ? 'popular' : 'new',
        if (location?.synced != true || location?.allowed != true)
          'use_location': '0',
      },
    ) as Map<String, dynamic>;
    return LocationResults(
      (data['items'] as List)
          .cast<Map<String, dynamic>>()
          .map(MapPostPoint.fromJson)
          .toList(),
      permissionRequired: data['location_required'] == true,
    );
  }

  Future<MapNoteMarkers> loadMapNotes() async {
    final radius = radiusMeters;
    if (radius != null &&
        (location?.synced != true || location?.allowed != true)) {
      return const MapNoteMarkers([], locationRequired: true);
    }
    return mapNotes!.markers(
      cityId: await cityId(city),
      radius: radius,
      useLocation: location?.synced == true && location?.allowed == true,
    );
  }

  void mapNotesChanged() {
    mapNotesVersion++;
    notifyListeners();
    unawaited(refreshNearbyUnread());
  }

  final _remotePosts = <String, Post>{};
  final _remotePeople = <String, Person>{};
  final _socialWrites = <String>{};
  int postsVersion = 0,
      savedVersion = 0,
      commentsVersion = 0,
      followsVersion = 0;

  int encounterVersion = 0;

  EncounterEntry _encounterEntry(Map<String, dynamic> json) => EncounterEntry(
    id: json['id'].toString(),
    status: json['status'] as String,
    outgoing: json['outgoing'] == true,
    requester: _rememberPerson(json['requester'] as Map<String, dynamic>),
    target: _rememberPerson(json['target'] as Map<String, dynamic>),
    source: json['source'] == null
        ? null
        : _rememberPost(json['source'] as Map<String, dynamic>),
    story: json['story'] == null
        ? null
        : _rememberPost(json['story'] as Map<String, dynamic>),
    encounterId: json['encounter_id'] as int?,
    storyRevision: (json['story'] as Map?)?['story_revision'] as int?,
    time: '',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  Future<EncounterEntry> loadEncounter(String id) async =>
      _encounterEntry(await _social!.object('GET', 'encounter-requests/$id'));

  Future<SocialPage<EncounterEntry>> loadEncounters(
    int page, {
    String? status,
    bool inbox = false,
  }) async => (await _social!.page(
    'encounter-requests',
    page,
    query: {'status': ?status, if (inbox) 'inbox': '1'},
  )).map(_encounterEntry);

  Future<SocialPage<Post>> loadFeaturedEncounters(
    int page, {
    String? username,
  }) async => (await _social!.page(
    username == null ? 'encounters/featured' : 'users/$username/encounters',
    page,
    query: {if (username == null) 'city_id': '${await cityId(city)}'},
  )).map(_rememberPost);

  Future<EncounterEntry> respondEncounter(String id, String action) async {
    final item = _encounterEntry(
      await _social!.object(
        action == 'cancel' ? 'DELETE' : 'POST',
        action == 'cancel'
            ? 'encounter-requests/$id'
            : 'encounter-requests/$id/$action',
      ),
    );
    _encountersChanged();
    return item;
  }

  Future<EncounterEntry> reviewEncounterStory(
    EncounterEntry item,
    String action,
  ) async {
    final result = _encounterEntry(
      await _social!.object(
        'POST',
        'encounters/${item.encounterId}/story/$action',
        body: {'revision': item.storyRevision},
      ),
    );
    _encountersChanged();
    return result;
  }

  Future<void> reviseEncounterStory(
    EncounterEntry item,
    String title,
    String body,
  ) async {
    await _social!.object(
      'PUT',
      'encounters/${item.encounterId}/story',
      body: {
        'revision': item.storyRevision,
        'title': title.trim(),
        'body': body.trim(),
      },
    );
    _encountersChanged();
  }

  void _encountersChanged() {
    encounterVersion++;
    postsVersion++;
    notifyListeners();
    unawaited(refreshUnread());
  }

  bool isRemotePost(String id) => connected && int.tryParse(id) != null;
  Post? cachedPost(String id) => _remotePosts[id];
  Map<String, String> mediaHeaders(String url) =>
      _api?.mediaHeaders(url) ?? const {};

  Person _rememberPerson(Map<String, dynamic> json) {
    final incoming = socialPerson(json);
    final existing = incoming.id == me.id ? me : _remotePeople[incoming.id];
    if (existing == null) {
      _remotePeople[incoming.id] = incoming;
      return incoming;
    }
    if (incoming.id != me.id) {
      existing
        ..name = incoming.name
        ..handle = incoming.handle
        ..photo = incoming.photo
        ..cover = incoming.cover
        ..bio = incoming.bio
        ..occupation = incoming.occupation;
      if (json.containsKey('city')) existing.city = incoming.city;
      if (json.containsKey('interests')) {
        existing.interests = incoming.interests;
      }
    }
    if (json.containsKey('post_count')) existing.postCount = incoming.postCount;
    if (json.containsKey('encounter_count')) {
      existing.encounterCount = incoming.encounterCount;
    }
    if (json.containsKey('followers_count')) {
      existing.followersCount = incoming.followersCount;
    }
    if (json.containsKey('following_count')) {
      existing.followingCount = incoming.followingCount;
    }
    if (json.containsKey('following')) {
      existing.isFollowing = incoming.isFollowing;
    }
    return existing;
  }

  Post _rememberPost(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    final incoming = socialPost(
      json,
      author == null ? '' : _rememberPerson(author).id,
    );
    incoming.storyParticipants =
        (json['story_participants'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(_rememberPerson)
            .toList();
    final existing = _remotePosts[incoming.id];
    if (existing == null) {
      _remotePosts[incoming.id] = incoming;
      return incoming;
    }
    existing
      ..text = incoming.text
      ..liked = incoming.liked
      ..saved = incoming.saved
      ..likes = incoming.likes
      ..commentCount = incoming.commentCount
      ..distanceMeters = incoming.distanceMeters
      ..occurredAt = incoming.occurredAt
      ..matchHint = incoming.matchHint
      ..travel = incoming.travel
      ..locationLabel = incoming.locationLabel
      ..encounterConfirmed = incoming.encounterConfirmed
      ..encounterRequestId = incoming.encounterRequestId
      ..encounterRequestStatus = incoming.encounterRequestStatus
      ..storyTitle = incoming.storyTitle
      ..storyStatus = incoming.storyStatus
      ..storyRevision = incoming.storyRevision
      ..storyParticipants = incoming.storyParticipants
      ..shareUrl = incoming.shareUrl
      ..cityWide = incoming.cityWide
      ..createdAt = incoming.createdAt
      ..time = incoming.time;
    return existing;
  }

  Comment _socialComment(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return Comment(
      author == null ? '' : _rememberPerson(author).id,
      json['body'] as String,
      id: json['id'].toString(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      mine: json['mine'] == true,
      parentId: json['parent_id']?.toString(),
      likes: (json['likes_count'] as num?)?.toInt() ?? 0,
      liked: json['liked_by_me'] == true,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      replies: [
        for (final reply in (json['replies'] as List?) ?? const [])
          _socialComment(reply as Map<String, dynamic>),
      ],
    );
  }

  Future<SocialPage<Post>> loadFeed(int page) async {
    final location = city;
    final current = filter.copy();
    final radius = radiusMeters;
    if (radius != null &&
        (this.location?.synced != true || this.location?.allowed != true)) {
      return const SocialPage([], null);
    }
    final selectedCity = location == account?.city.name
        ? account!.city.id
        : await cityId(location);
    final sort = switch (current.sort) {
      'En yakın' => 'nearby',
      'Popüler' => 'popular',
      _ => 'new',
    };
    // "Takip": the same feed query narrowed to the people the viewer follows (server-side).
    final following = current.sort == 'Takip';
    final content = switch (current.content) {
      'Fotoğraflı' => 'photo',
      'Yazılı' => 'text',
      'Karşılaşmalar' => 'encounter',
      'Etiketli' => 'tagged',
      'Anı' => 'moment',
      'İtiraf' => 'confession',
      'Düşünce' => 'thought',
      'Yolculuk' => 'travel',
      _ => null,
    };
    return (await _social!.page(
      'feed',
      page,
      query: {
        'city_id': '$selectedCity',
        'sort': sort,
        if (following) 'following': '1',
        if (this.location?.synced != true || this.location?.allowed != true)
          'use_location': '0',
        if (radius != null) 'radius': '$radius',
        'content': ?content,
        if (current.media != 'Tümü')
          'media': current.media == 'Fotoğraflı' ? 'photo' : 'text',
        if (current.photoFirst) 'photo_first': '1',
        if (current.encounterFirst) 'encounter_first': '1',
        for (final (index, item) in current.interests.indexed)
          'interests[$index]': item,
      },
    )).map(_rememberPost);
  }

  /// Asks the server what a shared link points to for this account: `('post', id)` or `('map_note', id)`, or null
  /// when it is not available to this account (removed, private, blocked, other age group ...).
  Future<(String, int)?> resolveShareLink(String publicId) async {
    try {
      final data = await _social!.object('GET', 'share-links/$publicId');
      final id = (data['id'] as num?)?.toInt();
      final type = data['type'] as String?;
      return id == null || type == null ? null : (type, id);
    } on ApiFailure catch (failure) {
      if (failure.status == 404) return null;
      rethrow;
    }
  }

  Future<Post> loadPost(String id) async =>
      _rememberPost(await _social!.object('GET', 'posts/$id'));

  Future<Post> publishPost({
    required String body,
    required PostKind kind,
    required List<XFile> media,
    required bool anonymous,
    required bool cityWide,
    required String location,
    required String requestId,
    int? placeId,
    bool attachLocation = false,
    PostPlaceSelection? place,
    DateTime? occurredAt,
    TravelDetails? travel,
    String? targetId,
    int? encounterId,
    String? storyTitle,
  }) async {
    final post = _rememberPost(
      await _social!.object(
        'POST',
        'posts',
        media: media,
        body: {
          'body': body.trim(),
          'type': kind.value,
          'city_id': await cityId(location),
          'place_id': ?placeId,
          'visibility': cityWide ? 'city' : 'private',
          'is_anonymous': anonymous ? 1 : 0,
          'request_id': requestId,
          if (place != null) ...place.toJson(),
          if (occurredAt != null)
            'occurred_at': occurredAt.toUtc().toIso8601String(),
          if (travel != null) 'travel': travel.toJson(),
          if (targetId != null)
            'encounter_target_id': int.parse(
              targetId.substring('account-'.length),
            ),
          'encounter_id': ?encounterId,
          'story_title': ?storyTitle?.trim(),
          if (attachLocation &&
              this.location?.synced == true &&
              this.location?.allowed == true)
            'attach_location': 1,
        },
      ),
    );
    if (targetId != null || encounterId != null) {
      _encountersChanged();
    } else {
      postsVersion++;
      notifyListeners();
    }
    unawaited(noteMeaningfulAction());
    return post;
  }

  Future<void> editPost(Post post, String text) async {
    _rememberPost(
      await _social!.object(
        'PUT',
        'posts/${post.id}',
        body: {'body': text.trim()},
      ),
    );
    postsVersion++;
    notifyListeners();
  }

  Future<void> deletePost(Post post) async {
    await _social!.delete('posts/${post.id}');
    _remotePosts.remove(post.id);
    encounterVersion++;
    postsVersion++;
    savedVersion++;
    notifyListeners();
  }

  Future<void> react(Post post, String action) async {
    final key = '${post.id}/$action';
    if (!_socialWrites.add(key)) return;
    try {
      final active = action == 'like' ? post.liked : post.saved;
      final result = await _social!.object(
        active ? 'DELETE' : 'POST',
        'posts/$key',
      );
      if (action == 'like') {
        post.liked = result['liked'] == true;
        post.likes = result['likes_count'] as int;
      } else {
        post.saved = result['saved'] == true;
        // Un-saving also leaves every collection (the server does the same).
        savedVersion++;
        collectionsVersion++;
      }
      notifyListeners();
    } finally {
      _socialWrites.remove(key);
    }
  }

  Future<SocialPage<Post>> loadSaved(int page) async =>
      (await _social!.page('posts/saved', page)).map(_rememberPost);

  Future<SocialPage<Comment>> loadComments(String id, int page) async =>
      (await _social!.page('posts/$id/comments', page)).map(_socialComment);

  /// Every reply of one top-level comment, oldest first (conversation order).
  Future<SocialPage<Comment>> loadReplies(
    String postId,
    String commentId,
    int page,
  ) async => (await _social!.page(
    'posts/$postId/comments/$commentId/replies',
    page,
  )).map(_socialComment);

  /// Like / unlike a comment or reply. The state flips at once and is restored if the server refuses.
  Future<void> toggleCommentLike(Post post, Comment comment) async {
    final key = 'c${comment.id}';
    if (comment.id == null || !_socialWrites.add(key)) return;
    final wasLiked = comment.liked;
    final wasCount = comment.likes;
    comment
      ..liked = !wasLiked
      ..likes = (wasCount + (wasLiked ? -1 : 1)).clamp(0, 1 << 30);
    notifyListeners();
    try {
      final result = await _social!.object(
        wasLiked ? 'DELETE' : 'POST',
        'posts/${post.id}/comments/${comment.id}/like',
      );
      comment
        ..liked = result['liked_by_me'] == true
        ..likes = (result['likes_count'] as num).toInt();
    } catch (_) {
      comment
        ..liked = wasLiked
        ..likes = wasCount;
      rethrow;
    } finally {
      _socialWrites.remove(key);
      notifyListeners();
    }
  }

  // ---- Private saved collections -------------------------------------------------------------

  /// Bumped whenever a collection or its contents change so open lists reload.
  int collectionsVersion = 0;

  Future<List<SavedCollection>> loadCollections({String? postId}) async {
    final data = await _api!.send(
      'GET',
      'saved-collections',
      authenticated: true,
      query: {'post_id': ?postId},
    ) as Map<String, dynamic>;
    return [
      for (final item in (data['items'] as List).cast<Map<String, dynamic>>())
        SavedCollection.fromJson(item),
    ];
  }

  Future<SavedCollection> createCollection(String name) async {
    final data = await _social!.object(
      'POST',
      'saved-collections',
      body: {'name': name},
    );
    collectionsVersion++;
    notifyListeners();
    return SavedCollection.fromJson(data);
  }

  Future<SavedCollection> renameCollection(
    SavedCollection collection,
    String name,
  ) async {
    final data = await _social!.object(
      'PUT',
      'saved-collections/${collection.id}',
      body: {'name': name},
    );
    collectionsVersion++;
    notifyListeners();
    return SavedCollection.fromJson(data);
  }

  /// Deleting a collection never un-saves its posts.
  Future<void> deleteCollection(SavedCollection collection) async {
    await _social!.delete('saved-collections/${collection.id}');
    collectionsVersion++;
    notifyListeners();
  }

  Future<SocialPage<Post>> loadCollectionPosts(int id, int page) async =>
      (await _social!.page(
        'saved-collections/$id/posts',
        page,
      )).map(_rememberPost);

  Future<void> setCollectionMembership(
    SavedCollection collection,
    Post post,
    bool member,
  ) async {
    final data = await _social!.object(
      member ? 'PUT' : 'DELETE',
      'saved-collections/${collection.id}/posts/${post.id}',
    );
    collection
      ..containsPost = data['contains_post'] == true
      ..postsCount =
          (data['posts_count'] as num?)?.toInt() ?? collection.postsCount;
    collectionsVersion++;
    notifyListeners();
  }

  Future<void> writeComment(Post post, String text, {Comment? parent}) async {
    await _social!.object(
      'POST',
      'posts/${post.id}/comments',
      body: {'body': text.trim(), 'parent_id': ?parent?.id},
    );
    post.commentCount++;
    commentsVersion++;
    notifyListeners();
    unawaited(noteMeaningfulAction());
  }

  Future<void> removeComment(Post post, Comment comment) async {
    await _social!.delete('posts/${post.id}/comments/${comment.id}');
    if (post.commentCount > 0) post.commentCount--;
    commentsVersion++;
    notifyListeners();
  }

  Future<Person> loadPublicProfile(String username) async =>
      _rememberPerson(await _social!.object('GET', 'users/$username'));

  Future<SocialPage<Post>> loadProfilePosts(String username, int page) async =>
      (await _social!.page('users/$username/posts', page)).map(_rememberPost);

  Future<SocialPage<Person>> loadConnections(
    String username,
    String relation,
    int page,
  ) async => (await _social!.page(
    'users/$username/$relation',
    page,
  )).map(_rememberPerson);

  /// Whether the signed-in user follows anybody (decides which Takip empty state is honest). Only asked when that feed is empty.
  Future<bool> followsAnyone() async {
    if (!connected) return me.followingCount > 0;
    final page = await loadConnections(me.handle, 'following', 1);
    return page.items.isNotEmpty;
  }

  Future<void> toggleFollow(Person person) async {
    if (!_socialWrites.add(person.id)) return;
    try {
      final wasFollowing = person.isFollowing;
      _rememberPerson(
        await _social!.object(
          wasFollowing ? 'DELETE' : 'POST',
          'users/${person.handle}/follow',
        ),
      );
      // Keep the own "following" count honest so the Takip empty state and a fresh Takip feed agree.
      final mine = _accountPerson;
      if (mine != null && person.isFollowing != wasFollowing) {
        mine.followingCount = (mine.followingCount + (wasFollowing ? -1 : 1))
            .clamp(0, 1 << 30);
      }
      followsVersion++;
      postsVersion++;
      notifyListeners();
    } finally {
      _socialWrites.remove(person.id);
    }
  }

  Future<SocialPage<Person>> searchPeople(
    String text,
    int page, {
    bool encounter = false,
  }) async => (await _social!.page(
    'search',
    page,
    query: {'q': text, 'type': 'users', if (encounter) 'encounter': '1'},
  )).map(_rememberPerson);

  Future<SocialPage<Post>> searchPosts(String text, int page) async =>
      (await _social!.page(
        'search',
        page,
        query: {'q': text, 'type': 'posts', 'city_id': '${await cityId(city)}'},
      )).map(_rememberPost);
  AccountProfile? _account;
  Person? _accountPerson;
  List<CatalogItem>? _cities, _interests;

  bool get connected => _api != null;
  AccountProfile? get account => _account;
  String get accountRoute => switch (_account?.onboardingStep) {
    0 => '/complete',
    1 => '/interests',
    2 => '/permissions',
    _ => '/home',
  };

  static const connectionChoices = {
    'friendship': 'Arkadaşlık',
    'encounters': 'Karşılaşmalar',
    'chat': 'Sohbet',
    'meet_people': 'Yeni insanlarla tanışma',
  };

  Future<String> restoreAccount() async {
    if (!connected) return '/welcome';
    try {
      final profile = await auth!.restore();
      if (profile == null) return '/welcome';
      _applyAccount(profile);
      return accountRoute;
    } on ApiFailure catch (error) {
      if (error.status == 401) return '/login';
      rethrow;
    }
  }

  Future<void> signIn(String action, Map<String, Object?> fields) async {
    _applyAccount(await auth!.signIn(action, fields));
  }

  /// [password] for accounts with an app password; otherwise [proof] from a fresh Google / Apple sign-in.
  Future<void> eraseAccount(
    String? password, {
    Map<String, Object?>? proof,
  }) async {
    final id = _account?.id;
    await auth!.erase(password: password, proof: proof);
    // Account deletion also removes whatever draft (and draft photos) that account left on this device.
    if (id != null) {
      try {
        await drafts.clear('account-$id');
      } catch (_) {
        // Best effort: the account is gone either way.
      }
      try {
        await reviews.forget(id);
      } catch (_) {
        // Only bookkeeping.
      }
    }
    _clearAccount();
  }

  Future<void> signOut() async {
    if (!connected) {
      logout();
      return;
    }
    try {
      await auth!.logout();
      _clearAccount();
    } on ApiFailure catch (error) {
      if (error.status != 401) rethrow;
      _clearAccount();
    }
  }

  Future<void> saveAccountProfile(Map<String, Object?> fields) async {
    _applyAccount(await _profiles!.save(fields));
  }

  Future<void> uploadAvatar(XFile image) async {
    _applyAccount(await _profiles!.uploadAvatar(image));
  }

  Future<void> uploadCover(XFile image) async {
    _applyAccount(await _profiles!.uploadCover(image));
  }

  Future<void> removeCover() async {
    _applyAccount(await _profiles!.removeCover());
  }

  Future<void> saveAccountInterests(List<CatalogItem> items) async {
    if (!connected) {
      me.interests = items.map((item) => item.name).toList();
      refresh();
      return;
    }
    _applyAccount(
      await _profiles!.saveInterests(items.map((item) => item.id).toList()),
    );
  }

  Future<List<CatalogItem>> loadCities() async {
    if (!connected) return previewCities;
    return _cities ??= await _catalog!.cities();
  }

  /// Remembers the area of a chosen place so the rest of the app can address it by name.
  void rememberCity(CatalogItem city) {
    _knownCities.remove(city.name);
    _knownCities[city.name] = city;
  }

  /// Place search through the API. Explicit searches only (a search button), never one call per keystroke.
  Future<List<PlaceResult>> searchPlaces(String query) =>
      _places!.search(query.trim(), country: _account?.place?.countryCode);

  /// Stores the picked search result on the server and returns it with its area.
  Future<ChosenPlace> resolvePlace(PlaceResult result) async {
    final chosen = await _places!.resolve(result.token);
    rememberCity(chosen.city);
    return chosen;
  }

  /// The neighbourhood / district around the device. The coordinate goes only to the SenMiydin API, which rounds it
  /// to about 1 km before asking the map provider; nothing is stored. Throws a readable [ApiFailure] when location is
  /// off or not allowed, so the picker can fall back to search.
  Future<PlaceResult?> placeAtDevice() async {
    final device = location?.device ?? const LocationDevice();
    try {
      if (!await device.enabled()) {
        throw const ApiFailure(
          'Konum servisleri kapalı. Yeri aramayla seçebilirsin.',
        );
      }
      var permission = await device.permission();
      if (permission == LocationPermission.denied) {
        permission = await device.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        throw const ApiFailure(
          'Konum izni verilmedi. Yeri aramayla seçebilirsin.',
        );
      }
      final point = await device.lastKnown() ?? await device.current();
      return await _places!.reverse(point.latitude, point.longitude);
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(
        'Konumun şu anda bulunamadı. Yeri aramayla seçebilirsin.',
      );
    } catch (_) {
      throw const ApiFailure(
        'Konumun şu anda bulunamadı. Yeri aramayla seçebilirsin.',
      );
    }
  }

  /// True while the operating system has not been asked for location yet (a short explanation is shown first).
  Future<bool> locationPermissionUndecided() async {
    try {
      return await (location?.device ?? const LocationDevice()).permission() ==
          LocationPermission.denied;
    } catch (_) {
      return false;
    }
  }

  Future<int> cityId(String name) async {
    final known = _knownCities[name];
    if (known != null) return known.id;
    final city = (await loadCities())
        .where((item) => item.name == name)
        .firstOrNull;
    if (city == null) throw const ApiFailure('Listeden bir şehir seç.');
    return city.id;
  }

  Future<List<CatalogItem>> loadInterests() async {
    if (!connected) {
      return allInterests.indexed
          .map((item) => CatalogItem(item.$1, item.$2))
          .toList();
    }
    return _interests ??= await _catalog!.interests();
  }

  static const previewCities = [
    CatalogItem(1, 'Alanya'),
    CatalogItem(2, 'İstanbul'),
    CatalogItem(3, 'Ankara'),
    CatalogItem(4, 'İzmir'),
    CatalogItem(5, 'Antalya'),
  ];

  void _applyAccount(AccountProfile profile) {
    final previous = _account;
    // Areas created from the place picker are not in the old catalogue list: remember the account's own.
    rememberCity(profile.city);
    if (profile.activeCity != null) rememberCity(profile.activeCity!);
    if (previous == null && profile.activeCitySource == 'manual') {
      _cityChosen = true;
    }
    activeCity ??= profile.activeCity;
    if (previous == null && _cityChosen && activeCity != null) {
      city = activeCity!.name;
    }
    if (!_cityChosen) city = activeCity?.name ?? profile.city.name;
    _account = profile;
    _accountPerson = Person(
      id: 'account-${profile.id}',
      name: profile.name,
      handle: profile.username,
      photo: profile.avatar,
      city: profile.city.name,
      distance: 0,
      visible: profile.nearbyVisible,
      remote: true,
      cover: profile.cover,
      postCount: _accountPerson?.postCount ?? 0,
      followersCount: _accountPerson?.followersCount ?? 0,
      encounterCount: _accountPerson?.encounterCount ?? 0,
      followingCount: _accountPerson?.followingCount ?? 0,
      bio: profile.bio,
      occupation: profile.occupation,
      interests: profile.interests.map((item) => item.name).toList(),
    );
    connections
      ..clear()
      ..addAll(
        profile.connections
            .map((key) => connectionChoices[key])
            .whereType<String>(),
      );
    preferences['Konum temelli öneriler'] = profile.cityDiscovery;
    preferences['Geçtiğim yer bildirimleri'] = profile.locationHistoryEnabled;
    authenticated = true;
    location?.configure(active: true, history: profile.locationHistoryEnabled);
    if (previous != null &&
        (previous.nearbyVisible != profile.nearbyVisible ||
            previous.city.id != profile.city.id)) {
      unawaited(location?.refresh(force: true));
    }
    notifyListeners();
  }

  void _clearAccount() {
    if (_disposed) return;
    final hadAccount = _account != null;
    location?.configure(active: false, history: false);
    activeCity = null;
    manualCityRequired = false;
    _cityChosen = false;
    _nearbyCache.clear();
    draftInterests = null;
    _account = null;
    _accountPerson = null;
    _reviewInviteReady = false;
    authenticated = false;
    ads.reset();
    push?.endSession();
    _remotePosts.clear();
    _remotePeople.clear();
    _socialWrites.clear();
    unreadMessages = unreadNotifications = 0;
    nearbyModuleEnabled = featuredModuleEnabled = true;
    nearbyNotesEnabled = true;
    nearbyUnread = const MapNoteUnread(0, locationRequired: true);
    openMapInNotes = false;
    maintenanceNotice = null;
    versionPolicy = null;
    homeAnnouncement = null;
    communicationVersion++;
    if (hadAccount) {
      people
        ..clear()
        ..addAll(seedPeople());
      posts
        ..clear()
        ..addAll(seedPosts());
      encounters
        ..clear()
        ..addAll(seedEncounters());
      conversations.clear();
      notices.clear();
      following
        ..clear()
        ..addAll({'u1', 'u2'});
      blocked.clear();
      connections
        ..clear()
        ..addAll({'Arkadaşlık', 'Karşılaşmalar'});
      preferences
        ..clear()
        ..addAll(_defaultPreferences);
      filter = FeedFilter();
      city = 'Alanya';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _api?.onUnauthorized = null;
    push?.dispose();
    location?.dispose();
    _api?.dispose();
    super.dispose();
  }

  final List<Person> people = seedPeople();
  final List<Post> posts = seedPosts();
  final List<Encounter> encounters = seedEncounters();
  late final List<Conversation> conversations = connected
      ? []
      : seedConversations();
  late final List<AppNotice> notices = connected ? [] : seedNotices();
  final Set<String> following = {'u1', 'u2'};
  late final Set<String> blocked = connected ? {} : {'u11'};
  final Set<String> connections = {'Arkadaşlık', 'Karşılaşmalar'};
  final Map<String, bool> preferences = {..._defaultPreferences};
  static const _defaultPreferences = {
    'Konum temelli öneriler': true,
    'Geçtiğim yer bildirimleri': false,
    'Mesaj bildirimleri': true,
    'Karşılaşma bildirimleri': true,
    'Beğeni / yorum bildirimleri': true,
    'Takip bildirimleri': true,
    'Bildirimlere izin ver': true,
  };
  FeedFilter filter = FeedFilter();
  String city = 'Alanya';
  bool authenticated = false;
  Person get me => _accountPerson ?? people.first;

  // ------------------------------------------------------------------------------------------------ review invitation

  /// The app's own weekly "rate SenMiydin?" invitation (see [ReviewPrompt]).
  final ReviewPrompt reviews;
  bool _reviewInviteReady = false;

  /// An invitation is due: a meaningful action just succeeded and the account qualifies. The home screen shows it a
  /// moment after the person is back there, never while something else is going on.
  bool get reviewInviteReady => _reviewInviteReady;

  /// A post, comment, message, Map Note or reply of the signed-in account went through.
  Future<void> noteMeaningfulAction() async {
    final account = _account;
    if (!connected || account == null) return;
    try {
      await reviews.recordAction(account.id);
      if (await reviews.isEligible(account.id, account.createdAt) &&
          !_reviewInviteReady) {
        _reviewInviteReady = true;
        notifyListeners();
      }
    } catch (_) {
      // Bookkeeping must never break the action that just succeeded.
    }
  }

  /// The invitation is on screen now (or was dropped): start the weekly cooldown.
  Future<void> reviewInviteShown() async {
    _reviewInviteReady = false;
    final account = _account;
    if (account != null) await reviews.markShown(account.id);
  }

  Person person(String id) => id == _accountPerson?.id
      ? _accountPerson!
      : _remotePeople[id] ?? people.firstWhere((p) => p.id == id);
  Post post(String id) =>
      _remotePosts[id] ?? posts.firstWhere((p) => p.id == id);
  int get unreadNotices => notices
      .where(
        (notice) =>
            !notice.read &&
            (notice.personId == null || !blocked.contains(notice.personId)),
      )
      .length;
  List<Person> get nearbyPeople => people
      .where((p) => p.visible && !blocked.contains(p.id) && p.city == city)
      .toList();
  List<Encounter> get featured => encounters
      .where(
        (e) =>
            e.status == EncounterStatus.approved &&
            !blocked.contains(e.fromId) &&
            !blocked.contains(e.toId),
      )
      .toList();
  List<Post> get feed {
    var result = posts.where(
      (p) =>
          !blocked.contains(p.authorId) &&
          p.city == city &&
          (p.cityWide || p.distance <= 5) &&
          p.distance <= filter.maxDistance,
    );
    if (filter.nearbyOnly) {
      result = result.where((p) => p.distance <= 5);
    }
    result = result.where(
      (p) => switch (filter.content) {
        'Fotoğraflı' => p.images.isNotEmpty,
        'Yazılı' => p.images.isEmpty,
        'Karşılaşmalar' => p.kind == PostKind.encounter,
        'Etiketli' => p.taggedId != null,
        'Anı' => p.kind == PostKind.memory,
        'İtiraf' => p.kind == PostKind.confession,
        'Düşünce' => p.kind == PostKind.thought,
        'Yolculuk' => p.kind == PostKind.journey,
        _ => true,
      },
    );
    if (filter.media == 'Fotoğraflı') {
      result = result.where((p) => p.images.isNotEmpty);
    } else if (filter.media == 'Yazılı') {
      result = result.where((p) => p.images.isEmpty);
    }
    if (filter.interests.isNotEmpty) {
      result = result.where(
        (p) => person(p.authorId).interests.any(filter.interests.contains),
      );
    }
    final list = result.toList();
    list.sort((a, b) {
      if (filter.encounterFirst &&
          (a.kind == PostKind.encounter) != (b.kind == PostKind.encounter)) {
        return a.kind == PostKind.encounter ? -1 : 1;
      }
      if (filter.photoFirst && a.images.isNotEmpty != b.images.isNotEmpty) {
        return a.images.isNotEmpty ? -1 : 1;
      }
      return switch (filter.sort) {
        'En yakın' => a.distance.compareTo(b.distance),
        'Popüler' => b.likes.compareTo(a.likes),
        _ => posts.indexOf(a).compareTo(posts.indexOf(b)),
      };
    });
    return list;
  }

  void refresh() => notifyListeners();
  void login() {
    assert(!connected);
    authenticated = true;
    notifyListeners();
  }

  void logout() {
    assert(!connected);
    authenticated = false;
    notifyListeners();
  }

  void like(Post p) {
    p.liked = !p.liked;
    p.likes += p.liked ? 1 : -1;
    notifyListeners();
  }

  void save(Post p) {
    p.saved = !p.saved;
    notifyListeners();
  }

  void comment(Post p, String text) {
    if (text.trim().isEmpty) {
      return;
    }
    p.comments.add(Comment(me.id, text.trim()));
    notifyListeners();
  }

  void follow(String id) {
    if (!following.add(id)) {
      following.remove(id);
    }
    notifyListeners();
  }

  void block(String id) {
    if (id != me.id) {
      blocked.add(id);
    }
    notifyListeners();
  }

  void unblock(String id) {
    blocked.remove(id);
    notifyListeners();
  }

  void markRead(AppNotice notice) {
    notice.read = true;
    notifyListeners();
  }

  void readAll() {
    for (final n in notices) {
      n.read = true;
    }
    notifyListeners();
  }

  void applyFilter(FeedFilter value) {
    filter = value;
    notifyListeners();
  }

  Future<void> setCity(String value, {int? placeId}) async {
    if (!connected) {
      _cityChosen = true;
      city = value;
      notifyListeners();
      return;
    }
    final data = await _social!.object(
      'PUT',
      'active-city',
      body: placeId != null
          ? {'place_id': placeId}
          : {'city_id': await cityId(value)},
    );
    if (_disposed || !authenticated) return;
    _cityChosen = true;
    manualCityRequired = false;
    activeCity = CatalogItem.fromJson(data['city'] as Map<String, dynamic>);
    rememberCity(activeCity!);
    city = activeCity!.name;
    locationVersion++;
    _nearbyCache.clear();
    notifyListeners();
  }

  Future<SocialPage<HistoricalPlace>> loadHistoricalPlaces(int page) async {
    if (account?.locationHistoryEnabled != true) {
      return const SocialPage([], null);
    }
    return (await _social!.page(
      'location-history',
      page,
    )).map(HistoricalPlace.fromJson);
  }

  void setPreference(String key, bool value) {
    preferences[key] = value;
    notifyListeners();
  }

  Conversation conversation(String id) {
    final existing = conversations.where((c) => c.personId == id);
    if (existing.isNotEmpty) {
      return existing.first;
    }
    final c = Conversation(id, []);
    conversations.insert(0, c);
    return c;
  }

  void send(String id, String text) {
    if (text.trim().isEmpty || blocked.contains(id)) {
      return;
    }
    conversation(id).messages
        .add(ChatMessage(text.trim(), mine: true, time: 'Şimdi'));
    notifyListeners();
  }

  Post publish({
    required String text,
    required PostKind kind,
    required List<String> images,
    required bool anonymous,
    required bool cityWide,
    String? taggedId,
    required String location,
  }) {
    final effectiveTag = anonymous ? null : taggedId;
    final p = Post(
      id: 'local-p${posts.length}',
      authorId: me.id,
      text: text.trim(),
      kind: kind,
      images: List.of(images),
      anonymous: anonymous,
      city: location,
      taggedId: effectiveTag,
      cityWide: cityWide,
      time: 'Az önce',
      distance: .2,
    );
    posts.insert(0, p);
    if (kind == PostKind.encounter && effectiveTag != null) {
      final e = Encounter(
        id: 'local-e${encounters.length}',
        postId: p.id,
        fromId: me.id,
        toId: effectiveTag,
      );
      encounters.insert(0, e);
      notices.insert(
        0,
        AppNotice(
          'local-n${notices.length}',
          NoticeKind.request,
          trf('{0} seni bir karşılaşmada etiketledi.', [me.name]),
          personId: me.id,
          postId: p.id,
          encounterId: e.id,
        ),
      );
    }
    notifyListeners();
    return p;
  }

  void resolveEncounter(Encounter e, bool approved) {
    if (e.status != EncounterStatus.pending) {
      return;
    }
    e.status = approved ? EncounterStatus.approved : EncounterStatus.rejected;
    for (final n in notices.where((n) => n.encounterId == e.id)) {
      n.read = true;
    }
    if (approved) {
      notices.insert(
        0,
        AppNotice(
          'local-n${notices.length}',
          NoticeKind.approved,
          trf('{0} karşılaşmanı onayladı. Birbirinizi buldunuz!', [
            person(e.toId).name,
          ]),
          personId: e.toId,
          encounterId: e.id,
          postId: e.postId,
        ),
      );
    }
    notifyListeners();
  }

  void deleteAccount() {
    posts.removeWhere((p) => p.authorId == me.id);
    encounters.removeWhere((e) => e.fromId == me.id || e.toId == me.id);
    following.clear();
    conversations.clear();
    notices.clear();
    me.visible = false;
    authenticated = false;
    notifyListeners();
  }
}

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
