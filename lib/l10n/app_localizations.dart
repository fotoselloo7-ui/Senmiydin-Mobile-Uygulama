import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appName.
  ///
  /// In tr, this message translates to:
  /// **'SenMiydin?'**
  String get appName;

  /// No description provided for @close.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get save;

  /// No description provided for @send.
  ///
  /// In tr, this message translates to:
  /// **'Gönder'**
  String get send;

  /// No description provided for @retry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get back;

  /// No description provided for @language.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get language;

  /// No description provided for @languageTurkish.
  ///
  /// In tr, this message translates to:
  /// **'Türkçe'**
  String get languageTurkish;

  /// No description provided for @languageEnglish.
  ///
  /// In tr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @navHome.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get navHome;

  /// No description provided for @navMap.
  ///
  /// In tr, this message translates to:
  /// **'Harita'**
  String get navMap;

  /// No description provided for @navMessages.
  ///
  /// In tr, this message translates to:
  /// **'Mesajlar'**
  String get navMessages;

  /// No description provided for @navProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @search.
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settings;

  /// No description provided for @feedAll.
  ///
  /// In tr, this message translates to:
  /// **'Akış'**
  String get feedAll;

  /// No description provided for @feedFollowing.
  ///
  /// In tr, this message translates to:
  /// **'Takip'**
  String get feedFollowing;

  /// No description provided for @feedNearby.
  ///
  /// In tr, this message translates to:
  /// **'Yakın'**
  String get feedNearby;

  /// No description provided for @feedPopular.
  ///
  /// In tr, this message translates to:
  /// **'Popüler'**
  String get feedPopular;

  /// No description provided for @notificationsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get notificationsTitle;

  /// No description provided for @notificationsUnreadCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} okunmamış'**
  String notificationsUnreadCount(int count);

  /// No description provided for @notificationsAllRead.
  ///
  /// In tr, this message translates to:
  /// **'Hepsi okundu'**
  String get notificationsAllRead;

  /// No description provided for @notificationsMarkAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü okundu'**
  String get notificationsMarkAll;

  /// No description provided for @notificationsMarkAllTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü okundu işaretle'**
  String get notificationsMarkAllTooltip;

  /// No description provided for @notificationsSeeAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü Gör'**
  String get notificationsSeeAll;

  /// No description provided for @notificationsGroupToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get notificationsGroupToday;

  /// No description provided for @notificationsGroupYesterday.
  ///
  /// In tr, this message translates to:
  /// **'Dün'**
  String get notificationsGroupYesterday;

  /// No description provided for @notificationsGroupEarlier.
  ///
  /// In tr, this message translates to:
  /// **'Daha Önce'**
  String get notificationsGroupEarlier;

  /// No description provided for @notificationsFilterAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get notificationsFilterAll;

  /// No description provided for @notificationsFilterUnread.
  ///
  /// In tr, this message translates to:
  /// **'Okunmamış'**
  String get notificationsFilterUnread;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Her şey güncel.'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Yeni etkileşimlerin burada görünecek.'**
  String get notificationsEmptyBody;

  /// No description provided for @notificationsUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Bu içerik artık kullanılamıyor.'**
  String get notificationsUnavailable;

  /// No description provided for @notificationsContentUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'İçerik kullanılamıyor'**
  String get notificationsContentUnavailable;

  /// No description provided for @notificationsUnreadSemantics.
  ///
  /// In tr, this message translates to:
  /// **'Okunmamış bildirim'**
  String get notificationsUnreadSemantics;

  /// No description provided for @notificationsReadSemantics.
  ///
  /// In tr, this message translates to:
  /// **'Okundu'**
  String get notificationsReadSemantics;

  /// No description provided for @notificationsLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler yüklenemedi.'**
  String get notificationsLoadError;

  /// No description provided for @seeOnMap.
  ///
  /// In tr, this message translates to:
  /// **'Haritada Gör'**
  String get seeOnMap;

  /// No description provided for @timeJustNow.
  ///
  /// In tr, this message translates to:
  /// **'Az önce'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In tr, this message translates to:
  /// **'{count} dk önce'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In tr, this message translates to:
  /// **'{count} sa önce'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In tr, this message translates to:
  /// **'{count} gün önce'**
  String timeDaysAgo(int count);

  /// No description provided for @messagesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mesajlar'**
  String get messagesTitle;

  /// No description provided for @messagesTabMessages.
  ///
  /// In tr, this message translates to:
  /// **'Mesajlar'**
  String get messagesTabMessages;

  /// No description provided for @messagesTabRequests.
  ///
  /// In tr, this message translates to:
  /// **'İstekler'**
  String get messagesTabRequests;

  /// No description provided for @messagesSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Mesajlarda ara'**
  String get messagesSearchHint;

  /// No description provided for @messagesEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz mesaj yok.'**
  String get messagesEmptyTitle;

  /// No description provided for @messagesEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Bir profilden mesaj göndererek sohbet başlatabilirsin.'**
  String get messagesEmptyBody;

  /// No description provided for @messagesPreviewPhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf'**
  String get messagesPreviewPhoto;

  /// No description provided for @messagesPreviewLocation.
  ///
  /// In tr, this message translates to:
  /// **'Konum'**
  String get messagesPreviewLocation;

  /// No description provided for @chatWriteHint.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj yaz…'**
  String get chatWriteHint;

  /// No description provided for @chatAttach.
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get chatAttach;

  /// No description provided for @chatEmoji.
  ///
  /// In tr, this message translates to:
  /// **'Emoji'**
  String get chatEmoji;

  /// No description provided for @chatSendTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Mesajı gönder'**
  String get chatSendTooltip;

  /// No description provided for @chatAttachPhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf'**
  String get chatAttachPhoto;

  /// No description provided for @chatAttachCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get chatAttachCamera;

  /// No description provided for @chatAttachLocation.
  ///
  /// In tr, this message translates to:
  /// **'Konum'**
  String get chatAttachLocation;

  /// No description provided for @chatLocationTitle.
  ///
  /// In tr, this message translates to:
  /// **'Konum'**
  String get chatLocationTitle;

  /// No description provided for @chatLocationApprox.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşık bölge'**
  String get chatLocationApprox;

  /// No description provided for @chatOpenOnMap.
  ///
  /// In tr, this message translates to:
  /// **'Haritada Aç'**
  String get chatOpenOnMap;

  /// No description provided for @chatSendCurrentLocation.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut konumumu gönder'**
  String get chatSendCurrentLocation;

  /// No description provided for @chatPickOnMap.
  ///
  /// In tr, this message translates to:
  /// **'Haritada yer seç'**
  String get chatPickOnMap;

  /// No description provided for @chatLocationHint.
  ///
  /// In tr, this message translates to:
  /// **'Konum yaklaşık olarak, yaklaşık 100 metrelik bir bölge olarak paylaşılır.'**
  String get chatLocationHint;

  /// No description provided for @chatPhotoPreviewSend.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı gönder'**
  String get chatPhotoPreviewSend;

  /// No description provided for @chatLocked.
  ///
  /// In tr, this message translates to:
  /// **'Bu sohbete yeni mesaj gönderilemiyor.'**
  String get chatLocked;

  /// No description provided for @settingsLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Dil / Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Türkçe veya English'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsAdPrivacy.
  ///
  /// In tr, this message translates to:
  /// **'Reklam Gizlilik Tercihleri'**
  String get settingsAdPrivacy;

  /// No description provided for @settingsAdPrivacySubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Reklam kişiselleştirme izni'**
  String get settingsAdPrivacySubtitle;

  /// No description provided for @adLabel.
  ///
  /// In tr, this message translates to:
  /// **'Reklam'**
  String get adLabel;

  /// No description provided for @unavailableContent.
  ///
  /// In tr, this message translates to:
  /// **'Bu içerik artık kullanılamıyor.'**
  String get unavailableContent;

  /// No description provided for @connectionsHeader.
  ///
  /// In tr, this message translates to:
  /// **'Aradığın bağlantılar'**
  String get connectionsHeader;

  /// No description provided for @messagesNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni mesaj'**
  String get messagesNew;

  /// No description provided for @messagesTabChats.
  ///
  /// In tr, this message translates to:
  /// **'Sohbetler'**
  String get messagesTabChats;

  /// No description provided for @messagesRequestPending.
  ///
  /// In tr, this message translates to:
  /// **'Onay bekliyor'**
  String get messagesRequestPending;

  /// No description provided for @messagesRequestIncoming.
  ///
  /// In tr, this message translates to:
  /// **'Gelen istek'**
  String get messagesRequestIncoming;

  /// No description provided for @messagesSayHi.
  ///
  /// In tr, this message translates to:
  /// **'Bir merhaba gönder.'**
  String get messagesSayHi;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
