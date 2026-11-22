import 'package:image_picker/image_picker.dart';

import '../core/app_locale.dart';
import '../core/relative_time.dart';

import 'account_api.dart';
import 'gifts.dart';
import 'models.dart';
import 'social_api.dart';

class ReportTarget {
  const ReportTarget(this.type, this.id, this.label);
  final String type, label;
  final int id;
}

class DirectMessage {
  DirectMessage(Map<String, dynamic> json)
    : id = json['id'] as int,
      body = json['body'] as String,
      mine = json['mine'] == true,
      image = ApiClient.mediaUrl(json['image'] as String?),
      read = json['read_at'] != null,
      date = DateTime.parse(json['created_at'] as String).toLocal(),
      type = json['type'] as String? ?? 'text',
      latitude = ((json['location'] as Map?)?['latitude'] as num?)?.toDouble(),
      longitude = ((json['location'] as Map?)?['longitude'] as num?)
          ?.toDouble(),
      placeLabel = (json['location'] as Map?)?['place_label'] as String?,
      audio = ApiClient.mediaUrl(json['audio'] as String?),
      durationMs = (json['duration_ms'] as num?)?.toInt() ?? 0,
      gift = json['gift'] is Map<String, dynamic>
          ? GiftItem.fromJson(json['gift'] as Map<String, dynamic>)
          : null;
  final int id;
  final String body, image, type;
  final String? placeLabel;

  /// Voice message: the (private) audio URL and its length as the server read it from the file.
  final String audio;
  final int durationMs;
  final GiftItem? gift;
  bool get isVoice => type == 'voice' && audio.isNotEmpty;
  bool get isGift => type == 'gift' && gift != null;
  final bool mine, read;
  final DateTime date;

  /// Approximate point of a location message (the server already snapped it; never a live position).
  final double? latitude, longitude;
  bool get isLocation => type == 'location' && latitude != null;

  /// One-line text for conversation lists and notifications.
  String get preview => switch (type) {
    'image' => currentL10n.messagesPreviewPhoto,
    'location' => currentL10n.messagesPreviewLocation,
    'voice' => tr('Sesli mesaj'),
    'gift' => tr('Hediye gönderdi'),
    _ => body,
  };
}

class DirectConversation {
  DirectConversation(
    Map<String, dynamic> json,
    Person Function(Map<String, dynamic>) person,
  ) : id = json['id'] as int?,
      status = json['status'] as String,
      peer = person(json['peer'] as Map<String, dynamic>),
      outgoing = json['outgoing'] == true,
      canSend = json['can_send'] == true,
      recentlyActive = json['recently_active'] == true,
      unread = json['unread'] as int? ?? 0,
      last = json['last_message'] == null
          ? null
          : DirectMessage(json['last_message'] as Map<String, dynamic>);
  final int? id;
  final String status;
  final Person peer;
  final bool outgoing, canSend, recentlyActive;
  final int unread;
  final DirectMessage? last;
}

class InboxNotification {
  InboxNotification(
    Map<String, dynamic> json,
    Person Function(Map<String, dynamic>) person,
  ) : id = json['id'] as int,
      type = json['type'] as String,
      route = json['route'] as String,
      entity = json['entity_id'] as int?,
      actor = json['actor'] == null
          ? null
          : person(json['actor'] as Map<String, dynamic>),
      text = json['text'] as String,
      announcementBody = json['announcement_body'] as String?,
      subtitle = json['subtitle'] as String?,
      read = json['read'] == true,
      available = json['available'] != false,
      createdAt = DateTime.parse(json['created_at'] as String).toLocal(),
      mapLatitude = ((json['map_target'] as Map?)?['latitude'] as num?)
          ?.toDouble(),
      mapLongitude = ((json['map_target'] as Map?)?['longitude'] as num?)
          ?.toDouble();
  final int id;
  final int? entity;
  final String type, route, text;
  String get time => relativeTime(createdAt);
  final String? announcementBody, subtitle;
  final Person? actor;
  final bool read;
  final bool available;
  final DateTime createdAt;

  /// Approximate target of a location announcement ("Haritada Gör"); never a user's position.
  final double? mapLatitude, mapLongitude;
  bool get hasMapTarget => mapLatitude != null && mapLongitude != null;
}

int accountId(String id) => int.parse(id.replaceFirst('account-', ''));

class CommunicationApi {
  CommunicationApi(this.client, this.person) : social = SocialService(client);
  final ApiClient client;
  final SocialService social;
  final Person Function(Map<String, dynamic>) person;

