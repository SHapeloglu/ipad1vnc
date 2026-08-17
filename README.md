# iPad1VNC

iPad1VNC is a lightweight Linux thin-client for **iPad 1 / iOS 5.1.1**. The goal is to turn first-generation jailbroken iPads into useful remote administration terminals for Linux servers while staying within the device's ~256 MB RAM and legacy iOS constraints.

## Current baseline

Latest working development line: **v2.2.0-beta3**.

Known-good hardware/runtime:
- iPad 1, iOS 5.1.1, jailbroken
- armv7
- Theos legacy iOS build
- TigerVNC server on Ubuntu 24.04
- XFCE desktop

Core features:
- VNC: RAW, Hextile, Tight
- Direct touch + trackpad input
- pinch zoom + two-finger scroll
- clipboard
- special-key toolbar
- auto reconnect
- profiles
- SSH terminal
- SSH VNC tunnel
- authenticated Files API
- upload/download/rename/delete/new-folder
- Keychain-backed secrets
- Wake-on-LAN
- dynamic resolution helpers
- diagnostics and connection statistics

## Project philosophy

This is not intended to compete with modern remote-desktop products by adding every protocol. The differentiator is:

> Keep a 2010 iPad useful as a fast, lightweight Linux management terminal in 2026.

Priorities are therefore:
1. stability
2. memory efficiency
3. low bandwidth
4. security
5. usability on iOS 5
6. graceful fallback when modern APIs are unavailable

## Important current status

- Tight encoding works on the real iPad against TigerVNC.
- v2.2 added a larger competitor-gap feature set; it remains beta and needs runtime validation.
- v2.2.0-beta3 fixes the main VNC Connect/Disconnect state bug: manual Disconnect cancels auto-reconnect and returns the button to Connect.
- SSH Tunnel remains the known-good secure transport path.
- X509 VeNCrypt/TLS is experimental and must not replace SSH Tunnel until validated on iOS 5.1.1 and the actual TigerVNC configuration.

## Documentation

Read these before changing code:
- `ARCHITECTURE.md`
- `CLAUDE.md`
- `AGENTS.md`
- `SESSION.md`
- `TASKS.md`
- `BUILD.md`
- `SERVER.md`
- `TESTING.md`
- `ROADMAP.md`
