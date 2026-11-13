# Mağaza inceleme hesabı yaklaşımı

Gerçek production hesabı bu çalışmada oluşturulmadı. Kullanıcı adı/parola source, test fixture, markdown veya metadata JSON’una konmaz. Yerel Demo hesabının parolası Console’a taşınmaz. Bu süreç gerçek production açıldıktan sonra yetkili işletmeci tarafından manuel uygulanır.

1. Normal kullanıcı rolünde bir review hesabı oluştur. Admin/moderatör yetkisi verme; yetişkin yaş kuralını ve gerçek terms acceptance akışını kullan.
2. Takip edilebilir, kişisel veri içermeyen örnek profil ve basit bir post hazırla. Profil şehrini ve review sırasında seçilecek aktif şehri kayıt altına al.
3. Konum izni vermeden giriş, manuel şehir ve temel feed erişimini doğrula. Review şehri [GERÇEK BİLGİ GEREKLİ].
4. Gerekirse ikinci normal rol hesabı oluştur; bir kabul edilmiş karşılaşma, partner onaylı ortak hikâye ve kabul edilmiş mesaj isteği hazırla. Fotoğrafsız hikâye ile iki izinli gerçek fotoğraf örneği kullan; avatarı hikâye fotoğrafı yapma.
5. Hesaplar kesin GPS paylaşmasın; gerçek kişilerin mesajı/konumu/fotoğrafı kullanılmasın. Mesajlar sade örnek içerik olsun. Görünür metne test UUID/timestamp ekleme.
6. İki hesabın username/ID ilişkisini yalnız güvenli işletme defterinde tut. İnceleme boyunca hesabı kilitleme, süre aşımıyla silme veya ikinci doğrulama engeli oluşturma. Parolayı gerçek güvenli yönetim kanalıyla sakla.
7. Console “App access” / App Store Connect sign-in alanlarına kullanıcı adı ve parolayı yetkili kişi girsin. Parolayı Review Notes serbest metnine veya depoya kopyalama.
8. Silme akışını gösteren hesabı ana inceleme hesabıyla aynı anda yok etme; ayrı silinebilir normal rol hesabı veya inceleyicinin kendi açacağı hesap kullan.
9. İnceleme tamamlanınca manuel güvenlik politikasıyla parolayı/erişimi yönet; mağaza yeniden inceleme ihtimali için işleyen erişim sürecini koru.

| Güvenli Console alanı | Değer |
|---|---|
| Ana review kullanıcı adı | [GERÇEK BİLGİ GEREKLİ] |
| Ana review parola | [GERÇEK BİLGİ GEREKLİ] |
| İkinci normal kullanıcı (gerekirse) | [GERÇEK BİLGİ GEREKLİ] |
| İkinci parola | [GERÇEK BİLGİ GEREKLİ] |
| İçerik/review şehri | [GERÇEK BİLGİ GEREKLİ] |
| İnceleme için gerçek backend / destek | [GERÇEK BİLGİ GEREKLİ] |

Push veya OAuth gerçek yapılandırılmamışsa çalışıyormuş gibi inceleme notu yazılmaz. Temel parola girişi ve in-app bildirim merkezinin durumu açıkça anlatılır. Hesapların oluşturulduğu/onaya hazır olduğu bu belgeyle iddia edilmez.
