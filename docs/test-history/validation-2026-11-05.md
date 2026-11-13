# Doğrulama raporu — 5 Kasım 2026

- Flutter 3.47.4 / Dart 3.13.3.
- Android: Pixel 6a, emulator-5558, API 34.
- Flutter projesi doğrudan proje kökünde; Android ve iOS kimliği `com.senmiydin.app`.
- İstenen 29 temel ekran ve ek yardımcı akışlar oluşturuldu. Ulaşım listesi README içindedir.

## Başarılı kontroller

| Kontrol | Sonuç | Kayıt |
|---|---|---|
| flutter pub get | Başarılı | Derleme / çalıştırma çıktısı |
| flutter analyze | Hata ve uyarı yok | analyze.log |
| flutter test | 12 test geçti | widget-test.log |
| Pixel 6a ekran / karşılaşma testi | Geçti | pixel6a-integration-test.log |
| Pixel 6a çoklu fotoğraf testi | Geçti | pixel6a-media-test.log |

Widget kontrolü: 320×568, 412×915 ve 891×411. Ayrıca 320×568 üzerinde 1.3 metin ölçeği ve 250 piksel klavye alanı; kayıt, profil tamamlama, paylaşım, yorum, sohbet, şikâyet, arama ve etiketleme ekranları.

Karşılaşma testi: Ana Sayfa → + → Karşılaşma → @elifb ara → kullanıcı seç → paylaş → diğer kullanıcının istek önizlemesi → onayla → Karşılaşmalarım / Onaylanan → ana sayfada yeni doğrulanmış karşılaşma.

Fotoğraf testi: iki yerel fotoğraf seç → sırasını değiştir → carousel içeren önizlemeyi aç → paylaş → ortak durumdaki fotoğraf sırasını doğrula.

Ekran görüntüleri `screenshots` klasöründedir. Testler sırasında çekilen ekranlar ve canlı normal uygulama görüntüsü ayrı adlandırılmıştır.

## Teknik sınırlar

- Tüm veriler mock ve oturum belleğinde; yeniden başlatmada sıfırlanır.
- Gerçek API, veritabanı, Firebase, sosyal giriş, push, GPS, harita, kamera veya yükleme bağlantısı yoktur.
- iOS iskeleti hazırlanmıştır; Windows üzerinde iOS derlemesi yapılmamıştır.
- Android debug sürümüdür; mağaza / release imzalama yapılmamıştır.
- Flutter hedefleri arasında geçişte görülen Gradle ZIP paketleme önbelleği çakışması temiz derleme ile giderilmiştir. Yenilenirse README'deki temizleme adımı kullanılabilir.
- Dosya eşitleme çakışma kopyaları kaybolmaması için `recovered_sync` altında saklanır. Referans dosyaları düzenlenmemiştir; SHA-256 kayıtları `reference-checksums.json` içindedir.

## Son normal çalıştırma

Normal debug sürümü temiz derlenip Pixel 6a'ya kuruldu. Ön plandaki activity `com.senmiydin.app/.MainActivity` olarak doğrulandı; ana sayfa açık bırakıldı. Canlı ekran: `screenshots/pixel6a-live.png`.

APK: `build/app/outputs/flutter-apk/app-debug.apk` — 67.319.464 bayt. ZIP bütünlüğü kontrol edildi; yinelenen dosya girdisi yoktur. SHA-256 kaydı: `apk-checksum.json`.
