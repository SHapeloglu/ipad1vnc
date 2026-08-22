# iPad1VNC Project Context

This is the single source of truth for continuing development in a new ChatGPT/Claude/coding-agent conversation.

## 1. Repository and current development line

Repository: `SHapeloglu/ipad1vnc`

Stable source currently committed on `main`: **v2.2.0-beta3**.

Active development branch: **`beta4-ui-security-polish`**.

Current product direction: a lightweight Linux administration console for obsolete first-generation iPads, combining VNC desktop access, SSH terminal/tunneling, remote file management, profiles, diagnostics, LAN discovery, WOL and low-memory interaction helpers.

Do not restart the project from scratch. Inspect current source first and preserve working behavior.

## 2. Non-negotiable platform constraints

Target hardware/software:
- iPad 1
- iOS 5.1.1
- jailbroken
- armv7
- about 256 MB RAM
- Objective-C / UIKit
- manual retain/release (non-ARC)
- Theos legacy build
- deployment target iOS 5.1
- legacy iOS 6.1 SDK

Required Makefile target:

```make
ARCHS = armv7
TARGET = iphone:clang:6.1:5.1
```

Rules:
- Do not introduce modern iOS APIs without explicit legacy compatibility handling.
- Avoid large dependencies and memory-heavy abstractions.
- Never load large files completely into RAM.
- Keep terminal scrollback bounded.
- Use autorelease pools in long-running worker/network loops.
- Preserve RAW/Hextile/Tight fallback behavior.
- Do not call a feature production-ready before physical iPad testing.

## 3. Main source ownership

`src/AppDelegate.m` / `.h`
- main UI and orchestration
- VNC connection lifecycle
- profiles
- SSH terminal panel
- Remote Files panel
- Tools / Diagnostics
- WOL
- dynamic resolution
- LAN discovery
- transfer queue
- Keychain migration

`src/VNCClient.m` / `.h`
- RFB/VNC protocol
- TCP connection and authentication
- framebuffer updates
- RAW / Hextile / Tight decoding
- clipboard
- pointer/key events
- diagnostics/statistics
- experimental VeNCrypt X509Vnc TLS

`src/VNCView.m` / `.h`
- framebuffer presentation
- Direct and Trackpad input
- pinch zoom
- two-finger scrolling
- right click
- middle click
- precision pointer
- drag lock

`src/TerminalSession.m` / `.h`
- local PTY and `/usr/bin/ssh`
- interactive SSH
- SSH port forwarding
- explicit SSH username
- key path / known_hosts / ssh-keygen

`src/LegacyTerminalBuffer.m` / `.h`
- lightweight bounded VT100-like terminal buffer

`src/KeychainStore.m` / `.h`
- VNC passwords and Files API tokens must be stored in Keychain, not plaintext NSUserDefaults

## 4. Known-good real-device behavior

Previously validated on the physical iPad:
- VNC connection to TigerVNC / XFCE
- RAW
- Hextile
- Tight encoding
- Direct touch
- Trackpad mode
- pinch zoom
- two-finger scroll
- clipboard
- connection profiles in earlier form
- Files API after replacing Python simple HTTP server with the custom authenticated API

Important result: **Tight successfully connected and rendered correctly on the real iPad.** Preserve this path.

## 5. Latest beta3 disconnect fix

Observed beta2 bug:
- tapping the main `Disconnect` button did not return it to `Connect`
- the app had to be closed/reopened before reconnecting

beta3 source fix:
- main button acts as Connect/Disconnect toggle
- manual disconnect sets `_shouldAutoReconnect = NO`
- pending reconnect timer is invalidated
- clipboard polling stops
- VNC client disconnects/releases
- active SSH VNC tunnel stops
- controls reopen
- button returns to `Connect`
- unexpected network/remote disconnect still keeps auto reconnect behavior

This fix is in source but still requires full physical-device validation.

## 6. Current observed bugs requiring beta4 work

### A. Remote Files toolbar overlap

Observed on real iPad: Remote Files top buttons overlap.

