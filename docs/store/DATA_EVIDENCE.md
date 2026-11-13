# Veri beyanı kanıt dizini

Denetim: 9 Kasım 2026. Kod yolları proje köküne göredir. Matrislerdeki “var” kararları bu kaynaklara dayandırılır; gerçek işletmeci/SMTP/log/hosting/provider sözleşmesi bilinmeyen yerlerde placeholder kullanılır.

| Alan | Kaynak ve doğrulanan davranış |
|---|---|
| Ürün ve baseline | SENMIYDIN_URUN_TANIMI.md; docs/VALIDATION.md; docs/LOCATION_TIME_TRAVEL.md; docs/DEPLOYMENT.md; docs/STORE_READINESS.md; docs/PRODUCTION_CHECKLIST.md okundu |
| Auth/name/email/DOB/terms/min age | backend/app/Http/Controllers/AuthController.php; users migration; mobile.minimum_age=18; accepted_terms zorunlu; Sanctum token adı mobile |
| Profil / zorunlu ilgi alanı | ProfileController::update/saveInterests; min:5; ProfileResource (özel), PublicUserResource (email/DOB yok); user_interests |
| Konum taşınması / precision | lib/data/location_service.dart (high accuracy); AppStore::_publishPosition; LocationController::update; LocationData::update (0.001°); remember (0.005°); PostPlace / PostMatcher / location config |
| Geçmiş / bildirim | history varsayılan false; location_match ayrı tercih; user_location_history ve location_matches; MatchLocationPost; Inbox / PushDelivery |
| Public location | LocationController nearby yaklaşık mesafe; map yaklaşık post noktası; history API yalnız sahibine bölge/yuvarlanmış saat |
| UGC / fotoğraf / Yolculuk | PostController, PostResource, PostTravelDetail, post_* migrationlar; PrivateImage re-encode; public travel ayrı tercih |
| Etkileşim / sosyal grafik | post_likes, post_saves, user_follows, user_blocks; SocialUserController ve SafetyController |
| Mesaj / sınırlı moderasyon | ConversationController, Message, Conversation; admin RecordsController::reportedTarget/reportImage, report.message_viewed/report.media_viewed audit; genel tüm sohbet taraması iddiası yok |
| Filtreler / yaptırımlar | ContentGuard, Blocks, ActiveAccount, Admin/ModerationController, PostPolicy/PostCommentPolicy; admin Settings |
| Push / cihaz | PushClient; ServiceAvailability; user_devices; InboxController; tokenlar server tarafında encrypted storage, token_hash eşleme; SDK provider davranışı ayrı raporda |
| OAuth | SocialAuthController, IdentityVerifier, AppleTokens, social_identities ve oauth_revocations; provider subject hash’i, şifreli token ve revocation işi |
| IP / güvenlik | AppServiceProvider RateLimiter IP ve kimlik-hash/IP cache anahtarları; sessions ip_address/user_agent; admin Audit::record ip_address. Mobil için ayrı erişim-log tablosu bulunmadı |
| Arama | GET search / q değerleri API’ye gider; özel sorgu-geçmiş tablosu yok. Production full URL/access-log saklama politikası bilinmiyor |
| Web destek / silme | WebsiteController::submit ve web_requests; /iletisim /hesap-silme POST; silme formu doğrulanacak talep oluşturur |
| Hesap/veri silme | AccountDeletionController, EraseAccount, MediaCleanup, CleanErasedMedia, routes/console.php |
| Transit / server privacy | ApiConfig release HTTPS guard; ProductionSecurity; config/production.json; release merged manifest usesCleartextTraffic=false; iOS ATS exception yok |
| Harici harita / paylaşım | lib/screens/live_map.dart ve widgets/post_context.dart TileLayer; varsayılan OSM HTTPS, tile indeksleri + IP + package user-agent; SharePlus kullanıcı eylemi |
| SDK / permission | pubspec.lock, package_config, source plugin xcprivacy, releaseRuntimeClasspath ve merged release manifest |
| Store link / boş durum | Admin/SystemController domain/path/paket ID doğrulaması; website/stores.blade.php boş değerlerde Yakında span; sahte href yok |
| Gerçek legal / operasyon durumu | .local/store-backend-audit.json: support_email ve store URLs boş, legal default, moderation kelime/domain listeleri boş; mevcut Readiness MISSING sonucunu korur |

## Teknik olmayan açık bilgiler

Hosting bölgesi/alıcıları, veri işleyen sözleşmeleri, gerçek TLS/domain, log/yedek/support/audit retention, hukuk onayı, çocuk güvenliği sorumlusu ve review hesabı gerçek bilgi gerektirir. Örnek sürelerden hukuki retention süresi üretilmez. SDK kaynak/manifest verileri Apple/Google yayın formunun yerine otomatik geçirilmez; son release build’i ve sağlayıcıları doğrulanır.

## Bu turdaki sınırlı kod düzeltmesi

lib/screens/settings.dart içindeki mevcut history onay metni ve auth.dart onboarding izin açıklaması; sunucuya konum iletimi, öneri/bildirim amacı, Android arka plan servisi ve iOS foreground-only sınırıyla netleştirildi. Yeni ekran/izin/ürün davranışı eklenmedi. Açıklama cihaz konumu eyleminden önce gösterilir; uzun onay küçük ekranda kaydırılabilir. Admin store linkleri için host yanında doğru path/paket ve credential’sız URL doğrulaması eklendi. Home, karşılaşma, mesaj, konum-zaman ve Yolculuk motorları değiştirilmedi. Tam test sonucu docs/STORE_AUDIT_VALIDATION.md’ye işlenir.
