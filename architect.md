# architect.md — iPad1VNC Mimarisi

> Ayrıntılı ve güncel sürüm: `PROJECT_CONTEXT.md` (§3, §8, §12) ve `beta4-ui-security-polish` dalındaki `ARCHITECTURE.md`.

```
iPad 1 (iOS 5.1.1)                                   Linux sunucu (Ubuntu 24.04, XFCE)
┌──────────────────────────────────────────┐         ┌────────────────────────────────────┐
│ AppDelegate (UI + orkestrasyon)           │         │ TigerVNC :1 (5901)                 │
│  ├─ VNCClient ──RFB/TCP (ops. SSH tünel)──┼────────►│   ~/.vnc/xstartup → startxfce4     │
│  ├─ VNCView (framebuffer, dokunmatik)     │         │                                    │
│  ├─ TerminalSession ──PTY /usr/bin/ssh────┼────────►│ sshd (terminal + port yönlendirme) │
│  ├─ Remote Files ──HTTP + X-iPad1VNC-Token┼────────►│ ipad1vnc_fileserver.py (8085)      │
│  ├─ LegacyTerminalBuffer (VT100, sınırlı) │         │   kök: ~/Downloads, token dosyası  │
│  └─ KeychainStore                         │         └────────────────────────────────────┘
└──────────────────────────────────────────┘
```

## Kaynak Dosyalar

| Dosya | Sorumluluk |
|---|---|
| `src/AppDelegate.m/.h` (~1.150 satır) | Ana UI, VNC bağlantı yaşam döngüsü, profiller, SSH terminal paneli, Remote Files paneli (`buildFilesPanel`), araçlar/tanılama, WOL, dinamik çözünürlük, LAN tarama, transfer kuyruğu, Keychain geçişi |
| `src/VNCClient.m/.h` | RFB protokolü, kimlik doğrulama, RAW/Hextile/Tight (zlib) çözme, pano, işaretçi/tuş olayları, istatistik, deneysel VeNCrypt (tip 19, X509Vnc 261; SecureTransport sembolleri `dlsym` ile) |
| `src/VNCView.m/.h` | Framebuffer çizimi; Direct / Trackpad girişi, pinch zoom, iki parmak kaydırma, sağ/orta tık, hassas işaretçi, drag lock |
| `src/TerminalSession.m/.h` | Yerel PTY + `/usr/bin/ssh`, port yönlendirme, açık SSH kullanıcı adı, anahtar / known_hosts / ssh-keygen |
| `src/LegacyTerminalBuffer.m/.h` | Hafif, sınırlı VT100 benzeri tampon |
| `src/KeychainStore.m/.h` | VNC şifresi ve Files token saklama |
| `scripts/ipad1vnc_fileserver.py` + `.service` | Token korumalı Files API (list, stat, download + HTTP Range, mkdir, rename, delete, upload, upload-chunk) |
| `scripts/server-ubuntu24.sh`, `xstartup`, `serve-downloads.sh` | Sunucu kurulum yardımcıları |
| `Makefile`, `control`, `Resources/Info.plist` | Theos paketleme |

## Mimari Kararlar

- **Tek AppDelegate orkestratörü**: eski cihazda ek katman/abstraction maliyetinden kaçınmak için.
- **SSH için sistem `ssh` ikilisi + PTY**: iOS 5'te SSH kütüphanesi taşımak yerine jailbreak ortamındaki OpenSSH.
- **Özel Files API** (Python simple HTTP yerine): kimlik doğrulama, Range ile devam eden indirme, parçalı yükleme.
- **TLS deneysel, SSH tünel varsayılan güvenli yol**: iOS 5.1.1'de SecureTransport davranışı belirsiz.
