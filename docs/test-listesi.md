# Cihaz test listesi

İki hesapla test edin: **A** (e-posta/şifre) ve **B** (Google). Mümkünse iki
telefon kullanın; bildirimler ancak öyle görülür. ⭐ en kritik olanlar.
Sorun bulursanız: ekran adı, ne yaptınız, ne oldu, varsa ekran görüntüsü.

## 0. Hazırlık
- [ ] Yeni `app-release.apk` kuruldu (debug APK değil).
- [ ] Koşullar ekranı her hesapta bir kez çıkıyor; kabulden sonra bir daha çıkmıyor.

## 1. Kayıt, giriş, doğrulama
- [ ] Kayıt formu: boş alan, hatalı e-posta, 8 karakterden kısa şifre alanın altında uyarı veriyor; koşullar kutusu işaretlenmeden kayıt olmuyor.
- [ ] ⭐ Kayıt → doğrulama ekranı → e-postadaki bağlantı → uygulamaya dönünce kendiliğinden devam. E-postayla kayıtta koşullar ekranı tekrar çıkmıyor.
- [ ] "Bağlantıyı tekrar gönder" 60 sn sayacı.
- [ ] Yanlış şifre: formun içinde Türkçe hata.
- [ ] Google ile giriş; hesap seçme penceresini kapatınca hata çıkmıyor.
- [ ] "Şifremi unuttum" e-postası geliyor, yeni şifreyle giriş oluyor.
- [ ] Şifre yöneticisi e-posta/şifreyi dolduruyor; klavyede "ileri" sonraki alana geçiyor.

## 2. Profil
- [ ] Ad değiştir → karşı tarafta yeni ad.
- [ ] Şifre değiştir: yanlış mevcut şifre → "Mevcut şifre yanlış."; eşleşmeyen şifre uyarısı; başarılıysa yeni şifreyle giriş.
- [ ] Bildirim anahtarları; tema (Sistem/Açık/Koyu).
- [ ] Pacta kodum: QR, kopyala, paylaş.
- [ ] ⭐ Kodu yenile → eski kodla ekleme başarısız, yeni kodla başarılı.

## 3. Kişi ekleme
- [ ] E-postayla (kayıtsız ya da doğrulanmamış e-postada açıklayıcı mesaj).
- [ ] Pacta koduyla (önce ad gösteriliyor), QR ile, WhatsApp davet linkiyle (link uygulamayı açıyor).
- [ ] Kendi kodunuzu/e-postanızı girince hata; özel defter açma.

## 4. ⭐ Kayıtlar ve onay
- [ ] A, B'ye borç yazar → B'de "onay bekliyor", A'nın bakiyesi değişmiyor.
- [ ] B onaylar → iki tarafta aynı bakiye.
- [ ] İtiraz → A düzeltir → B yeni hâlini onaylar; reddet (bakiye değişmez); geri çek.
- [ ] A "ödeme aldım" (aleyhine) → onaysız işlenir, B'ye bilgi.
- [ ] Onaylı kayda düzeltme (ters kayıt) → onaylanınca bakiye düzelir.
- [ ] "12,5" → 12,50 ₺; dolar/altın ayrı bakiye; vadeli kayıt Vadeler ve Hareketler'de; ileri tarih reddediliyor.

## 5. Hatırlatma ve bildirimler
- [ ] Hatırlat → bildirim gelir, tutar yazmaz; ikinci hatırlatmada "bir sonraki" tarihi; 21:00–09:00 arası sabaha kalır; sessize alınan kişiden bildirim gelmez.
- [ ] ⭐ Bildirime dokununca ilgili kayıt açılır; zil listesi dolar.
- [ ] ⭐ Çıkış yapıp başka hesapla girince eski hesabın bildirimleri gelmez. **İnterneti kapatıp çıkış yapın**, sonra interneti açıp başka hesapla girin: yine gelmemeli.
- [ ] Aynı hesap iki telefonda açıkken bildirim ikisine de geliyor; birinden çıkınca diğerine gelmeye devam ediyor.
- [ ] Durum çubuğundaki bildirim simgesi beyaz kare değil (yuvarlak onay işareti).

## 5b. ⭐ Engelleme
- [ ] Ortak defter menüsü → "Engelle": onay soruyor; defterde "engellediniz" notu ve "Engeli kaldır".
- [ ] Engellenen kişinin telefonunda: defterde "kayıt gönderilemiyor" notu, Kayıt ekle / Hatırlat yok; bekleyen kaydını geri çekebiliyor.
- [ ] Engelleyen kayıt eklemeye devam edebiliyor; engel kalkınca her şey eski hâline dönüyor.

