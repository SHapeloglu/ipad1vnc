# iPad1VNC Architecture

## Product boundary

iPad1VNC is the graphical remote-desktop member of the iPad1 suite.

Primary responsibility:

```text
RFB/VNC desktop
+ remote input
+ clipboard
+ VNC profiles
+ diagnostics
+ Direct / SSH Tunnel / TLS transport required by VNC
+ lightweight remote-side orchestration
```

The application must stay small enough for first-generation iPad hardware.

## Platform constraints

```text
iPad 1
iOS 5.1.1
armv7
~256 MB RAM
Objective-C / UIKit
non-ARC / MRC
Theos
legacy iPhoneOS 6.1 SDK
```

No architecture change may assume modern iOS APIs, ARC, large frameworks or large persistent in-memory models.

## Mandatory responsibility filter

Before implementing any new feature in iPad1VNC, ask in this order:

```text
1. Is this intrinsically a VNC/RFB or VNC-transport function?
2. Is it already the responsibility of another iPad1 suite application?
3. Can iPad1VNC delegate the action through a small URL/path contract instead of duplicating the subsystem?
```

If another suite application owns the capability, delegation is preferred. Do not implement a duplicate subsystem merely because a competitor includes that feature inside one large application.

## Suite ownership

```text
iPad1VNC             -> VNC/RFB, VNC input/clipboard, profiles, diagnostics,
                        VNC discovery/WOL, Direct/TLS/SSH-tunnel transport
iPad1Terminal        -> local terminal + interactive SSH shell
iPad1Files           -> local file management + folder/file picker + ZIP
iPad1FTPDownloader   -> network transfer engine, queue, pause/resume/retry
iPad1PDFReader       -> PDF + supported text-reader formats
```

## Core ownership

### AppDelegate

Owns VNC orchestration only:
- VNC lifecycle
- profiles
- status UI
- transport selection
- lightweight Remote Files orchestration
- WOL / VNC-oriented LAN discovery
- cross-app launch actions

It must not continue growing terminal emulation, local file management, document rendering or durable transfer-manager functionality.

### VNCClient

Owns:
- RFB 3.8
- VNC authentication
- VeNCrypt/TLS negotiation
- RAW/Hextile/Tight decoding
- framebuffer transport
- clipboard protocol
- pointer/key events
- connection statistics

### VNCView

Owns:
- framebuffer presentation
- Direct / Trackpad input
- zoom
- scrolling
- precision pointer
- drag lock / mouse buttons
- VNC key events and lightweight Quick Keys

### TerminalSession

Permanent role in iPad1VNC:
- SSH port forwarding required to carry a VNC session

Transitional role only:
- embedded interactive SSH terminal fallback until iPad1Terminal has a stable SSH provider contract and that hand-off is physically validated

The general SSH shell UX is not a long-term iPad1VNC responsibility.

### KeychainStore

Owns secrets required by iPad1VNC. Secrets must never be passed to another suite app through URL query strings.

## Current responsibility audit

The current AppDelegate still contains functionality that is intentionally transitional:

### Must migrate to iPad1Terminal when provider is ready
- embedded SSH Terminal panel
- interactive SSH connect/stop UX
- terminal special-key UX
- terminal buffer/emulation path used only for shell interaction
- shell-oriented SSH key/profile UX where it is not needed for VNC tunnelling

### Must migrate to iPad1FTPDownloader when provider contract is ready
- download/upload transfer engine
- transfer FIFO queue
- pause/resume/cancel/retry semantics
- large-transfer persistence/resume mechanics
- transfer progress/ETA ownership

### Must delegate to iPad1Files
- local folder picker
- local upload-file picker
- local move/copy/delete/archive operations
- local destination management beyond a small remembered preference

### Must delegate to iPad1PDFReader
- PDF/TXT/MD/CSV/etc rendering or preview

### May remain in iPad1VNC as lightweight remote orchestration
- browse remote path belonging to the current remote host
- select a remote item
- copy remote path
- small Files-API mkdir/rename/delete actions when they are part of remote-host orchestration
- launch Terminal/Downloader/Files/Reader with validated non-secret parameters

## Provider-readiness rule

Do not remove an existing fallback before its provider is actually ready.

Current known provider state:
- iPad1Terminal currently has validated Local Terminal/PTTY work but SSH is not yet implemented.
- therefore the embedded iPad1VNC SSH terminal must remain as a compatibility fallback for now.
- it must not receive new terminal-specific feature expansion.

The same rule applies to Downloader/Files/Reader hand-offs: provider contract first, physical iPad validation second, duplicate-code removal last.

## Migration principle

```text
1. Freeze responsibility boundary
2. Implement provider capability and safe URL/path contract
3. Add iPad1VNC delegation action
4. Validate on physical iPad 1
5. Prefer provider path
6. Remove duplicated fallback only after repeated validation
```

## Security policy

Transport modes must be explicit:

```text
DIRECT · PLAIN
DIRECT · TLSVNC
DIRECT · X509VNC
SSH TUNNEL · VNC
```

If TLS is requested, iPad1VNC must not silently downgrade to Plain VNC.

SSH Tunnel remains an iPad1VNC feature because it is transport for VNC, not an interactive shell feature.

Never pass passwords, API tokens or private-key material in suite URL schemes.

## Memory policy

- never load large remote/local files into RAM unnecessarily
- keep network and transfer buffers bounded
- keep any transitional terminal buffers bounded
- use autorelease pools in long network/worker loops
- release dormant UI/resources where safe
- preserve low-memory RAW/Hextile/Tight behavior
- prefer cross-app delegation over keeping multiple heavyweight subsystems alive in one process

## Non-goals

Do not add to iPad1VNC:
- RDP
- audio streaming
- cloud relay/accounts
- multi-monitor support
- PDF/text rendering
- ZIP/archive management
- general local file manager
- general-purpose transfer/download manager
- general-purpose SSH terminal feature growth
- shell-command macros

## Physical-device rule

A feature or migration is not considered working until it has been validated on the physical iPad 1. Build success alone is insufficient.
