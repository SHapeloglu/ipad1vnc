# CLAUDE.md

Bu dosya, bu proje üzerinde çalışırken Claude'un (Claude Code dahil) izlemesi gereken bağlamı ve kuralları içerir.

## Proje

**ipad1vnc** — _README'de açıklama bulunamadı. Projenin amacını buraya bir-iki cümleyle yazın._

- GitHub: https://github.com/SHapeloglu/ipad1vnc

## Teknoloji Yığını

- Objective-C / UIKit (iOS, Theos ile derleniyor)
- Bash betikleri

## Önemli Dosyalar

- `Makefile`
- `Resources/Info.plist`
- `scripts/ipad1vnc-fileserver.service`
- `src/AppDelegate.m`
- `src/main.m`

Mimari ayrıntılar için bkz. `architect.md`.

## Sık Kullanılan Komutlar

```bash
# Henüz belgelenmiş komut yok — kurulum/çalıştırma adımlarını buraya ekleyin.
```

## Kurallar

- Proje eski iOS sürümlerini (iPad 1 / iOS 5.1.1 dahil) hedefliyor olabilir — yeni API kullanmadan önce deployment target'ı kontrol et.
- Derleme ortamını (Xcode veya Theos `Makefile`) değiştirmeden önce mevcut yapı dosyalarını incele; yeni kaynak dosyalarını derleme listesine (`project.pbxproj` / Makefile `*_FILES`) eklemeyi unutma.
- `.env`, parola, token ve API anahtarlarını asla commit etme.
- Her çalışma oturumunun sonunda `session.md`ye kısa kayıt düş; görev durumunu `task.md`de güncelle.
- Önceliklendirilmemiş fikirleri `backlog.md`ye yaz; somutlaşınca `task.md`ye taşı.

## Çalışma Dosyaları

| Dosya | Amaç |
|---|---|
| `architect.md` | Mimari ve dizin yapısı referansı |
| `task.md` | Aktif / devam eden / tamamlanan görevler |
| `backlog.md` | Önceliklendirilmemiş fikir ve teknik borç havuzu |
| `session.md` | Oturum günlüğü — her oturum sonunda güncellenir |
