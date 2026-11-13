# SenMiydin? final branding gereksinimleri

Durum: **WAITING FOR BRAND**. Final logo henüz seçilmedi. Mevcut geçici kalp işareti final olarak sabitlenmedi; bu tur logo, store screenshot veya grafik üretilmedi.

## Gerçek master teslimi

| Master | Gereksinim |
|---|---|
| Horizontal logo | Onaylı sembol + SenMiydin? wordmark; tercihen SVG, doğru viewBox/boşluk; transparan |
| Square app icon master | Ayrı kare viewBox’lı SVG; küçük boyutta okunabilir ve adaptive crop güvenli |
| PNG kaynaklar | Yüksek çözünürlük, orijinal boyut/alpha; mümkünse kare master en az 1024×1024 ve yatay 2×/3× çıktı. PNG tek kaynaksa helper için tasarım ekibinden uygun SVG istenir |
| Light background version | Mevcut beyaz tasarım için onaylı renkli master zorunlu |
| Dark background version | Marka bunu gerektiriyorsa ayrıca sağlanır; yeni dark tema oluşturulmaz |
| Lisans / tipografi | Kullanım hakkı, doğru yazım, font/outline durumu ve renk değerleri işletmeci tarafından onaylanır |

SVG içinde script, event handler, dış kaynak veya aktif içerik bulunmamalı. Hazır olmayan master yerine AI/rastgele logo çizilmez.

## Uygulanacak çıktılar

Android adaptive foreground ve normal icon; Android/iOS splash; iOS AppIcon (opak RGB export); Flutter header/splash; web header logo; admin login logo; favicon; apple-touch-icon; OG image; store grafik tasarım kaynağı. Store feature graphic ve store screenshotlar ayrı onay/üretim adımıdır; helper’ın ikon/OG üretmesi bu alanların tamamlandığı anlamına gelmez.

## Mevcut uygulama hattı

Önce tool/branding-requirements.txt bağımlılıkları gerçek geliştirme ortamında kurulur. Ardından yalnız gerçek onaylı master yollarıyla:

    powershell -ExecutionPolicy Bypass -File tool/apply_branding.ps1 -SquareSvg "GERCEK_KARE_MASTER.svg" -HorizontalSvg "GERCEK_YATAY_MASTER.svg"

Bu isimler örnek parametredir; mevcut dosya oldukları veya final oldukları iddia edilmez. Helper iki gerçek SVG’yi doğrular, mevcut geçici markanın aynısını final diye kabul etmez; önceki varlıkları ignored .local/branding-backup altında yedekler. assets/brand/mark.svg, horizontal.svg ve brand flag; native ikon/splash ve web/admin exportlar mevcut export_brand_icons hattıyla güncellenir.

Sonrasında Android adaptive crop/iOS opaklık/çözünürlük/kenar boşluğu, web/admin görünümü ve lisans kontrolü yapılır; Flutter/native build ve cihaz QA yenilenir. Kullanıcı Home düzeni, renk sistemi veya ürün akışı yeniden tasarlanmaz.

Ayrıntılı mevcut kullanım: [DEPLOYMENT.md](DEPLOYMENT.md), tool/apply_branding.ps1, tool/apply_branding.py ve tool/export_brand_icons.py. Bu tur helper uygulanmadı.
