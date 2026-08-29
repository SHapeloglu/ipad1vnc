# iPad1VNC Integration Contract

## Purpose

This document defines how iPad1VNC participates in the iPad1 application suite without absorbing the responsibilities of iPad1Files, iPad1Terminal, iPad1PDFReader or iPad1FTPDownloader.

All integrations must remain compatible with:

```text
iPad 1 / iOS 5.1.1 / armv7 / ~256 MB RAM / Objective-C / UIKit / non-ARC MRC / Theos
```

## Responsibility gate

Every new feature request must be checked before implementation:

```text
Is it VNC/RFB or VNC transport?
    -> iPad1VNC may own it.

Is it terminal/interactive SSH?
    -> iPad1Terminal owns it.

Is it local filesystem or ZIP?
    -> iPad1Files owns it.

Is it network transfer queue/pause/resume/retry?
    -> iPad1FTPDownloader owns it.

Is it document rendering/reading?
    -> iPad1PDFReader owns it.
```

When another application owns the feature, iPad1VNC should orchestrate or hand off rather than duplicate the subsystem.

## iPad1VNC responsibility

```text
iPad1VNC
= RFB/VNC remote desktop + input + clipboard + VNC profiles
  + transport required by VNC (Direct / SSH Tunnel / TLS)
  + lightweight remote-side orchestration
```

## Cross-application responsibility map

| Capability | Owner |
|---|---|
| VNC/RFB desktop | iPad1VNC |
| Direct/TLS/SSH tunnel used to carry VNC | iPad1VNC |
| Interactive SSH shell / terminal | iPad1Terminal |
| Local file management / ZIP | iPad1Files |
| Folder/file picker | iPad1Files |
| Network transfer queue / pause / resume / retry | iPad1FTPDownloader |
| PDF/TXT/MD/CSV/etc viewing | iPad1PDFReader |

## Current migration audit

The current iPad1VNC source still contains legacy/transitional implementations that cross these boundaries.

### Transitional Terminal code

Current embedded SSH terminal functionality remains only because the provider is not ready yet.

iPad1Terminal's current authoritative state says:
- Local Terminal/PTTY exists;
- SSH is not implemented yet;
- SSH must not be started until the terminal input/screen model is sufficiently stable.

Therefore:
- do not remove the embedded iPad1VNC terminal yet;
- do not add new shell/terminal-specific features to it;
- once iPad1Terminal has safe SSH launch support and it is tested on the physical iPad, iPad1VNC should delegate interactive shell usage to it.

SSH port forwarding for VNC remains permanently inside iPad1VNC.

### Transitional transfer code

The current iPad1VNC transfer engine, queue, pause/resume and upload/download state are transitional.

Do not improve them as a long-term VNC subsystem except for bug fixes needed to preserve existing behavior while migration is incomplete.

Long-term transfer ownership belongs to iPad1FTPDownloader/Downloader.

## Shared file root

Canonical local file root:

```text
/var/mobile/Media/iPad1Files/
```

Applications should operate on the same physical file where practical instead of copying large files between application sandboxes.

## URL scheme contract

Use small, explicit URL contracts supported by iOS 5 `openURL:` / `canOpenURL:`.

### Terminal

Target contract once SSH exists in iPad1Terminal:

```text
ipad1terminal://ssh?host=<host>&port=<port>&user=<user>
ipad1terminal://local?cwd=<percent-encoded-path>
```

Security rules:
- never pass arbitrary shell commands;
- never pass passwords/private keys;
- host/user/port/path are data only;
- receiving app validates all parameters.

### Files

```text
ipad1files://open?path=<percent-encoded-absolute-path>
ipad1files://show?path=<percent-encoded-absolute-path>
ipad1files://pickFolder?root=<root>&callback=<callback>
ipad1files://pickFile?root=<root>&callback=<callback>
```

Use the exact subset actually implemented by iPad1Files; do not assume an unimplemented route is available.

### Reader

```text
ipad1pdf://open?path=<percent-encoded-absolute-path>
```

Reader validates the path and supported type.

### Downloader

Desired suite-level direction:

```text
ipad1downloader://download?url=<percent-encoded-url>
```

However, iPad1VNC's current Remote Files transport is an authenticated custom HTTP Files API, not FTP. Before adding this hand-off, inspect iPad1FTPDownloader's architecture and decide whether accepting generic HTTP/Files-API jobs still fits its role as the suite network-transfer specialist. Do not force a protocol into that app without this review.

Credentials/API tokens must never appear in the URL.

If a secure hand-off needs authentication, use a provider-owned saved profile/reference rather than transmitting secrets in the URL.

## iPad1VNC Remote Files policy

Remote Files may remain as a lightweight remote browser/orchestrator because iPad1VNC already knows the active remote host/session.

Allowed long-term scope:

```text
browse remote directory
select remote item
copy remote path
small remote mkdir/rename/delete actions when needed by the current Files API
Open Terminal Here -> provider when available
Download -> transfer provider when available
Open local result -> Files/Reader
```

Do not grow it into:
- a local filesystem manager;
- a durable transfer manager;
- a ZIP manager;
- a document preview system;
- a recursive remote sync product.

## VNC Quick Keys vs Terminal keys

VNC keyboard helpers may remain in iPad1VNC when they emit RFB keyboard events, for example:

```text
Esc / Tab / Ctrl / Alt / arrows / F1-F12 / Alt-Tab / Ctrl-Alt-Del
```

Shell-command macros do not belong in iPad1VNC. If a task requires command execution, open iPad1Terminal.

## Graceful fallback

Before opening another application:

```objc
UIApplication *app=[UIApplication sharedApplication];
if([app canOpenURL:url]){
    [app openURL:url];
}else{
    // lightweight alert or validated legacy fallback
}
```

A missing suite application must never prevent normal VNC operation.

Fallbacks are transitional, not permission to keep expanding duplicate subsystems.

## Security rules

- Never put VNC passwords, SSH passwords, Files API tokens or private keys in URL query strings.
- Percent-encode externally supplied host/path/URL values.
- Receiving applications validate every parameter and allowed path.
- No arbitrary command-execution URL.
- No silent fallback from requested secure VNC transport to Plain VNC.
- Public repository files must not contain real infrastructure credentials.

## Migration order

```text
Phase 1  Freeze responsibility boundaries.
Phase 2  Make each provider capable of the required operation.
Phase 3  Add safe provider URL/path contract.
Phase 4  Add iPad1VNC hand-off with graceful fallback.
Phase 5  Build/install/test on physical iPad 1.
Phase 6  Prefer provider path after repeated validation.
Phase 7  Remove duplicate legacy code only then.
```

## Current priority implication

Do not spend beta4 effort polishing iPad1VNC transfer queue/pause-resume as a product feature. That roadmap item is superseded by the suite responsibility decision.

Near-term iPad1VNC work should prioritize:
1. TLSVnc request-state/runtime validation;
2. explicit Direct/TLS/SSH transport indicator;
3. provider readiness checks and hand-off design;
4. VNC-specific input/profile/quality improvements;
5. Remote Files simplification after providers are validated.

## Acceptance rule

A cross-app migration is not complete until it is tested on the physical iPad 1. Compilation alone is not sufficient.
