# backlog.md — iPad1VNC Fikir Havuzu

Bu geliştirme hattında **yapılmayacaklar** (PROJECT_CONTEXT §7): RDP, ses, çoklu monitör, bulut hesap/relay, ağır terminal framework'leri.

Olası sonraki işler:
- Public 5901 ve 8085 portlarını SSH tüneli doğrulandıktan sonra firewall ile kapatma rehberi.
- Files API için HTTPS (self-signed + pinning) — iOS 5 TLS davranışı netleşince.
- Kardeş uygulamalarla (iPad1Terminal, iPad1Files, iPad1FTPDownloader…) sorumluluk ayrımı — beta4 dalındaki `RESPONSIBILITY_AUDIT.md` / `SIBLING_APP_GUIDANCE.md`; Terminal'i ayırma işi iPad1Terminal SSH desteği gelene kadar bekliyor.
- Harici uygulamalardan `vnc://` benzeri URL ile bağlantı açma (beta4'te başladı: `EXTERNAL_VNC_URL_TESTING.md`).
- 15/30/60 dakikalık kararlılık oturumları için otomatik log toplama.

## Ekleme Şablonu

```markdown
### Başlık
- **Kategori:** yeni özellik / iyileştirme / teknik borç / araştırma
- **Neden:** kısa gerekçe
- **Notlar:** iOS 5.1.1 uyumluluğu, bellek etkisi, test planı
```
