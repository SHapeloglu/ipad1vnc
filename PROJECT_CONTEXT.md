# iPad1VNC Proje Bağlamı

Bu dosya, yeni bir ChatGPT/Claude/kod asistanı konuşmasında geliştirmeye devam etmek için tek doğruluk kaynağıdır.

## 1. Repo ve güncel geliştirme hattı

Repo: `SHapeloglu/ipad1vnc`

`main` dalında commit'li kararlı kaynak: **v2.2.0-beta3**.

Aktif geliştirme dalı: **`beta4-ui-security-polish`**.

Güncel ürün yönü: eski birinci nesil iPad'ler için VNC masaüstü erişimi, SSH terminal/tünel, uzak dosya yönetimi, profiller, tanılama, LAN keşfi, WOL ve düşük bellekli etkileşim yardımcılarını birleştiren hafif bir Linux yönetim konsolu.

Projeyi sıfırdan yeniden başlatma. Önce güncel kaynağı incele ve çalışan davranışı koru.

## 2. Değiştirilemez platform kısıtları

Hedef donanım/yazılım:
- iPad 1
- iOS 5.1.1
- jailbreak'li
- armv7
- yaklaşık 256 MB RAM
- Objective-C / UIKit
- manuel retain/release (non-ARC)
- eski Theos derlemesi
- dağıtım hedefi iOS 5.1
- eski iOS 6.1 SDK

Zorunlu Makefile hedefi:

```make
ARCHS = armv7
TARGET = iphone:clang:6.1:5.1
```

Kurallar:
- Açık eski sürüm uyumluluk koruması olmadan güncel iOS API'leri ekleme.
- Büyük bağımlılıklardan ve bellek ağırlıklı soyutlamalardan kaçın.
- Büyük dosyaları asla tamamen RAM'e yükleme.
- Terminal geri kaydırma geçmişini sınırlı tut.
- Uzun süren işçi/ağ döngülerinde autorelease pool kullan.
- RAW/Hextile/Tight geri dönüş davranışını koru.
- Fiziksel iPad testi olmadan bir özelliğe üretime hazır deme.

## 3. Ana kaynak dosya sorumlulukları

`src/AppDelegate.m` / `.h`
- ana arayüz ve orkestrasyon
- VNC bağlantı yaşam döngüsü
- profiller
- SSH terminal paneli
- Uzak Dosyalar paneli
- Araçlar / Tanılama
- WOL
- dinamik çözünürlük
- LAN keşfi
- transfer kuyruğu
- Keychain geçişi

`src/VNCClient.m` / `.h`
- RFB/VNC protokolü
- TCP bağlantısı ve kimlik doğrulama
- framebuffer güncellemeleri
- RAW / Hextile / Tight çözme
- pano
- işaretçi/tuş olayları
- tanılama/istatistikler
- deneysel VeNCrypt X509Vnc TLS

`src/VNCView.m` / `.h`
- framebuffer sunumu
- Direct ve Trackpad girişi
- iki parmakla yakınlaştırma
- iki parmakla kaydırma
- sağ tık
- orta tık
- hassas işaretçi
- drag lock (sürükleme kilidi)

`src/TerminalSession.m` / `.h`
- yerel PTY ve `/usr/bin/ssh`
- etkileşimli SSH
- SSH port yönlendirme
- açık SSH kullanıcı adı
- anahtar yolu / known_hosts / ssh-keygen

`src/LegacyTerminalBuffer.m` / `.h`
- hafif, sınırlı VT100 benzeri terminal tamponu

`src/KeychainStore.m` / `.h`
- VNC şifreleri ve Files API token'ları düz metin NSUserDefaults'ta değil Keychain'de saklanmalı

## 4. Gerçek cihazda bilinen iyi davranışlar

Daha önce fiziksel iPad'de doğrulananlar:
- TigerVNC / XFCE'ye VNC bağlantısı
- RAW
- Hextile
- Tight kodlama
- Direct dokunma
- Trackpad modu
- iki parmakla yakınlaştırma
- iki parmakla kaydırma
- pano
- bağlantı profilleri (önceki haliyle)
- Python basit HTTP sunucusu yerine özel kimlik doğrulamalı API'ye geçildikten sonra Files API