## 6. Kişiler ekranı
- [ ] Favori, listeden kaldır / geri getir, süzgeçler.
- [ ] "Liste | Tablo" seçicisi; tabloda toplamlar doğru.
- [ ] Sağ üst menü → "Özeti dışa aktar (PDF / CSV)"; bir süzgeçle (ör. "Vadesi geçen") yalnızca görünenler aktarılıyor.

## 7. ⭐ Özel defteri ortak deftere taşıma
- [ ] Vadeli + vadesiz kayıtlı özel defter → "Taşı" → B. Önizleme doğru; "Açıklamaları da gönder" kapalıyken notlar gitmiyor.
- [ ] B'ye tek bildirim; B onaylayınca bakiye ortak defterde.
- [ ] Eski özel defter listede görünmüyor, toplamda iki kez sayılmıyor; ortak defterdeki "Özel defterdeki eski kayıtlar" açılıyor.

## 7b. ⭐ Uygulamasız web onayı (sunucu ve hosting kurulduktan sonra)
- [ ] Özel defterde bir kayıt → "Karşı taraftan onay iste": açıklama anahtarı, paylaşım menüsü açılıyor; mesajda tutar, link ve son geçerlilik tarihi var.
- [ ] Linki uygulaması olmayan bir telefonda / bilgisayarda aç: doğrulamadan önce yalnızca gönderenin adı görünüyor.
- [ ] E-posta yaz → gelen bağlantıya aynı cihazda dokun → kayıt açılıyor (tutar, tarih, açıklama). Başka cihazda açınca e-posta yeniden soruluyor.
- [ ] Onayla / İtiraz et (önerilen tutarla) / Reddet: sayfada makbuz; uygulamada bildirim, kayıtta durum kartı ("Karşı taraf onayladı", gizlenmiş e-posta).
- [ ] Aynı linki başka bir e-postayla açınca "başka bir adrese bağlı" diyor; "Farklı adresle doğrula" ile doğru adres denenebiliyor.
- [ ] Link oluştururken karşı tarafın e-postası yazılınca: sayfa "a***@… adresi için oluşturuldu" diyor, başka adres kabul edilmiyor; kartta "Belirttiğiniz adresle doğrulandı".
- [ ] "Onay linkini yeniden gönder" sonrası eski link "Bu link yenilendi" diyor.
- [ ] Linki doğrulayan kişi sonra aynı e-postayla uygulamaya kaydolabiliyor ("kullanımda" hatası yok).

## 8. Dışa aktarma (kişi)
- [ ] Defter menüsü → "Ekstre (PDF)": Türkçe harfler, ₺, bakiye ve kayıtlar doğru.
- [ ] "Tablo (CSV)" Excel / Google E-Tablolar'da sütunlara ayrılmış açılıyor; WhatsApp/e-postayla gönderilebiliyor.

## 9. Uygulama kilidi
- [ ] Açarken parmak izi/PIN istiyor; uygulamayı kapatıp açınca içerik görünmeden kilit geliyor.
- [ ] 1 dk'dan kısa arka plan sormuyor, uzun soruyor; PIN ile açılıyor; kilit ekranından çıkış; kapatırken de doğrulama istiyor.
- [ ] ⭐ Bir kişinin defteri açıkken kilit gelsin → "Çıkış yap": giriş ekranı açılıyor, geri tuşuyla eski defter görünmüyor.
- [ ] Kilit açıkken son uygulamalar ekranında Pacta önizlemesi boş/gizli; ekran görüntüsü alınamıyor (kilit kapalıyken alınabiliyor).
- [ ] Telefonun ekran kilidini kaldırınca Pacta kilitli kalmıyor (kilit kendiliğinden kapanıyor).

## 10. Yeni kullanıcı
- [ ] Kişisi olmayan hesapta ana sayfada "Başlarken" 3 adımı ve düğmeleri.

## 11. ⭐ Hesap silme (yalnızca test hesabıyla — geri alınamaz)
- [ ] Profil > Hesabı sil yeniden giriş istiyor; silince giriş ekranı.
- [ ] Karşı tarafta "Silinmiş kullanıcı", defter kapalı, yeni kayıt yok, bir bildirim.
- [ ] Silinen hesapla giriş yapılamıyor; doğrulama ekranındaki "Hesabı sil" çalışıyor.

## 12. Genel
- [ ] Tüm ekranlar koyu temada okunaklı.
- [ ] İnternetsiz açılış takılmıyor.
- [ ] Telefonda büyük yazı boyutunda taşan/kesilen metin yok.

## Beklenen, hata sayılmaz
- Gizlilik / Koşullar bağlantıları şimdilik "Sayfa bulunamadı" açar (yasal sayfalar hukukçu onayından sonra yayınlanacak).
- https://pacta-76686.web.app ana adresi artık yalnızca kısa bir tanıtım sayfası (web uygulaması yayında değil).
- iPhone test edilmiyor.