  Future<SocialPage<DirectConversation>> conversations(
    int page,
    bool requests,
    String query,
  ) async => (await social.page(
    'conversations',
    page,
    query: {
      'requests': requests ? '1' : '0',
      if (query.trim().isNotEmpty) 'q': query.trim(),
    },
  )).map((json) => DirectConversation(json, person));

  Future<DirectConversation> conversation(
    String id, {
    required bool byPeer,
  }) async => DirectConversation(
    await social.object(
      'GET',
      byPeer ? 'users/${accountId(id)}/conversation' : 'conversations/$id',
    ),
    person,
  );

  Future<({List<DirectMessage> items, bool more})> messages(
    int id, {
    int? before,
    int? after,
  }) async {
    final data = await client.send(
      'GET',
      'conversations/$id/messages',
      authenticated: true,
      query: {'before': ?before?.toString(), 'after': ?after?.toString()},
    ) as Map<String, dynamic>;
    return (
      items: (data['items'] as List)
          .cast<Map<String, dynamic>>()
          .map(DirectMessage.new)
          .toList(),
      more: data['has_more'] == true,
    );
  }

  Future<(DirectConversation, DirectMessage)> send(
    Person peer,
    String body,
    String requestId,
    XFile? image, {
    ({double latitude, double longitude, String? label})? location,
    XFile? voice,
    String? gift,
  }) async {
    final data = await client.send(
      'POST',
      'users/${accountId(peer.id)}/messages',
      authenticated: true,
      body: {
        'body': body,
        'request_id': requestId,
        'gift': ?gift,
        if (location != null) ...{
          'latitude': location.latitude,
          'longitude': location.longitude,
          if (location.label != null && location.label!.isNotEmpty)
            'place_label': location.label,
        },
      },
      messageImage: image,
      files: {'audio': ?voice},
    ) as Map<String, dynamic>;
    return (
      DirectConversation(data['conversation'] as Map<String, dynamic>, person),
      DirectMessage(data['message'] as Map<String, dynamic>),
    );
  }

  /// The active gift catalog in the account language.
  Future<List<GiftItem>> gifts() async {
    final data = await client.send(
      'GET',
      'gifts',
      authenticated: true,
    ) as Map<String, dynamic>;
    return (data['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(GiftItem.fromJson)
        .toList();
  }

  Future<DirectConversation> respond(int id, bool accept) async =>
      DirectConversation(
        await social.object(
          'POST',
          'conversations/$id/request/${accept ? 'accept' : 'reject'}',
        ),
        person,
      );

  Future<void> readMessages(int id, int through) async {
    await client.send(
      'PUT',
      'conversations/$id/read',
      authenticated: true,
      body: {'through': through},
    );
  }

  Future<void> hide(int id) => social.delete('conversations/$id');
  /// [everyone]: the sender takes the message back for both people; otherwise it only leaves the caller's own view.
  Future<void> deleteMessage(int id, int message, {bool everyone = false}) =>
      social.delete(
        'conversations/$id/messages/$message',
        query: everyone ? {'scope': 'everyone'} : null,
      );

  Future<SocialPage<InboxNotification>> inbox(int page, bool unread) async =>
      (await social.page(
        'notifications',
        page,
        query: {'unread': unread ? '1' : '0'},
      )).map((json) => InboxNotification(json, person));

  Future<InboxNotification> notification(int id) async => InboxNotification(
    await social.object('GET', 'notifications/$id'),
    person,
  );

  Future<void> readNotification([int? id]) async {
    await client.send(
      'PUT',
      id == null ? 'notifications/read' : 'notifications/$id/read',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> counts() =>
      social.object('GET', 'unread-counts');

  Future<SocialPage<Person>> blocks(int page) async =>
      (await social.page('blocks', page)).map(person);

  Future<void> block(String id, bool value) async {
    await client.send(
      value ? 'PUT' : 'DELETE',
      'blocks/${accountId(id)}',
      authenticated: true,
    );
  }

  Future<void> report(
    ReportTarget target,
    String reason,
    String description,
  ) async {
    await client.send(
      'POST',
      'reports',
      authenticated: true,
      body: {
        'target_type': target.type,
        'target_id': target.id,
        'reason': reason,
        'description': description,
      },
    );
  }

  Future<void> disableDevice(String id) => social.delete('push-device/$id');

  Future<void> registerDevice(Map<String, Object?> fields) async {
    await client.send('PUT', 'push-device', authenticated: true, body: fields);
  }
}