Root cause found in `buildFilesPanel` inside `src/AppDelegate.m`: `Up/New` and `Queue/Pause/Upload/Close` are placed in overlapping fixed horizontal frame ranges.

Required beta4 change:
- redesign the Files toolbar for iPad 1 dimensions
- no overlapping controls in landscape or portrait
- keep UIKit/iOS 5 compatibility
- use compact layout and simple autoresizing/layout calculations rather than modern Auto Layout APIs if risky
- improve Queue / Pause-Resume / Upload / Close clarity

### B. TLS / VeNCrypt error

Real-device TLS attempt currently fails.

Current implementation in `src/VNCClient.m`:
- VeNCrypt security type 19
- target X509Vnc subtype 261
- SecureTransport
- legacy symbols such as `SSLNewContext`, `SSLDisposeContext`, `SSLSetEnableCertVerify` are resolved through `dlsym`

TLS remains **experimental**.

Required beta4 work:
- improve TLS error/status reporting so failure stage is visible
- verify runtime SecureTransport symbol availability on iOS 5.1.1
- distinguish: server does not offer VeNCrypt, no X509Vnc subtype, TLS context failure, certificate/handshake failure, VNC auth failure
- never break normal VNC when TLS is OFF
- never remove SSH Tunnel as the known-good secure transport
- show clear connection mode/status: Direct / SSH Tunnel / TLS when practical

Do not silently claim TLS is fixed until physical-device + correctly configured TigerVNC testing passes.

## 7. beta4 development scope

Active branch: `beta4-ui-security-polish`.

Planned beta4 work, in priority order:
1. Fix Remote Files button overlap.
2. Make Remote Files panel safe in portrait/landscape.
3. Improve TLS/VeNCrypt diagnostics and clean failure behavior.
4. Add clearer Direct / SSH / TLS connection indication.
5. Improve transfer queue UI and Pause/Resume semantics.
6. Polish profile quick actions and auto/default-profile flow without redesigning architecture.
7. Polish LAN discovery result UX and keep scanning off the main thread.
8. Improve status/error strings without increasing memory footprint materially.
9. Preserve beta3 Disconnect -> Connect fix.
10. Build, install and validate on physical iPad.

Do not add RDP, audio, multi-monitor, cloud accounts/relay or heavyweight terminal frameworks in this development line.

## 8. Existing v2.2 features that must be preserved

Implemented/targeted in current source:
- Diagnostics 2.0 with rolling RTT/FPS statistics
- Precision mouse mode
- Drag Lock
- middle click
- Profiles 3.0 quick actions
- LAN scan
- expanded special/hardware keyboard keys
- transfer queue
- resumable downloads using `.part` + HTTP Range
- resumable/chunked uploads
- Files `/api/stat`
- memory-pressure cleanup
- per-network-message autorelease pools
- experimental VeNCrypt X509Vnc TLS

Many of these still need runtime validation. Do not rewrite working subsystems merely for style.

## 9. Build environment

Known WSL environment:

```text
Theos: /home/yeliz/theos
Legacy SDK: /home/yeliz/legacy-ios-sdks/iPhoneOS6.1-extracted/iPhoneOS6.1.sdk
```

Typical local checkout path:

```text
~/projects/ipad1vnc/iPad1VNC-v2.2.0-beta3
```

Build:

```bash
make clean
make package FINALPACKAGE=1
```

Expected beta3 artifact naming:

```text
packages/com.olap.ipad1vnc_2.2.0-beta3_iphoneos-arm.deb
```

A warning that building for iOS 5.1 is deprecated is expected and is not itself a failure.

## 10. Copy/install on iPad

Known LAN test address has been `192.168.1.2`.

Modern OpenSSH requires compatibility with the old iPad SSH server:

```bash
scp \
-o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/com.olap.ipad1vnc_<VERSION>_iphoneos-arm.deb \
root@192.168.1.2:/var/mobile/
```

SSH:

```bash
ssh \
-o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
root@192.168.1.2
```

Do not globally enable obsolete SSH algorithms.

On the iPad:

```bash
dpkg -i /var/mobile/com.olap.ipad1vnc_<VERSION>_iphoneos-arm.deb
killall SpringBoard
```

