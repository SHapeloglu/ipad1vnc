#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
p = root / "src" / "AppDelegate.m"
s = p.read_text()

# Rename the setup label so the control reflects both TLSVnc and X509Vnc support.
s = s.replace('tlsLabel.text=@"X509 TLS";', 'tlsLabel.text=@"TLS";', 1)

# Make switch changes explicit on the iPad before reconnecting.
old = '- (void)tlsChanged { [self saveConnectionSettings]; _statusLabel.text=(_tlsSwitch.on?@"X509 VeNCrypt TLS enabled — reconnect":@"Direct VNC security mode"); }'
new = '- (void)tlsChanged { [self saveConnectionSettings]; _statusLabel.text=(_tlsSwitch.on?@"TLS requested — reconnect required":@"Plain VNC requested — reconnect required"); }'
if old in s:
    s = s.replace(old, new, 1)

# Snapshot the UI switch exactly once for the new connection. This makes the
# requested mode visible and ensures the same value is passed to VNCClient.
needle = '''    NSString *host=[_hostField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSInteger port=[_portField.text integerValue];if(![host length]||port<=0){_statusLabel.text=@"Host/port required";return;}
    [_client disconnect];[_client release];_client=nil;
    NSString *connectHost=host;NSInteger connectPort=port;
'''
repl = '''    NSString *host=[_hostField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSInteger port=[_portField.text integerValue];if(![host length]||port<=0){_statusLabel.text=@"Host/port required";return;}
    BOOL requestedTLS=(_tlsSwitch&&_tlsSwitch.on);
    _statusLabel.text=(requestedTLS?@"Connecting — TLS requested":@"Connecting — Plain requested");
    [_client disconnect];[_client release];_client=nil;
    NSString *connectHost=host;NSInteger connectPort=port;
'''
if needle not in s:
    if 'BOOL requestedTLS=(_tlsSwitch&&_tlsSwitch.on);' not in s:
        raise SystemExit('startConnection snapshot anchor not found')
else:
    s = s.replace(needle, repl, 1)

old_assign = '_client.preferTight=_tightSwitch.on;_client.preferX509TLS=_tlsSwitch.on;'
new_assign = '_client.preferTight=_tightSwitch.on;_client.preferX509TLS=requestedTLS;'
if old_assign in s:
    s = s.replace(old_assign, new_assign, 1)
elif new_assign not in s:
    raise SystemExit('VNCClient TLS assignment anchor not found')

p.write_text(s)
print('OK: beta4 TLS request-state diagnostics applied')
