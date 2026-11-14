// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'SenMiydin?';

  @override
  String get close => 'Kapat';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get save => 'Kaydet';

  @override
  String get send => 'Gönder';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get back => 'Geri';

  @override
  String get language => 'Dil';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'English';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navMap => 'Harita';

  @override
  String get navMessages => 'Mesajlar';

  @override
  String get navProfile => 'Profil';

  @override
  String get search => 'Ara';

  @override
  String get settings => 'Ayarlar';

  @override
  String get feedAll => 'Akış';

  @override
  String get feedFollowing => 'Takip';

  @override
  String get feedNearby => 'Yakın';

  @override
  String get feedPopular => 'Popüler';

  @override
  String get notificationsTitle => 'Bildirimler';

  @override
  String notificationsUnreadCount(int count) {
    return '$count okunmamış';
  }

  @override
  String get notificationsAllRead => 'Hepsi okundu';

  @override
  String get notificationsMarkAll => 'Tümünü okundu';

  @override
  String get notificationsMarkAllTooltip => 'Tümünü okundu işaretle';

  @override
  String get notificationsSeeAll => 'Tümünü Gör';

  @override
  String get notificationsGroupToday => 'Bugün';

  @override
  String get notificationsGroupYesterday => 'Dün';

  @override
  String get notificationsGroupEarlier => 'Daha Önce';

  @override
  String get notificationsFilterAll => 'Tümü';

  @override
  String get notificationsFilterUnread => 'Okunmamış';

  @override
  String get notificationsEmptyTitle => 'Her şey güncel.';

  @override
  String get notificationsEmptyBody => 'Yeni etkileşimlerin burada görünecek.';

  @override
  String get notificationsUnavailable => 'Bu içerik artık kullanılamıyor.';

  @override
  String get notificationsContentUnavailable => 'İçerik kullanılamıyor';

  @override
  String get notificationsUnreadSemantics => 'Okunmamış bildirim';

  @override
  String get notificationsReadSemantics => 'Okundu';

  @override
  String get notificationsLoadError => 'Bildirimler yüklenemedi.';

  @override
  String get seeOnMap => 'Haritada Gör';

  @override
  String get timeJustNow => 'Az önce';

  @override
  String timeMinutesAgo(int count) {
    return '$count dk önce';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count sa önce';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count gün önce';
  }

  @override
  String get messagesTitle => 'Mesajlar';

  @override
  String get messagesTabMessages => 'Mesajlar';

  @override
  String get messagesTabRequests => 'İstekler';

  @override
  String get messagesSearchHint => 'Mesajlarda ara';

  @override
  String get messagesEmptyTitle => 'Henüz mesaj yok.';

  @override
  String get messagesEmptyBody =>
      'Bir profilden mesaj göndererek sohbet başlatabilirsin.';

  @override
  String get messagesPreviewPhoto => 'Fotoğraf';

  @override
  String get messagesPreviewLocation => 'Konum';

  @override
  String get chatWriteHint => 'Mesaj yaz…';

  @override
  String get chatAttach => 'Ekle';

  @override
  String get chatEmoji => 'Emoji';

  @override
  String get chatSendTooltip => 'Mesajı gönder';

  @override
  String get chatAttachPhoto => 'Fotoğraf';

  @override
  String get chatAttachCamera => 'Kamera';

  @override
  String get chatAttachLocation => 'Konum';

  @override
  String get chatLocationTitle => 'Konum';

  @override
  String get chatLocationApprox => 'Yaklaşık bölge';

  @override
  String get chatOpenOnMap => 'Haritada Aç';

  @override
  String get chatSendCurrentLocation => 'Mevcut konumumu gönder';

  @override
  String get chatPickOnMap => 'Haritada yer seç';

  @override
  String get chatLocationHint =>
      'Konum yaklaşık olarak, yaklaşık 100 metrelik bir bölge olarak paylaşılır.';

  @override
  String get chatPhotoPreviewSend => 'Fotoğrafı gönder';

  @override
  String get chatLocked => 'Bu sohbete yeni mesaj gönderilemiyor.';

  @override
  String get settingsLanguage => 'Dil / Language';

  @override
  String get settingsLanguageSubtitle => 'Türkçe veya English';

  @override
  String get settingsAdPrivacy => 'Reklam Gizlilik Tercihleri';

  @override
  String get settingsAdPrivacySubtitle => 'Reklam kişiselleştirme izni';

  @override
  String get adLabel => 'Reklam';

  @override
  String get unavailableContent => 'Bu içerik artık kullanılamıyor.';

  @override
  String get connectionsHeader => 'Aradığın bağlantılar';

  @override
  String get messagesNew => 'Yeni mesaj';

  @override
  String get messagesTabChats => 'Sohbetler';

  @override
  String get messagesRequestPending => 'Onay bekliyor';

  @override
  String get messagesRequestIncoming => 'Gelen istek';

  @override
  String get messagesSayHi => 'Bir merhaba gönder.';
}
