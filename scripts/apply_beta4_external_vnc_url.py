#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
app = root / "src" / "AppDelegate.m"
plist = root / "Resources" / "Info.plist"

ms = app.read_text()
ps = plist.read_text()

# Declare helper in the private interface.
if "- (BOOL)handleVNCURL:(NSURL*)url;" not in ms:
    anchor = "- (void)disconnectManually;\n@end"
    repl = "- (void)disconnectManually;\n- (BOOL)handleVNCURL:(NSURL*)url;\n@end"
    if anchor not in ms:
        raise SystemExit("AppDelegate private-interface anchor not found")
    ms = ms.replace(anchor, repl, 1)

# Add an iOS 5-compatible external VNC URL handler. No secrets are accepted.
# Use the query-helper implementation as the idempotency marker: the method
# declaration above must not prevent the implementation block from being added.
if "- (NSDictionary*)ipad1vncQueryDictionary:(NSURL*)url {" not in ms:
    insert_at = ms.rfind("@end")
    if insert_at < 0:
        raise SystemExit("AppDelegate implementation end not found")

    block = r'''

- (NSDictionary*)ipad1vncQueryDictionary:(NSURL*)url {
    NSMutableDictionary *out=[NSMutableDictionary dictionary];
    NSString *q=[url query];
    if(![q length])return out;
    for(NSString *part in [q componentsSeparatedByString:@"&"]){
        NSRange eq=[part rangeOfString:@"="];
        NSString *k=nil,*v=nil;
        if(eq.location==NSNotFound){k=part;v=@"";}
        else{k=[part substringToIndex:eq.location];v=[part substringFromIndex:eq.location+1];}
        k=[k stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        v=[v stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if([k length])[out setObject:(v?:@"") forKey:k];
    }
    return out;
}

- (BOOL)handleVNCURL:(NSURL*)url {
    if(!url||![[[url scheme] lowercaseString] isEqualToString:@"ipad1vnc"])return NO;
    NSString *action=[[url host] lowercaseString];
    NSDictionary *q=[self ipad1vncQueryDictionary:url];
    BOOL autoConnect=[[[q objectForKey:@"autoconnect"] description] boolValue];

    if([action isEqualToString:@"profile"]){
        NSString *pid=[q objectForKey:@"id"];
        if(![pid length]){_statusLabel.text=@"External VNC profile request missing id";return YES;}
        NSInteger found=-1;
        for(NSUInteger i=0;i<[_profiles count];i++){
            NSDictionary *p=[_profiles objectAtIndex:i];
            if([[[p objectForKey:@"id"] description] isEqualToString:pid]){found=(NSInteger)i;break;}
        }
        if(found<0){_statusLabel.text=@"External VNC profile not found";return YES;}
        [self loadProfileAtIndex:found];
        _statusLabel.text=@"External VNC profile loaded";
        if(autoConnect&&!_client)[self connectTapped];
        return YES;
    }

    if(![action isEqualToString:@"connect"]){_statusLabel.text=@"Unsupported iPad1VNC URL action";return YES;}

    NSString *host=[q objectForKey:@"host"];
    if(![host length]||[host length]>255){_statusLabel.text=@"External VNC request has invalid host";return YES;}

    // Direct host requests are configuration-only. Never reuse a password left in the UI
    // for a different externally supplied host. Password-bearing auto-connect belongs to
    // the saved-profile route, where the secret is loaded locally from Keychain.
    _hostField.text=host;
    _passwordField.text=@"";

    NSString *portText=[q objectForKey:@"port"];
    if([portText length]){
        NSInteger port=[portText integerValue];
        if(port<1||port>65535){_statusLabel.text=@"External VNC request has invalid port";return YES;}
        _portField.text=[NSString stringWithFormat:@"%ld",(long)port];
    }

    NSString *tls=[q objectForKey:@"tls"];
    if([tls length])_tlsSwitch.on=[tls boolValue];
    NSString *tight=[q objectForKey:@"tight"];
    if([tight length])_tightSwitch.on=[tight boolValue];

    NSString *quality=[q objectForKey:@"quality"];
    if([quality length]){
        NSInteger n=[quality integerValue];
        if(n>=0&&n<=3)_qualityControl.selectedSegmentIndex=n;
    }
    NSString *input=[q objectForKey:@"input"];
    if([input length]){
        NSInteger n=[input integerValue];
        if(n>=0&&n<=1){_inputModeControl.selectedSegmentIndex=n;_vncView.inputMode=(VNCInputMode)n;}
    }

    [self saveConnectionSettings];
    if(autoConnect){
        _statusLabel.text=@"External VNC loaded — enter password, then Connect";
    }else{
        _statusLabel.text=@"External VNC request loaded";
    }
    return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    (void)application;
    return [self handleVNCURL:url];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    (void)application;(void)sourceApplication;(void)annotation;
    return [self handleVNCURL:url];
}
'''
    ms = ms[:insert_at] + block + "\n" + ms[insert_at:]

# Register the URL scheme without relying on modern APIs.
if "<string>ipad1vnc</string>" not in ps:
    anchor = "    <key>LSRequiresIPhoneOS</key><true/>\n"
    block = '''    <key>CFBundleURLTypes</key>\n    <array>\n        <dict>\n            <key>CFBundleURLName</key><string>com.olap.ipad1vnc.external</string>\n            <key>CFBundleURLSchemes</key>\n            <array><string>ipad1vnc</string></array>\n        </dict>\n    </array>\n'''
    if anchor not in ps:
        raise SystemExit("Info.plist URL-scheme anchor not found")
    ps = ps.replace(anchor, block + anchor, 1)

app.write_text(ms)
plist.write_text(ps)
print("OK: safe ipad1vnc:// external VNC invocation applied")
