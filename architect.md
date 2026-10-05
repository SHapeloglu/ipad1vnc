# architect.md — ipad1vnc Mimari Referansı

Bu dosya projenin yapısının hızlı-referans özetidir. Kod değiştikçe güncel tutun.

## Genel Bakış

_README'de açıklama bulunamadı. Projenin amacını buraya bir-iki cümleyle yazın._

## Teknoloji Yığını

- Objective-C / UIKit (iOS, Theos ile derleniyor)
- Bash betikleri

## Dizin Yapısı

```
.gitignore
Makefile
PROJECT_CONTEXT.md
Resources/
  Info.plist
control
scripts/
  ipad1vnc-fileserver.service
  ipad1vnc_fileserver.py
  serve-downloads.sh
  server-ubuntu24.sh
  xstartup
src/
  AppDelegate.h
  AppDelegate.m
  KeychainStore.h
  KeychainStore.m
  LegacyTerminalBuffer.h
  LegacyTerminalBuffer.m
  TerminalSession.h
  TerminalSession.m
  VNCClient.h
  VNCClient.m
  VNCView.h
  VNCView.m
  main.m
```

## Modüller / Kaynak Dosyalar

- `scripts/ipad1vnc_fileserver.py`
- `scripts/serve-downloads.sh`
- `scripts/server-ubuntu24.sh`
- `src/AppDelegate.m` — import "AppDelegate.h"
- `src/KeychainStore.m` — import "KeychainStore.h"
- `src/LegacyTerminalBuffer.m` — import "LegacyTerminalBuffer.h"
- `src/TerminalSession.m` — import "TerminalSession.h"
- `src/VNCClient.m` — import "VNCClient.h"
- `src/VNCView.m` — import "VNCView.h"
- `src/main.m` — import <UIKit/UIKit.h>

## Giriş Noktaları ve Yapılandırma

- `Makefile`
- `Resources/Info.plist`
- `scripts/ipad1vnc-fileserver.service`
- `src/AppDelegate.m`
- `src/main.m`

## Dağıtım / Çalışma Ortamı

- GitHub: https://github.com/SHapeloglu/ipad1vnc

## Diğer Dokümanlar

- `PROJECT_CONTEXT.md`

## Mimari Kararlar

_Önemli tasarım kararlarını ve gerekçelerini buraya ekleyin (ör. "X yerine Y seçildi çünkü ...")._
