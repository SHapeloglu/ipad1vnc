# iPad1VNC Competitor Review — 2026

This review applies the mandatory iPad1 Suite responsibility filter before recommending features.

## Reference competitors

Current feature references reviewed:
- RealVNC Connect Viewer / Classic Viewer
- Jump Desktop
- Remoter Pro
- Mocha VNC

## What competitors do well that is already present in iPad1VNC

The current iPad1VNC source already covers many VNC-owned capabilities that competitors emphasize:

- RFB 3.8
- RAW / Hextile / Tight
- Direct touch and Trackpad input
- precision pointer, drag lock, right/middle click
- pinch zoom and scrolling
- clipboard
- VNC-specific special keys including F1–F12, Alt+Tab and Ctrl+Alt+Del
- VNC profiles storing quality, input mode, SSH tunnel, TLS, precision and drag-lock choices
- Wake-on-LAN
- LAN discovery
- diagnostics / RTT / FPS / kbps / encoding / quality
- adaptive quality
- SSH tunnel used specifically as VNC transport
- experimental TLSVnc / X509Vnc work

Do not duplicate these merely because they appear in competitor feature lists.

## VNC-owned gaps worth adding

### 1. Explicit transport/security state

Keep transport visible as one of:

```text
DIRECT · PLAIN
DIRECT · TLSVNC
DIRECT · X509VNC
SSH TUNNEL · VNC
```

Status must reflect the transport actually negotiated, not merely the requested switch state.

### 2. Safe external VNC URL invocation

Competitors such as Jump Desktop and Remoter support launching remote sessions from other applications. This is useful for the iPad1 Suite and belongs to iPad1VNC because it only configures/starts a VNC session.

Supported contract:

```text
ipad1vnc://connect?host=<host>&port=<port>&tls=0|1&tight=0|1&quality=0..3&input=0|1&autoconnect=0|1
ipad1vnc://profile?id=<profile-id>&autoconnect=0|1
```

Security:
- never accept or transmit VNC passwords through the URL;
- never accept Files API tokens or SSH passwords/keys;
- validate port and enum ranges;
- percent-decode data only;
- unknown parameters are ignored.

### 3. Keep VNC Quick Keys polished, not shell macros

Existing VNC key sequences already cover the important competitor gap. Do not add arbitrary shell-command macros. A VNC macro may only be a key-event sequence.

### 4. Continue transport-aware profiles

The profile model already stores quality/input/SSH-tunnel/TLS. Future profile work should polish UX rather than add unrelated Terminal/Files/Downloader fields.

## Features explicitly rejected for iPad1VNC

Do not add:
- RDP;
- audio streaming;
- cloud relay/accounts;
- multi-session live desktops on 256 MB RAM;
- general SSH terminal product features;
- general file manager;
- ZIP/archive features;
- durable download queue/pause/resume/retry;
- PDF/text rendering;
- shell-command macros.

These are either outside the product goal or owned by sibling suite applications.

## Competitive positioning

The target is not an all-in-one remote access suite. The product goal is:

> iPad1VNC = the lightest capable VNC client for iPad 1, with explicit secure transport and clean hand-off to specialist iPad1 Suite applications.

This preserves the iPad 1 / iOS 5.1.1 / armv7 / non-ARC / ~256 MB RAM constraints.
