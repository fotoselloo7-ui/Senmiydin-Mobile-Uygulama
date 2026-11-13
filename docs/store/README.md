# SenMiydin? store submission paketi

Denetim: 9 Kasım 2026. Belgeler hazır; **gerçek mağaza gönderimi hazır/onaylandı anlamına gelmez**. Gerçek bilgi gereken alanlar [GERÇEK BİLGİ GEREKLİ]. Final artwork, screenshot, provider hesabı veya review hesabı üretilmedi.

| İş | Belge |
|---|---|
| Play Console kopyalama alanları | [GOOGLE_PLAY_SUBMISSION.md](GOOGLE_PLAY_SUBMISSION.md) |
| App Store Connect alanları ve İngilizce Review Notes | [APP_STORE_SUBMISSION.md](APP_STORE_SUBMISSION.md) |
| Ortak doğrulanabilir copy | [STORE_METADATA.json](STORE_METADATA.json) |
| Google verileri | [GOOGLE_PLAY_DATA_SAFETY.md](GOOGLE_PLAY_DATA_SAFETY.md) |
| Apple privacy | [APPLE_PRIVACY_LABELS.md](APPLE_PRIVACY_LABELS.md) |
| İzinler | [PERMISSIONS.md](PERMISSIONS.md) |
| Android arka plan / FGS | [BACKGROUND_LOCATION_DECLARATION.md](BACKGROUND_LOCATION_DECLARATION.md) |
| Video planı, video yok | [BACKGROUND_LOCATION_REVIEW_VIDEO.md](BACKGROUND_LOCATION_REVIEW_VIDEO.md) |
| UGC / çocuk güvenliği / sınırlar | [UGC_MODERATION.md](UGC_MODERATION.md) |
| Gerçek silme davranışı | [ACCOUNT_DELETION.md](ACCOUNT_DELETION.md) |
| Rating soruları | [CONTENT_RATING.md](CONTENT_RATING.md) |
| Görsel çekim planı, screenshot yok | [SCREENSHOT_PLAN.md](SCREENSHOT_PLAN.md) |
| 1024×500 brief, grafik yok | [FEATURE_GRAPHIC_BRIEF.md](FEATURE_GRAPHIC_BRIEF.md) |
| Gerçek master gereksinimleri | [BRANDING_REQUIREMENTS.md](../BRANDING_REQUIREMENTS.md) |
| Tek gerçek bilgi listesi | [REQUIRED_REAL_INFORMATION.md](REQUIRED_REAL_INFORMATION.md) |
| Review hesabı manuel süreci | [REVIEW_ACCOUNT.md](REVIEW_ACCOUNT.md) |
| Gerçek SDK/manifest denetimi | [SDK_AUDIT.md](SDK_AUDIT.md) |
| Kaynak kanıt dizini | [DATA_EVIDENCE.md](DATA_EVIDENCE.md) |
| Store URL / Yakında davranışı | [STORE_URL_SETTINGS.md](STORE_URL_SETTINGS.md) |
| Public legal route ve içerik ayrımı | [PUBLIC_LEGAL_AUDIT.md](PUBLIC_LEGAL_AUDIT.md) |
| Son otomatik sonuç | [STORE_READINESS_REPORT.md](STORE_READINESS_REPORT.md) / [JSON](STORE_READINESS_REPORT.json) |

## Çalıştırma

Proje kökünden:

    powershell -ExecutionPolicy Bypass -File tool/store_readiness_check.ps1

Android merged release manifest/dependency kanıtı yoksa veya bağımlılıklar değiştiyse:

    powershell -ExecutionPolicy Bypass -File tool/store_readiness_check.ps1 -RefreshAndroidAudit

Yalnız kaynak/doküman kontrolü için -SkipRuntime, makine çıktısı için -Json kullanılabilir. Normal tam kontrol yerel backend üzerinde yalnız SELECT ve public GET yapar; form göndermez, seed/reset/.env/signing işlemi yapmaz, sır istemez. Gradle seçeneği dependency/manifest üretir; imzalı release paketi üretmez. Önceki release_check.ps1 değiştirilmedi.

READY tek kontrolün geçtiğini; WAITING dış araç/insan doğrulaması beklediğini; MISSING gerçek bilgi/kurulum veya legal/policy eksikliği olduğunu; FAIL teknik tutarsızlığı belirtir. Öncelik FAIL > MISSING > WAITING > READY. Exit 0 tümü READY; exit 1 FAIL; exit 2 MISSING veya WAITING. Yerel geliştirme ortamı production gibi gösterilmez; demo verisi bu kontrolle silinmez.

## İnsan tarafından doğrulanacak kapılar

Örnek [OPERATOR_VERIFICATION.example.json](OPERATOR_VERIFICATION.example.json) yalnız şemadır. Gerçek incelemeler tamamlanırsa ignored .local/store-operator-verification.json içinde confirmed=true ve mevcut bir evidence_file verilebilir. Parola/anahtar bu dosyaya yazılmaz. Script yalnız kanıt dosyasının varlığını ve operatör onayını tanır; Mac archive, sözleşme, policy incelemesi veya gerçek hesabın fiilen çalıştığını bağımsız doğruladığını iddia etmez. Bu alanlar doldurulmadan WAITING/MISSING kalır; backend gerçek production-check kapıları ayrıca uygulanır.

Son uygulama baseline’ı ve bu turdaki yalnız izin metni/store URL düzeltmeleri için [STORE_AUDIT_VALIDATION.md](../STORE_AUDIT_VALIDATION.md) okunur. Tam UI/ürün yeniden geliştirilmedi.
