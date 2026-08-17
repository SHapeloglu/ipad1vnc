# CLAUDE.md

This file is the handoff guide for Claude Code / Claude-style coding agents working on iPad1VNC.

## Project identity

iPad1VNC is a lightweight remote Linux thin client for **iPad 1 / iOS 5.1.1**.

Primary value proposition:
> Keep a 2010 iPad useful as a fast Linux management terminal.

Do not optimize for modern iOS. Optimize for:
- armv7
- iOS 5.1.1
- ~256 MB RAM
- jailbreak environment
- Theos legacy SDK builds
- low bandwidth
- low memory
- predictable fallback behavior

## Current development baseline

Latest source line expected after this handoff: **v2.2.0-beta3**.

Known-good historical points:
- v2.1.0-rc2 compiled successfully with the user's Theos environment.
- Tight encoding worked on the physical iPad against TigerVNC.
- v2.2.0-beta2 compiled successfully.
- v2.2.0-beta3 fixes manual VNC disconnect state handling and should be compiled/tested next.

## Build environment

User environment:
- WSL Ubuntu
- Theos: `/home/yeliz/theos`
- legacy iOS SDK: `/home/yeliz/legacy-ios-sdks/iPhoneOS6.1-extracted/iPhoneOS6.1.sdk`
- SDK symlink exists under Theos

Expected Makefile target:
```make
ARCHS = armv7
TARGET = iphone:clang:6.1:5.1
```

Build:
```bash
make clean
make package FINALPACKAGE=1
```

Do not propose Xcode-only workflows.

## Installation flow

Build on WSL, then copy the `.deb` to the iPad.

Typical iPad LAN IP during current testing:
`192.168.1.2`

Modern OpenSSH may reject the old iPad host key. Use a host-specific compatibility invocation when needed:
```bash
scp \
-o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/<package>.deb \
root@192.168.1.2:/var/mobile/
```

If DSS is required, enable it only for this old device, not globally.

Install on iPad:
```bash
dpkg -i /var/mobile/<package>.deb
killall SpringBoard
```

Never tell the user to run `dpkg` in WSL.

## Coding constraints

### Objective-C / iOS 5
- Manual memory management is expected.
- Avoid APIs newer than iOS 5 unless dynamically resolved or guarded.
- Build uses warnings-as-errors in important cases.
- Keep class-extension declarations as prototypes only; never emit method bodies inside `@interface`.
- Older compiler warnings such as misleading indentation can fail the build.

### Memory
- iPad 1 has very limited RAM.
- Do not read large files into a single `NSData`.
- Keep transfer chunks small (64 KB is the current upload choice).
- Keep terminal scrollback bounded.
- Use autorelease pools in long-running worker loops.
- Avoid duplicate framebuffer copies.

### Networking
- Do blocking network work off the main thread.
- Keep VNC RAW/Hextile fallback available even when experimenting with Tight/TLS.
- SSH Tunnel is the known-good secure path.

## Source ownership

### `VNCClient`
Protocol logic only:
- RFB handshake
- authentication
- pixel formats
- encoding negotiation
- RAW/Hextile/Tight
- clipboard
- pointer/key events
- stats
- experimental VeNCrypt TLS

### `VNCView`
Rendering/input only:
- Direct
- Trackpad
- zoom
- gestures
- pointer precision
- mouse buttons

### `TerminalSession`
PTY and `/usr/bin/ssh` process management.

### `LegacyTerminalBuffer`
Small VT100-like terminal buffer. Do not turn it into a heavyweight emulator.

### `AppDelegate`
UI orchestration. Avoid putting encoding or SSH protocol logic here.

## Tight status

Tight was originally experimental and failed to connect. It was reworked to support:
- four persistent zlib streams
- reset bits
- Copy
- Palette
- Gradient
- JPEG
- Fill

On physical-device testing, Tight subsequently **worked**.

Do not regress this. Every new VNC change should first be tested with:
1. Tight ON
2. Hextile fallback

## Manual Disconnect behavior

Current required behavior after v2.2.0-beta3:
- main button toggles Connect / Disconnect
- manual Disconnect sets `_shouldAutoReconnect=NO`
- pending reconnect timer is invalidated
- VNC client is disconnected/released
- active VNC SSH tunnel is stopped
- clipboard polling stops
- controls reopen
- button becomes Connect

Unexpected remote/network loss should still use auto reconnect.

## SSH requirements

Do not allow an empty SSH username to silently fall back to iOS local user `mobile`.

Terminal flow:
1. enter host/user/port/key
2. tap Connect
3. show explicit `user@host`

Expected iPad commands:
- `/usr/bin/ssh`
- optionally `/usr/bin/ssh-keygen`

Host verification:
- interactive Terminal: `StrictHostKeyChecking=ask`
- tunnel: stricter known-host behavior

## Files API

Server script:
`scripts/ipad1vnc_fileserver.py`

Server root used in testing:
`/home/desktop/Downloads`

Service:
`ipad1vnc-fileserver.service`

Typical endpoint:
`http://95.111.242.96:8085`

Token file:
`/home/desktop/.ipad1vnc-files-token`

Current target API supports list/stat/download/mkdir/rename/delete/chunked upload.

Secrets:
- Files token goes to Keychain
- do not reintroduce plaintext secrets in `NSUserDefaults`

## Security priorities

Known-good secure strategy:
- SSH tunnel VNC
- eventually SSH tunnel Files too
- close public 5901 and 8085 after tunnel validation

Experimental:
- VeNCrypt X509Vnc via legacy SecureTransport

Do not claim VeNCrypt production-ready until verified on the actual device and server.

## UX priorities

Do not overcrowd the iPad 1 screen.

Prefer:
- compact controls
- secondary action sheets
- Tools panel
- profile-driven workflow

Profiles should be the long-term home screen concept:
- Desktop Connect
- Terminal
- Files
- Wake
- Edit

## Development workflow

Before changing code:
1. read `SESSION.md`
2. read `TASKS.md`
3. read `ARCHITECTURE.md`
4. preserve existing working paths

After a non-trivial change:
1. bump beta/rc version
2. update `CHANGELOG.md`
3. update `SESSION.md` if current test state changes
4. provide exact build commands
5. do not call a feature finished until physical-device runtime test passes

## Communication style for this project

The user works interactively and posts terminal output after each step.

Prefer:
- exact standalone commands
- small ordered steps
- no unnecessary theory
- never paste shell prompts into commands
- distinguish clearly between WSL commands, Contabo commands, and iPad commands