Önemli sonuç: **Tight gerçek iPad'de başarıyla bağlandı ve doğru görüntülendi.** Bu yolu koru.

## 5. Son beta3 bağlantı kesme düzeltmesi

beta2'de görülen hata:
- ana `Disconnect` düğmesine dokunmak onu `Connect`'e döndürmüyordu
- yeniden bağlanmak için uygulamanın kapatılıp açılması gerekiyordu

beta3 kaynak düzeltmesi:
- ana düğme Bağlan/Bağlantıyı Kes geçişi olarak çalışıyor
- elle bağlantı kesme `_shouldAutoReconnect = NO` yapıyor
- bekleyen yeniden bağlanma zamanlayıcısı iptal ediliyor
- pano yoklaması duruyor
- VNC istemcisi bağlantıyı kesip serbest bırakılıyor
- aktif SSH VNC tüneli duruyor
- kontroller yeniden açılıyor
- düğme `Connect`'e dönüyor
- beklenmedik ağ/uzak bağlantı kopmasında otomatik yeniden bağlanma davranışı korunuyor

Bu düzeltme kaynakta var ama hâlâ tam fiziksel cihaz doğrulaması gerektiriyor.

## 6. beta4 çalışması gerektiren gözlenen güncel hatalar

### A. Uzak Dosyalar araç çubuğu çakışması

Gerçek iPad'de gözlendi: Uzak Dosyalar üst düğmeleri üst üste biniyor.

Kök neden `src/AppDelegate.m` içindeki `buildFilesPanel`'de bulundu: `Up/New` ile `Queue/Pause/Upload/Close` çakışan sabit yatay çerçeve aralıklarına yerleştirilmiş.

Gereken beta4 değişikliği:
- Files araç çubuğunu iPad 1 boyutlarına göre yeniden tasarla
- yatay veya dikey modda çakışan kontrol olmasın
- UIKit/iOS 5 uyumluluğunu koru
- riskliyse güncel Auto Layout API'leri yerine kompakt yerleşim ve basit autoresizing/yerleşim hesapları kullan
- Kuyruk / Duraklat-Devam / Yükle / Kapat netliğini iyileştir

### B. TLS / VeNCrypt hatası

Gerçek cihazdaki TLS denemesi şu an başarısız oluyor.

`src/VNCClient.m` içindeki güncel uygulama:
- VeNCrypt güvenlik türü 19
- hedef X509Vnc alt türü 261
- SecureTransport
- `SSLNewContext`, `SSLDisposeContext`, `SSLSetEnableCertVerify` gibi eski semboller `dlsym` ile çözümleniyor

TLS **deneysel** olarak kalıyor.

Gereken beta4 çalışması:
- başarısızlık aşaması görünsün diye TLS hata/durum raporlamasını iyileştir
- iOS 5.1.1'de çalışma zamanında SecureTransport sembollerinin varlığını doğrula
- şunları ayırt et: sunucu VeNCrypt sunmuyor, X509Vnc alt türü yok, TLS bağlam hatası, sertifika/el sıkışma hatası, VNC kimlik doğrulama hatası
- TLS KAPALIYKEN normal VNC'yi asla bozma
- bilinen iyi güvenli taşıma olarak SSH Tünelini asla kaldırma
- pratik olduğunda bağlantı modunu/durumunu açıkça göster: Direct / SSH Tünel / TLS

Fiziksel cihaz + doğru yapılandırılmış TigerVNC testi geçmeden TLS'in düzeldiğini sessizce iddia etme.

## 7. beta4 geliştirme kapsamı

Aktif dal: `beta4-ui-security-polish`.

Öncelik sırasıyla planlanan beta4 işleri:
1. Uzak Dosyalar düğme çakışmasını düzelt.
2. Uzak Dosyalar panelini dikey/yatayda güvenli yap.
3. TLS/VeNCrypt tanılamasını ve temiz başarısızlık davranışını iyileştir.
4. Daha net Direct / SSH / TLS bağlantı göstergesi ekle.
5. Transfer kuyruğu arayüzünü ve Duraklat/Devam anlamını iyileştir.
6. Mimariyi yeniden tasarlamadan profil hızlı işlemlerini ve otomatik/varsayılan profil akışını iyileştir.
7. LAN keşfi sonuç deneyimini iyileştir ve taramayı ana iş parçacığı dışında tut.
8. Bellek ayak izini belirgin artırmadan durum/hata metinlerini iyileştir.
9. beta3 Bağlantıyı Kes -> Bağlan düzeltmesini koru.
10. Fiziksel iPad'de derle, kur ve doğrula.

