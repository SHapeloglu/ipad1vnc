#!/usr/bin/env bash
set -euo pipefail
sudo apt update
sudo apt install -y tigervnc-standalone-server tigervnc-tools dbus-x11 xfce4
mkdir -p "$HOME/.vnc"
cat > "$HOME/.vnc/xstartup" <<'XSTART'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session startxfce4
XSTART
chmod +x "$HOME/.vnc/xstartup"
printf '\nRun vncpasswd, then start:\n'
printf '  vncserver :1 -geometry 1024x768 -depth 24 -localhost no\n'
printf '\nRestrict TCP 5901 in your firewall to trusted source IPs.\n'
