# CLAUDE.md — iPad1VNC

Jailbreak'li **1. nesil iPad (iOS 5.1.1, armv7, ~256 MB RAM)** için hafif Linux yönetim konsolu: VNC masaüstü (RAW / Hextile / Tight, deneysel VeNCrypt X509Vnc TLS), SSH terminal ve tünel, uzaktan dosya yönetimi (kendi Files API sunucusuyla), profiller, tanılama, LAN tarama, Wake-on-LAN. Objective-C, UIKit, **non-ARC**, Theos.

- GitHub: https://github.com/SHapeloglu/ipad1vnc — **PUBLIC repo**
- **Tek doğruluk kaynağı: `PROJECT_CONTEXT.md`.** Bu dosya ve `architect.md` / `task.md` / `backlog.md` / `session.md` onun özetidir; çelişki olursa önce kaynağa bak, sonra `PROJECT_CONTEXT.md`'yi güncelle.

## ⚠️ Branch durumu

- `main` = kararlı **v2.2.0-beta3** (+ bu çalışma dosyaları).
- **Aktif geliştirme `beta4-ui-security-polish` dalında** (2026-08-29'a kadar 10+ commit önde): Remote Files toolbar düzeltmesi, TLS tanılama yamaları (`scripts/apply_beta4_*.py`), harici VNC URL çağrısı, `ARCHITECTURE.md`, `INTEGRATION.md`, `RESPONSIBILITY_AUDIT.md`, rakip incelemesi. O dalda bu beş dosya yok ve daha güncel bir `PROJECT_CONTEXT.md` var.
- Kod işine başlamadan önce `git checkout beta4-ui-security-polish` ve oradaki `PROJECT_CONTEXT.md` "Hemen yapılacak sonraki adım" bölümünü oku.

## Derleme ve Kurulum (WSL + Theos)

```bash
make clean && make package FINALPACKAGE=1     # → packages/com.olap.ipad1vnc_<VER>_iphoneos-arm.deb
scp -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa packages/*.deb root@<ipad-lan-ip>:/var/mobile/
ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@<ipad-lan-ip>
dpkg -i /var/mobile/com.olap.ipad1vnc_<VER>_iphoneos-arm.deb && killall SpringBoard
```

- `Makefile`: `ARCHS = armv7`, `TARGET = iphone:clang:6.1:5.1`, `-fno-objc-arc`. Bunlar değiştirilmez.
- Theos ve iOS 6.1 SDK yolları `PROJECT_CONTEXT.md` §9'da. "iOS 5.1 deprecated" uyarısı normal.
- Sürüm `control` dosyasında (`Version:`).

## Değiştirilemez Kurallar

- iOS 5.1.1'de olmayan API kullanma (Auto Layout, modern SecureTransport API'leri vb.) — gerekirse `respondsToSelector` / `dlsym` ile koru.
- Manuel retain/release doğru olmalı; uzun döngülerde `@autoreleasepool`; büyük dosyaları belleğe tümden alma; terminal scrollback sınırlı.
- RAW / Hextile / Tight geri dönüş yolunu ve **gerçek cihazda doğrulanmış Tight yolunu** bozma; TLS kapalıyken normal VNC her zaman çalışmalı; SSH Tunnel bilinen güvenli yol olarak kalmalı.
- VNC şifresi ve Files token yalnızca Keychain'de (`KeychainStore`), `NSUserDefaults`'ta değil.
- **Public repo:** gerçek sunucu IP'si, şifre, token, özel anahtar commit etme.
- Fiziksel iPad testinden geçmeyen özelliği "hazır" diye işaretleme.
- Oturum sonunda `session.md`'ye kayıt düş, `task.md`'yi güncelle (aktif dalda çalışıyorsan `PROJECT_CONTEXT.md`'yi).
