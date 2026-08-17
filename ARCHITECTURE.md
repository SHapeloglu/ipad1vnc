# ARCHITECTURE.md

## 1. Purpose

iPad1VNC is an Objective-C / UIKit application for jailbroken **iPad 1 / iOS 5.1.1** that acts as a lightweight Linux thin client.

The application combines:
- VNC desktop access
- SSH terminal
- SSH tunneling
- a small authenticated HTTP Files API
- connection profiles
- diagnostics
- low-memory input and transfer helpers

The architecture must remain compatible with armv7 and legacy iOS SDKs.

---

## 2. Runtime constraints

Primary target:
- iPad 1
- iOS 5.1.1
- ~256 MB RAM
- armv7
- jailbroken filesystem access

Consequences:
- avoid ARC assumptions; project uses manual retain/release patterns
- avoid modern Objective-C APIs unless availability is verified
- avoid large frameworks and dependencies
- never load large files fully into memory
- keep terminal scrollback bounded
- create autorelease pools inside long-running worker/network loops
- prefer simple UIKit controls over modern UI abstractions

---

## 3. Main source files

### `src/AppDelegate.m` / `src/AppDelegate.h`
Owns the main application UI and coordinates:
- connection controls
- VNC lifecycle
- connection profiles
- SSH terminal panel
- Files panel
- Tools / Diagnostics panel
- Keychain migration
- Wake-on-LAN
- dynamic-resolution helper
- LAN discovery
- transfer queue

This file is intentionally the orchestration layer. Do not move protocol decoding into it.

### `src/VNCClient.m` / `src/VNCClient.h`
Owns RFB/VNC protocol handling:
- TCP connection
- RFB handshake
- VNC password authentication
- pixel-format negotiation
- framebuffer update requests
- RAW decoding
- Hextile decoding
- Tight decoding
- clipboard messages
- pointer events
- key events
- connection statistics
- optional experimental VeNCrypt/X509Vnc transport

Tight support includes:
- four persistent zlib streams
- reset bits
- Fill
- Copy filter
- Palette filter
- Gradient filter
- JPEG rectangles

Known-good baseline: Tight works against the project's TigerVNC server on the real iPad.

### `src/VNCView.m` / `src/VNCView.h`
Owns interaction and framebuffer presentation:
- framebuffer image display
- Direct input mode
- Trackpad input mode
- pinch zoom
- two-finger scroll/wheel
- right-click gesture
- middle-click gesture
- precision-pointer mode
- drag lock

### `src/TerminalSession.m` / `src/TerminalSession.h`
Owns local child-process / PTY interaction with the jailbroken iPad SSH client.

Expected executable:
`/usr/bin/ssh`

Responsibilities:
- SSH interactive session
- SSH port forwarding
- explicit SSH username
- SSH key path
- known_hosts behavior
- RSA key generation through `/usr/bin/ssh-keygen`

Do not silently fall back to local iOS user `mobile` when SSH User is empty.

### `src/LegacyTerminalBuffer.m` / `.h`
Small bounded VT100-like terminal compatibility layer.

Goals:
- support common server administration commands
- remain memory-light
- bounded scrollback

It is **not** intended to become a complete modern xterm implementation.

### `src/KeychainStore.m` / `.h`
Small iOS Keychain wrapper.

Secrets that belong in Keychain:
- VNC password
- Files API token
- future SSH passphrases

Non-secrets may remain in `NSUserDefaults`.

---

## 4. Server-side components

### TigerVNC
Typical server setup:
- Ubuntu 24.04
- XFCE
- VNC display `:1`
- TCP 5901 during development

Example:
```bash
vncserver :1 -geometry 1024x768 -depth 24 -localhost no
```

Expected `~/.vnc/xstartup`:
```sh
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session startxfce4
```

### Files API
Server script:
`scripts/ipad1vnc_fileserver.py`

Typical root:
`/home/desktop/Downloads`

Typical port:
`8085`

Authentication:
`X-iPad1VNC-Token`

Supported/target endpoints:
- `GET /api/list?path=...`
- `GET /api/stat?path=...`
- `GET /download?path=...&token=...`
- `POST /api/mkdir`
- `POST /api/rename`
- `POST /api/delete`
- `POST /api/upload`
- `POST /api/upload-chunk`

Range/resume support is part of the v2.2 server path.

---

## 5. Security model

Preferred secure architecture:

```text
iPad1VNC
   |
   +-- SSH --> Linux server:22
          |
          +-- local VNC tunnel --> 127.0.0.1:localPort -> server:5901
          +-- optional Files tunnel -> server:8085
```

Long-term production direction:
- do not leave VNC 5901 publicly exposed
- do not leave Files 8085 publicly exposed
- use SSH tunneling as the proven secure path

Experimental:
- VeNCrypt / X509Vnc via SecureTransport

Do not call the TLS implementation production-ready until tested on the real iOS 5.1.1 runtime and configured TigerVNC server.

---

## 6. Connection lifecycle

Expected VNC button state machine:

```text
Idle
  Connect
    -> Connecting
       -> Connected
          Disconnect
             -> Idle / Connect
```

Unexpected network disconnect:
- keep automatic reconnect behavior

Manual Disconnect:
- set `_shouldAutoReconnect = NO`
- invalidate pending reconnect timer
- disconnect VNC client
- stop clipboard timer
- stop active VNC SSH tunnel
- restore main button to `Connect`
- reopen controls

This behavior was fixed in **v2.2.0-beta3**.

---

## 7. Profiles

Profiles should represent a complete destination rather than only a VNC endpoint.

Profile fields may include:
- name
- id
- VNC host
- VNC port
- VNC secret in Keychain
- quality
- input mode
- pointer speed
- SSH user
- SSH port
- SSH key path
- SSH tunnel enabled
- Files URL
- Files token in Keychain
- WOL MAC
- broadcast address
- remote DISPLAY
- auto resolution
- X509 TLS preference
- Precision mode
- Drag Lock
- Auto Connect

Profile actions:
- Desktop Connect
- Terminal
- Files
- Wake
- Load & Edit
- Duplicate
- Delete
- Set Default
- Auto Connect

---

## 8. Performance strategy

The product should optimize for the old device rather than raw feature count.

Rules:
1. Prefer Tight or Hextile depending stability/bandwidth.
2. Never decode or transfer huge files into one `NSData` object.
3. Use streaming/chunking.
4. Bound terminal history.
5. Avoid retaining framebuffer copies unnecessarily.
6. Keep network workers off the main thread.
7. Avoid rapid quality oscillation: use hysteresis.
8. Keep UI updates coarse enough for iPad 1.

---

## 9. Diagnostics

Target diagnostics:
- RTT current
- RTT average
- RTT max
- FPS current
- FPS average
- kbps
- total frames
- encoding
- quality
- uptime
- reconnect count
- network health classification

The diagnostics bug observed before v2.2 was that FPS/latency appeared static. v2.2 introduced new rolling calculations and must be validated on device.

---

## 10. Non-goals for now

Do not prioritize these ahead of stability/security:
- RDP
- audio streaming
- multi-monitor
- cloud account/relay service
- heavyweight xterm implementation

The project's value is its lightweight legacy-device focus.
