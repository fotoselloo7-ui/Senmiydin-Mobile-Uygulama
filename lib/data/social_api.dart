import '../core/relative_time.dart';
import 'post_context.dart';

import 'package:image_picker/image_picker.dart';

import 'account_api.dart';
import 'models.dart';

class SocialPage<T> {
  const SocialPage(this.items, this.nextPage);
  final List<T> items;
  final int? nextPage;

  SocialPage<R> map<R>(R Function(T) convert) =>
      SocialPage(items.map(convert).toList(), nextPage);
}

class SocialService {
  SocialService(this.client);
  final ApiClient client;

  Future<Map<String, dynamic>> object(
    String method,
    String path, {
    Map<String, Object?>? body,
    List<XFile> media = const [],
  }) async => await client.send(
    method,
    path,
    authenticated: true,
    body: body,
    media: media,
  ) as Map<String, dynamic>;

  Future<SocialPage<Map<String, dynamic>>> page(
    String path,
    int page, {
    Map<String, dynamic> query = const {},
  }) async {
    final data = await client.send(
      'GET',
      path,
      authenticated: true,
      query: {...query, 'page': '$page'},
    ) as Map<String, dynamic>;
    return SocialPage(
      (data['items'] as List).cast<Map<String, dynamic>>(),
      data['next_page'] as int?,
    );
  }

  Future<void> delete(String path) async {
    await client.send('DELETE', path, authenticated: true);
  }
}

String socialTime(String value) => relativeTime(DateTime.parse(value).toLocal());

Person socialPerson(Map<String, dynamic> json) => Person(
  id: 'account-${json['id']}',
  name: json['name'] as String,
  handle: json['username'] as String,
  photo: ApiClient.mediaUrl(json['avatar'] as String?),
  cover: ApiClient.mediaUrl(json['cover_image'] as String?),
  city: (json['city'] as Map<String, dynamic>?)?['name'] as String? ?? '',
  bio: json['bio'] as String? ?? '',
  occupation: json['occupation_school'] as String? ?? '',
  interests:
      (json['interests'] as List?)
          ?.map((item) => item['name'] as String)
          .toList() ??
      [],
  remote: true,
  visible: false,
  distance: 0,
  postCount: json['post_count'] as int? ?? 0,
  followersCount: json['followers_count'] as int? ?? 0,
  encounterCount: json['encounter_count'] as int? ?? 0,
  followingCount: json['following_count'] as int? ?? 0,
  isFollowing: json['following'] == true,
);

/// A share link is only ever an https address; anything else from the server is ignored.
String? safeShareUrl(Object? value) {
  final uri = value is String ? Uri.tryParse(value) : null;
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
      ? uri.toString()
      : null;
}

Post socialPost(Map<String, dynamic> json, String authorId) => Post(
  id: json['id'].toString(),
  authorId: authorId,
  text: json['body'] as String,
  occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? '')
      ?.toLocal(),
  matchHint: json['match_hint'] as String?,
  travel: json['travel'] is Map<String, dynamic>
      ? TravelDetails.fromJson(json['travel'] as Map<String, dynamic>)
      : null,
  kind: PostKind.values.firstWhere((kind) => kind.value == json['type']),
  images: (json['media'] as List)
      .map((image) => ApiClient.mediaUrl(image['url'] as String))
      .toList(),
  city: json['city']['name'] as String,
  createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  anonymous: json['is_anonymous'] == true,
  cityWide: json['visibility'] == 'city',
  likes: json['likes_count'] as int,
  liked: json['liked'] == true,
  saved: json['saved'] == true,
  mine: json['mine'] == true,
  commentCount: json['comments_count'] as int,
  commentsEnabled: json['comments_enabled'] == true,
  distanceMeters: json['distance_meters'] as int?,
  locationLabel: json['location_label'] as String?,
  encounterConfirmed: json['encounter_confirmed'] == true,
  encounterRequestId: json['encounter_request_id']?.toString(),
  encounterRequestStatus: json['encounter_request_status'] as String?,
  storyTitle: json['story_title'] as String?,
  storyStatus: json['story_status'] as String?,
  storyRevision: json['story_revision'] as int?,
  shareUrl: safeShareUrl(json['share_url']),
  remote: true,
  distance: 0,
);
