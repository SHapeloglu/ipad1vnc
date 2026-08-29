# iPad1VNC Architecture

## Product boundary

iPad1VNC is the graphical remote-desktop member of the iPad1 suite.

Primary responsibility:

```text
RFB/VNC desktop
+ remote input
+ clipboard
+ profiles
+ diagnostics
+ Direct / SSH Tunnel / TLS transport required by VNC
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

## Core ownership

### AppDelegate

Owns orchestration only:
- VNC lifecycle
- connection profiles
- status UI
- transport selection
- Remote Files orchestration
- WOL / LAN helpers
- cross-app launch actions

It should not accumulate document rendering, archive engines or general local-file-management logic.

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

### TerminalSession

Long-term role in iPad1VNC:
- SSH port forwarding/tunnel required by VNC
- compatibility fallback during suite migration

General interactive SSH terminal UX belongs to iPad1Terminal.

### KeychainStore

Owns secrets required by iPad1VNC. Secrets must never be passed to other suite applications in URL schemes.

## Suite delegation

See `INTEGRATION.md` for the normative contract.

```text
iPad1VNC             -> VNC/RFB + VNC transport
iPad1Terminal        -> terminal / interactive SSH
iPad1Files           -> local file manager / ZIP
iPad1FTPDownloader   -> downloads / durable queue / pause-resume
iPad1PDFReader       -> PDF + supported text-reader formats
```

## Migration principle

Do not delete working in-process functionality merely because another application should eventually own it.

Use this order:

```text
1. Freeze responsibility boundary
2. Implement provider URL contract
3. Add delegation action
4. Test on physical iPad 1
5. Only then remove duplicated code
```

This avoids regressions while reducing long-term application size and complexity.

## Memory policy

- never load large remote/local files into RAM unnecessarily
- keep transfer buffers bounded
- keep terminal buffers bounded
- use autorelease pools in network/worker loops
- release dormant panels/resources under memory pressure where safe
- preserve low-memory RAW/Hextile/Tight behavior

## Security policy

Transport modes must be explicit:

```text
Direct / Plain VNC
Direct / TLSVnc
Direct / X509Vnc
SSH Tunnel / VNC
```

If the user requests TLS, the client must not silently downgrade to Plain VNC.

SSH Tunnel remains a valid secure VNC transport even if legacy SecureTransport/TLS compatibility is limited.

## Non-goals

Do not add to iPad1VNC:
- RDP
- audio streaming
- cloud relay/accounts
- multi-monitor support
- PDF/text rendering
- ZIP/archive management
- general local file manager
- general FTP/HTTP download manager
- heavyweight terminal framework

## Physical-device rule

A feature is not considered working until it has been validated on the physical iPad 1. Build success alone is insufficient.
