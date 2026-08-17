# TESTING.md

## Test philosophy

A successful compile is not enough. iPad1VNC targets a physical iPad 1 with unusual legacy constraints, so important features must be validated on-device.

Use this order to isolate regressions.

## 1. Install / launch

- [ ] `.deb` builds for armv7.
- [ ] package installs with `dpkg -i`.
- [ ] SpringBoard restarts.
- [ ] app launches without immediate crash.
- [ ] existing Keychain secrets survive upgrade.

## 2. Baseline VNC

### Tight
- [ ] Tight ON connects.
- [ ] XFCE renders correctly.
- [ ] move several windows.
- [ ] open menus.
- [ ] scroll file manager/web content.
- [ ] no color corruption.
- [ ] no stale rectangles.
- [ ] no disconnect during 10-15 minutes.

### Hextile fallback
- [ ] Tight OFF connects.
- [ ] Hextile renders correctly.
- [ ] no regression from Tight work.

## 3. Connection state

Required after v2.2.0-beta3:

- [ ] tap Connect.
- [ ] button becomes Disconnect.
- [ ] tap Disconnect.
- [ ] button becomes Connect immediately.
- [ ] controls reopen.
- [ ] no automatic reconnect after manual Disconnect.
- [ ] tap Connect again without restarting app.
- [ ] remote/server disconnect still triggers automatic reconnect.
- [ ] active SSH VNC tunnel stops after manual Disconnect.

## 4. Diagnostics 2.0

Create visual activity by dragging windows and scrolling.

- [ ] RTT current changes.
- [ ] RTT average changes.
- [ ] RTT max can increase.
- [ ] FPS changes between idle and active screen.
- [ ] FPS average updates.
- [ ] kbps changes.
- [ ] total frames increases.
- [ ] encoding label matches Tight/Hextile.
- [ ] quality label is sensible.
- [ ] uptime advances.
- [ ] reconnect count changes after reconnect.
- [ ] health classification does not remain obviously wrong.

## 5. Input

### Direct
- [ ] tap.
- [ ] drag.
- [ ] right click.

### Trackpad
- [ ] pointer movement.
- [ ] tap click.
- [ ] two-finger scroll.
- [ ] sensitivity slider.

### Mouse extensions
- [ ] Precision mode clearly slows pointer.
- [ ] Drag Lock works.
- [ ] three-finger tap produces middle click.
- [ ] long press produces right click.

## 6. Keyboard

- [ ] normal typing.
- [ ] Backspace.
- [ ] Esc.
- [ ] Tab.
- [ ] arrows.
- [ ] Home/End.
- [ ] PgUp/PgDn.
- [ ] F1-F12.
- [ ] Insert/Delete.
- [ ] Print Screen.
- [ ] Alt+Tab.
- [ ] Ctrl+Alt+T.
- [ ] Ctrl+Alt+Del.
- [ ] Ctrl+Shift+Esc.

If a Bluetooth keyboard is available, test modifier behavior separately from the on-screen toolbar.

## 7. Clipboard

- [ ] iPad -> remote clipboard.
- [ ] remote -> iPad clipboard.
- [ ] repeated copy/paste does not leak noticeably.

## 8. Profiles

- [ ] save.
- [ ] load.
- [ ] Desktop Connect.
- [ ] Terminal quick action.
- [ ] Files quick action.
- [ ] Wake quick action.
- [ ] Load & Edit.
- [ ] Duplicate.
- [ ] Delete.
- [ ] Set Default.
- [ ] Auto Connect.
- [ ] profile-specific VNC password restored from Keychain.
- [ ] profile-specific Files token restored from Keychain.

## 9. SSH Terminal

- [ ] SSH User field is respected.
- [ ] blank SSH User is rejected.
- [ ] connection text shows explicit `user@host`.
- [ ] Connect/Stop can be repeated.
- [ ] host fingerprint prompt on first connection where expected.
- [ ] known_hosts persists.
- [ ] generated RSA key works where server supports it.
- [ ] Ctrl-C.
- [ ] arrows.
- [ ] Home/End.
- [ ] PgUp/PgDn.
- [ ] `top` acceptable.
- [ ] `nano` acceptable.

## 10. Files baseline

Deploy the matching server script before testing v2.2 resume behavior.

- [ ] authenticated list.
- [ ] folder navigation.
- [ ] download.
- [ ] upload.
- [ ] rename.
- [ ] delete.
- [ ] new folder.
- [ ] file size shown.

## 11. Files resume / queue

- [ ] `/api/stat` works.
- [ ] server returns `Accept-Ranges`.
- [ ] partial download uses `.part`.
- [ ] cancel/interruption keeps `.part`.
- [ ] next download uses HTTP Range and resumes.
- [ ] interrupted upload resumes from server-side size.
- [ ] transfer queue starts next item.
- [ ] pause state does not corrupt files.
- [ ] 100+ MB transfer does not crash iPad.

## 12. LAN discovery

On Wi-Fi:
- [ ] local IPv4 detected.
- [ ] scan does not freeze UI.
- [ ] SSH server appears.
- [ ] VNC server appears.
- [ ] selected item fills Host.
- [ ] scan time is acceptable for iPad 1.

## 13. Wake-on-LAN

- [ ] valid MAC accepted.
- [ ] packet sent.
- [ ] target wakes on a network where broadcast WOL is supported.

## 14. Dynamic resolution

- [ ] manual landscape match.
- [ ] manual portrait match.
- [ ] correct remote DISPLAY.
- [ ] orientation auto mode does not loop.
- [ ] VNC stays usable after resize.

## 15. SSH Tunnel

This is security-critical.

- [ ] tunnel starts with explicit SSH user/key.
- [ ] VNC connects through local forwarded port.
- [ ] manual Disconnect stops tunnel.
- [ ] reconnect behavior works.
- [ ] after validation, direct 5901 can be firewall-restricted.

## 16. VeNCrypt / X509Vnc

Experimental; run last.

- [ ] server is deliberately configured for X509Vnc.
- [ ] required SecureTransport symbols exist at runtime.
- [ ] trusted certificate connects.
- [ ] invalid/untrusted certificate fails.
- [ ] TLS OFF leaves normal VNC working.
- [ ] SSH tunnel remains usable if TLS fails.

## 17. Long-session stability

- [ ] 15 min Tight.
- [ ] 30 min Tight.
- [ ] 60 min Tight.
- [ ] repeated Connect/Disconnect cycles.
- [ ] repeated Terminal sessions.
- [ ] repeated Files transfers.
- [ ] no obvious increasing UI lag.
- [ ] memory warning path does not crash.

## Release gate

A release candidate should not be called stable unless these core items pass:
- Tight
- Hextile fallback
- manual Disconnect/Connect
- unexpected auto reconnect
- SSH user handling
- Files baseline
- Keychain persistence
- 30-minute stability test
