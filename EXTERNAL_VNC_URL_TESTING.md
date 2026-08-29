# External VNC URL Invocation — Validation

Target: iPad 1 / iOS 5.1.1 / armv7 / non-ARC.

This feature is not considered working until tested on the physical iPad.

## Apply

```bash
cd ~/projects/ipad1vnc/iPad1VNC-v2.2.0-beta3
git pull origin beta4-ui-security-polish
python3 scripts/apply_beta4_external_vnc_url.py
make clean
make package FINALPACKAGE=1
```

## Supported safe routes

Load host settings only:

```text
ipad1vnc://connect?host=192.168.1.10&port=5901
```

Load VNC preferences:

```text
ipad1vnc://connect?host=192.168.1.10&port=5901&tls=1&tight=1&quality=0&input=1
```

Load a saved profile:

```text
ipad1vnc://profile?id=<profile-id>
```

Auto-connect is allowed for the saved-profile route because the VNC secret remains local in Keychain:

```text
ipad1vnc://profile?id=<profile-id>&autoconnect=1
```

## Security invariants

External URLs must never contain or accept:

- VNC password
- SSH password
- Files API token
- private key material
- arbitrary shell command text

A direct `connect` route clears the password field so a password left from a previous host cannot accidentally be sent to the externally supplied host.

## Physical-device checks

1. Opening a `connect` URL launches iPad1VNC.
2. Host and port are populated correctly.
3. TLS/Tight/quality/input values are applied when supplied.
4. The password field is empty after a direct external host request.
5. Invalid ports such as `0` or `70000` do not start a connection.
6. An unknown action does not crash the app.
7. A valid saved-profile route loads the expected profile.
8. Saved-profile `autoconnect=1` uses the profile's Keychain secret and connects.
9. Direct host requests do not auto-connect using a previously loaded password.
10. Normal manual VNC connection and Disconnect -> Connect behavior still work.

## Acceptance

Do not commit locally patched source as validated until all relevant checks pass on the physical iPad 1.
