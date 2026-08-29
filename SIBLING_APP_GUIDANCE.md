# iPad1 Suite — Competitor-derived sibling app guidance

These recommendations came from reviewing modern remote-access competitors, but they do **not** belong inside iPad1VNC.

## iPad1Terminal

Owner: terminal / interactive SSH.

Recommended competitor-derived capabilities when its own roadmap is ready:

- SSH session profiles;
- safe URL launch contract using host/user/port or profile ID;
- public-key authentication and key selection/management;
- terminal-specific helper keys;
- terminal macros only when they remain safe and explicit;
- bounded scrollback and real ANSI/VT100 cursor/screen behavior before expanding SSH UX.

Do not implement these inside iPad1VNC. iPad1VNC keeps only SSH port forwarding required to carry VNC, plus its transitional fallback until iPad1Terminal SSH is physically validated.

## iPad1Files

Owner: local filesystem management and picker UI.

Recommended suite capabilities:

- `ipad1files://open?path=...` / `show?path=...`;
- safe folder picker callback;
- safe file picker callback;
- Open With / hand-off registry kept lightweight;
- local copy/move/delete/rename/folder operations;
- ZIP/archive management;
- shared canonical root `/var/mobile/Media/iPad1Files/`.

Do not build a second local browser or picker in iPad1VNC.

## iPad1FTPDownloader / transfer provider

Owner: durable network transfer behavior.

Competitor-derived capabilities that belong here:

- FIFO transfer queue;
- pause / resume / cancel / retry;
- progress / speed / ETA;
- durable resume metadata;
- externally requested download jobs through a safe URL scheme;
- destination selection by calling iPad1Files;
- graceful post-download hand-off to iPad1Files or iPad1PDFReader.

Before generalizing beyond FTP, review whether HTTP / iPad1 Files API transfer jobs fit the provider architecture. Do not pass Files API tokens through URL schemes.

Do not continue product-development of durable queue/pause/resume inside iPad1VNC.

## iPad1PDFReader

Owner: document reading.

Recommended suite capabilities:

- keep and validate `ipad1pdf://open?path=...`;
- open supported PDF/text formats from the same physical shared file;
- PDF search/highlight and text-reader functionality stay here;
- fail safely for unsupported or invalid paths.

Do not add PDF/TXT/MD/CSV rendering to iPad1VNC.

## Shared integration rules

All sibling applications must preserve:

```text
iPad 1
iOS 5.1.1
armv7
~256 MB RAM
Objective-C / UIKit
non-ARC / MRC
Theos / legacy SDK
```

Cross-app rules:

- use `canOpenURL:` / `openURL:` compatible with iOS 5;
- pass identifiers, hosts, ports, URLs and validated paths as data;
- never pass passwords, API tokens, private keys or arbitrary command strings;
- use one physical file rather than copying large data between apps;
- receiving app validates every external parameter;
- integration is not complete until physically tested on iPad 1.