Bu geliştirme hattına RDP, ses, çoklu monitör, bulut hesapları/relay veya ağır terminal framework'leri ekleme.

## 8. Korunması gereken mevcut v2.2 özellikleri

Güncel kaynakta yapılmış/hedeflenmiş olanlar:
- yuvarlanan RTT/FPS istatistikleriyle Tanılama 2.0
- Hassas fare modu
- Drag Lock
- orta tık
- Profiller 3.0 hızlı işlemleri
- LAN tarama
- genişletilmiş özel/donanım klavye tuşları
- transfer kuyruğu
- `.part` + HTTP Range ile devam edebilen indirmeler
- devam edebilen/parçalı yüklemeler
- Files `/api/stat`
- bellek baskısında temizlik
- ağ mesajı başına autorelease pool'lar
- deneysel VeNCrypt X509Vnc TLS

Bunların çoğu hâlâ çalışma zamanı doğrulaması gerektiriyor. Çalışan alt sistemleri yalnızca stil için yeniden yazma.

## 9. Derleme ortamı

Bilinen WSL ortamı:

```text
Theos: /home/yeliz/theos
Legacy SDK: /home/yeliz/legacy-ios-sdks/iPhoneOS6.1-extracted/iPhoneOS6.1.sdk
```

Tipik yerel çalışma klasörü:

```text
~/projects/ipad1vnc/iPad1VNC-v2.2.0-beta3
```

Derleme:

```bash
make clean
make package FINALPACKAGE=1
```

beta3 için beklenen paket adı:

```text
packages/com.olap.ipad1vnc_2.2.0-beta3_iphoneos-arm.deb
```

iOS 5.1 için derlemenin kullanımdan kalktığı uyarısı beklenir ve tek başına hata değildir.

## 10. iPad'e kopyalama/kurulum

Bilinen yerel ağ test adresi `192.168.1.2` oldu.

Güncel OpenSSH, eski iPad SSH sunucusuyla uyumluluk gerektirir:

```bash
scp \
-o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/com.olap.ipad1vnc_<VERSION>_iphoneos-arm.deb \
root@192.168.1.2:/var/mobile/
```

SSH:

```bash
ssh \
-o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
root@192.168.1.2
```

Eski SSH algoritmalarını genel olarak açma.

iPad'de:

```bash
dpkg -i /var/mobile/com.olap.ipad1vnc_<VERSION>_iphoneos-arm.deb
killall SpringBoard
```

## 11. Linux/TigerVNC sunucu bağlamı

Geliştirme sunucusu:
- Ubuntu 24.04
- XFCE
- Linux masaüstü kullanıcısı: `desktop`
- TigerVNC ekranı `:1`
- geliştirme VNC portu `5901`

Tipik VNC komutu:

```bash
vncserver :1 -geometry 1024x768 -depth 24 -localhost no
```

Tipik `~/.vnc/xstartup`:

```sh
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session startxfce4
```

Repo herkese açıktır. Gerçek genel sunucu IP'sini, şifreleri, API token'larını veya özel anahtarları asla commit etme.

## 12. Files API sunucusu

Eşleşen kaynak:

```text
scripts/ipad1vnc_fileserver.py
```

Tipik sunucu kurulumu:

```text
/opt/ipad1vnc/ipad1vnc_fileserver.py
```

Dosya kökü:

```text
/home/desktop/Downloads
```

Token dosyası:

```text
/home/desktop/.ipad1vnc-files-token
```

Geliştirme portu: `8085`

Kimlik doğrulama başlığı:

```text
X-iPad1VNC-Token
```

Uç noktalar:
- `GET /api/list?path=...`
- `GET /api/stat?path=...`
- `GET /download?path=...&token=...`
- `POST /api/mkdir`
- `POST /api/rename`
- `POST /api/delete`
- `POST /api/upload`
- `POST /api/upload-chunk?path=...&offset=...&total=...`

v2.2, devam için HTTP Range indirmelerini destekler/hedefler.

