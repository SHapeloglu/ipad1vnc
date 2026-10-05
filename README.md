# iPad1VNC

Birinci nesil **iPad 1 (iOS 5.1.1, jailbreak)** için hafif Linux yönetim konsolu: VNC uzak masaüstü, SSH terminal ve tünel, uzaktan dosya yönetimi, bağlantı profilleri, tanılama, LAN tarama ve Wake-on-LAN — tek uygulamada, ~256 MB RAM'e sığacak şekilde.

**Kararlı sürüm:** v2.2.0-beta3 (`main`) · **Geliştirme:** `beta4-ui-security-polish` dalı

## Özellikler

- **VNC:** RAW / Hextile / Tight kodlama (Tight gerçek cihazda doğrulandı), pano paylaşımı, otomatik yeniden bağlanma, dinamik çözünürlük.
- **Dokunmatik:** Direct ve Trackpad modu, pinch zoom, iki parmakla kaydırma, sağ/orta tık, hassas işaretçi, drag lock, genişletilmiş özel tuşlar.
- **SSH:** etkileşimli terminal (sınırlı VT100 tamponu), port yönlendirme / VNC için SSH tüneli, anahtar ve known_hosts desteği.
- **Uzak Dosyalar:** listele, bilgi, indir (HTTP Range ile kaldığı yerden devam), parçalı/devam eden yükleme, yeniden adlandır, sil, klasör oluştur, transfer kuyruğu.
- **Profiller** ve hızlı işlemler, **tanılama** (RTT/FPS/kbps), **LAN tarama**, **Wake-on-LAN**.
- VNC şifreleri ve Files API token'ı **Keychain**'de saklanır.
- Deneysel: VeNCrypt X509Vnc (TLS) — güvenli bağlantı için şimdilik **SSH tüneli** önerilir.

## Gereksinimler

- Jailbreak'li iPad 1, iOS 5.1.1 (armv7)
- Derleme: [Theos](https://theos.dev) + iPhoneOS 6.1 SDK
- Sunucu: Linux masaüstü + TigerVNC (örn. Ubuntu 24.04 + XFCE), isteğe bağlı OpenSSH ve Files API

## Derleme ve kurulum

```bash
make clean
make package FINALPACKAGE=1
# packages/com.olap.ipad1vnc_<SÜRÜM>_iphoneos-arm.deb

scp -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa \
    packages/com.olap.ipad1vnc_<SÜRÜM>_iphoneos-arm.deb root@<ipad-ip>:/var/mobile/
ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@<ipad-ip>
dpkg -i /var/mobile/com.olap.ipad1vnc_<SÜRÜM>_iphoneos-arm.deb && killall SpringBoard
```

"Building for iOS 5.1 is deprecated" uyarısı normaldir.

## Sunucu tarafı

**TigerVNC:**

```bash
vncserver :1 -geometry 1024x768 -depth 24 -localhost no
```

`~/.vnc/xstartup` örneği: [`scripts/xstartup`](scripts/xstartup). Ubuntu kurulum yardımcısı: [`scripts/server-ubuntu24.sh`](scripts/server-ubuntu24.sh).

**Files API** ([`scripts/ipad1vnc_fileserver.py`](scripts/ipad1vnc_fileserver.py)): `~/Downloads` klasörünü token korumalı bir HTTP API olarak sunar (varsayılan port 8085, başlık `X-iPad1VNC-Token`). systemd birimi: [`scripts/ipad1vnc-fileserver.service`](scripts/ipad1vnc-fileserver.service).

> Token düz HTTP üzerinde kimlik doğrulamadır, şifreleme değildir. İnternete açık sunucularda 5901 ve 8085 portlarını kapatıp **SSH tüneli** kullanın.

## Geliştirici dokümanları

- [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) — tek doğruluk kaynağı: kısıtlar, kaynak dosya sorumlulukları, cihaz test listesi, sıradaki adım
- `CLAUDE.md`, `architect.md`, `task.md`, `backlog.md`, `session.md`
