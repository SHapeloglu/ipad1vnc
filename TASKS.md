# TASKS.md

## P0 — immediate validation

### v2.2.0-beta3 manual disconnect
- [ ] Compile beta3 on WSL/Theos.
- [ ] Install on iPad.
- [ ] Tight ON connection succeeds.
- [ ] Tap Disconnect.
- [ ] Button immediately becomes Connect.
- [ ] Controls reopen.
- [ ] Tap Connect again without restarting app.
- [ ] Confirm manual Disconnect does not trigger 3-second auto reconnect.
- [ ] Confirm unexpected network/server disconnect still auto reconnects.

### Diagnostics 2.0
- [ ] Confirm RTT current changes.
- [ ] Confirm RTT average changes.
- [ ] Confirm RTT max can increase.
- [ ] Confirm FPS changes between idle desktop and moving windows.
- [ ] Confirm kbps changes.
- [ ] Confirm frame counter increases.
- [ ] Validate health classification.

## P1 — v2.2 runtime coverage

### Mouse UX
- [ ] Precision mode visibly slows pointer to fine-control speed.
- [ ] long press = right click.
- [ ] three-finger tap = middle click.
- [ ] Drag Lock toggles held-left-button state.
- [ ] two-finger pan = wheel.

### Profiles 3.0
- [ ] Desktop Connect.
- [ ] Terminal.
- [ ] Files.
- [ ] Wake.
- [ ] Load & Edit.
- [ ] Duplicate.
- [ ] Delete.
- [ ] Set Default / Auto Connect from existing profile management.
- [ ] profile-specific Keychain VNC password.
- [ ] profile-specific Files token.

### Keyboard
- [ ] F1-F12.
- [ ] Insert.
- [ ] Delete.
- [ ] Print Screen.
- [ ] Alt+Tab.
- [ ] Ctrl+Alt+Del.
- [ ] Ctrl+Alt+T.
- [ ] Ctrl+Shift+Esc.
- [ ] Super/Menu/Pause/Scroll Lock.

### Terminal
- [ ] SSH user is always explicit.
- [ ] no fallback to `mobile` when user field is blank.
- [ ] Connect/Stop work repeatedly.
- [ ] Ctrl-C.
- [ ] arrows/Home/End/PgUp/PgDn.
- [ ] `top` renders acceptably.
- [ ] `nano` renders acceptably.
- [ ] known_hosts persists.
- [ ] generated RSA key works where supported.

## P1 — Files 2.2

Before testing, deploy matching `scripts/ipad1vnc_fileserver.py` to Contabo.

- [ ] `/api/list` works.
- [ ] `/api/stat` works.
- [ ] small download.
- [ ] small upload.
- [ ] rename.
- [ ] delete.
- [ ] new folder.
- [ ] HTTP Range returns `206`.
- [ ] interrupt download, keep `.part`, resume without restart.
- [ ] interrupt upload, resume from remote size.
- [ ] transfer queue starts next item.
- [ ] pause/resume behavior is understandable.
- [ ] 100+ MB file does not crash the iPad.

## P1 — SSH Tunnel hardening

- [ ] Verify VNC through SSH tunnel on device.
- [ ] Verify reconnect behavior through tunnel.
- [ ] Verify tunnel stops after manual Disconnect.
- [ ] Tunnel Files 8085 or add equivalent secure path.
- [ ] After validation, firewall/restrict public 5901.
- [ ] After Files secure path validation, firewall/restrict public 8085.

## P2 — LAN discovery

- [ ] Wi-Fi IPv4 detected.
- [ ] local /24 scan completes without freezing UI.
- [ ] SSH host appears.
- [ ] VNC host appears.
- [ ] selecting result fills host.
- [ ] evaluate timeout/performance on iPad 1.
- [ ] consider mDNS/Bonjour later if lightweight enough.

## P2 — VeNCrypt / X509Vnc

Experimental. Test last.

- [ ] Configure TigerVNC for X509Vnc.
- [ ] Verify required SecureTransport symbols exist on iOS 5.1.1 runtime.
- [ ] trusted certificate connects.
- [ ] wrong/untrusted certificate fails.
- [ ] normal VNC still works with TLS switch OFF.
- [ ] SSH Tunnel remains functional regardless of TLS state.

Do not label production-ready until all items pass.

## P2 — dynamic resolution

- [ ] manual Match iPad landscape.
- [ ] manual Match iPad portrait.
- [ ] remote DISPLAY selection works.
- [ ] Auto Resolution does not loop on orientation events.
- [ ] no loss of active VNC session where server/XFCE allows resize.

## P2 — stability

- [ ] 15-minute Tight session.
- [ ] 30-minute session.
- [ ] 60-minute session.
- [ ] repeated Connect/Disconnect cycles.
- [ ] repeated Files transfers.
- [ ] memory-warning path does not crash.
- [ ] no obvious terminal scrollback leak.
- [ ] no framebuffer growth leak.

## P3 — UI polish after stability

- [ ] audit overlaps in portrait/landscape.
- [ ] make profile-centric main workflow cleaner.
- [ ] improve status labels without increasing memory footprint.
- [ ] improve transfer queue UI.
- [ ] add clearer secure-connection indicators: Direct / SSH / TLS.
- [ ] retain iOS 5 visual compatibility.

## Deferred / not current scope

- RDP.
- audio.
- multi-monitor.
- cloud account/relay.
- heavyweight xterm.

Revisit only after v2.x is stable and secure.
