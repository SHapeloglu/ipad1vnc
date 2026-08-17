# SERVER.md

## Current Linux server

Development server profile:
- Ubuntu 24.04
- XFCE
- TigerVNC display `:1`
- Linux desktop user used in the current lab: `desktop`

> The repository is public. Keep the real public server IP, passwords, API tokens, private keys and other live credentials outside GitHub. In commands below use `<CONTABO_IP>`.

## TigerVNC

Typical launch:
```bash
vncserver :1 -geometry 1024x768 -depth 24 -localhost no
```

Development VNC port:
```text
5901
```

Typical xstartup:
```sh
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session startxfce4
```

Typical file:
```text
/home/desktop/.vnc/xstartup
```

## Files API

Server script from the matching application release:
```text
scripts/ipad1vnc_fileserver.py
```

Installed path used by the lab server:
```text
/opt/ipad1vnc/ipad1vnc_fileserver.py
```

Files root:
```text
/home/desktop/Downloads
```

Token file path:
```text
/home/desktop/.ipad1vnc-files-token
```

Never commit the token value.

Development port:
```text
8085
```

## Systemd service

```ini
[Unit]
Description=iPad1VNC File Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=desktop
Group=desktop
WorkingDirectory=/home/desktop/Downloads
ExecStart=/usr/bin/python3 /opt/ipad1vnc/ipad1vnc_fileserver.py --root /home/desktop/Downloads --bind 0.0.0.0 --port 8085 --token-file /home/desktop/.ipad1vnc-files-token
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Reload/restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ipad1vnc-fileserver
sudo systemctl status ipad1vnc-fileserver --no-pager -l
```

Logs:
```bash
sudo journalctl -u ipad1vnc-fileserver -n 50 --no-pager
```

## Deploy a new Files API version

From the WSL project directory:
```bash
scp scripts/ipad1vnc_fileserver.py \
root@<CONTABO_IP>:/opt/ipad1vnc/ipad1vnc_fileserver.py
```

Then on the server:
```bash
sudo chmod 755 /opt/ipad1vnc/ipad1vnc_fileserver.py
sudo systemctl restart ipad1vnc-fileserver
sudo systemctl status ipad1vnc-fileserver --no-pager -l
```

The existing token file should remain unchanged.

## API

Authentication header:
```text
X-iPad1VNC-Token
```

Endpoints used/targeted by v2.2:
- `GET /api/list?path=<relative-path>`
- `GET /api/stat?path=<relative-path>`
- `GET /download?path=<relative-path>&token=<token>`
- `POST /api/mkdir`
- `POST /api/rename`
- `POST /api/delete`
- `POST /api/upload`
- `POST /api/upload-chunk?path=<path>&offset=<offset>&total=<total>`

v2.2 target supports HTTP Range downloads for resume.

## Security

During development, VNC 5901 and Files 8085 may be reachable directly. This should not be the final production posture.

Preferred final posture:
1. verify SSH VNC tunnel,
2. route Files securely as well,
3. firewall/restrict public 5901,
4. firewall/restrict public 8085.

The Files token over plain HTTP is authentication, not transport encryption.

## Dynamic resolution helper

Example remote command:
```bash
DISPLAY=:1 xrandr --fb 1024x768
```

Test manual `Match iPad` before enabling automatic orientation-driven resize.

## TLS / VeNCrypt

Experimental v2.2 work targets X509Vnc. Do not replace the known-good SSH Tunnel path until X509Vnc is verified on the physical iPad and actual TigerVNC configuration.
