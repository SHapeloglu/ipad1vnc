# task.md — iPad1VNC Görevleri

> Güncel görev listesi `beta4-ui-security-polish` dalındaki `PROJECT_CONTEXT.md`'dedir; bu dosya `main` dalının özetidir.

## 🔜 Sıradaki (beta4 kapsamı, öncelik sırasıyla)

- [ ] Remote Files toolbar çakışması (`buildFilesPanel`) — beta4 dalında düzeltme yapıldı, **fiziksel iPad'de yatay/dikey doğrulama bekliyor**
- [ ] TLS/VeNCrypt tanılama: sunucu loglarında `VeNCrypt(19)` isteği görülüyor mu? (`VncAuth(2)` görülüyorsa önce bağlantı durumu yolu incelenecek)
- [ ] Direct / SSH Tunnel / TLS bağlantı modu göstergesi
- [ ] Transfer kuyruğu UI ve Pause/Resume anlamı
- [ ] Profil hızlı işlemleri, LAN tarama UX (ana thread dışında kalmalı)
- [ ] beta3 Disconnect → Connect düzeltmesinin korunduğunu doğrula
- [ ] beta4 derle, kur, `PROJECT_CONTEXT.md` §13 fiziksel cihaz kontrol listesini çalıştır
- [ ] beta4 doğrulanınca `main`'e birleştir; bu beş dosya ile beta4'teki `ARCHITECTURE.md` / `PROJECT_CONTEXT.md` arasında tek kaynak kararı ver

## 🚧 Devam Eden

- [ ] `beta4-ui-security-polish` (son commit 2026-08-29)

## ✅ Tamamlanan

- [x] 2026-10-05 — Çalışma dosyaları kod ve PROJECT_CONTEXT okunarak yeniden yazıldı
- [x] 2026-08-22 — Devir dokümanları `PROJECT_CONTEXT.md`'de birleştirildi
- [x] 2026-08-17 — v2.2.0-beta3 kaynak kodu (Disconnect/Connect düzeltmesi dahil)
