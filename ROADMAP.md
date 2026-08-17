# ROADMAP.md

## Product direction

iPad1VNC should remain a focused legacy-device Linux thin client.

The strategic advantage is not protocol count; it is keeping an iPad 1 useful with a compact, low-memory toolchain.

## v2.2 stabilization

### Connection lifecycle
- manual Disconnect/Connect must be repeatable
- unexpected disconnect must auto reconnect
- SSH tunnel lifecycle must follow VNC lifecycle

### Diagnostics 2.0
- dynamic RTT/FPS/kbps
- current/average/max latency
- frame count
- uptime/reconnect count
- simple network-quality indicator

### Input polish
- Precision pointer
- Drag Lock
- middle click
- full practical special-key coverage

### Profiles 3.0
- profile-first actions
- Desktop / Terminal / Files / Wake
- secure per-profile secrets
- default + auto-connect behavior

### Files 2.2
- transfer queue
- resumable downloads
- resumable uploads
- large-file memory safety
- clearer progress/failure state

### LAN discovery
- local SSH/VNC discovery
- low-impact worker-thread scan
- later consider Bonjour/mDNS only if lightweight

### Security
- validate SSH VNC tunnel
- secure Files transport
- close/restrict public VNC/Files ports
- experimental X509Vnc validation

## v2.2 release candidate gate

Before promoting beta to RC:
- Tight stable
- Hextile fallback stable
- Disconnect/Connect bug closed
- diagnostics confirmed dynamic
- Terminal explicit-user flow confirmed
- Files baseline confirmed
- 30-minute stability test

## v2.3 potential polish

After v2.2 is stable:
- cleaner profile-centric landing page
- secure-transport status badge
- stronger transfer queue UI
- connection-history/last-error diagnostics
- better hardware Bluetooth keyboard modifier handling
- lighter/faster LAN discovery
- optional Files-over-SSH integration

## Later possibilities

Only evaluate if they do not compromise the legacy-device mission:
- Bonjour/mDNS discovery
- URL schemes/deep links
- profile import/export
- server-side helper installer
- basic connection presets for common Linux distributions

## Explicitly deferred

These are not priorities for the current product:
- RDP
- audio streaming
- multi-monitor
- cloud relay/account platform
- subscription service
- heavyweight xterm emulator

They add complexity and RAM footprint without strengthening the core iPad 1 use case.

## Competitive positioning

Target message:

> A lightweight, direct Linux management console for first-generation iPads that modern remote-desktop clients no longer support.

Differentiators:
- iOS 5.1.1
- VNC Tight/Hextile
- SSH Terminal
- SSH tunneling
- Files management
- profiles
- Wake-on-LAN
- diagnostics
- no mandatory cloud
- no subscription requirement
