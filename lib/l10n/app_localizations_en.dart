// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'SenMiydin?';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get send => 'Send';

  @override
  String get retry => 'Try again';

  @override
  String get back => 'Back';

  @override
  String get language => 'Language';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'English';

  @override
  String get navHome => 'Home';

  @override
  String get navMap => 'Map';

  @override
  String get navMessages => 'Messages';

  @override
  String get navProfile => 'Profile';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get feedAll => 'Feed';

  @override
  String get feedFollowing => 'Following';

  @override
  String get feedNearby => 'Nearby';

  @override
  String get feedPopular => 'Popular';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String notificationsUnreadCount(int count) {
    return '$count unread';
  }

  @override
  String get notificationsAllRead => 'All caught up';

  @override
  String get notificationsMarkAll => 'Mark all read';

  @override
  String get notificationsMarkAllTooltip => 'Mark all as read';

  @override
  String get notificationsSeeAll => 'See all';

  @override
  String get notificationsGroupToday => 'Today';

  @override
  String get notificationsGroupYesterday => 'Yesterday';

  @override
  String get notificationsGroupEarlier => 'Earlier';

  @override
  String get notificationsFilterAll => 'All';

  @override
  String get notificationsFilterUnread => 'Unread';

  @override
  String get notificationsEmptyTitle => 'You\'re all caught up.';

  @override
  String get notificationsEmptyBody => 'New interactions will show up here.';

  @override
  String get notificationsUnavailable => 'This content is no longer available.';

  @override
  String get notificationsContentUnavailable => 'Content unavailable';

  @override
  String get notificationsUnreadSemantics => 'Unread notification';

  @override
  String get notificationsReadSemantics => 'Read';

  @override
  String get notificationsLoadError => 'Notifications could not be loaded.';

  @override
  String get seeOnMap => 'View on map';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count d ago';
  }

  @override
  String get messagesTitle => 'Messages';

  @override
  String get messagesTabMessages => 'Messages';

  @override
  String get messagesTabRequests => 'Requests';

  @override
  String get messagesSearchHint => 'Search messages';

  @override
  String get messagesEmptyTitle => 'No messages yet.';

  @override
  String get messagesEmptyBody =>
      'Start a chat by sending a message from someone\'s profile.';

  @override
  String get messagesPreviewPhoto => 'Photo';

  @override
  String get messagesPreviewLocation => 'Location';

  @override
  String get chatWriteHint => 'Write a message…';

  @override
  String get chatAttach => 'Attach';

  @override
  String get chatEmoji => 'Emoji';

  @override
  String get chatSendTooltip => 'Send message';

  @override
  String get chatAttachPhoto => 'Photo';

  @override
  String get chatAttachCamera => 'Camera';

  @override
  String get chatAttachLocation => 'Location';

  @override
  String get chatLocationTitle => 'Location';

  @override
  String get chatLocationApprox => 'Approximate area';

  @override
  String get chatOpenOnMap => 'Open on map';

  @override
  String get chatSendCurrentLocation => 'Send my current location';

  @override
  String get chatPickOnMap => 'Pick a place on the map';

  @override
  String get chatLocationHint =>
      'Locations are shared approximately, as an area of roughly 100 meters.';

  @override
  String get chatPhotoPreviewSend => 'Send photo';

  @override
  String get chatLocked => 'New messages can\'t be sent in this chat.';

  @override
  String get settingsLanguage => 'Language / Dil';

  @override
  String get settingsLanguageSubtitle => 'English or Türkçe';

  @override
  String get settingsAdPrivacy => 'Ad privacy choices';

  @override
  String get settingsAdPrivacySubtitle => 'Ad personalization consent';

  @override
  String get adLabel => 'Ad';

  @override
  String get unavailableContent => 'This content is no longer available.';

  @override
  String get connectionsHeader => 'Connections you\'re looking for';

  @override
  String get messagesNew => 'New message';

  @override
  String get messagesTabChats => 'Chats';

  @override
  String get messagesRequestPending => 'Awaiting approval';

  @override
  String get messagesRequestIncoming => 'Incoming request';

  @override
  String get messagesSayHi => 'Say hello.';
}
