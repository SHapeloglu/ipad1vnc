# iPad1VNC Integration Contract

## Purpose

This document defines how iPad1VNC participates in the iPad1 application suite without absorbing the responsibilities of iPad1Files, iPad1Terminal, iPad1PDFReader or iPad1FTPDownloader.

All integrations must remain compatible with:

```text
iPad 1 / iOS 5.1.1 / armv7 / ~256 MB RAM / Objective-C / UIKit / non-ARC MRC / Theos
```

## iPad1VNC responsibility

```text
iPad1VNC
= RFB/VNC remote desktop + input + clipboard + VNC connection profiles
  + transport required by VNC (Direct / SSH Tunnel / TLS)
  + lightweight remote-side orchestration
```

It is not intended to become:

- a general local file manager
- a general FTP/HTTP download manager
- a PDF/text reader
- a general-purpose SSH terminal application
- a ZIP/archive manager

## Cross-application responsibility map

| Capability | Owner |
|---|---|
| VNC/RFB desktop | iPad1VNC |
| Direct/TLS/SSH tunnel used to carry VNC | iPad1VNC |
| Interactive SSH shell / terminal | iPad1Terminal |
| Local file management / ZIP | iPad1Files |
| FTP/HTTP downloads, queue, pause/resume | iPad1FTPDownloader |
| PDF/TXT/MD/CSV/etc viewing | iPad1PDFReader |

## Shared file root

Canonical local file root:

```text
/var/mobile/Media/iPad1Files/
```

Expected shared folders include:

```text
Downloads/
Documents/
PDFs/
Images/
Music/
Videos/
Archives/
Shared/
Temp/
AppData/
```

Applications should operate on the same physical file where practical instead of copying large files between application sandboxes.

## URL scheme contract

The suite should use small, explicit URL contracts supported by iOS 5 `openURL:` / `canOpenURL:`.

### Terminal

```text
ipad1terminal://ssh?host=<host>&port=<port>&user=<user>
ipad1terminal://local?cwd=<percent-encoded-path>
```

Security rule: never pass arbitrary shell commands through the URL. Host/user/port/path are data, not executable command text.

### Files

```text
ipad1files://open?path=<percent-encoded-absolute-path>
```

The target application must validate that paths are inside allowed roots before performing destructive operations.

### Reader

Existing preferred PDF contract:

```text
ipad1pdf://open?path=<percent-encoded-absolute-path>
```

A future generic reader route may be added only if iPad1PDFReader owns and validates it.

### Downloader

Proposed suite contract:

```text
ipad1downloader://download?url=<percent-encoded-url>
```

Credentials, passwords, API tokens and private keys must not be embedded in cross-app URLs.

## iPad1VNC Remote Files policy

Remote Files may remain as a lightweight remote browser/orchestrator because the VNC application already knows the current remote host and remote path.

Long-term responsibility:

```text
Remote Files in iPad1VNC
- browse remote path
- select remote item
- mkdir/rename/delete only when required by the VNC-side Files API
- copy remote path
- hand a transfer request to the downloader when the downloader contract supports it
- hand a downloaded local file to Files or Reader
```

Do not grow Remote Files into a second local file manager or a full download manager.

Existing transfer code must not be deleted until the replacement cross-app flow is physically validated on iPad 1.

## SSH policy

SSH port forwarding required to secure a VNC connection remains inside iPad1VNC.

Interactive shell UX belongs to iPad1Terminal. Once iPad1Terminal's external SSH profile/host contract is physically validated, iPad1VNC should prefer an `Open Terminal` action that launches iPad1Terminal rather than expanding its own terminal panel.

The current embedded terminal path is a compatibility fallback until the external integration is proven.

## Reader policy

iPad1VNC must not render PDF, TXT, Markdown, CSV or other local document formats. After a remote file is downloaded, use the Reader contract when the file type is supported.

## Files policy

iPad1VNC must not implement local move/copy/delete/archive workflows. Use iPad1Files for local file management.

## Downloader policy

Transfer queue, durable pause/resume, retry, background-ish persistence and protocol-specific download behavior belong to iPad1FTPDownloader/Downloader.

The current iPad1VNC transfer implementation is transitional and should be reduced only after the downloader accepts the required external transfer request and the physical iPad flow has been validated.

## Graceful fallback

Before opening another application:

```objc
UIApplication *app=[UIApplication sharedApplication];
if([app canOpenURL:url]){
    [app openURL:url];
}else{
    // show a lightweight alert; do not crash or silently fail
}
```

A missing suite application must never prevent normal VNC operation.

## Security rules

- Never put VNC passwords, SSH passwords, Files API tokens or private keys in URL query strings.
- Percent-encode externally supplied host/path/URL values.
- Receiving applications must validate every parameter.
- No arbitrary command execution URL.
- No silent fallback from requested secure VNC transport to Plain VNC.
- Public repository files must not contain real server IPs, credentials or tokens.

## Migration plan

Phase 1 — boundary freeze:
- document ownership
- stop adding Files/Reader/Downloader/Terminal-specific features to iPad1VNC
- preserve all currently working code

Phase 2 — provider contracts:
- iPad1Terminal accepts safe host/user/port launch requests
- iPad1Files accepts safe local path open requests
- iPad1PDFReader keeps/validates `ipad1pdf://open?path=...`
- iPad1FTPDownloader accepts safe external download requests

Phase 3 — VNC delegation:
- add `Open Terminal`
- add `Open in Files`
- add `Open in Reader`
- delegate supported downloads to Downloader
- retain fallback only where the external app is absent or integration is not yet validated

Phase 4 — slimming:
- after physical-device validation, remove duplicated UI/logic from iPad1VNC where another suite application is the established owner
- do not remove VNC transport code, including SSH tunneling and TLS

## Acceptance rule

A cross-app migration is not complete until it is tested on the physical iPad 1. Compilation alone is not sufficient.