Güvenlik yönü:
- düz HTTP üzerindeki Files token'ı şifreleme değil, kimlik doğrulamadır
- kanıtlanmış güvenli yol SSH Tünelidir
- güvenli tünel doğrulandıktan sonra genel 5901 ve 8085 portlarını kısıtla/güvenlik duvarıyla kapat

## 13. Fiziksel cihaz doğrulama kontrol listesi

En yüksek öncelikli sıra:
1. Tight AÇIK bağlanıyor.
2. Ana `Disconnect` hemen `Connect` oluyor.
3. Uygulamayı yeniden başlatmadan yeniden bağlan.
4. Elle bağlantı kesme 3 saniye sonra otomatik yeniden bağlanmıyor.
5. Beklenmedik ağ/sunucu kaybı hâlâ otomatik yeniden bağlanıyor.
6. Uzak Dosyalar kontrolleri yatayda çakışmıyor.
7. Uzak Dosyalar kontrolleri dikeyde çakışmıyor.
8. Kuyruk / Duraklat-Devam / Yükle / Kapat tekrar tekrar çalışıyor.
9. Tanılama RTT/FPS/kbps/kare değerleri gerçekçi şekilde değişiyor.
10. Hassas mod ve Drag Lock çalışıyor.
11. Profil hızlı işlemleri çalışıyor.
12. Terminal açık SSH kullanıcısı gerektiriyor ve Bağlan/Durdur tekrar tekrar çalışıyor.
13. Files listele/bilgi/indir/yükle/yeniden adlandır/sil/klasör oluştur çalışıyor.
14. Kesilen indirme `.part` dosyasından HTTP Range ile devam ediyor.
15. Kesilen yükleme uzak boyuttan/parçalardan devam ediyor.
16. 100+ MB transfer iPad'i çökertmiyor.
17. LAN tarama arayüzü dondurmadan tamamlanıyor.
18. SSH tüneli çalışıyor ve elle bağlantı kesmede duruyor.
19. TLS/X509Vnc en son, doğru yapılandırılmış TigerVNC ile test ediliyor.
20. 15/30/60 dakikalık kararlılık oturumları ve tekrarlı bağlan/kes döngüleri çalıştırılıyor.

## 14. Kodlama/geliştirme kuralları

- Riskli beta değişiklikleri yaparken son bilinen iyi yolu koru.
- non-ARC bellek sahipliğini doğru tut.
- UIKit'i iOS 5.1.1 ile uyumlu tut.
- Yalnızca derlensin diye uyarıları kapatmaktan kaçın; pratikse kaynağı düzelt.
- VNC şifrelerini veya Files token'larını düz metin defaults'ta saklama.
- Bu herkese açık repoda özel altyapı kimlik bilgilerini açığa çıkarma.
- Küçük, incelenebilir değişiklikleri ve anlamlı adımlardan sonra gerçek cihaz doğrulamasını tercih et.
- Dokümantasyon ile kaynak çelişirse kaynağı incele ve gerçek durumu belirledikten sonra bu dosyayı güncelle.

## 15. Hemen yapılacak sonraki adım

Şu dalda devam et:

```text
beta4-ui-security-polish
```

İlk kod değişikliği: `src/AppDelegate.m` içindeki `buildFilesPanel`'i, Uzak Dosyalar araç çubuğu düğmeleri iPad 1'de yatay veya dikey modda çakışamayacak şekilde düzelt. Ardından beta4'ü derleyip kur ve TLS tanılamasına geçmeden önce yerleşimi fiziksel cihazda doğrula.

## 16. Yeni sohbet başlangıç metni

Yeni bir konuşmada bu kısa metni kullan:

```text
https://github.com/SHapeloglu/ipad1vnc üzerinden iPad1VNC projesine devam et.
Önce PROJECT_CONTEXT.md'yi oku, sonra güncel kaynak kodu incele.
Projeyi yeniden tasarlama veya baştan başlatma.
iPad 1 / iOS 5.1.1 / armv7 / non-ARC / ~256 MB RAM kısıtlarını koru.
PROJECT_CONTEXT.md'deki "Hemen yapılacak sonraki adım" bölümünden devam et ve anlamlı ilerlemeden sonra o dosyayı güncel tut.
```
