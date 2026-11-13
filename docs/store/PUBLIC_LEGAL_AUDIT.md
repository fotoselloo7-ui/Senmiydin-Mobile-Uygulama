# Public legal / support route ve içerik audit

Denetim: 9 Kasım 2026. Canlı alan adı/HTTPS sahipliği doğrulanmadı. Kodda hedef domain bulunması çalışan production URL’si olduğu anlamına gelmez; Console alanları [GERÇEK BİLGİ GEREKLİ] kalır.

| Yol | Gerçek route / davranış | İçerik durumu |
|---|---|---|
| /gizlilik | WebsiteController::page; legal CMS veya varsayılan | Yerel CMS satırı var ama varsayılan metin; operatör/retention tamamlanmamış |
| /kvkk | Aynı public route, yoksa varsayılan içerik | Yerelde gerçek CMS satırı yok; fallback taslak |
| /kullanim-kosullari | Public legal metin | Varsayılan; gerçek işletmeci/hukuk onayı yok |
| /topluluk-kurallari | Public legal metin | Taciz/nefret/spam/mahremiyet kuralları var; açık CSAE standardı ve gerçek safety contact eksik |
| /hesap-silme | GET açıklama + POST sahiplik doğrulanacak destek talebi | Doğrudan silme değildir; gerçek destek ve operasyon süresi eksik |
| /iletisim | GET form + POST web_requests contact | support_email boş; çalışır gerçek iletişim yöntemi MISSING |

Son GET HTTP durumları STORE_READINESS_REPORT.json içinde üretilir. Test formu gönderilmedi; e-posta veya gerçek hesap işlemi yapılmadı. Sayfanın HTTP 200 dönmesi içeriğinin yayın için hukuken tamamlandığını göstermez.

Readiness::checks, OPERATOR_NAME / OPERATOR_CONTACT / LEGAL_REVIEWED yanında CMS gövdelerinin varsayılandan gerçekten farklı ve placeholder’sız olmasını bekler. Mevcut ortam bu nedenle **MISSING** kalır. Sadece LEGAL_REVIEWED=true yaparak veya sahte şirket/e-posta yazarak kontrol yeşile çevrilmez; bu tur .env/DB legal metni değiştirilmedi.

İşletmeci, veri kategorileri/amaçlar, gerçek hukuki dayanak, alıcı/aktarım, barındırma ülkesi, log/audit/support/yedek saklama ve silme prosedürü, gerçek destek/veri sorumlusu iletişimi ile metinleri tamamlar. Sosyal uygulama çocuk güvenliği standardı ve temas noktası ayrıca yayımlanmalıdır. Taslaklar UGC_MODERATION.md ve REQUIRED_REAL_INFORMATION.md ile ilişkilidir.

Kanıt: backend/routes/web.php; Website/Pages.php; WebsiteController; Deployment/Readiness.php; Administration/Settings.php. Gerçek yayın URL’lerinin erişim/HTTPS, girişsiz görüntüleme ve mobil legal CMS tutarlılığı deployment sonrasında ayrıca doğrulanır.
