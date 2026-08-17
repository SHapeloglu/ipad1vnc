# SERVER.md

## Current Linux server

Development server:
- Ubuntu 24.04
- public IP used during development: `95.111.242.96`
- Linux desktop user: `desktop`
- XFCE
- TigerVNC display `:1`

## TigerVNC

Typical launch:
```bash
vncserver :1 -geometry 1024x768 -depth 24 -localhost no
```

Expected port:
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

File:
```text
/home/desktop/.vnc/xstartup
```

Make executable:
```bash
chmod +x /home/desktop/.vnc/xstartup
```

## Files API

Server script from the matching application release:
```text
scripts/ipad1vnc_fileserver.py
```

Production path used during development:
```text
/opt/ipad1vnc/ipad1vnc_fileserver.py
```

Files root:
```text
/home/desktop/Downloads
```

Token file:
```text
/home/desktop/.ipad1vnc-files-token
```

Port:
```text
8085
```

## Systemd service

Recommended service:
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
root@95.111.242.96:/opt/ipad1vnc/ipad1vnc_fileserver.py
```

Then on Contabo:
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

### List
```text
GET /api/list?path=<relative-path>
```

### Stat
```text
GET /api/stat?path=<relative-path>
```

### Download
```text
GET /download?path=<relative-path>&token=<token>
```

v2.2 server target supports HTTP Range requests for resume.

### New folder
```text
POST /api/mkdir
```

### Rename
```text
POST /api/rename
```

### Delete
```text
POST /api/delete
```

### Upload
```text
POST /api/upload
```

### Chunked/resumable upload
```text
POST /api/upload-chunk?path=<path>&offset=<offset>&total=<total>
```

## Security

During development, VNC 5901 and Files 8085 have been reachable directly.

This should not be the final production posture.

Preferred final posture:
1. verify SSH VNC tunnel,
2. route Files securely as well,
3. firewall/restrict public 5901,
4. firewall/restrict public 8085.

The Files token over plain HTTP is authentication, not transport encryption. Do not treat the token alone as network confidentiality.

## Dynamic resolution helper

v2.1/v2.2 can issue remote commands similar to:
```bash
DISPLAY=:1 xrandr --fb 1024x768
```

Actual success depends on the X/VNC server configuration. Test manual `Match iPad` before enabling automatic orientation-driven resize.

## TLS / VeNCrypt

Experimental v2.2 work targets X509Vnc.

Do not alter the known-good TigerVNC configuration solely to force TLS testing until:
- baseline Tight/Hextile remains working,
- SSH tunnel is working,
- there is a rollback path.
