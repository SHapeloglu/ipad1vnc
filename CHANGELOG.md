# CHANGELOG.md

## 2.2.0-beta3
- Fixed main VNC Connect/Disconnect state handling.
- Manual Disconnect now disables auto reconnect.
- Pending reconnect timer is cancelled.
- Clipboard timer stops on manual disconnect.
- Active VNC SSH tunnel stops on manual disconnect.
- Connection controls reopen.
- Main button returns to Connect.
- Unexpected remote/network disconnect keeps auto reconnect.
- X509 TLS preference is saved through normal connection settings.

## 2.2.0-beta2
- Fixed legacy iOS SDK compile issues around SecureTransport symbol declarations.
- Experimental TLS symbols moved to runtime `dlsym` lookup.
- Fixed methods accidentally placed with bodies inside the private `@interface`.
- Preserved resumable download implementation.
- Removed accidental Python `__pycache__` from source package.
- Build succeeded in the user's Theos/iOS 5 environment.

## 2.2.0-beta1
Large competitor-gap feature branch:
- Diagnostics 2.0.
- rolling RTT/FPS statistics.
- Precision pointer.
- Drag Lock.
- middle mouse gesture.
- Profiles 3.0 quick actions.
- LAN SSH/VNC discovery.
- expanded special-key support.
- transfer queue.
- resumable Range downloads.
- resumable chunk uploads.
- `/api/stat` Files endpoint.
- memory-pressure cleanup.
- worker-loop autorelease pool.
- experimental VeNCrypt/X509Vnc TLS.

Initial beta1 did not compile due legacy SecureTransport declarations and malformed AppDelegate class-extension generation; fixed in beta2.

## 2.1.0-rc2
- Fixed Hextile compiler warning caused by misleading indentation.
- Restored required `terminalSessionEnded:` delegate implementation.
- Successfully compiled.
- Tight subsequently tested successfully on the physical iPad against TigerVNC.

## 2.1.0-rc1
Major consolidation release:
- reworked Tight decoder with four persistent zlib streams.
- Copy/Palette/Gradient/JPEG/Fill Tight handling.
- Auto Quality improvements.
- connection statistics.
- Keychain secret storage/migration.
- Profiles 2.0.
- SSH key/known_hosts improvements.
- lightweight VT100 terminal buffer.
- chunked Files upload.
- Wake-on-LAN.
- dynamic resolution helper.

Initial rc1 had legacy compile errors fixed by rc2.

## 2.0.0-beta5
- Fixed SSH user workflow.
- Terminal no longer auto-connects before user edits SSH User.
- Added Terminal Connect / Stop.
- Blank SSH username rejected rather than falling back to local `mobile`.

## 2.0.0-beta4
- Tight advertisement made optional.
- Tight OFF advertised Hextile + RAW + DesktopSize only.
- Tight at that time remained experimental.

## Earlier history
- v1.x established VNC, clipboard, keyboard, Files, input modes, quality settings and profiles.
- v0.x established basic iPad 1 RFB connectivity, persistence, reconnect, fullscreen, rotation, pointer and zoom behavior.
