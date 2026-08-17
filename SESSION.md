# SESSION.md

## Current handoff snapshot

Date of handoff: 2026-08-17

Repository:
`SHapeloglu/ipad1vnc`

Current development line:
**v2.2.0-beta3**

## What is known to work on the physical iPad

Hardware/software:
- first-generation iPad
- iOS 5.1.1
- jailbroken
- armv7

Validated application behavior from prior iterations:
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
- Files API after server-side API replacement

Important real-device result:
- **Tight successfully connected and visually worked.**
- During Tight testing there was no reported corruption/disconnect; FPS/latency display remained static, which motivated Diagnostics 2.0 in v2.2.

## Latest bug and fix

Observed in v2.2.0-beta2:
- user tapped the main `Disconnect` button
- button did not return to `Connect`
- user had to close/reopen app to initiate a new connection

Cause:
- main button action was not a complete connection-state toggle
- manual disconnect did not fully separate itself from the auto-reconnect path

v2.2.0-beta3 fix:
- main button is a Connect/Disconnect toggle
- manual disconnect sets `_shouldAutoReconnect=NO`
- pending reconnect timer is invalidated
- clipboard polling stops
- VNC client is disconnected/released
- active SSH VNC tunnel is stopped
- controls reopen
- button returns to `Connect`
- unexpected remote/network disconnect retains auto reconnect

**Next immediate action:** compile and install v2.2.0-beta3, then verify this exact behavior on device.

## v2.2 feature branch status

v2.2.0-beta2 compiled successfully in the user's environment.

v2.2 adds/targets:
- Diagnostics 2.0
- rolling RTT and FPS statistics
- Precision mouse mode
- Drag Lock
- middle click
- Profiles 3.0 quick actions
- LAN scan
- expanded hardware/special keyboard keys
- transfer queue
- resumable downloads with `.part` + HTTP Range
- resumable chunk uploads
- Files `/api/stat`
- memory-pressure cleanup
- per-network-message autorelease pools
- experimental VeNCrypt X509Vnc TLS

These are not all runtime-validated yet. Treat them as beta until tested.

## VeNCrypt/TLS status

The first v2.2 attempt failed to compile because the legacy SDK headers did not expose:
- `SSLNewContext`
- `SSLDisposeContext`
- `SSLSetEnableCertVerify`

beta2 changed these to runtime `dlsym` resolution so the old SDK can compile.

Current policy:
- X509 TLS OFF by default
- SSH Tunnel remains the known-good secure transport
- if the old iOS runtime lacks required SecureTransport symbols, TLS must fail cleanly
- do not close the secure fallback path

## SSH context

The iPad's own SSH server is old and offers legacy host-key types such as:
- `ssh-rsa`
- possibly `ssh-dss`

Modern WSL OpenSSH may need host-specific compatibility flags when copying builds to the iPad.

Example:
```bash
scp \
-o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/com.olap.ipad1vnc_2.2.0-beta3_iphoneos-arm.deb \
root@192.168.1.2:/var/mobile/
```

Do not globally enable obsolete algorithms.

The app's SSH Terminal previously had a bug where opening the Terminal immediately started SSH before the user could edit SSH User, causing fallback to local `mobile`. That was fixed in v2.0.0-beta5 by adding explicit Connect/Stop and rejecting blank SSH user.

## Files server context

Contabo server:
- Ubuntu 24.04
- main public IP used during development: `95.111.242.96`
- user: `desktop`
- Files root: `/home/desktop/Downloads`

Systemd service:
`ipad1vnc-fileserver.service`

Script path:
`/opt/ipad1vnc/ipad1vnc_fileserver.py`

Token file:
`/home/desktop/.ipad1vnc-files-token`

Port:
`8085`

The user chose a shorter manually-enterable API token and confirmed Files worked after switching from Python simple HTTP server to the custom authenticated API.

For v2.2 resume functionality, the server script from the matching source tree must be installed before testing Range/stat/resume features.

## VNC server context

TigerVNC display:
`:1`

Typical command:
```bash
vncserver :1 -geometry 1024x768 -depth 24 -localhost no
```

XFCE xstartup:
```sh
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session startxfce4
```

Development port:
5901

Security goal after tunnel validation:
- stop exposing 5901 publicly
- stop exposing 8085 publicly

## Build environment

WSL project root has been rotated between versions, generally:
`~/projects/ipad1vnc/<version-folder>`

Theos:
`/home/yeliz/theos`

Legacy SDK:
`/home/yeliz/legacy-ios-sdks/iPhoneOS6.1-extracted/iPhoneOS6.1.sdk`

Target:
```make
ARCHS = armv7
TARGET = iphone:clang:6.1:5.1
```

Build:
```bash
make clean
make package FINALPACKAGE=1
```

## Immediate recommended test sequence

After beta3 compiles/installs:
1. Tight ON connects.
2. Main `Disconnect` -> button becomes `Connect` immediately.
3. Tap `Connect` again without restarting app.
4. Force remote/network loss -> auto reconnect still works.
5. Drag windows/scroll and confirm FPS/latency now vary.
6. Test Precision and Drag Lock.
7. Test profile quick actions.
8. Test Terminal explicit user.
9. Upgrade Files server script and test resume.
10. Test LAN scan on Wi-Fi.
11. Test SSH tunnel.
12. Test X509 TLS last, only with correctly configured TigerVNC.

## Product direction

Do not broaden into RDP/audio/cloud yet.

The strongest positioning is:
> A lightweight Linux management console for obsolete iPads that modern clients no longer support.
