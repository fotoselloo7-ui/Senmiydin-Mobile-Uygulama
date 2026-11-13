# Store URL ayarları / boş bağlantı davranışı

Denetim: 9 Kasım 2026.

Admin sistem ayarlarında app_store_url ve play_store_url vardır. Settings varsayılanları boş string’dir. SystemController HTTPS URL, host ve path doğrular: Google Play /store/apps/details?id=com.senmiydin.app; Apple apps.apple.com üzerinde id<sayısal app id>. Yanlış platform/paket veya zorunlu minimum sürüme karşı store adresi eksikse validation hatası verir. Kullanıcıya sunulan mobil store linkleri ServiceAvailability.store ile HTTPS ve doğru host kontrolünden geçer.

Public website/stores.blade.php:
- Değer doluysa gerçek URL ile indir linki;
- Boşsa href yerine “Yakında” yazan store-disabled span;
- Website schema downloadUrl yalnız dolu ayarlardan oluşturulur.

Yerel denetimde iki URL de boş; bu bilerek gerçek olmayan link eklenmemesi durumudur. Bu tur DB ayarı değiştirilmedi, store hesabı/app record oluşturulmadı. Route/HTML denetim sonucu STORE_READINESS_REPORT.json içinde yer alır.

Gerçek yayın hesabından URL gelince yetkili admin doğrulanmış adresi kaydeder. Kaynakta tahminî mağaza ID’si oluşturulmaz. Boş linkler ilk mağaza incelemesinde broken link olarak gösterilmez; gerçek linklerin olmaması dışında final domain/support/legal/review bilgileri yine gereklidir.

Kanıt: backend/app/Administration/Settings.php; Http/Controllers/Admin/SystemController.php; resources/views/website/stores.blade.php ve layout.blade.php; lib/core/service_availability.dart; WebsiteTest ve AdministrationTest.
