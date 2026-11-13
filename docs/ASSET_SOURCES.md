# Yerel görsel ve font kaynakları

Fotoğraflar örnek kullanıcı içeriğidir; uygulamanın arka planı veya dekoratif şehir teması olarak kullanılmaz. Profil isimleri kurgusaldır; fotoğraftaki kişilerle gerçek bir ilişki iddiası yoktur.

- `sunset.jpg`: https://images.unsplash.com/photo-1472120435266-53107fd0c44a
- `coffee.jpg`: https://images.unsplash.com/photo-1442512595331-e89e73853f31
- `coast.jpg`: https://images.unsplash.com/photo-1519451241324-20b4ea2c4220
- `journey.jpg`: https://images.unsplash.com/photo-1474487548417-781cb71495f3
- Avatarlar: https://randomuser.me/api/portraits/ üzerinden örnek portreler. Tam indirme adresleri `tool/download_demo_assets.py` dosyasında.
- Nunito Sans: Google Fonts deposu, `ofl/nunitosans`. SIL Open Font License metni `assets/fonts/OFL.txt` içindedir.
- Marka işareti: Kullanıcının sağladığı referanslardaki kalp / kesişen yol yaklaşımından oluşturulmuş kod tabanlı vektör. Flutter CustomPainter ve Android vector drawable. Platform bitmap dışa aktarımı: `tool/export_brand_icons.py`.

Bu dosyalar uygulama paketine gömülüdür; uygulama çalışırken uzak kaynaklardan görsel indirilmez.
