# iOS — Mac devir teslim listesi

Bu proje Windows üzerinde geliştirildi. **iOS tarafında Xcode derlemesi, imzalama, archive, Privacy Report, TestFlight ve gerçek cihaz testi yapılmadı.** Windows'ta yalnızca dosyalara bakan statik bir doğrulama var; bu belge, Mac'te geriye kalan işi sıralar. Hiçbir madde "iOS çalışıyor" anlamına gelmez.

## 1. Windows'ta yapılanlar (yalnız statik)

`python -I tool/platform_manifest_check.py ios` şunları dosyalardan denetler (yapı çıktısı üretmez):

- `Info.plist` ve `PrivacyInfo.xcprivacy` geçerli plist; bundle id `com.senmiydin.app`.
- İzin metinleri tanımlı ve açıklayıcı: mikrofon (`NSMicrophoneUsageDescription`), kamera, fotoğraf arşivi, konum (yalnız uygulama açıkken), takip (ATT). Her biri `en.lproj` ve `tr.lproj` `InfoPlist.strings` içinde de var.
- "Her zaman konum", rehber gibi kullanılmayan izinler yok; ATS gevşetilmemiş; arka plan modu yalnız `remote-notification`.
- Gizlilik manifestinde ses verisi (`AudioData`), fotoğraf/video ve yaklaşık konum bildirilmiş; ses kaydı "tracking" değil.
- AdMob uygulama kimliği yer tutucudur (`ADMOB_APP_ID_IOS`) — gerçek kimlik **harici bilgi**dir ve yoksa kontrol `MISSING` verir (kod hatası sayılmaz).

## 2. Mac'te önkoşullar

- macOS + güncel Xcode (App Store'un istediği en düşük SDK ile), CocoaPods, Flutter **3.47.4** (`flutter --version` aynı olmalı).
- Apple Developer hesabı, `com.senmiydin.app` için App ID; **Sign in with Apple** ve **Push Notifications** yetenekleri.
- Gerçek değerler (repoya koyulmaz): `config/production.local.json`, `ios/Flutter/OAuth.xcconfig` (`tool/configure_mobile.py` yazar), `GoogleService-Info.plist`, AdMob iOS uygulama kimliği.

## 3. Kurulum adımları

```bash
flutter pub get
cd ios && pod install --repo-update && cd ..
flutter build ios --release --no-codesign --dart-define-from-file=config/production.local.json
open ios/Runner.xcworkspace
```

Xcode'da: Team seç, Signing & Capabilities'te Sign in with Apple + Push (`aps-environment` = production) doğrula, sonra **Product → Archive**.

## 4. Yeni medya özellikleri — Mac'te elle doğrulanacaklar

Bu sürümde eklendi; Windows'ta yalnız Android'de denendi.

**Sesli mesaj (`record`, `audioplayers`)**

1. Mikrofon düğmesi → önce uygulama içi açıklama, sonra **bir kez** sistem izni. Reddedilince uygulama tekrar tekrar sormamalı; Ayarlar'dan izin verince çalışmalı.
2. Kayıt AAC-LC / M4A üretmeli; sunucu bu biçimi (`ftyp` + `mp4a`) kabul ediyor. iOS'ta üretilen dosyayla **gerçek bir gönderim** yapıp sunucunun kabul ettiğini doğrula (en kritik madde).
3. 00:12 sayacı, durdur, önizleme dinleme, iptal (dosya silinir), gönder; 2 dakikada otomatik durma; 1 sn'den kısa kayıt gönderilmez.
4. Telefon görüşmesi / uygulama arka plana geçişinde kayıt ve çalma temiz durmalı (ses oturumu kesintisi).
5. Gelen sesli mesaj: oynat/duraklat, aynı anda tek ses, sohbet kapanınca durur.
6. Sessiz anahtar / hoparlör davranışı (ses kaydı oynatma beklenen şekilde duyuluyor mu).

**Fotoğraflı Harita Notu**: galeri/kamera seçimi, önizleme + kaldırma, yayın, 7 gün sonra herkese kapanıp Mektuplarım → Arşiv'de fotoğrafın durması, yeniden paylaşımda fotoğrafın korunması.

**Hediyeler**: 8 hediye SVG'si (`assets/gifts/`, kendi çizimimiz) doğru çiziliyor; `flutter_svg` iOS'ta sorunsuz.

**Emoji paneli**: panel açıkken klavye gizli; boş alana dokunma, geri hareketi, klavye açma paneli kapatıyor; sistem emoji klavyesi de çalışıyor.

## 5. Gizlilik ve mağaza

- **Xcode → Product → Archive → Distribute → Privacy Report**: Flutter, Firebase, Google Sign-In, Google Mobile Ads, **record**, **audioplayers**, **emoji_picker_flutter / shared_preferences** SDK manifestleri ile `PrivacyInfo.xcprivacy` birleşimini incele. Required-reason API'lar (UserDefaults, dosya zaman damgası vb.) eksikse manifest'e ekle.
- App Store Connect "App Privacy": `docs/store/APPLE_PRIVACY_LABELS.md` + **Audio Data (sesli mesaj, uygulama işlevi, takip yok)**.
- İnceleme notlarına sesli mesaj ve hediye (ücretsiz, ödeme yok) cümlesi eklenmeli; uygulama içi satın alma yoktur.
- Ekran görüntüleri ve final marka dosyaları mağaza hazırlığında ayrıca beklenir.

## 6. Çıkış kriteri

Aşağıdakilerin hepsi Mac'te işaretlenmeden iOS yayına hazır sayılmaz: Archive başarılı · gerçek cihazda giriş/konum/bildirim · sesli mesaj gönder-al · fotoğraf/kamera · Privacy Report temiz · TestFlight iç test · App Store Connect alanları dolu.
