# Mağaza yerelleştirme (TR / EN)

Bu klasör iki mağaza dilinin metadata dosyalarını içerir. **Türkiye** mağazası için `tr-TR`; diğer tüm pazarlar için küresel yedek olarak `en-US` kullanılır.

| Dosya | İçerik |
|---|---|
| `tr-TR/app_store.json`, `en-US/app_store.json` | App Name, Subtitle, Promotional text, Description, Keywords, What's New şablonu, Privacy / Support / Marketing URL, App Review Notes |
| `tr-TR/google_play.json`, `en-US/google_play.json` | Title, Short description, Full description, Release notes, Privacy policy URL, `contains_ads: true` |

Sınırlar test edilmiştir: App Store alt başlık ≤ 30, anahtar kelimeler ≤ 100, tanıtım metni ≤ 170; Google Play kısa açıklama ≤ 80, tam açıklama ≤ 4000 karakter.

Kurallar: gerçek operatör kimliği, demo hesap parolası, mağaza URL'si veya e-posta **uydurulmaz**; bunlar işletici tarafından mağaza konsollarında girilir. Konum reklam amacıyla kullanılmadığı metinlerde açıkça belirtilir. `docs/store/STORE_METADATA.json` önceki (tr-TR) tek dilli taslaktır; güncel çok dilli kaynak bu klasördür.