## 11. Linux/TigerVNC server context

Development server:
- Ubuntu 24.04
- XFCE
- Linux desktop user: `desktop`
- TigerVNC display `:1`
- development VNC port `5901`

Typical VNC command:

```bash
vncserver :1 -geometry 1024x768 -depth 24 -localhost no
```

Typical `~/.vnc/xstartup`:

```sh
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session startxfce4
```

The repository is public. Never commit the real public server IP, passwords, API tokens or private keys.

## 12. Files API server

Matching source:

```text
scripts/ipad1vnc_fileserver.py
```

Typical server installation:

```text
/opt/ipad1vnc/ipad1vnc_fileserver.py
```

Files root:

```text
/home/desktop/Downloads
```

Token file:

```text
/home/desktop/.ipad1vnc-files-token
```

Development port: `8085`

Authentication header:

```text
X-iPad1VNC-Token
```

Endpoints:
- `GET /api/list?path=...`
- `GET /api/stat?path=...`
- `GET /download?path=...&token=...`
- `POST /api/mkdir`
- `POST /api/rename`
- `POST /api/delete`
- `POST /api/upload`
- `POST /api/upload-chunk?path=...&offset=...&total=...`

v2.2 supports/targets HTTP Range downloads for resume.

Security direction:
- Files token over plain HTTP is authentication, not encryption
- SSH Tunnel is the proven secure path
- after secure tunnel validation, restrict/firewall public 5901 and 8085

## 13. Physical-device validation checklist

Highest-priority sequence:
1. Tight ON connects.
2. Main `Disconnect` immediately becomes `Connect`.
3. Reconnect without restarting app.
4. Manual disconnect does not auto-reconnect after 3 seconds.
5. Unexpected network/server loss still auto-reconnects.
6. Remote Files controls do not overlap in landscape.
7. Remote Files controls do not overlap in portrait.
8. Queue / Pause-Resume / Upload / Close work repeatedly.
9. Diagnostics RTT/FPS/kbps/frame values change realistically.
10. Precision mode and Drag Lock work.
11. Profile quick actions work.
12. Terminal requires explicit SSH user and Connect/Stop work repeatedly.
13. Files list/stat/download/upload/rename/delete/mkdir work.
14. Interrupted download resumes from `.part` via HTTP Range.
15. Interrupted upload resumes from remote size/chunks.
16. 100+ MB transfer does not crash the iPad.
17. LAN scan completes without freezing UI.
18. SSH tunnel works and stops on manual disconnect.
19. TLS/X509Vnc is tested last with correctly configured TigerVNC.
20. Run 15/30/60-minute stability sessions and repeated connect/disconnect cycles.

## 14. Coding/development rules

- Preserve the last known-good path while making risky beta changes.
- Keep non-ARC memory ownership correct.
- Keep UIKit compatible with iOS 5.1.1.
- Avoid disabling warnings merely to make code compile; fix the source where practical.
- Do not store VNC passwords or Files tokens in plaintext defaults.
- Do not expose private infrastructure credentials in this public repository.
- Prefer small, reviewable changes and real-device validation after meaningful steps.
- When documentation and source conflict, inspect the source and update this file after establishing actual state.

## 15. Immediate next action

Continue on branch:

```text
beta4-ui-security-polish
```

First code change: fix `buildFilesPanel` in `src/AppDelegate.m` so Remote Files toolbar buttons cannot overlap on iPad 1 in landscape or portrait. Then build/install beta4 and validate layout on the physical device before moving to TLS diagnostics.

## 16. New-chat bootstrap prompt

Use this minimal prompt in a new conversation:

```text
Continue the iPad1VNC project from https://github.com/SHapeloglu/ipad1vnc
Read PROJECT_CONTEXT.md first, then inspect the current source code.
Do not redesign or restart the project.
Preserve iPad 1 / iOS 5.1.1 / armv7 / non-ARC / ~256 MB RAM constraints.
Continue from the Immediate next action in PROJECT_CONTEXT.md and keep that file updated after meaningful progress.
```
