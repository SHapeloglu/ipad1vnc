# AGENTS.md

## Mission

Maintain and improve iPad1VNC without regressing its core constraint: **iPad 1 / iOS 5.1.1 / armv7 / ~256 MB RAM**.

## Non-negotiable rules

1. Do not introduce APIs that require modern iOS without compatibility guards.
2. Do not load large files wholly into memory.
3. Do not remove RAW/Hextile fallback while changing Tight/TLS.
4. Do not store VNC passwords or Files tokens in plaintext `NSUserDefaults`.
5. Do not silently use `mobile` as SSH user when the SSH username is blank.
6. Do not call runtime features complete before testing on the physical iPad.
7. Do not expand scope into RDP/audio/cloud before current VNC/SSH/Files paths are stable.
8. Keep old-device security exceptions narrowly scoped. Never globally enable obsolete SSH algorithms.

## Required reading order

Before editing:
1. `SESSION.md`
2. `TASKS.md`
3. `ARCHITECTURE.md`
4. `BUILD.md`
5. relevant source files

## Build target

```make
ARCHS = armv7
TARGET = iphone:clang:6.1:5.1
```

Build command:
```bash
make clean
make package FINALPACKAGE=1
```

Warnings may be treated as errors. Old Clang is sensitive to:
- misleading indentation
- incomplete protocol implementation
- undeclared functions
- malformed Objective-C class extensions

## Version discipline

Use incremental prerelease versions during testing:
- `-betaN` for feature-heavy changes
- `-rcN` for stabilization

Every meaningful source update should also update:
- `README.md` if user-visible feature set changes
- `CHANGELOG.md`
- `SESSION.md`
- `TASKS.md` where applicable

## Code boundaries

- `VNCClient`: RFB protocol, encodings, statistics, TLS transport
- `VNCView`: framebuffer presentation and touch/mouse gestures
- `TerminalSession`: PTY + SSH process/tunnel
- `LegacyTerminalBuffer`: lightweight terminal interpretation
- `KeychainStore`: secrets
- `AppDelegate`: UI orchestration only

Do not put VNC decoding logic into `AppDelegate`.

## Manual memory management

Assume non-ARC.

Review every new ownership path:
- `alloc/init` => release
- retained ivars => release in `dealloc`
- worker loops => local autorelease pool
- long-lived buffers => bounded size

For the iPad 1, memory leaks are product-breaking bugs.

## Files transfer rules

Uploads/downloads must be stream-based.

Current upload design:
- 64 KB chunks
- server resumable endpoint

Current download design target:
- `.part` file
- HTTP Range resume
- keep partial file after interruption

Never replace this with `dataWithContentsOfFile:` for large transfers.

## Security rules

Preferred secure connection:
- SSH VNC tunnel

Files should eventually use SSH tunneling too.

VeNCrypt/X509Vnc is experimental. If SecureTransport functionality is missing on iOS 5 runtime, fail cleanly and preserve normal VNC/SSH tunnel paths.

## Testing rules

At minimum after VNC changes:
- Tight ON
- Hextile fallback
- window movement
- scrolling
- clipboard
- Direct input
- Trackpad
- manual Disconnect -> Connect
- unexpected disconnect -> auto reconnect
- 15-minute session

After memory-sensitive changes:
- 30-minute session
- ideally 60-minute session

After Files changes:
- small upload/download
- 100+ MB transfer
- interrupt/resume
- rename/delete/new folder

After SSH changes:
- explicit SSH user respected
- key path respected
- host-key verification behavior
- tunnel lifecycle

## Shell command hygiene

When writing instructions, keep commands standalone and indicate execution host when ambiguity exists:

### WSL
```bash
make clean
make package FINALPACKAGE=1
```

### iPad
```bash
dpkg -i /var/mobile/<package>.deb
killall SpringBoard
```

### Contabo
```bash
sudo systemctl restart ipad1vnc-fileserver
```

Never include copied shell prompt text inside commands.
