// ignore_for_file: prefer_initializing_formals
import '../core/app_locale.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../core/relative_time.dart';
import 'post_context.dart';

enum PostKind {
  memory('Anı', 'moment'),
  encounter('Karşılaşma', 'encounter'),
  confession('İtiraf', 'confession'),
  thought('Düşünce', 'thought'),
  journey('Yolculuk', 'travel');

  const PostKind(this.label, this.value);
  final String label, value;
}

enum EncounterStatus {
  pending('Bekleyen'),
  approved('Onaylanan'),
  rejected('Reddedilen');

  const EncounterStatus(this.label);
  final String label;
}

class Person {
  Person({
    required this.id,
    required this.name,
    required this.handle,
    required this.photo,
    this.city = 'Alanya',
    this.distance = .35,
    this.visible = true,
    this.bio = 'Kahve, müzik ve güzel karşılaşmalar… ✨',
    this.occupation = 'Tasarımcı',
    this.remote = false,
    this.cover = '',
    this.postCount = 0,
    this.followersCount = 0,
    this.encounterCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.interests = const ['Kahve', 'Müzik', 'Seyahat'],
  });
  final String id;
  String name, handle, city, bio, occupation, photo;
  final double distance;
  bool visible, isFollowing;
  final bool remote;
  String cover;
  int postCount, followersCount, followingCount, encounterCount;
  List<String> interests;
  String get distanceLabel => distance < 1
      ? '${(distance * 1000).round()} m'
      : '${distance.toStringAsFixed(1).replaceAll('.', ',')} km';
}

class Comment {
  Comment(
    this.authorId,
    this.text, {
    String time = 'Az önce',
    this.createdAt,
    this.id,
    this.mine = false,
    this.parentId,
    this.replyCount = 0,
    List<Comment>? replies,
    this.likes = 0,
    this.liked = false,
  }) : _time = time,
       replies = replies ?? [];
  final String? id;
  final bool mine;
  final String authorId, text;
  final String _time;

  /// The raw timestamp is the source of truth: the label is formatted when shown, so it follows the language.
  final DateTime? createdAt;
  String get time => createdAt != null ? relativeTime(createdAt!) : tr(_time);

  /// Set only on replies: the top-level comment they answer (replies never answer replies).
  final String? parentId;

  /// Top-level comments only: how many replies exist and the (oldest-first) ones loaded so far.
  int replyCount;
  List<Comment> replies;

  /// Likes on this comment or reply (state kept on the object so every list showing it stays in step).
  int likes;
  bool liked;
}

/// A private saved collection ("Sonra Bak", "Alanya"…). Only its owner ever sees it.
class SavedCollection {
  SavedCollection({
    required this.id,
    required this.name,
    this.postsCount = 0,
    this.containsPost,
  });
  factory SavedCollection.fromJson(Map<String, dynamic> json) =>
      SavedCollection(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        postsCount: (json['posts_count'] as num?)?.toInt() ?? 0,
        containsPost: json['contains_post'] as bool?,
      );
  final int id;
  String name;
  int postsCount;

  /// Only set when the list was asked about one post.
  bool? containsPost;
}

class Post {
  Post({
    required this.id,
    required this.authorId,
    required this.text,
    this.kind = PostKind.memory,
    this.images = const [],
    this.anonymous = false,
    this.city = 'Alanya',
    this.distance = 1.2,
    this.likes = 0,
    this.liked = false,
    this.saved = false,
    String time = '28 dk önce',
    this.createdAt,
    this.taggedId,
    List<Comment>? comments,
    this.cityWide = true,
    this.remote = false,
    this.mine = false,
    this.commentsEnabled = true,
    this.commentCount = 0,
    this.distanceMeters,
    this.locationLabel,
    this.mapPoint,
    this.encounterConfirmed = false,
    this.encounterRequestId,
    this.encounterRequestStatus,
    this.storyTitle,
    this.storyStatus,
    this.storyRevision,
    this.storyParticipants = const [],
    this.occurredAt,
    this.matchHint,
    this.travel,
    this.shareUrl,
  }) : _time = time,
       comments = comments ?? [];
  DateTime? occurredAt;
  String? matchHint;
  TravelDetails? travel;

  /// Public https link (null when the server says this post may not leave the app: private, teen, removed ...).
  String? shareUrl;
  final String id, authorId;
  String text;
  final PostKind kind;
  final List<String> images;
  final bool anonymous, remote, mine, commentsEnabled;
  bool cityWide;
  int commentCount;
  int? distanceMeters;
  String? locationLabel;

  /// The approximate (grid) point the map shows for this post; null when the post has no place. Never an exact position.
  LatLng? mapPoint;
  bool encounterConfirmed;
  String? encounterRequestId, encounterRequestStatus, storyTitle, storyStatus;
  int? storyRevision;
  List<Person> storyParticipants;
  bool get jointStory => storyStatus != null;
  bool get interactionsEnabled => !jointStory || storyStatus == 'published';
  int get displayedCommentCount => remote ? commentCount : comments.length;
  final String city;
  String _time;

  /// Raw timestamp (source of truth for the relative label, which re-formats with the language).
  DateTime? createdAt;
  String get time => createdAt != null ? relativeTime(createdAt!) : tr(_time);
  set time(String value) => _time = value;

  /// "17 sa" for the tight footer of a narrow card.
  String get timeShort => shortRelativeTime(time);
  final double distance;
  final String? taggedId;
  int likes;
  bool liked, saved;
  final List<Comment> comments;
}

class Encounter {
  Encounter({
    required this.id,
    required this.postId,
    required this.fromId,
    required this.toId,
    this.status = EncounterStatus.pending,
    this.title = 'Birbirimizi bulduk',
    this.description = 'Yarım kalan bir merhaba, güzel bir hikâyeye dönüştü. ☕',
  });
  final String id, postId, fromId, toId, title, description;
  EncounterStatus status;
}

class ChatMessage {
  ChatMessage(this.text, {this.mine = false, this.time = '13:24'});
  final String text, time;
  final bool mine;
}

class Conversation {
  Conversation(
    this.personId,
    this.messages, {
    this.unread = 0,
    this.request = false,
  });
  final String personId;
  final List<ChatMessage> messages;
  int unread;
  bool request;
}

enum NoticeKind {
  like,
  comment,
  follow,
  message,
  tag,
  request,
  approved,
  nearby,
  system,
}

class AppNotice {
  AppNotice(
    this.id,
    this.kind,
    this.text, {
    this.personId,
    this.postId,
    this.encounterId,
    this.read = false,
    this.time = 'Az önce',
  });
  final String id, text, time;
  final NoticeKind kind;
  final String? personId, postId, encounterId;
  bool read;
}

class FeedFilter {
  String range = 'Tüm şehir', sort = 'Yeni', content = 'Tüm paylaşımlar';
  String media = 'Tümü';
  Set<String> interests = {};
  bool nearbyOnly = false, photoFirst = false, encounterFirst = false;
  FeedFilter copy() => FeedFilter()
    ..range = range
    ..sort = sort
    ..content = content
    ..media = media
    ..interests = {...interests}
    ..nearbyOnly = nearbyOnly
    ..photoFirst = photoFirst
    ..encounterFirst = encounterFirst;
  double get maxDistance => switch (range) {
    '5 km' => 5,
    '10 km' => 10,
    '25 km' => 25,
    _ => double.infinity,
  };
}
