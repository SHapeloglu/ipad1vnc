# iPad1VNC Project Context

This is the authoritative handoff document for continuing development.

## 1. Repository and active line

Repository: `SHapeloglu/ipad1vnc`

Stable `main`: **v2.2.0-beta3**

Active development branch:

```text
beta4-ui-security-polish
```

Do not restart or redesign the project. Inspect current source and preserve known-good behavior.

## 2. Non-negotiable platform constraints

```text
iPad 1
iOS 5.1.1
jailbroken
armv7
~256 MB RAM
Objective-C / UIKit
non-ARC / MRC
Theos legacy
legacy iPhoneOS 6.1 SDK
deployment target 5.1
```

Required Makefile direction:

```make
ARCHS = armv7
TARGET = iphone:clang:6.1:5.1
```

Rules:
- no modern-only iOS APIs without explicit compatibility handling;
- avoid large dependencies and memory-heavy abstractions;
- use bounded buffers/scrollback;
- use autorelease pools in long network/worker loops;
- preserve RAW/Hextile/Tight fallback;
- never call a feature working until it is tested on the physical iPad 1.

## 3. Mandatory suite responsibility rule

Before every iPad1VNC feature, determine ownership first.

```text
iPad1VNC             -> VNC/RFB, VNC input/clipboard, profiles, diagnostics,
                        VNC discovery/WOL, Direct/TLS/SSH-tunnel transport
iPad1Terminal        -> local terminal + interactive SSH shell
iPad1Files           -> local filesystem management + file/folder picker + ZIP
iPad1FTPDownloader   -> network transfer engine + queue + pause/resume/retry
iPad1PDFReader       -> PDF and supported text-reader formats
```

If another suite application owns a capability, iPad1VNC should hand off to that application rather than duplicate the subsystem.

This rule supersedes older roadmap text that treated iPad1VNC as an all-in-one Linux administration console.

See:
- `ARCHITECTURE.md`
- `INTEGRATION.md`
- `RESPONSIBILITY_AUDIT.md`

## 4. Current source ownership

### `src/VNCClient.m/.h`
Owns:
- RFB 3.8;
- VNC authentication;
- RAW/Hextile/Tight;
- framebuffer transport;
- clipboard;
- pointer/key events;
- connection statistics;
- experimental VeNCrypt/TLS.

### `src/VNCView.m/.h`
Owns:
- framebuffer presentation;
- Direct/Trackpad input;
- pinch zoom/two-finger scroll;
- right/middle click;
- precision pointer;
- Drag Lock;
- VNC keyboard events.

### `src/AppDelegate.m/.h`
Long-term ownership:
- VNC lifecycle/orchestration;
- VNC profiles;
- transport selection;
- status/diagnostics;
- WOL/VNC LAN discovery;
- lightweight Remote Files orchestration;
- suite-app hand-offs.

Current AppDelegate still contains transitional embedded Terminal and transfer-manager logic. Do not expand those subsystems.

### `src/TerminalSession.m/.h`
Permanent iPad1VNC responsibility:
- SSH port forwarding/tunnel required to carry VNC.

Transitional responsibility:
- embedded interactive SSH terminal fallback until iPad1Terminal SSH is actually implemented and physically validated.

### `src/LegacyTerminalBuffer.m/.h`
Transitional shell/terminal support only. Do not grow it into a larger terminal product inside iPad1VNC.

### `src/KeychainStore.m/.h`
VNC secrets and currently required iPad1VNC secrets. Never expose secrets through public repo or URL-scheme query strings.

## 5. Known-good physical-device behavior

Previously validated on physical iPad 1:
- TigerVNC/XFCE connection;
- RAW;
- Hextile;
- Tight;
- Direct touch;
- Trackpad;
- pinch zoom;
- two-finger scroll;
- clipboard;
- Remote Files API path in earlier form.

Important: Tight rendered successfully on the real device. Preserve it.

## 6. beta3 disconnect behavior that must not regress

The beta2 bug was that manual Disconnect did not cleanly return to Connect.

Source fix in beta3:
- Connect/Disconnect toggle;
- manual disconnect disables auto-reconnect;
- reconnect timer invalidated;
- clipboard polling stops;
- VNC client disconnects/releases;
- active SSH VNC tunnel stops;
- controls reopen;
- button returns to Connect;
- unexpected disconnect may still auto-reconnect.

Do not break this path.

## 7. beta4 progress already achieved

### Remote Files layout

The overlapping top toolbar was redesigned into two rows.

Physical iPad validation completed in both:
- landscape;
- portrait.

Result: no overlapping Remote Files buttons. Treat this item as completed unless a regression appears.

### TLS diagnostics

Legacy SecureTransport/VeNCrypt diagnostics were added and compile successfully with the legacy toolchain.

Detailed handshake errors now distinguish RFB/VeNCrypt/TLS stages.

### TLSVnc support work

TigerVNC development server runs with:

```text
SecurityTypes VncAuth,TLSVnc
```

iPad1VNC work added support direction for:
- X509Vnc subtype 261;
- TLSVnc subtype 258;
- no silent TLS-to-Plain fallback when TLS is requested;
- security-mode status text.

However, physical server logs showed test connections still requesting:

```text
VncAuth(2)
```

rather than VeNCrypt(19).

A TLS request-state diagnostic patch was prepared to make the UI show whether the connection was started as TLS-requested or Plain-requested.

TLS is **not yet considered working**.

## 8. Current TigerVNC test context

Development server:

```text
Ubuntu 24.04
XFCE
user: desktop
TigerVNC display :1
port 5901
```

Typical launch:

```bash
sudo -u desktop -H vncserver :1 -geometry 1024x768 -depth 24 -localhost no
```

Observed security configuration:

```text
VncAuth,TLSVnc
```

Do not commit real public IPs, passwords, API tokens or private keys.

## 9. Responsibility audit of existing iPad1VNC features

### Keep in iPad1VNC
- RFB/VNC;
- RAW/Hextile/Tight;
- Direct/Trackpad/Precision/Drag Lock;
- clipboard;
- TLSVnc/X509Vnc;
- SSH tunnel for VNC;
- WOL;
- VNC-oriented LAN discovery;
- VNC profiles;
- diagnostics/adaptive quality;
- VNC Quick Keys;
- lightweight remote-path browsing/orchestration.

### Transitional: migrate later

#### To iPad1Terminal
- embedded interactive SSH terminal;
- shell-oriented terminal UI/buffer;
- terminal-specific key UX;
- shell-specific SSH connection/profile behavior.

Current blocker: iPad1Terminal's authoritative `SESSION.md` says SSH is not yet implemented. Therefore do **not** remove the iPad1VNC terminal fallback yet, but do not expand it.

#### To iPad1FTPDownloader
- download/upload transfer engine;
- durable transfer queue;
- pause/resume/cancel/retry product behavior;
- large-transfer resume state/progress ownership.

Current blocker: iPad1VNC uses a custom authenticated HTTP Files API, while iPad1FTPDownloader is currently FTP-focused. Review provider architecture before adding a generic HTTP/Files-API job; never pass the Files API token in a URL scheme.

#### To iPad1Files
- local destination/folder picker;
- local upload-file picker;
- local copy/move/delete/archive;
- local filesystem organization.

#### To iPad1PDFReader
- PDF/TXT/MD/CSV/etc rendering or preview.

## 10. Remote Files long-term boundary

Allowed lightweight iPad1VNC scope:

```text
browse remote directory
select remote item
copy remote path
small remote mkdir/rename/delete where required by current Files API
Download -> transfer provider when ready
Open Terminal Here -> iPad1Terminal when ready
Open local result -> iPad1Files / iPad1PDFReader
```

Do not grow Remote Files into:
- a general local file manager;
- a durable download manager;
- ZIP/archive manager;
- document viewer;
- recursive sync product.

The older beta4 roadmap item "improve transfer queue UI and Pause/Resume semantics" is superseded by this responsibility decision. Do not spend product-development effort on expanding that subsystem inside iPad1VNC.

## 11. Suite integration safety

Preferred iOS 5-compatible mechanism:

```objc
canOpenURL:
openURL:
```

Principles:
- percent-encode external data;
- validate host/path/port in receiving app;
- never pass passwords, tokens or private keys in URLs;
- never support arbitrary `?command=...` execution;
- missing sibling app must not break normal VNC operation;
- preserve fallback until provider path is physically validated.

## 12. Build/install

Typical checkout:

```text
~/projects/ipad1vnc/iPad1VNC-v2.2.0-beta3
```

Build:

```bash
make clean
make package FINALPACKAGE=1
```

Legacy deployment warning for iOS 5.1 is expected.

Typical artifact still currently uses beta3 package naming:

```text
packages/com.olap.ipad1vnc_2.2.0-beta3_iphoneos-arm.deb
```

Install over old iPad SSH server using per-command RSA compatibility only.

## 13. Updated beta4 priority order

```text
P0  Finish TLS request-state test and determine why TLS toggle still produced VncAuth(2).
P1  Make Direct / TLSVnc / X509Vnc / SSH-Tunnel status explicit.
P2  Preserve beta3 disconnect behavior and re-test after TLS changes.
P3  Improve VNC-specific Quick Keys/input only; no shell-command macros.
P4  Improve transport-aware VNC profiles.
P5  Polish VNC connection health/adaptive quality.
P6  Prepare suite provider integrations only when provider capability exists.
P7  Simplify Remote Files after provider hand-offs are physically proven.
P8  Remove duplicated terminal/transfer code only after successful migration.
```

Do **not** make iPad1VNC transfer-queue polish or terminal-feature expansion a beta4 product priority.

## 14. Immediate next action

Continue on:

```text
beta4-ui-security-polish
```

First, finish the already-prepared TLS request-state diagnostic on the physical iPad:

Expected visible states after the latest diagnostic patch:

```text
TLS requested — reconnect required
Connecting — TLS requested
```

Then inspect TigerVNC log immediately after one TLS-requested connection.

Expected correct RFB security request if the switch state reaches VNCClient:

```text
Client requests security type VeNCrypt(19)
```

If the server still sees `VncAuth(2)`, inspect the iPad1VNC connection creation/state path before touching TLS handshake/cipher code.

Do not start cross-app Terminal removal yet: iPad1Terminal currently has no SSH implementation.

## 15. Physical-device migration rule

Architecture cleanup order:

```text
provider capability
-> safe integration contract
-> iPad1VNC hand-off
-> physical iPad validation
-> repeated validation
-> remove duplicate fallback
```

Never reverse this sequence merely to reduce code size.

## 16. New-chat bootstrap

```text
Continue the iPad1VNC project from https://github.com/SHapeloglu/ipad1vnc
Read PROJECT_CONTEXT.md, ARCHITECTURE.md, INTEGRATION.md and RESPONSIBILITY_AUDIT.md first.
Inspect current source before changing anything.
Preserve iPad 1 / iOS 5.1.1 / armv7 / non-ARC / ~256 MB RAM constraints.
Apply the suite responsibility filter before every feature: do not duplicate iPad1Terminal, iPad1Files, iPad1FTPDownloader or iPad1PDFReader responsibilities inside iPad1VNC.
Continue from Immediate next action and keep PROJECT_CONTEXT.md authoritative.
```
