#import "AppDelegate.h"
#import "VNCClient.h"
#import "VNCView.h"
#import "TerminalSession.h"
#import "LegacyTerminalBuffer.h"
#import "KeychainStore.h"
#import <arpa/inet.h>
#import <sys/socket.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <fcntl.h>
#import <sys/select.h>
#import <netinet/in.h>
#import <arpa/inet.h>

@interface RotationViewController : UIViewController
@end

@implementation RotationViewController
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation { (void)interfaceOrientation; return YES; }
- (BOOL)shouldAutorotate { return YES; }
- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
@end

@interface AppDelegate () <VNCClientDelegate, TerminalSessionDelegate>
- (void)connectTapped;
- (void)terminalTapped;
- (void)closeTerminalTapped;
- (void)terminalSendTapped;
- (void)terminalConnectTapped;
- (void)terminalDisconnectTapped;
- (void)terminalSpecialKeyTapped:(UIButton*)sender;
- (void)generateSSHKeyTapped;
- (void)buildTerminalPanel;
- (void)tightChanged;
- (void)tlsChanged;
- (void)profilesTapped;
- (void)deleteProfileAtIndex:(NSInteger)index;
- (void)showProfileActionsAtIndex:(NSInteger)index;

- (void)keyboardTapped;
- (void)extendedKeysTapped;
- (void)sendExtendedKeyAtIndex:(NSInteger)index;

- (void)filesTapped;
- (void)closeFilesTapped;
- (void)filesUpTapped;
- (void)downloadTapped;
- (void)cancelDownloadTapped;
- (void)refreshFileList;
- (void)startBrowseURL:(NSURL*)url;
- (void)startDownloadFromURL:(NSURL*)url;
- (void)parseDirectoryHTML:(NSData*)data baseURL:(NSURL*)baseURL;
- (NSString*)downloadsDirectory;
- (NSString*)uniqueDownloadPathForName:(NSString*)name;
- (NSString*)remotePathForEntry:(NSDictionary*)e;
- (NSURL*)downloadURLForEntry:(NSDictionary*)e;
- (void)renameRemoteEntry:(NSDictionary*)entry;
- (void)deleteRemoteEntry:(NSDictionary*)entry;
- (void)mkdirRemote;
- (void)uploadLocalFile;
- (NSDictionary*)remoteStatPath:(NSString*)path;
- (void)enqueueTransfer:(NSDictionary*)item;
- (void)startNextTransfer;
- (void)pauseTransferTapped;
- (void)showTransferQueueTapped;
- (void)streamUploadInfo:(NSDictionary*)info;
- (void)uploadProgressMain:(NSNumber*)n;
- (void)uploadFinishedMain:(NSString*)s;
- (void)performFileAPIPath:(NSString*)path method:(NSString*)method body:(NSData*)body contentType:(NSString*)contentType;

- (void)saveConnectionSettings;
- (void)setControlsCollapsed:(BOOL)collapsed animated:(BOOL)animated;
- (void)toolsTapped;
- (void)closeToolsTapped;
- (void)precisionChanged;
- (void)dragLockChanged;
- (void)scanLANTapped;
- (void)scanLANThread;
- (void)scanLANFinished:(NSArray*)results;
- (NSString*)localIPv4;
- (BOOL)portOpenHost:(NSString*)host port:(NSInteger)port timeoutMS:(NSInteger)timeoutMS;
- (void)showLANResults;
- (void)wakeTapped;
- (void)matchResolutionTapped;
- (void)orientationChanged:(NSNotification*)note;
- (BOOL)sendWakePacketMAC:(NSString*)mac broadcast:(NSString*)broadcast;
- (NSString*)currentProfileID;
- (void)migrateSecretsToKeychain;
- (void)terminalSessionEnded:(NSString*)reason;
- (void)disconnectManually;
@end

@implementation AppDelegate
@synthesize window = _window;

- (NSDictionary*)remoteStatPath:(NSString*)path {
    if(!_remoteBaseURL)return nil;NSString *esc=[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];NSURL*u=[NSURL URLWithString:[NSString stringWithFormat:@"%@/api/stat?path=%@",[_remoteBaseURL absoluteString],esc]];
    NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:u cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];if([_filesToken length])[r setValue:_filesToken forHTTPHeaderField:@"X-iPad1VNC-Token"];NSData*d=[NSURLConnection sendSynchronousRequest:r returningResponse:nil error:nil];if(!d)return nil;id o=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil];return [o isKindOfClass:[NSDictionary class]]?o:nil;
}

- (void)enqueueTransfer:(NSDictionary*)item {
    if(!item)return;[_transferQueue addObject:item];_downloadStatusLabel.text=[NSString stringWithFormat:@"Queued: %lu",(unsigned long)[_transferQueue count]];[self startNextTransfer];
}

- (void)startNextTransfer {
    if(_currentTransfer||_transferPaused||![_transferQueue count])return;
    _currentTransfer=[[_transferQueue objectAtIndex:0] retain];[_transferQueue removeObjectAtIndex:0];
    NSString*type=[_currentTransfer objectForKey:@"type"];
    if([type isEqualToString:@"upload"])[NSThread detachNewThreadSelector:@selector(streamUploadInfo:) toTarget:self withObject:_currentTransfer];
    else if([type isEqualToString:@"download"])[self startDownloadFromURL:[_currentTransfer objectForKey:@"url"]];
}

- (void)pauseTransferTapped {
    _transferPaused=!_transferPaused;
    if(_transferPaused){if(_downloadConnection)[self cancelDownloadTapped];_uploading=NO;_downloadStatusLabel.text=@"Transfers paused";}else{_downloadStatusLabel.text=@"Transfers resumed";[self startNextTransfer];}
}

- (void)showTransferQueueTapped {
    NSMutableString*s=[NSMutableString stringWithFormat:@"Current: %@\nQueued: %lu\n",(_currentTransfer?[[_currentTransfer objectForKey:@"name"] description]:@"none"),(unsigned long)[_transferQueue count]];
    for(NSDictionary*i in _transferQueue)[s appendFormat:@"%@ — %@\n",[i objectForKey:@"type"],[i objectForKey:@"name"]?:@""];
    UIAlertView*a=[[[UIAlertView alloc]initWithTitle:@"Transfer Queue" message:s delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]autorelease];[a show];
}

- (void)precisionChanged {
    _vncView.precisionMode=_precisionSwitch.on;
    [[NSUserDefaults standardUserDefaults]setBool:_precisionSwitch.on forKey:@"precisionMode"];[[NSUserDefaults standardUserDefaults]synchronize];
    _statusLabel.text=(_precisionSwitch.on?@"Precision pointer 0.3x":@"Normal pointer precision");
}

- (void)dragLockChanged {
    _vncView.dragLock=_dragLockSwitch.on;
    [[NSUserDefaults standardUserDefaults]setBool:_dragLockSwitch.on forKey:@"dragLock"];[[NSUserDefaults standardUserDefaults]synchronize];
    _statusLabel.text=(_dragLockSwitch.on?@"Drag Lock enabled — double tap toggles drag":@"Drag Lock disabled");
}

- (NSString*)localIPv4 {
    struct ifaddrs *ifaddr=NULL;if(getifaddrs(&ifaddr)!=0)return nil;NSString *result=nil;
    for(struct ifaddrs *ifa=ifaddr;ifa;ifa=ifa->ifa_next){
        if(!ifa->ifa_addr||ifa->ifa_addr->sa_family!=AF_INET)continue;
        if(!(ifa->ifa_flags&IFF_UP)||(ifa->ifa_flags&IFF_LOOPBACK))continue;
        struct sockaddr_in *sa=(struct sockaddr_in*)ifa->ifa_addr;char b[INET_ADDRSTRLEN]={0};
        if(inet_ntop(AF_INET,&sa->sin_addr,b,sizeof(b))){result=[NSString stringWithUTF8String:b];if([[NSString stringWithUTF8String:ifa->ifa_name] isEqualToString:@"en0"])break;}
    }
    freeifaddrs(ifaddr);return result;
}

- (BOOL)portOpenHost:(NSString*)host port:(NSInteger)port timeoutMS:(NSInteger)timeoutMS {
    int fd=socket(AF_INET,SOCK_STREAM,0);if(fd<0)return NO;int fl=fcntl(fd,F_GETFL,0);fcntl(fd,F_SETFL,fl|O_NONBLOCK);
    struct sockaddr_in a;memset(&a,0,sizeof(a));a.sin_family=AF_INET;a.sin_port=htons((uint16_t)port);if(inet_aton([host UTF8String],&a.sin_addr)==0){close(fd);return NO;}
    int r=connect(fd,(struct sockaddr*)&a,sizeof(a));if(r==0){close(fd);return YES;}if(errno!=EINPROGRESS){close(fd);return NO;}
    fd_set wf;FD_ZERO(&wf);FD_SET(fd,&wf);struct timeval tv;tv.tv_sec=timeoutMS/1000;tv.tv_usec=(timeoutMS%1000)*1000;
    r=select(fd+1,NULL,&wf,NULL,&tv);BOOL ok=NO;if(r>0&&FD_ISSET(fd,&wf)){int e=0;socklen_t l=sizeof(e);getsockopt(fd,SOL_SOCKET,SO_ERROR,&e,&l);ok=(e==0);}close(fd);return ok;
}

- (void)scanLANTapped {
    _scanLANButton.enabled=NO;_diagnosticsLabel.text=@"Scanning local /24 for SSH and VNC…";
    [NSThread detachNewThreadSelector:@selector(scanLANThread) toTarget:self withObject:nil];
}

- (void)scanLANThread {
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc]init];NSString *ip=[self localIPv4];NSMutableArray *found=[NSMutableArray array];
    if([ip length]){
        NSArray *p=[ip componentsSeparatedByString:@"."];if([p count]==4){
            NSString *prefix=[NSString stringWithFormat:@"%@.%@.%@.",[p objectAtIndex:0],[p objectAtIndex:1],[p objectAtIndex:2]];
            NSInteger vp=[_portField.text integerValue];if(vp<=0)vp=5901;
            for(int i=1;i<255;i++){
                if(i%16==0&&![NSThread currentThread].isCancelled){}
                NSString *host=[prefix stringByAppendingFormat:@"%d",i];
                BOOL ssh=[self portOpenHost:host port:22 timeoutMS:35];
                BOOL vnc=[self portOpenHost:host port:vp timeoutMS:35];
                if(ssh||vnc)[found addObject:[NSDictionary dictionaryWithObjectsAndKeys:host,@"host",[NSNumber numberWithBool:ssh],@"ssh",[NSNumber numberWithBool:vnc],@"vnc",nil]];
            }
        }
    }
    [self performSelectorOnMainThread:@selector(scanLANFinished:) withObject:[NSArray arrayWithArray:found] waitUntilDone:NO];[pool drain];
}

- (void)scanLANFinished:(NSArray*)results {
    [_lanResults removeAllObjects];[_lanResults addObjectsFromArray:results];_scanLANButton.enabled=YES;
    if(![_lanResults count]){_diagnosticsLabel.text=@"LAN scan finished: no SSH/VNC hosts found.";return;}
    NSMutableString *s=[NSMutableString stringWithFormat:@"LAN scan: %lu host(s)\n",(unsigned long)[_lanResults count]];
    for(NSDictionary *r in _lanResults)[s appendFormat:@"%@  %@ %@\n",[r objectForKey:@"host"],[[r objectForKey:@"ssh"]boolValue]?@"SSH":@"",[[r objectForKey:@"vnc"]boolValue]?@"VNC":@""];
    _diagnosticsLabel.text=s;[self showLANResults];
}

- (void)showLANResults {
    if(![_lanResults count])return;UIActionSheet *s=[[[UIActionSheet alloc]initWithTitle:@"LAN Hosts — tap to use" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil]autorelease];s.tag=950;
    NSUInteger max=MIN((NSUInteger)12,[_lanResults count]);for(NSUInteger i=0;i<max;i++){NSDictionary*r=[_lanResults objectAtIndex:i];[s addButtonWithTitle:[NSString stringWithFormat:@"%@  %@%@",[r objectForKey:@"host"],[[r objectForKey:@"ssh"]boolValue]?@"SSH ":@"",[[r objectForKey:@"vnc"]boolValue]?@"VNC":@""]];}
    s.cancelButtonIndex=[s addButtonWithTitle:@"Cancel"];[s showInView:_controller.view];
}



- (void)tightChanged { [self saveConnectionSettings]; _statusLabel.text=(_tightSwitch.on?@"Tight ON: 24-bit transport; reconnect":@"Hextile/RAW mode; reconnect"); }
- (void)tlsChanged { [self saveConnectionSettings]; _statusLabel.text=(_tlsSwitch.on?@"X509 VeNCrypt TLS enabled — reconnect":@"Direct VNC security mode"); }
- (void)vncClientStatsFPS:(CGFloat)fps avgFPS:(CGFloat)avgFPS kbps:(CGFloat)kbps latency:(CGFloat)latency avgLatency:(CGFloat)avgLatency maxLatency:(CGFloat)maxLatency encoding:(NSString*)encoding quality:(NSString*)quality uptime:(NSTimeInterval)uptime totalFrames:(unsigned long long)totalFrames {
    NSInteger sec=(NSInteger)uptime;NSInteger hh=sec/3600,mm=(sec%3600)/60,ss=sec%60;
    NSString *health=@"Excellent";
    if(latency>180||fps<5)health=@"Poor";else if(latency>90||fps<9)health=@"Good";
    _statsLabel.text=[NSString stringWithFormat:@"%.0fms | %.1f FPS | %.0f kbps | %@",latency,fps,kbps,encoding];
    if(_diagnosticsLabel)_diagnosticsLabel.text=[NSString stringWithFormat:
        @"Network: %@\nRTT now: %.0f ms\nRTT avg: %.0f ms\nRTT max: %.0f ms\nFPS now: %.1f\nFPS avg: %.1f\nTraffic: %.0f kbps\nFrames: %llu\nEncoding: %@\nQuality: %@\nUptime: %02ld:%02ld:%02ld\nReconnects: %lu",
        health,latency,avgLatency,maxLatency,fps,avgFPS,kbps,totalFrames,encoding,quality,(long)hh,(long)mm,(long)ss,(unsigned long)_reconnectCount];
}

- (void)buildTerminalPanel {
    if(_terminalPanel)return;
    CGFloat w=_controller.view.bounds.size.width,h=_controller.view.bounds.size.height,pw=MIN(900.0,w-20),ph=MIN(680.0,h-20);
    _terminalPanel=[[UIView alloc] initWithFrame:CGRectMake((w-pw)/2,(h-ph)/2,pw,ph)];
    _terminalPanel.autoresizingMask=(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight);_terminalPanel.backgroundColor=[UIColor colorWithWhite:0.06 alpha:0.98];_terminalPanel.hidden=YES;
    UILabel *title=[[[UILabel alloc] initWithFrame:CGRectMake(14,8,180,30)] autorelease];title.backgroundColor=[UIColor clearColor];title.textColor=[UIColor whiteColor];title.text=@"SSH Terminal";title.font=[UIFont boldSystemFontOfSize:16];[_terminalPanel addSubview:title];
    UIButton *connectSSH=[UIButton buttonWithType:UIButtonTypeRoundedRect];connectSSH.frame=CGRectMake(pw-270,6,80,32);[connectSSH setTitle:@"Connect" forState:UIControlStateNormal];[connectSSH addTarget:self action:@selector(terminalConnectTapped) forControlEvents:UIControlEventTouchUpInside];[_terminalPanel addSubview:connectSSH];
    UIButton *disconnectSSH=[UIButton buttonWithType:UIButtonTypeRoundedRect];disconnectSSH.frame=CGRectMake(pw-185,6,80,32);[disconnectSSH setTitle:@"Stop" forState:UIControlStateNormal];[disconnectSSH addTarget:self action:@selector(terminalDisconnectTapped) forControlEvents:UIControlEventTouchUpInside];[_terminalPanel addSubview:disconnectSSH];
    UIButton *close=[UIButton buttonWithType:UIButtonTypeRoundedRect];close.frame=CGRectMake(pw-100,6,86,32);[close setTitle:@"Close" forState:UIControlStateNormal];[close addTarget:self action:@selector(closeTerminalTapped) forControlEvents:UIControlEventTouchUpInside];[_terminalPanel addSubview:close];

    _sshUserField=[[UITextField alloc] initWithFrame:CGRectMake(14,44,120,34)];_sshUserField.borderStyle=UITextBorderStyleRoundedRect;_sshUserField.placeholder=@"SSH user";_sshUserField.text=[[NSUserDefaults standardUserDefaults] stringForKey:@"sshUser"];[_terminalPanel addSubview:_sshUserField];
    _sshPortField=[[UITextField alloc] initWithFrame:CGRectMake(140,44,70,34)];_sshPortField.borderStyle=UITextBorderStyleRoundedRect;_sshPortField.keyboardType=UIKeyboardTypeNumberPad;_sshPortField.placeholder=@"22";NSString*sp=[[NSUserDefaults standardUserDefaults]stringForKey:@"sshPort"];_sshPortField.text=([sp length]?sp:@"22");[_terminalPanel addSubview:_sshPortField];
    _sshKeyField=[[UITextField alloc] initWithFrame:CGRectMake(216,44,pw-430,34)];_sshKeyField.borderStyle=UITextBorderStyleRoundedRect;_sshKeyField.placeholder=@"/var/mobile/.ssh/id_rsa";_sshKeyField.text=[[NSUserDefaults standardUserDefaults]stringForKey:@"sshKey"];[_terminalPanel addSubview:_sshKeyField];
    UILabel *tl=[[[UILabel alloc]initWithFrame:CGRectMake(pw-205,46,90,30)]autorelease];tl.backgroundColor=[UIColor clearColor];tl.textColor=[UIColor whiteColor];tl.font=[UIFont systemFontOfSize:12];tl.text=@"VNC Tunnel";[_terminalPanel addSubview:tl];
    _sshTunnelSwitch=[[UISwitch alloc]initWithFrame:CGRectMake(pw-105,44,90,30)];_sshTunnelSwitch.on=[[NSUserDefaults standardUserDefaults] boolForKey:@"sshTunnel"];[_terminalPanel addSubview:_sshTunnelSwitch];

    _terminalView=[[UITextView alloc] initWithFrame:CGRectMake(14,84,pw-28,ph-150)];_terminalView.backgroundColor=[UIColor blackColor];_terminalView.textColor=[UIColor whiteColor];_terminalView.font=[UIFont fontWithName:@"Courier" size:13];_terminalView.editable=NO;[_terminalPanel addSubview:_terminalView];
    UIButton *gen=[UIButton buttonWithType:UIButtonTypeRoundedRect];gen.frame=CGRectMake(pw-365,6,90,32);[gen setTitle:@"Gen Key" forState:UIControlStateNormal];[gen addTarget:self action:@selector(generateSSHKeyTapped) forControlEvents:UIControlEventTouchUpInside];[_terminalPanel addSubview:gen];

    _terminalKeyBar=[[UIView alloc] initWithFrame:CGRectMake(14,ph-100,pw-28,34)];
    NSArray *kt=[NSArray arrayWithObjects:@"Esc",@"Ctrl-C",@"Tab",@"Home",@"End",@"PgUp",@"PgDn",@"←",@"↑",@"↓",@"→",nil];
    CGFloat kbw=(pw-28)/(CGFloat)[kt count];
    for(NSUInteger i=0;i<[kt count];i++){UIButton*b=[UIButton buttonWithType:UIButtonTypeRoundedRect];b.frame=CGRectMake(i*kbw,0,kbw-2,32);b.tag=600+i;[b setTitle:[kt objectAtIndex:i] forState:UIControlStateNormal];[b addTarget:self action:@selector(terminalSpecialKeyTapped:) forControlEvents:UIControlEventTouchUpInside];[_terminalKeyBar addSubview:b];}
    [_terminalPanel addSubview:_terminalKeyBar];
    _terminalView.frame=CGRectMake(14,84,pw-28,ph-190);

    _terminalInput=[[UITextField alloc] initWithFrame:CGRectMake(14,ph-58,pw-110,40)];_terminalInput.borderStyle=UITextBorderStyleRoundedRect;_terminalInput.placeholder=@"Command…";_terminalInput.delegate=self;[_terminalPanel addSubview:_terminalInput];
    UIButton *send=[UIButton buttonWithType:UIButtonTypeRoundedRect];send.frame=CGRectMake(pw-90,ph-58,76,40);[send setTitle:@"Send" forState:UIControlStateNormal];[send addTarget:self action:@selector(terminalSendTapped) forControlEvents:UIControlEventTouchUpInside];[_terminalPanel addSubview:send];
    [_controller.view addSubview:_terminalPanel];
}
- (void)terminalSpecialKeyTapped:(UIButton*)sender {
    NSArray *s=[NSArray arrayWithObjects:@"\033",@"\003",@"\t",@"\033[H",@"\033[F",@"\033[5~",@"\033[6~",@"\033[D",@"\033[A",@"\033[B",@"\033[C",nil];
    NSInteger i=sender.tag-600;if(i>=0&&i<(NSInteger)[s count])[_terminalSession sendText:[s objectAtIndex:i]];
}
- (void)generateSSHKeyTapped {
    NSString *path=[_sshKeyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(![path length]){path=@"/var/mobile/.ssh/ipad1vnc_rsa";_sshKeyField.text=path;}
    if(!_terminalSession)_terminalSession=[[TerminalSession alloc]init];
    BOOL ok=[_terminalSession generateRSAKeyAtPath:path];
    _terminalView.text=[_terminalView.text stringByAppendingString:(ok?@"\n[SSH RSA key generated]\n":@"\n[ssh-keygen failed]\n")];
}
- (void)terminalTapped {
    [self buildTerminalPanel];
    _terminalPanel.hidden=NO;
    [_controller.view bringSubviewToFront:_terminalPanel];
    if(!_terminalSession){_terminalSession=[[TerminalSession alloc] init];_terminalSession.delegate=self;}
    if(!_terminalSession.running)_terminalView.text=[_terminalView.text stringByAppendingString:@"Enter SSH user/port/key, then tap Connect.\n"];
}
- (void)terminalConnectTapped {
    if(!_terminalSession){
        _terminalSession=[[TerminalSession alloc] init];
        _terminalSession.delegate=self;
    }
    if(_terminalSession.running){
        _terminalView.text=[_terminalView.text stringByAppendingString:@"\n[SSH already connected]\n"];
        return;
    }

    NSString *host=[_hostField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *user=[_sshUserField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *key=[_sshKeyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSInteger port=[_sshPortField.text integerValue]; if(port<=0)port=22;

    if(![host length]){
        _terminalView.text=[_terminalView.text stringByAppendingString:@"\n[Host is empty]\n"];
        return;
    }
    if(![user length]){
        _terminalView.text=[_terminalView.text stringByAppendingString:@"\n[SSH User is required]\n"];
        return;
    }

    [[NSUserDefaults standardUserDefaults] setObject:user forKey:@"sshUser"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%ld",(long)port] forKey:@"sshPort"];
    [[NSUserDefaults standardUserDefaults] setObject:(key?:@"") forKey:@"sshKey"];
    [[NSUserDefaults standardUserDefaults] setBool:_sshTunnelSwitch.on forKey:@"sshTunnel"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    _terminalView.text=[_terminalView.text stringByAppendingFormat:@"\nConnecting as %@@%@:%ld …\n",user,host,(long)port];
    BOOL ok=[_terminalSession startSSHHost:host port:port user:user keyPath:key command:nil];
    if(!ok){
        _terminalView.text=[_terminalView.text stringByAppendingString:@"[Could not start SSH]\n"];
    }
}
- (void)terminalDisconnectTapped {
    if(_terminalSession && _terminalSession.running)[_terminalSession stop];
    _terminalView.text=[_terminalView.text stringByAppendingString:@"\n[SSH stopped]\n"];
}

- (void)closeTerminalTapped {_terminalPanel.hidden=YES;}
- (void)terminalSendTapped {NSString *s=_terminalInput.text;if(![s length])return;[_terminalSession sendText:[s stringByAppendingString:@"\n"]];_terminalInput.text=@"";}
- (void)terminalSessionOutput:(NSString*)text {
    if(![text length])return;
    if(!_terminalBuffer)_terminalBuffer=[[LegacyTerminalBuffer alloc] initWithColumns:100 rows:32];
    [_terminalBuffer appendTerminalText:text];
    _terminalView.text=[_terminalBuffer renderString];
    NSRange r=NSMakeRange([_terminalView.text length],0);[_terminalView scrollRangeToVisible:r];
}

- (void)terminalSessionEnded:(NSString*)reason {
    if(!_terminalBuffer)_terminalBuffer=[[LegacyTerminalBuffer alloc] initWithColumns:100 rows:32];
    NSString *line=[NSString stringWithFormat:@"\n[%@]\n",(reason?:@"SSH session ended")];
    [_terminalBuffer appendTerminalText:line];
    _terminalView.text=[_terminalBuffer renderString];
    NSRange r=NSMakeRange([_terminalView.text length],0);
    [_terminalView scrollRangeToVisible:r];
}

- (void)profilesTapped {
    if(!_profiles){NSArray*s=[[NSUserDefaults standardUserDefaults]arrayForKey:@"profiles"];_profiles=[[NSMutableArray alloc]initWithArray:(s?s:[NSArray array])];}
    UIActionSheet *sheet=[[[UIActionSheet alloc]initWithTitle:@"Connection Profiles" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil]autorelease];
    for(NSDictionary*p in _profiles)[sheet addButtonWithTitle:[p objectForKey:@"name"]];
    [sheet addButtonWithTitle:@"Save Current…"];
    [sheet addButtonWithTitle:@"Manage…"];
    sheet.cancelButtonIndex=[sheet addButtonWithTitle:@"Cancel"];
    [sheet showInView:_controller.view];
}
- (void)actionSheet:(UIActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(actionSheet.tag==950){
        if(buttonIndex>=0&&buttonIndex<(NSInteger)MIN((NSUInteger)12,[_lanResults count])){NSDictionary*r=[_lanResults objectAtIndex:buttonIndex];_hostField.text=[r objectForKey:@"host"];[self saveConnectionSettings];_statusLabel.text=[NSString stringWithFormat:@"LAN host selected: %@",[r objectForKey:@"host"]];}return;
    }
    if(actionSheet.tag==902){
        if(_selectedProfileIndex<0||_selectedProfileIndex>=(NSInteger)[_profiles count])return;
        NSDictionary *p=[_profiles objectAtIndex:_selectedProfileIndex];
        if(buttonIndex==0){[self loadProfileAtIndex:_selectedProfileIndex];[self connectTapped];return;}
        if(buttonIndex==1){[self loadProfileAtIndex:_selectedProfileIndex];[self terminalTapped];return;}
        if(buttonIndex==2){[self loadProfileAtIndex:_selectedProfileIndex];[self filesTapped];return;}
        if(buttonIndex==3){[self loadProfileAtIndex:_selectedProfileIndex];if(_wolMACField&&[_wolMACField.text length])[self wakeTapped];else _statusLabel.text=@"Profile has no WOL MAC";return;}
        if(buttonIndex==4){[self loadProfileAtIndex:_selectedProfileIndex];[self setControlsCollapsed:NO animated:YES];return;}
        if(buttonIndex==5){[self loadProfileAtIndex:_selectedProfileIndex];[self saveProfileNamed:[NSString stringWithFormat:@"%@ Copy",[p objectForKey:@"name"]]];return;}
        if(buttonIndex==6){[self deleteProfileAtIndex:_selectedProfileIndex];return;}
        return;
    }
    if(actionSheet.tag==960){if(buttonIndex>=0&&buttonIndex<19)[self sendExtendedKeyAtIndex:buttonIndex];return;}
    if(actionSheet.tag==970){return;}

    if(buttonIndex<0)return;
    if(actionSheet.tag==920){
        if(_selectedRemoteIndex<0||_selectedRemoteIndex>=(NSInteger)[_remoteEntries count])return;NSDictionary*e=[_remoteEntries objectAtIndex:_selectedRemoteIndex];
        if(buttonIndex==0){[self deleteRemoteEntry:e];return;}if(buttonIndex==1){NSURL*u=[self downloadURLForEntry:e];NSDictionary*q=[NSDictionary dictionaryWithObjectsAndKeys:@"download",@"type",([e objectForKey:@"name"]?:@"file"),@"name",u,@"url",nil];[self enqueueTransfer:q];return;}if(buttonIndex==2){[self renameRemoteEntry:e];return;}return;
    }
    if(actionSheet.tag==921){
        NSArray*files=[[NSFileManager defaultManager]contentsOfDirectoryAtPath:[self downloadsDirectory] error:nil];if(buttonIndex>=0&&buttonIndex<(NSInteger)[files count]){NSString*name=[files objectAtIndex:buttonIndex],*lp=[[self downloadsDirectory]stringByAppendingPathComponent:name];NSString*rp=([_remoteRelativePath length]?[_remoteRelativePath stringByAppendingPathComponent:name]:name);NSDictionary*info=[NSDictionary dictionaryWithObjectsAndKeys:@"upload",@"type",name,@"name",lp,@"local",rp,@"remote",nil];[self enqueueTransfer:info];}return;
    }
    if(actionSheet.tag==901){
        if(buttonIndex==0){[self deleteProfileAtIndex:_selectedProfileIndex];return;}
        if(buttonIndex==1){[self loadProfileAtIndex:_selectedProfileIndex];return;}
        if(buttonIndex==2){NSDictionary*src=[_profiles objectAtIndex:_selectedProfileIndex];[self loadProfileAtIndex:_selectedProfileIndex];[self saveProfileNamed:[NSString stringWithFormat:@"%@ Copy",[src objectForKey:@"name"]]];return;}
        if(buttonIndex==3){NSDictionary*pr=[_profiles objectAtIndex:_selectedProfileIndex];[[NSUserDefaults standardUserDefaults]setObject:[pr objectForKey:@"id"] forKey:@"defaultProfileID"];[[NSUserDefaults standardUserDefaults]synchronize];_statusLabel.text=@"Default profile set";return;}
        if(buttonIndex==4){NSMutableDictionary*pr=[NSMutableDictionary dictionaryWithDictionary:[_profiles objectAtIndex:_selectedProfileIndex]];BOOL v=![[pr objectForKey:@"autoConnect"]boolValue];[pr setObject:[NSNumber numberWithBool:v] forKey:@"autoConnect"];[_profiles replaceObjectAtIndex:_selectedProfileIndex withObject:pr];[[NSUserDefaults standardUserDefaults]setObject:_profiles forKey:@"profiles"];[[NSUserDefaults standardUserDefaults]synchronize];_statusLabel.text=(v?@"Auto Connect ON":@"Auto Connect OFF");return;}return;
    }
    if(_profileManageMode){_profileManageMode=NO;if(buttonIndex<(NSInteger)[_profiles count]){_selectedProfileIndex=buttonIndex;UIActionSheet*m=[[[UIActionSheet alloc]initWithTitle:[[_profiles objectAtIndex:buttonIndex]objectForKey:@"name"] delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete" otherButtonTitles:@"Load",@"Duplicate",@"Set Default",@"Toggle Auto Connect",nil]autorelease];m.tag=901;[m showInView:_controller.view];}return;}
    if(buttonIndex<(NSInteger)[_profiles count]){[self showProfileActionsAtIndex:buttonIndex];return;}
    if(buttonIndex==(NSInteger)[_profiles count]){_savingProfilePrompt=YES;UIAlertView*a=[[[UIAlertView alloc]initWithTitle:@"Save Profile" message:@"Profile name" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save",nil]autorelease];a.alertViewStyle=UIAlertViewStylePlainTextInput;[[a textFieldAtIndex:0]setText:_hostField.text];[a show];return;}
    if(buttonIndex==(NSInteger)[_profiles count]+1){_profileManageMode=YES;UIActionSheet*s=[[[UIActionSheet alloc]initWithTitle:@"Choose profile to manage" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil]autorelease];for(NSDictionary*p in _profiles)[s addButtonWithTitle:[p objectForKey:@"name"]];s.cancelButtonIndex=[s addButtonWithTitle:@"Cancel"];[s showInView:_controller.view];return;}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(alertView.tag==930){
        if(buttonIndex==alertView.cancelButtonIndex)return;NSString *name=[[[alertView textFieldAtIndex:0] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];if(![name length])return;
        NSString *rp=([_remoteRelativePath length]?[_remoteRelativePath stringByAppendingPathComponent:name]:name);NSData*b=[NSJSONSerialization dataWithJSONObject:[NSDictionary dictionaryWithObject:rp forKey:@"path"] options:0 error:nil];[self performFileAPIPath:@"/api/mkdir" method:@"POST" body:b contentType:@"application/json"];return;
    }
    if(alertView.tag==931){
        if(buttonIndex==alertView.cancelButtonIndex||_selectedRemoteIndex<0||_selectedRemoteIndex>=(NSInteger)[_remoteEntries count])return;
        NSDictionary *e=[_remoteEntries objectAtIndex:_selectedRemoteIndex];NSString *newName=[[[alertView textFieldAtIndex:0] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];if(![newName length])return;
        NSString *from=[self remotePathForEntry:e];NSString *to=([_remoteRelativePath length]?[_remoteRelativePath stringByAppendingPathComponent:newName]:newName);
        NSDictionary *o=[NSDictionary dictionaryWithObjectsAndKeys:from,@"from",to,@"to",nil];NSData*b=[NSJSONSerialization dataWithJSONObject:o options:0 error:nil];[self performFileAPIPath:@"/api/rename" method:@"POST" body:b contentType:@"application/json"];return;
    }
    if(!_savingProfilePrompt)return;_savingProfilePrompt=NO;if(buttonIndex==alertView.cancelButtonIndex)return;
    NSString *name=[[[alertView textFieldAtIndex:0] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(![name length])name=@"Server";[self saveProfileNamed:name];
}
- (void)showProfileActionsAtIndex:(NSInteger)index {
    if(index<0||index>=(NSInteger)[_profiles count])return;_selectedProfileIndex=index;NSDictionary *p=[_profiles objectAtIndex:index];
    UIActionSheet *s=[[[UIActionSheet alloc]initWithTitle:[p objectForKey:@"name"] delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Desktop Connect",@"Terminal",@"Files",@"Wake",@"Load & Edit",@"Duplicate",@"Delete",nil]autorelease];s.tag=902;[s showInView:_controller.view];
}
- (void)saveProfileNamed:(NSString *)name {
    if(!_profiles)_profiles=[[NSMutableArray alloc]init];
    NSString *pid=[NSString stringWithFormat:@"%0.f",[[NSDate date] timeIntervalSince1970]*1000.0];
    NSDictionary *p=[NSDictionary dictionaryWithObjectsAndKeys:
        name,@"name",pid,@"id",(_hostField.text?:@""),@"host",(_portField.text?:@"5901"),@"port",
        [NSNumber numberWithInteger:_qualityControl.selectedSegmentIndex],@"quality",
        [NSNumber numberWithInteger:_inputModeControl.selectedSegmentIndex],@"input",
        [NSNumber numberWithFloat:_speedSlider.value],@"speed",
        (_sshUserField.text?:@""),@"sshUser",(_sshPortField.text?:@"22"),@"sshPort",(_sshKeyField.text?:@""),@"sshKey",
        [NSNumber numberWithBool:_sshTunnelSwitch.on],@"sshTunnel",[NSNumber numberWithBool:_tlsSwitch.on],@"x509TLS",[NSNumber numberWithBool:_vncView.precisionMode],@"precision",[NSNumber numberWithBool:_vncView.dragLock],@"dragLock",
        (_downloadURLField.text?:@""),@"filesURL",
        (_wolMACField.text?:@""),@"wolMAC",(_broadcastField.text?:@"255.255.255.255"),@"broadcast",
        (_remoteDisplayField.text?:@":1"),@"display",[NSNumber numberWithBool:_autoResolutionSwitch.on],@"autoResolution",
        [NSNumber numberWithBool:NO],@"autoConnect",nil];
    [_profiles addObject:p];
    [KeychainStore setString:(_passwordField.text?:@"") service:@"com.olap.ipad1vnc.profile.vnc" account:pid];
    [KeychainStore setString:(_filesTokenField.text?:@"") service:@"com.olap.ipad1vnc.profile.files" account:pid];
    [[NSUserDefaults standardUserDefaults]setObject:_profiles forKey:@"profiles"];[[NSUserDefaults standardUserDefaults]synchronize];_statusLabel.text=@"Profile saved securely";
}
- (void)loadProfileAtIndex:(NSInteger)index {
    if(index<0||index>=(NSInteger)[_profiles count])return;NSDictionary*p=[_profiles objectAtIndex:index];NSString*pid=[p objectForKey:@"id"];
    _hostField.text=[p objectForKey:@"host"];_portField.text=[p objectForKey:@"port"];_passwordField.text=([pid length]?[KeychainStore stringForService:@"com.olap.ipad1vnc.profile.vnc" account:pid]:@"");
    NSInteger q=[[p objectForKey:@"quality"]integerValue];if(q>=0&&q<=3)_qualityControl.selectedSegmentIndex=q;NSInteger im=[[p objectForKey:@"input"]integerValue];if(im>=0&&im<=1)_inputModeControl.selectedSegmentIndex=im;
    CGFloat sp=[[p objectForKey:@"speed"]floatValue];if(sp>=.5&&sp<=1.5){_speedSlider.value=sp;_vncView.pointerSensitivity=sp;}
    _sshUserField.text=[p objectForKey:@"sshUser"];_sshPortField.text=[p objectForKey:@"sshPort"];_sshKeyField.text=[p objectForKey:@"sshKey"];_sshTunnelSwitch.on=[[p objectForKey:@"sshTunnel"]boolValue];_tlsSwitch.on=[[p objectForKey:@"x509TLS"]boolValue];_vncView.precisionMode=[[p objectForKey:@"precision"]boolValue];_vncView.dragLock=[[p objectForKey:@"dragLock"]boolValue];
    _downloadURLField.text=[p objectForKey:@"filesURL"];_filesTokenField.text=([pid length]?[KeychainStore stringForService:@"com.olap.ipad1vnc.profile.files" account:pid]:@"");
    if(_wolMACField)_wolMACField.text=[p objectForKey:@"wolMAC"];if(_broadcastField)_broadcastField.text=[p objectForKey:@"broadcast"];if(_remoteDisplayField)_remoteDisplayField.text=[p objectForKey:@"display"];if(_autoResolutionSwitch)_autoResolutionSwitch.on=[[p objectForKey:@"autoResolution"]boolValue];
    _vncView.inputMode=(VNCInputMode)_inputModeControl.selectedSegmentIndex;[self saveConnectionSettings];_statusLabel.text=[NSString stringWithFormat:@"Loaded %@",[p objectForKey:@"name"]];
}
- (void)deleteProfileAtIndex:(NSInteger)index {
    if(index<0||index>=(NSInteger)[_profiles count])return;
    NSDictionary *pr=[_profiles objectAtIndex:index];NSString *name=[pr objectForKey:@"name"];NSString *pid=[pr objectForKey:@"id"];
    if([pid length]){[KeychainStore deleteService:@"com.olap.ipad1vnc.profile.vnc" account:pid];[KeychainStore deleteService:@"com.olap.ipad1vnc.profile.files" account:pid];}
    [_profiles removeObjectAtIndex:index];
    [[NSUserDefaults standardUserDefaults] setObject:_profiles forKey:@"profiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _statusLabel.text=[NSString stringWithFormat:@"Deleted %@",name];
}



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)launchOptions;
    [application setStatusBarHidden:YES animated:NO];

    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    _controller = [[RotationViewController alloc] init];
    _controller.view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];

    CGFloat w = _controller.view.bounds.size.width;
    CGFloat panelExpandedHeight = 292.0;
    _connectionPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, panelExpandedHeight)];
    _connectionPanel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _connectionPanel.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    [_controller.view addSubview:_connectionPanel];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [self migrateSecretsToKeychain];
    NSArray *savedProfiles=[defaults arrayForKey:@"profiles"];_profiles=[[NSMutableArray alloc] initWithArray:(savedProfiles?savedProfiles:[NSArray array])];
    _transferQueue=[[NSMutableArray alloc] init];_lanResults=[[NSMutableArray alloc] init];

    _hostField = [[UITextField alloc] initWithFrame:CGRectMake(20,20,w-230,38)];
    _hostField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _hostField.borderStyle = UITextBorderStyleRoundedRect;
    _hostField.placeholder = @"VNC host";
    _hostField.text = [defaults stringForKey:@"host"];
    _hostField.autocorrectionType = UITextAutocorrectionTypeNo;
    _hostField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [_connectionPanel addSubview:_hostField];

    _portField = [[UITextField alloc] initWithFrame:CGRectMake(w-200,20,70,38)];
    _portField.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _portField.borderStyle = UITextBorderStyleRoundedRect;
    _portField.keyboardType = UIKeyboardTypeNumberPad;
    NSString *savedPort = [defaults stringForKey:@"port"];
    _portField.text = ([savedPort length] ? savedPort : @"5901");
    [_connectionPanel addSubview:_portField];

    _passwordField = [[UITextField alloc] initWithFrame:CGRectMake(20,66,w-315,38)];
    _passwordField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _passwordField.borderStyle = UITextBorderStyleRoundedRect;
    _passwordField.placeholder = @"VNC password";
    _passwordField.secureTextEntry = YES;
    _passwordField.text = [KeychainStore stringForService:@"com.olap.ipad1vnc" account:@"vnc.default"];
    if(![_passwordField.text length])_passwordField.text=[defaults stringForKey:@"password"];
    [_connectionPanel addSubview:_passwordField];

    _profilesButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    _profilesButton.frame = CGRectMake(w-285,66,75,38);
    _profilesButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_profilesButton setTitle:@"Profiles" forState:UIControlStateNormal];
    [_profilesButton addTarget:self action:@selector(profilesTapped) forControlEvents:UIControlEventTouchUpInside];
    [_connectionPanel addSubview:_profilesButton];

    _connectButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    _connectButton.frame = CGRectMake(w-120,20,100,84);
    _connectButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    [_connectButton addTarget:self action:@selector(connectTapped) forControlEvents:UIControlEventTouchUpInside];
    [_connectionPanel addSubview:_connectButton];

    CGFloat savedSpeed = [defaults floatForKey:@"pointerSpeed"];
    if (savedSpeed < 0.5 || savedSpeed > 1.5) savedSpeed = 1.0;
    _speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(20,112,120,26)];
    _speedLabel.backgroundColor = [UIColor clearColor];
    _speedLabel.textColor = [UIColor whiteColor];
    _speedLabel.font = [UIFont systemFontOfSize:13];
    _speedLabel.text = [NSString stringWithFormat:@"Pointer %.1fx", savedSpeed];
    [_connectionPanel addSubview:_speedLabel];

    _speedSlider = [[UISlider alloc] initWithFrame:CGRectMake(135,112,w-155,26)];
    _speedSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _speedSlider.minimumValue = 0.5f;
    _speedSlider.maximumValue = 1.5f;
    _speedSlider.value = savedSpeed;
    [_speedSlider addTarget:self action:@selector(speedChanged) forControlEvents:UIControlEventValueChanged];
    [_connectionPanel addSubview:_speedSlider];

    UILabel *qualityLabel = [[[UILabel alloc] initWithFrame:CGRectMake(20,146,80,28)] autorelease];
    qualityLabel.backgroundColor = [UIColor clearColor];
    qualityLabel.textColor = [UIColor whiteColor];
    qualityLabel.font = [UIFont systemFontOfSize:13];
    qualityLabel.text = @"Quality"; qualityLabel.tag = 500;
    [_connectionPanel addSubview:qualityLabel];

    _qualityControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Auto",@"Fast",@"Balanced",@"Quality",nil]];
    _qualityControl.frame = CGRectMake(105,146,w-125,30);
    _qualityControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    NSInteger savedQuality;
    if ([defaults objectForKey:@"qualityMode"]) savedQuality=[defaults integerForKey:@"qualityMode"];
    else {
        NSInteger legacy=[defaults objectForKey:@"qualityProfile"]?[defaults integerForKey:@"qualityProfile"]:1;
        savedQuality=MIN(3,MAX(1,legacy+1));
    }
    if(savedQuality<0||savedQuality>3)savedQuality=0;
    _qualityControl.selectedSegmentIndex=savedQuality;
    [_qualityControl addTarget:self action:@selector(qualityChanged) forControlEvents:UIControlEventValueChanged];
    [_connectionPanel addSubview:_qualityControl];

    UILabel *inputLabel = [[[UILabel alloc] initWithFrame:CGRectMake(20,184,80,28)] autorelease];
    inputLabel.backgroundColor=[UIColor clearColor]; inputLabel.textColor=[UIColor whiteColor];
    inputLabel.font=[UIFont systemFontOfSize:13]; inputLabel.text=@"Pointer Mode"; inputLabel.tag=501;
    [_connectionPanel addSubview:inputLabel];

    _inputModeControl=[[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Direct",@"Trackpad",nil]];
    _inputModeControl.frame=CGRectMake(105,184,220,30);
    NSInteger savedInput=[defaults objectForKey:@"inputMode"]?[defaults integerForKey:@"inputMode"]:0;
    if(savedInput<0||savedInput>1)savedInput=0;
    _inputModeControl.selectedSegmentIndex=savedInput;
    [_inputModeControl addTarget:self action:@selector(inputModeChanged) forControlEvents:UIControlEventValueChanged];
    [_connectionPanel addSubview:_inputModeControl];

    UILabel *tightLabel=[[[UILabel alloc] initWithFrame:CGRectMake(20,216,80,28)] autorelease];
    tightLabel.backgroundColor=[UIColor clearColor];tightLabel.textColor=[UIColor whiteColor];tightLabel.font=[UIFont systemFontOfSize:13];tightLabel.text=@"Tight";tightLabel.tag=502;[_connectionPanel addSubview:tightLabel];
    _tightSwitch=[[UISwitch alloc] initWithFrame:CGRectMake(105,216,80,28)];
    _tightSwitch.on=[defaults objectForKey:@"preferTight"]?[defaults boolForKey:@"preferTight"]:NO;
    [_tightSwitch addTarget:self action:@selector(tightChanged) forControlEvents:UIControlEventValueChanged];[_connectionPanel addSubview:_tightSwitch];

    UILabel *tlsLabel=[[[UILabel alloc] initWithFrame:CGRectMake(185,216,70,28)] autorelease];
    tlsLabel.backgroundColor=[UIColor clearColor];tlsLabel.textColor=[UIColor whiteColor];tlsLabel.font=[UIFont systemFontOfSize:12];tlsLabel.text=@"X509 TLS";tlsLabel.tag=503;[_connectionPanel addSubview:tlsLabel];
    _tlsSwitch=[[UISwitch alloc] initWithFrame:CGRectMake(250,216,80,28)];
    _tlsSwitch.on=[defaults boolForKey:@"preferX509TLS"];[_tlsSwitch addTarget:self action:@selector(tlsChanged) forControlEvents:UIControlEventValueChanged];[_connectionPanel addSubview:_tlsSwitch];

    _statsLabel=[[UILabel alloc] initWithFrame:CGRectMake(335,216,w-355,28)];
    _statsLabel.autoresizingMask=UIViewAutoresizingFlexibleWidth;_statsLabel.backgroundColor=[UIColor clearColor];
    _statsLabel.textColor=[UIColor lightGrayColor];_statsLabel.font=[UIFont systemFontOfSize:12];_statsLabel.text=@"FPS -- | -- kbps | --";[_connectionPanel addSubview:_statsLabel];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(340,184,w-360,30)];
    _statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _statusLabel.backgroundColor = [UIColor clearColor];
    _statusLabel.textColor = [UIColor whiteColor];
    _statusLabel.font = [UIFont systemFontOfSize:13];
    _statusLabel.text = @"Ready";
    [_connectionPanel addSubview:_statusLabel];

    _keyboardButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    _keyboardButton.frame = CGRectMake(w-515,248,80,34);
    _keyboardButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_keyboardButton setTitle:@"Keyboard" forState:UIControlStateNormal];
    [_keyboardButton addTarget:self action:@selector(keyboardTapped) forControlEvents:UIControlEventTouchUpInside];
    [_connectionPanel addSubview:_keyboardButton];

    _filesButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    _filesButton.frame = CGRectMake(w-425,248,80,34);
    _filesButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_filesButton setTitle:@"Files" forState:UIControlStateNormal];
    [_filesButton addTarget:self action:@selector(filesTapped) forControlEvents:UIControlEventTouchUpInside];
    [_connectionPanel addSubview:_filesButton];

    _terminalButton=[[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    _terminalButton.frame=CGRectMake(w-605,248,80,34);_terminalButton.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin;
    [_terminalButton setTitle:@"Terminal" forState:UIControlStateNormal];[_terminalButton addTarget:self action:@selector(terminalTapped) forControlEvents:UIControlEventTouchUpInside];[_connectionPanel addSubview:_terminalButton];

    _fullScreenButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    _fullScreenButton.frame = CGRectMake(w-335,248,80,34);
    _fullScreenButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_fullScreenButton setTitle:@"Full" forState:UIControlStateNormal];
    [_fullScreenButton addTarget:self action:@selector(fullScreenTapped) forControlEvents:UIControlEventTouchUpInside];
    [_connectionPanel addSubview:_fullScreenButton];


    _toolsButton=[[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    _toolsButton.frame=CGRectMake(w-245,248,80,34);_toolsButton.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin;
    [_toolsButton setTitle:@"Tools" forState:UIControlStateNormal];[_toolsButton addTarget:self action:@selector(toolsTapped) forControlEvents:UIControlEventTouchUpInside];[_connectionPanel addSubview:_toolsButton];

    _settingsButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    _settingsButton.frame = CGRectMake(w-155,248,135,34);
    _settingsButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_settingsButton setTitle:@"Hide Setup" forState:UIControlStateNormal];
    [_settingsButton addTarget:self action:@selector(settingsTapped) forControlEvents:UIControlEventTouchUpInside];
    [_connectionPanel addSubview:_settingsButton];

    _keyboardField = [[UITextField alloc] initWithFrame:CGRectMake(-100,-100,10,10)];
    _keyboardField.delegate = self;
    _keyboardField.autocorrectionType = UITextAutocorrectionTypeNo;
    _keyboardField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _keyboardField.text = @" ";
    [_controller.view addSubview:_keyboardField];

    _vncView = [[VNCView alloc] initWithFrame:CGRectMake(0,panelExpandedHeight,w,_controller.view.bounds.size.height-panelExpandedHeight)];
    _vncView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _vncView.pointerSensitivity = savedSpeed;
    [_controller.view addSubview:_vncView];

    _exitFullScreenButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    _exitFullScreenButton.frame = CGRectMake(w-78,6,70,34);
    _exitFullScreenButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin;
    [_exitFullScreenButton setTitle:@"Menu" forState:UIControlStateNormal];
    [_exitFullScreenButton addTarget:self action:@selector(exitFullScreenTapped) forControlEvents:UIControlEventTouchUpInside];
    _exitFullScreenButton.alpha = 0.0;
    [_controller.view addSubview:_exitFullScreenButton];

    _keyBar = [[UIView alloc] initWithFrame:CGRectMake(4,_controller.view.bounds.size.height-42,w-8,38)];
    _keyBar.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
    _keyBar.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.94];
    _keyBar.hidden = YES;
    NSArray *titles = [NSArray arrayWithObjects:@"Esc",@"Ctrl",@"Alt",@"Tab",@"←",@"↑",@"↓",@"→",@"⌫",@"Home",@"End",@"PgUp",@"PgDn",@"F1",@"F2",@"F3",@"F4",@"Copy",@"Paste",@"Keys…",nil];
    for (NSUInteger i=0;i<[titles count];i++) {
        UIButton *b=[UIButton buttonWithType:UIButtonTypeRoundedRect];
        b.tag=100+(NSInteger)i;
        [b setTitle:[titles objectAtIndex:i] forState:UIControlStateNormal];
        [b addTarget:self action:@selector(specialKeyTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_keyBar addSubview:b];
    }
    [_controller.view addSubview:_keyBar];

    [self buildFilesPanel];
    [self buildTerminalPanel];
    [self toolsTapped]; _toolsPanel.hidden=YES;
    NSString *defID=[defaults stringForKey:@"defaultProfileID"];
    if([defID length])for(NSUInteger i=0;i<[_profiles count];i++){NSDictionary*pr=[_profiles objectAtIndex:i];if([[pr objectForKey:@"id"] isEqualToString:defID]){[self loadProfileAtIndex:i];if([[pr objectForKey:@"autoConnect"]boolValue])[self performSelector:@selector(connectTapped) withObject:nil afterDelay:0.8];break;}}

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];

    self.window.rootViewController = _controller;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)layoutKeyBarButtons {
    CGFloat width = _keyBar.bounds.size.width;
    NSUInteger count = [[_keyBar subviews] count];
    if (!count) return;
    CGFloat bw = width/(CGFloat)count;
    for (NSUInteger i=0;i<count;i++) {
        UIView *v=[[_keyBar subviews] objectAtIndex:i];
        v.frame=CGRectMake(i*bw+1,2,bw-2,34);
    }
}

- (void)saveConnectionSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:(_hostField.text ?: @"") forKey:@"host"];
    [defaults setObject:(_portField.text ?: @"5901") forKey:@"port"];
    [KeychainStore setString:(_passwordField.text?:@"") service:@"com.olap.ipad1vnc" account:@"vnc.default"];
    [defaults removeObjectForKey:@"password"];
    [defaults setFloat:_speedSlider.value forKey:@"pointerSpeed"];
    [defaults setInteger:_qualityControl.selectedSegmentIndex forKey:@"qualityMode"];
    [defaults setInteger:_inputModeControl.selectedSegmentIndex forKey:@"inputMode"];
    [defaults setBool:_tightSwitch.on forKey:@"preferTight"];
    [defaults setBool:_tlsSwitch.on forKey:@"preferX509TLS"];
    [defaults synchronize];
}

- (void)connectTapped {
    [_hostField resignFirstResponder]; [_portField resignFirstResponder]; [_passwordField resignFirstResponder];

    // The same button is Connect while idle and Disconnect while a session
    // (or a pending reconnect) exists.
    if(_client || _shouldAutoReconnect || _reconnectTimer){
        [self disconnectManually];
        return;
    }

    NSString *host = [_hostField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSInteger port = [_portField.text integerValue];
    if ([host length] == 0) { _statusLabel.text = @"Enter host"; return; }
    if (port <= 0) _portField.text = @"5901";

    _shouldAutoReconnect = YES;
    [self saveConnectionSettings];
    [self startConnection];
}

- (void)disconnectManually {
    // A user-requested disconnect must never trigger the automatic
    // three-second reconnect loop.
    _shouldAutoReconnect=NO;

    if(_reconnectTimer){
        [_reconnectTimer invalidate];
        [_reconnectTimer release];
        _reconnectTimer=nil;
    }

    [self stopClipboardTimer];

    if(_client){
        _client.delegate=nil;
        [_client disconnect];
        [_client release];
        _client=nil;
    }
    _vncView.client=nil;

    if(_tunnelSession){
        _tunnelSession.delegate=nil;
        if(_tunnelSession.running)[_tunnelSession stop];
        [_tunnelSession release];
        _tunnelSession=nil;
    }

    [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    _statusLabel.text=@"Disconnected";
    [self setControlsCollapsed:NO animated:YES];
}

- (void)startConnection {
    [self saveConnectionSettings];
    NSString *host=[_hostField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSInteger port=[_portField.text integerValue];if(![host length]||port<=0){_statusLabel.text=@"Host/port required";return;}
    [_client disconnect];[_client release];_client=nil;
    NSString *connectHost=host;NSInteger connectPort=port;

    if(_sshTunnelSwitch && _sshTunnelSwitch.on){
        if(!_tunnelSession)_tunnelSession=[[TerminalSession alloc] init];
        _tunnelSession.delegate=self;
        _tunnelLocalPort=15901;
        NSInteger sshPort=[_sshPortField.text integerValue];if(sshPort<=0)sshPort=22;
        if(![_sshKeyField.text length]){_statusLabel.text=@"SSH tunnel needs key path";return;}
        BOOL tunnelOK=[_tunnelSession startTunnelHost:host port:sshPort user:_sshUserField.text keyPath:_sshKeyField.text localPort:_tunnelLocalPort remoteHost:@"127.0.0.1" remotePort:port];
        if(!tunnelOK){_statusLabel.text=@"SSH tunnel failed";return;}
        connectHost=@"127.0.0.1";connectPort=_tunnelLocalPort;
        _statusLabel.text=@"Opening SSH tunnel…";
        [NSThread sleepForTimeInterval:0.8];
    }

    _client=[[VNCClient alloc] initWithHost:connectHost port:connectPort password:_passwordField.text ?: @""];
    _client.delegate=self;
    NSInteger qm=_qualityControl.selectedSegmentIndex;
    _client.adaptiveQualityEnabled=(qm==0);
    _client.qualityProfile=(qm==0?VNCQualityBalanced:(VNCQualityProfile)(qm-1));
    _client.preferTight=_tightSwitch.on;_client.preferX509TLS=_tlsSwitch.on;
    _vncView.client=_client;_vncView.inputMode=(VNCInputMode)_inputModeControl.selectedSegmentIndex;
    _shouldAutoReconnect=YES;[_connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
    [_client connect];
}

- (void)scheduleReconnect {
    if (!_shouldAutoReconnect || _reconnectTimer) return;
    _statusLabel.text=@"Disconnected — reconnecting in 3s…";
    _reconnectTimer=[[NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(reconnectTimerFired:) userInfo:nil repeats:NO] retain];
}
- (void)reconnectTimerFired:(NSTimer *)timer { (void)timer; _reconnectCount++; [_reconnectTimer release]; _reconnectTimer=nil; if(_shouldAutoReconnect)[self startConnection]; }

- (void)toolsTapped {
    if(!_toolsPanel){
        CGFloat w=_controller.view.bounds.size.width,h=_controller.view.bounds.size.height,pw=MIN(620.0,w-20),ph=410;
        _toolsPanel=[[UIView alloc]initWithFrame:CGRectMake((w-pw)/2,(h-ph)/2,pw,ph)];_toolsPanel.backgroundColor=[UIColor colorWithWhite:.08 alpha:.98];_toolsPanel.autoresizingMask=(UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin);
        UILabel *title=[[[UILabel alloc]initWithFrame:CGRectMake(14,8,pw-110,32)]autorelease];title.text=@"Tools / Diagnostics";title.textColor=[UIColor whiteColor];title.backgroundColor=[UIColor clearColor];title.font=[UIFont boldSystemFontOfSize:16];[_toolsPanel addSubview:title];
        UIButton *close=[UIButton buttonWithType:UIButtonTypeRoundedRect];close.frame=CGRectMake(pw-90,6,76,32);[close setTitle:@"Close" forState:UIControlStateNormal];[close addTarget:self action:@selector(closeToolsTapped) forControlEvents:UIControlEventTouchUpInside];[_toolsPanel addSubview:close];
        _wolMACField=[[UITextField alloc]initWithFrame:CGRectMake(14,50,210,34)];_wolMACField.borderStyle=UITextBorderStyleRoundedRect;_wolMACField.placeholder=@"Wake MAC 00:11:22:33:44:55";_wolMACField.text=[[NSUserDefaults standardUserDefaults]stringForKey:@"wolMAC"];[_toolsPanel addSubview:_wolMACField];
        _broadcastField=[[UITextField alloc]initWithFrame:CGRectMake(230,50,170,34)];_broadcastField.borderStyle=UITextBorderStyleRoundedRect;_broadcastField.placeholder=@"255.255.255.255";NSString*b=[[NSUserDefaults standardUserDefaults]stringForKey:@"broadcast"];_broadcastField.text=([b length]?b:@"255.255.255.255");[_toolsPanel addSubview:_broadcastField];
        UIButton *wake=[UIButton buttonWithType:UIButtonTypeRoundedRect];wake.frame=CGRectMake(410,50,90,34);[wake setTitle:@"Wake" forState:UIControlStateNormal];[wake addTarget:self action:@selector(wakeTapped) forControlEvents:UIControlEventTouchUpInside];[_toolsPanel addSubview:wake];
        _remoteDisplayField=[[UITextField alloc]initWithFrame:CGRectMake(14,94,100,34)];_remoteDisplayField.borderStyle=UITextBorderStyleRoundedRect;_remoteDisplayField.placeholder=@":1";NSString*d=[[NSUserDefaults standardUserDefaults]stringForKey:@"remoteDisplay"];_remoteDisplayField.text=([d length]?d:@":1");[_toolsPanel addSubview:_remoteDisplayField];
        UILabel *ar=[[[UILabel alloc]initWithFrame:CGRectMake(125,96,135,30)]autorelease];ar.text=@"Auto Resolution";ar.textColor=[UIColor whiteColor];ar.backgroundColor=[UIColor clearColor];[_toolsPanel addSubview:ar];
        _autoResolutionSwitch=[[UISwitch alloc]initWithFrame:CGRectMake(260,94,80,30)];_autoResolutionSwitch.on=[[NSUserDefaults standardUserDefaults]boolForKey:@"autoResolution"];[_toolsPanel addSubview:_autoResolutionSwitch];
        _matchResolutionButton=[UIButton buttonWithType:UIButtonTypeRoundedRect];_matchResolutionButton.frame=CGRectMake(350,94,150,34);[_matchResolutionButton setTitle:@"Match iPad" forState:UIControlStateNormal];[_matchResolutionButton addTarget:self action:@selector(matchResolutionTapped) forControlEvents:UIControlEventTouchUpInside];[_toolsPanel addSubview:_matchResolutionButton];

        UILabel *pl=[[[UILabel alloc]initWithFrame:CGRectMake(14,134,85,30)]autorelease];pl.text=@"Precision";pl.textColor=[UIColor whiteColor];pl.backgroundColor=[UIColor clearColor];[_toolsPanel addSubview:pl];
        _precisionSwitch=[[UISwitch alloc]initWithFrame:CGRectMake(95,132,80,30)];_precisionSwitch.on=[[NSUserDefaults standardUserDefaults]boolForKey:@"precisionMode"];[_precisionSwitch addTarget:self action:@selector(precisionChanged) forControlEvents:UIControlEventValueChanged];[_toolsPanel addSubview:_precisionSwitch];
        UILabel *dl=[[[UILabel alloc]initWithFrame:CGRectMake(185,134,75,30)]autorelease];dl.text=@"Drag Lock";dl.textColor=[UIColor whiteColor];dl.backgroundColor=[UIColor clearColor];[_toolsPanel addSubview:dl];
        _dragLockSwitch=[[UISwitch alloc]initWithFrame:CGRectMake(260,132,80,30)];_dragLockSwitch.on=[[NSUserDefaults standardUserDefaults]boolForKey:@"dragLock"];[_dragLockSwitch addTarget:self action:@selector(dragLockChanged) forControlEvents:UIControlEventValueChanged];[_toolsPanel addSubview:_dragLockSwitch];
        _scanLANButton=[UIButton buttonWithType:UIButtonTypeRoundedRect];_scanLANButton.frame=CGRectMake(350,132,150,34);[_scanLANButton setTitle:@"Scan LAN" forState:UIControlStateNormal];[_scanLANButton addTarget:self action:@selector(scanLANTapped) forControlEvents:UIControlEventTouchUpInside];[_toolsPanel addSubview:_scanLANButton];

        _diagnosticsLabel=[[UILabel alloc]initWithFrame:CGRectMake(14,176,pw-28,214)];_diagnosticsLabel.numberOfLines=0;_diagnosticsLabel.textColor=[UIColor whiteColor];_diagnosticsLabel.backgroundColor=[UIColor colorWithWhite:.12 alpha:1];_diagnosticsLabel.font=[UIFont fontWithName:@"Courier" size:13];_diagnosticsLabel.text=@"No active diagnostics yet.";[_toolsPanel addSubview:_diagnosticsLabel];
        [_controller.view addSubview:_toolsPanel];
    }
    _toolsPanel.hidden=NO;[_controller.view bringSubviewToFront:_toolsPanel];
}
- (void)closeToolsTapped {_toolsPanel.hidden=YES;}
- (BOOL)sendWakePacketMAC:(NSString*)mac broadcast:(NSString*)broadcast {
    NSArray *parts=[[mac stringByReplacingOccurrencesOfString:@"-" withString:@":"] componentsSeparatedByString:@":"];if([parts count]!=6)return NO;
    uint8_t m[6];for(int i=0;i<6;i++){unsigned int v=0;NSScanner*s=[NSScanner scannerWithString:[parts objectAtIndex:i]];if(![s scanHexInt:&v])return NO;m[i]=(uint8_t)v;}
    uint8_t pkt[102];memset(pkt,0xFF,6);for(int i=0;i<16;i++)memcpy(pkt+6+i*6,m,6);
    int fd=socket(AF_INET,SOCK_DGRAM,0);if(fd<0)return NO;int yes=1;setsockopt(fd,SOL_SOCKET,SO_BROADCAST,&yes,sizeof(yes));struct sockaddr_in a;memset(&a,0,sizeof(a));a.sin_family=AF_INET;a.sin_port=htons(9);a.sin_addr.s_addr=inet_addr([broadcast UTF8String]);BOOL ok=sendto(fd,pkt,sizeof(pkt),0,(struct sockaddr*)&a,sizeof(a))==sizeof(pkt);close(fd);return ok;
}
- (void)wakeTapped {
    BOOL ok=[self sendWakePacketMAC:_wolMACField.text broadcast:_broadcastField.text];_diagnosticsLabel.text=(ok?@"Wake-on-LAN packet sent.":@"Invalid MAC/broadcast or UDP send failed.");
    [[NSUserDefaults standardUserDefaults]setObject:_wolMACField.text forKey:@"wolMAC"];[[NSUserDefaults standardUserDefaults]setObject:_broadcastField.text forKey:@"broadcast"];[[NSUserDefaults standardUserDefaults]synchronize];
}
- (void)matchResolutionTapped {
    NSString *user=[_sshUserField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]],*key=[_sshKeyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]],*host=[_hostField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(![user length]||![key length]||![host length]){_diagnosticsLabel.text=@"Match Resolution needs Host + SSH User + Key.";return;}
    NSInteger port=[_sshPortField.text integerValue];if(port<=0)port=22;CGSize s=_controller.view.bounds.size;NSInteger rw=(NSInteger)MAX(s.width,s.height),rh=(NSInteger)MIN(s.width,s.height);if(UIInterfaceOrientationIsPortrait(_controller.interfaceOrientation)){rw=(NSInteger)MIN(s.width,s.height);rh=(NSInteger)MAX(s.width,s.height);}
    NSString *disp=([_remoteDisplayField.text length]?_remoteDisplayField.text:@":1");
    NSString *cmd=[NSString stringWithFormat:@"DISPLAY=%@ xrandr --fb %ldx%ld",disp,(long)rw,(long)rh];
    TerminalSession *tmp=[[[TerminalSession alloc]init]autorelease];tmp.delegate=self;BOOL ok=[tmp startSSHHost:host port:port user:user keyPath:key command:cmd];_diagnosticsLabel.text=(ok?[NSString stringWithFormat:@"Requested remote framebuffer %ldx%ld",(long)rw,(long)rh]:@"Could not start resolution command.");
    [[NSUserDefaults standardUserDefaults]setObject:disp forKey:@"remoteDisplay"];[[NSUserDefaults standardUserDefaults]setBool:_autoResolutionSwitch.on forKey:@"autoResolution"];[[NSUserDefaults standardUserDefaults]synchronize];
}
- (void)orientationChanged:(NSNotification*)note {(void)note;if(_autoResolutionSwitch&&_autoResolutionSwitch.on)[self performSelector:@selector(matchResolutionTapped) withObject:nil afterDelay:1.0];}
- (void)migrateSecretsToKeychain {
    NSUserDefaults*d=[NSUserDefaults standardUserDefaults];NSString*p=[d stringForKey:@"password"];if([p length]&&![KeychainStore stringForService:@"com.olap.ipad1vnc" account:@"vnc.default"])[KeychainStore setString:p service:@"com.olap.ipad1vnc" account:@"vnc.default"];[d removeObjectForKey:@"password"];
    NSString*f=[d stringForKey:@"filesToken"];if([f length]&&![KeychainStore stringForService:@"com.olap.ipad1vnc" account:@"files.default"])[KeychainStore setString:f service:@"com.olap.ipad1vnc" account:@"files.default"];[d removeObjectForKey:@"filesToken"];[d synchronize];
}
- (NSString*)currentProfileID {return @"default";}
- (void)keyboardTapped {
    if ([_keyboardField isFirstResponder]) { [_keyboardField resignFirstResponder]; [_keyboardButton setTitle:@"Keyboard" forState:UIControlStateNormal]; }
    else { _keyboardField.text=@" "; [_keyboardField becomeFirstResponder]; [_keyboardButton setTitle:@"Hide KB" forState:UIControlStateNormal]; }
}
- (void)filesTapped { _filesPanel.hidden=NO; if(![_downloadURLField.text length]&&[_hostField.text length])_downloadURLField.text=[NSString stringWithFormat:@"http://%@:8085/",_hostField.text]; [self refreshFileList]; }
- (void)settingsTapped { [self setControlsCollapsed:!_controlsCollapsed animated:YES]; }
- (void)fullScreenTapped { [self setFullScreen:YES animated:YES]; }
- (void)exitFullScreenTapped { [self setFullScreen:NO animated:YES]; }
- (void)speedChanged { _vncView.pointerSensitivity=_speedSlider.value; _speedLabel.text=[NSString stringWithFormat:@"Pointer %.1fx",_speedSlider.value]; [self saveConnectionSettings]; }
- (void)qualityChanged { [self saveConnectionSettings]; _statusLabel.text = _client ? @"Quality mode saved — reconnect to apply" : @"Quality mode saved"; }
- (void)inputModeChanged { _vncView.inputMode=(VNCInputMode)_inputModeControl.selectedSegmentIndex; [self saveConnectionSettings]; _statusLabel.text=(_inputModeControl.selectedSegmentIndex?@"Trackpad mode":@"Direct touch mode"); }

- (void)setFullScreen:(BOOL)fullScreen animated:(BOOL)animated {
    _fullScreen=fullScreen; CGFloat w=_controller.view.bounds.size.width,h=_controller.view.bounds.size.height;
    if(animated){[UIView beginAnimations:@"fullScreen" context:NULL];[UIView setAnimationDuration:0.20];}
    _connectionPanel.alpha=fullScreen?0.0:1.0; _connectionPanel.userInteractionEnabled=!fullScreen; _exitFullScreenButton.alpha=fullScreen?0.82:0.0;
    if(fullScreen)_vncView.frame=CGRectMake(0,0,w,h); else [self setControlsCollapsed:YES animated:NO];
    if(animated)[UIView commitAnimations];
}

- (void)setControlsCollapsed:(BOOL)collapsed animated:(BOOL)animated {
    _controlsCollapsed=collapsed; CGFloat panelHeight=collapsed?42.0:292.0; CGFloat w=_controller.view.bounds.size.width,h=_controller.view.bounds.size.height;
    if(animated){[UIView beginAnimations:@"connectionPanel" context:NULL];[UIView setAnimationDuration:0.20];}
    CGRect pf=_connectionPanel.frame;pf.size.height=panelHeight;_connectionPanel.frame=pf;
    _hostField.alpha=collapsed?0:1;_portField.alpha=collapsed?0:1;_passwordField.alpha=collapsed?0:1;_connectButton.alpha=collapsed?0:1;_speedLabel.alpha=collapsed?0:1;_speedSlider.alpha=collapsed?0:1;_qualityControl.alpha=collapsed?0:1;_inputModeControl.alpha=collapsed?0:1;_profilesButton.alpha=collapsed?0:1;_tightSwitch.alpha=collapsed?0:1;_tlsSwitch.alpha=collapsed?0:1;_statsLabel.alpha=collapsed?0:1;[_connectionPanel viewWithTag:500].alpha=collapsed?0:1;[_connectionPanel viewWithTag:501].alpha=collapsed?0:1;[_connectionPanel viewWithTag:502].alpha=collapsed?0:1;[_connectionPanel viewWithTag:503].alpha=collapsed?0:1;
    _statusLabel.frame=CGRectMake(12,collapsed?7:184,collapsed?w-620:w-360,28);
    _keyboardButton.frame=CGRectMake(w-515,collapsed?5:248,80,34);
    _terminalButton.frame=CGRectMake(w-605,collapsed?5:248,80,34);
    _filesButton.frame=CGRectMake(w-425,collapsed?5:248,80,34);
    _fullScreenButton.frame=CGRectMake(w-335,collapsed?5:248,80,34);
    _settingsButton.frame=CGRectMake(w-245,collapsed?5:248,225,34);
    [_settingsButton setTitle:(collapsed?@"Setup":@"Hide Setup") forState:UIControlStateNormal];
    _vncView.frame=CGRectMake(0,panelHeight,w,h-panelHeight);
    if(animated)[UIView commitAnimations];
}

- (void)keyboardWillShow:(NSNotification *)note {
    NSDictionary *u=[note userInfo]; NSValue *value=[u objectForKey:UIKeyboardFrameEndUserInfoKey]; CGRect r=[value CGRectValue];
    r=[_controller.view convertRect:r fromView:nil]; CGFloat w=_controller.view.bounds.size.width;
    _keyBar.frame=CGRectMake(4,MAX(0,r.origin.y-40),w-8,38); _keyBar.hidden=NO; [self layoutKeyBarButtons];
}
- (void)keyboardWillHide:(NSNotification *)note { (void)note; _keyBar.hidden=YES; _ctrlArmed=NO; _altArmed=NO; [self refreshModifierButtons]; }

- (void)refreshModifierButtons {
    for(UIButton *b in [_keyBar subviews]) {
        if(b.tag==101)[b setTitle:(_ctrlArmed?@"Ctrl*":@"Ctrl") forState:UIControlStateNormal];
        if(b.tag==102)[b setTitle:(_altArmed?@"Alt*":@"Alt") forState:UIControlStateNormal];
    }
}
- (void)sendChordKey:(uint32_t)keysym ctrl:(BOOL)ctrl alt:(BOOL)alt {
    if(!_client)return; if(ctrl)[_client sendKeySym:0xFFE3 down:YES]; if(alt)[_client sendKeySym:0xFFE9 down:YES];
    [_client sendKeySym:keysym down:YES]; [_client sendKeySym:keysym down:NO];
    if(alt)[_client sendKeySym:0xFFE9 down:NO]; if(ctrl)[_client sendKeySym:0xFFE3 down:NO];
}
- (void)sendKey:(uint32_t)keysym { [self sendChordKey:keysym ctrl:_ctrlArmed alt:_altArmed]; _ctrlArmed=NO;_altArmed=NO;[self refreshModifierButtons]; }
- (void)specialKeyTapped:(UIButton *)sender {
    NSInteger i=sender.tag-100;
    if(i==1){_ctrlArmed=!_ctrlArmed;[self refreshModifierButtons];return;}
    if(i==2){_altArmed=!_altArmed;[self refreshModifierButtons];return;}
    if(i==17){UIPasteboard.generalPasteboard.string=UIPasteboard.generalPasteboard.string?:@"";return;}
    if(i==18){NSString*s=UIPasteboard.generalPasteboard.string;if([s length])[_client sendClipboardText:s];return;}if(i==19){[self extendedKeysTapped];return;}
    uint32_t keys[]={0xff1b,0,0,0xff09,0xff51,0xff52,0xff54,0xff53,0xff08,0xff50,0xff57,0xff55,0xff56,0xffbe,0xffbf,0xffc0,0xffc1};
    if(i<0||i>16)return;uint32_t k=keys[i];if(_ctrlArmed)[_client sendKeySym:0xffe3 down:YES];if(_altArmed)[_client sendKeySym:0xffe9 down:YES];[_client sendKeySym:k down:YES];[_client sendKeySym:k down:NO];if(_ctrlArmed)[_client sendKeySym:0xffe3 down:NO];if(_altArmed)[_client sendKeySym:0xffe9 down:NO];_ctrlArmed=_altArmed=NO;[self refreshModifierButtons];
}
- (void)extendedKeysTapped {
    UIActionSheet *s=[[[UIActionSheet alloc]initWithTitle:@"Extended Keys" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil]autorelease];s.tag=960;
    NSArray *n=[NSArray arrayWithObjects:@"F5",@"F6",@"F7",@"F8",@"F9",@"F10",@"F11",@"F12",@"Insert",@"Delete",@"Print Screen",@"Alt+Tab",@"Ctrl+Alt+Del",@"Ctrl+Alt+T",@"Ctrl+Shift+Esc",@"Super",@"Menu",@"Pause",@"Scroll Lock",nil];
    for(NSString*x in n)[s addButtonWithTitle:x];s.cancelButtonIndex=[s addButtonWithTitle:@"Cancel"];[s showInView:_controller.view];
}
- (void)sendExtendedKeyAtIndex:(NSInteger)i {
    uint32_t fkeys[]={0xffc2,0xffc3,0xffc4,0xffc5,0xffc6,0xffc7,0xffc8,0xffc9};
    if(i>=0&&i<8){[_client sendKeySym:fkeys[i] down:YES];[_client sendKeySym:fkeys[i] down:NO];return;}
    if(i==8){[self sendChordKey:0xff63 ctrl:NO alt:NO];return;}
    if(i==9){[self sendChordKey:0xffff ctrl:NO alt:NO];return;}
    if(i==10){[self sendChordKey:0xff61 ctrl:NO alt:NO];return;}
    if(i==11){[self sendChordKey:0xff09 ctrl:NO alt:YES];return;}
    if(i==12){if(!_client)return;[_client sendKeySym:0xffe3 down:YES];[_client sendKeySym:0xffe9 down:YES];[_client sendKeySym:0xffff down:YES];[_client sendKeySym:0xffff down:NO];[_client sendKeySym:0xffe9 down:NO];[_client sendKeySym:0xffe3 down:NO];return;}
    if(i==13){if(!_client)return;[_client sendKeySym:0xffe3 down:YES];[_client sendKeySym:0xffe9 down:YES];[_client sendKeySym:'t' down:YES];[_client sendKeySym:'t' down:NO];[_client sendKeySym:0xffe9 down:NO];[_client sendKeySym:0xffe3 down:NO];return;}
    if(i==14){if(!_client)return;[_client sendKeySym:0xffe3 down:YES];[_client sendKeySym:0xffe1 down:YES];[_client sendKeySym:0xff1b down:YES];[_client sendKeySym:0xff1b down:NO];[_client sendKeySym:0xffe1 down:NO];[_client sendKeySym:0xffe3 down:NO];return;}
    if(i==15){[self sendChordKey:0xffeb ctrl:NO alt:NO];return;}
    if(i==16){[self sendChordKey:0xff67 ctrl:NO alt:NO];return;}
    if(i==17){[self sendChordKey:0xff13 ctrl:NO alt:NO];return;}
    if(i==18){[self sendChordKey:0xff14 ctrl:NO alt:NO];return;}
}
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    (void)range; if(textField!=_keyboardField||!_client)return YES;
    if([string length]==0){
        [self sendKey:0xFF08];
    } else {
        for(NSUInteger i=0;i<[string length];i++){
            unichar c=[string characterAtIndex:i];
            [self sendKey:(c=='\n'?0xFF0D:(uint32_t)c)];
        }
    }
    /* Keep one invisible sentinel character so iOS 5 continues to emit delete events. */
    textField.text=@" ";
    return NO;
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { if(textField==_keyboardField&&_client)[self sendKey:0xFF0D]; return NO; }

- (void)startClipboardTimer {
    [self stopClipboardTimer]; _lastPasteboardChangeCount=[[UIPasteboard generalPasteboard] changeCount];
    _clipboardTimer=[[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(clipboardTimerFired:) userInfo:nil repeats:YES] retain];
}
- (void)stopClipboardTimer { if(_clipboardTimer){[_clipboardTimer invalidate];[_clipboardTimer release];_clipboardTimer=nil;} }
- (void)clipboardTimerFired:(NSTimer *)timer { (void)timer; UIPasteboard *pb=[UIPasteboard generalPasteboard]; NSInteger cc=[pb changeCount]; if(cc!=_lastPasteboardChangeCount){_lastPasteboardChangeCount=cc;NSString *s=[pb string];if([s length]&&_client)[_client sendClipboardText:s];} }

- (void)vncClientStatus:(NSString *)status {
    _statusLabel.text=status;
    if([status isEqualToString:@"Connected"]){if(_reconnectTimer){[_reconnectTimer invalidate];[_reconnectTimer release];_reconnectTimer=nil;}[self setControlsCollapsed:YES animated:YES];[self startClipboardTimer];}
}
- (void)vncClientFramebuffer:(UIImage *)image width:(NSUInteger)width height:(NSUInteger)height { (void)width;(void)height;[_vncView updateImage:image]; }
- (void)vncClientClipboardText:(NSString *)text { if(![text length])return; UIPasteboard *pb=[UIPasteboard generalPasteboard]; pb.string=text; _lastPasteboardChangeCount=[pb changeCount]; _statusLabel.text=@"Clipboard received"; }
- (void)vncClientDisconnected:(NSString *)reason {
    _statusLabel.text=reason;
    [self stopClipboardTimer];

    if(_client){
        _client.delegate=nil;
        [_client release];
        _client=nil;
        _vncView.client=nil;
    }

    if(_shouldAutoReconnect){
        if(!_fullScreen)[self setControlsCollapsed:YES animated:YES];
        [_connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
        [self scheduleReconnect];
    }else{
        [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
        if(!_fullScreen)[self setControlsCollapsed:NO animated:YES];
        _statusLabel.text=@"Disconnected";
    }
}

- (NSString *)downloadsDirectory {
    NSString *dir=@"/var/mobile/Documents/iPad1VNC"; NSError *err=nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&err];
    if(err){ NSString *fallback=[NSTemporaryDirectory() stringByAppendingPathComponent:@"iPad1VNC"]; [[NSFileManager defaultManager] createDirectoryAtPath:fallback withIntermediateDirectories:YES attributes:nil error:nil]; return fallback; }
    return dir;
}
- (NSString *)uniqueDownloadPathForName:(NSString *)name {
    NSString *safe=[name lastPathComponent]; if(![safe length])safe=@"download.bin";
    NSString *dir=[self downloadsDirectory]; NSString *path=[dir stringByAppendingPathComponent:safe];
    NSString *base=[safe stringByDeletingPathExtension],*ext=[safe pathExtension]; NSInteger n=2;
    while([[NSFileManager defaultManager] fileExistsAtPath:path]){NSString *candidate=[ext length]?[NSString stringWithFormat:@"%@-%ld.%@",base,(long)n,ext]:[NSString stringWithFormat:@"%@-%ld",base,(long)n];path=[dir stringByAppendingPathComponent:candidate];n++;}
    return path;
}
- (void)buildFilesPanel {
    CGFloat w=_controller.view.bounds.size.width,h=_controller.view.bounds.size.height,pw=MIN(760.0,w-20),ph=MIN(620.0,h-20);
    _filesPanel=[[UIView alloc] initWithFrame:CGRectMake((w-pw)/2,(h-ph)/2,pw,ph)];_filesPanel.autoresizingMask=(UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin);_filesPanel.backgroundColor=[UIColor colorWithWhite:0.10 alpha:0.98];_filesPanel.hidden=YES;
    UILabel *title=[[[UILabel alloc] initWithFrame:CGRectMake(15,8,pw-300,30)] autorelease];title.backgroundColor=[UIColor clearColor];title.textColor=[UIColor whiteColor];title.text=@"Remote Files";title.font=[UIFont boldSystemFontOfSize:16];[_filesPanel addSubview:title];
    _filesUpButton=[[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];_filesUpButton.frame=CGRectMake(pw-280,6,60,32);[_filesUpButton setTitle:@"Up" forState:UIControlStateNormal];[_filesUpButton addTarget:self action:@selector(filesUpTapped) forControlEvents:UIControlEventTouchUpInside];[_filesPanel addSubview:_filesUpButton];
    UIButton *mkdir=[UIButton buttonWithType:UIButtonTypeRoundedRect];mkdir.frame=CGRectMake(pw-215,6,60,32);[mkdir setTitle:@"New" forState:UIControlStateNormal];[mkdir addTarget:self action:@selector(mkdirRemote) forControlEvents:UIControlEventTouchUpInside];[_filesPanel addSubview:mkdir];
    UIButton *queue=[UIButton buttonWithType:UIButtonTypeRoundedRect];queue.frame=CGRectMake(pw-330,6,70,32);[queue setTitle:@"Queue" forState:UIControlStateNormal];[queue addTarget:self action:@selector(showTransferQueueTapped) forControlEvents:UIControlEventTouchUpInside];[_filesPanel addSubview:queue];
    UIButton *pause=[UIButton buttonWithType:UIButtonTypeRoundedRect];pause.frame=CGRectMake(pw-255,6,70,32);[pause setTitle:@"Pause" forState:UIControlStateNormal];[pause addTarget:self action:@selector(pauseTransferTapped) forControlEvents:UIControlEventTouchUpInside];[_filesPanel addSubview:pause];
    UIButton *upload=[UIButton buttonWithType:UIButtonTypeRoundedRect];upload.frame=CGRectMake(pw-180,6,90,32);[upload setTitle:@"Upload" forState:UIControlStateNormal];[upload addTarget:self action:@selector(uploadLocalFile) forControlEvents:UIControlEventTouchUpInside];[_filesPanel addSubview:upload];
    UIButton *close=[UIButton buttonWithType:UIButtonTypeRoundedRect];close.frame=CGRectMake(pw-85,6,70,32);[close setTitle:@"Close" forState:UIControlStateNormal];[close addTarget:self action:@selector(closeFilesTapped) forControlEvents:UIControlEventTouchUpInside];[_filesPanel addSubview:close];

    _downloadURLField=[[UITextField alloc] initWithFrame:CGRectMake(15,44,pw-230,34)];_downloadURLField.borderStyle=UITextBorderStyleRoundedRect;_downloadURLField.placeholder=@"http://server:8085";_downloadURLField.autocorrectionType=UITextAutocorrectionTypeNo;_downloadURLField.autocapitalizationType=UITextAutocapitalizationTypeNone;NSString *saved=[[NSUserDefaults standardUserDefaults] stringForKey:@"filesBaseURL"];if([saved length])_downloadURLField.text=saved;[_filesPanel addSubview:_downloadURLField];
    _filesTokenField=[[UITextField alloc] initWithFrame:CGRectMake(pw-210,44,120,34)];_filesTokenField.borderStyle=UITextBorderStyleRoundedRect;_filesTokenField.placeholder=@"API token";_filesTokenField.secureTextEntry=YES;_filesTokenField.text=[KeychainStore stringForService:@"com.olap.ipad1vnc" account:@"files.default"];
    if(![_filesTokenField.text length])_filesTokenField.text=[[NSUserDefaults standardUserDefaults] stringForKey:@"filesToken"];[_filesPanel addSubview:_filesTokenField];
    _browseFilesButton=[[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];_browseFilesButton.frame=CGRectMake(pw-85,44,70,34);[_browseFilesButton setTitle:@"Browse" forState:UIControlStateNormal];[_browseFilesButton addTarget:self action:@selector(browseFilesTapped) forControlEvents:UIControlEventTouchUpInside];[_filesPanel addSubview:_browseFilesButton];

    _remoteEntries=[[NSMutableArray alloc] init];_selectedRemoteIndex=-1;
    _remoteFilesTable=[[UITableView alloc] initWithFrame:CGRectMake(15,86,pw-30,ph-248) style:UITableViewStylePlain];_remoteFilesTable.delegate=self;_remoteFilesTable.dataSource=self;[_filesPanel addSubview:_remoteFilesTable];
    _downloadProgress=[[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];_downloadProgress.frame=CGRectMake(15,ph-152,pw-120,18);[_filesPanel addSubview:_downloadProgress];
    UIButton *cancel=[UIButton buttonWithType:UIButtonTypeRoundedRect];cancel.frame=CGRectMake(pw-95,ph-163,80,34);[cancel setTitle:@"Cancel" forState:UIControlStateNormal];[cancel addTarget:self action:@selector(cancelDownloadTapped) forControlEvents:UIControlEventTouchUpInside];[_filesPanel addSubview:cancel];
    _downloadStatusLabel=[[UILabel alloc] initWithFrame:CGRectMake(15,ph-132,pw-30,22)];_downloadStatusLabel.backgroundColor=[UIColor clearColor];_downloadStatusLabel.textColor=[UIColor whiteColor];_downloadStatusLabel.font=[UIFont systemFontOfSize:12];_downloadStatusLabel.text=@"Files v2: enter server and token.";[_filesPanel addSubview:_downloadStatusLabel];
    UILabel *local=[[[UILabel alloc] initWithFrame:CGRectMake(15,ph-108,pw-30,20)] autorelease];local.backgroundColor=[UIColor clearColor];local.textColor=[UIColor lightGrayColor];local.font=[UIFont boldSystemFontOfSize:12];local.text=@"Local: /var/mobile/Documents/iPad1VNC";[_filesPanel addSubview:local];
    _fileListView=[[UITextView alloc] initWithFrame:CGRectMake(15,ph-86,pw-30,72)];_fileListView.editable=NO;_fileListView.font=[UIFont systemFontOfSize:11];[_filesPanel addSubview:_fileListView];[_controller.view addSubview:_filesPanel];
}
- (void)browseFilesTapped {
    NSString*u=[_downloadURLField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(![u length]&&[_hostField.text length])u=[NSString stringWithFormat:@"http://%@:8085",_hostField.text];
    if(![u hasPrefix:@"http://"]&&![u hasPrefix:@"https://"])u=[@"http://" stringByAppendingString:u];
    while([u hasSuffix:@"/"])u=[u substringToIndex:[u length]-1];
    NSURL*url=[NSURL URLWithString:u];if(!url){_downloadStatusLabel.text=@"Invalid server address";return;}
    _downloadURLField.text=u;[_filesToken release];_filesToken=[_filesTokenField.text copy];
    [[NSUserDefaults standardUserDefaults] setObject:u forKey:@"filesBaseURL"];[KeychainStore setString:(_filesToken?:@"") service:@"com.olap.ipad1vnc" account:@"files.default"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"filesToken"];[[NSUserDefaults standardUserDefaults] synchronize];
    [_downloadURLField resignFirstResponder];[_filesTokenField resignFirstResponder];
    [_remoteRelativePath release];_remoteRelativePath=[@"" copy];
    [self startBrowseURL:url];
}
- (void)startBrowseURL:(NSURL*)url {
    if(_browseConnection){[_browseConnection cancel];[_browseConnection release];_browseConnection=nil;}[_browseData release];_browseData=[[NSMutableData alloc]init];
    [_remoteBaseURL release];_remoteBaseURL=[url retain];
    NSString *pathEsc=[_remoteRelativePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *s=[NSString stringWithFormat:@"%@/api/list?path=%@",[url absoluteString],pathEsc?:@""];
    NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:s] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20.0];
    if([_filesToken length])[req setValue:_filesToken forHTTPHeaderField:@"X-iPad1VNC-Token"];
    _downloadStatusLabel.text=@"Loading remote files…";_browseConnection=[[NSURLConnection alloc]initWithRequest:req delegate:self startImmediately:YES];
}
- (void)filesUpTapped {
    if(![_remoteRelativePath length])return;
    NSString *p=[_remoteRelativePath stringByDeletingLastPathComponent];[_remoteRelativePath release];_remoteRelativePath=[p copy];[self startBrowseURL:_remoteBaseURL];
}
- (void)parseDirectoryHTML:(NSData*)data baseURL:(NSURL*)baseURL {
    (void)baseURL;NSError *err=nil;NSDictionary *obj=[NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    [_remoteEntries removeAllObjects];
    if(![obj isKindOfClass:[NSDictionary class]]){_downloadStatusLabel.text=@"Files API error / invalid token";[_remoteFilesTable reloadData];return;}
    NSArray *entries=[obj objectForKey:@"entries"];NSString *serverPath=[obj objectForKey:@"path"];
    if([serverPath isKindOfClass:[NSString class]]){[_remoteRelativePath release];_remoteRelativePath=[serverPath copy];}
    for(NSDictionary *e in entries)if([e isKindOfClass:[NSDictionary class]])[_remoteEntries addObject:e];
    [_remoteFilesTable reloadData];_downloadStatusLabel.text=([_remoteEntries count]?@"Tap folder; tap file for actions.":@"Remote folder is empty.");
}
- (NSString*)remotePathForEntry:(NSDictionary*)e {
    NSString *n=[e objectForKey:@"name"];return([_remoteRelativePath length]?[_remoteRelativePath stringByAppendingPathComponent:n]:n);
}
- (NSURL*)downloadURLForEntry:(NSDictionary*)e {
    NSString *path=[[self remotePathForEntry:e] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *tok=[_filesToken stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/download?path=%@&token=%@",[_remoteBaseURL absoluteString],path?:@"",tok?:@""]];
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {(void)section;return(tableView==_remoteFilesTable?[_remoteEntries count]:0);}
- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {static NSString*CID=@"RemoteFile";UITableViewCell*cell=[tableView dequeueReusableCellWithIdentifier:CID];if(!cell)cell=[[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CID]autorelease];NSDictionary*e=[_remoteEntries objectAtIndex:indexPath.row];BOOL dir=[[e objectForKey:@"dir"] boolValue];unsigned long long sz=[[e objectForKey:@"size"] unsignedLongLongValue];NSString *detail=(dir?@"":[NSString stringWithFormat:@"  %.1f KB",(double)sz/1024.0]);cell.textLabel.text=[NSString stringWithFormat:@"%@ %@%@",dir?@"[DIR]":@"↓",[e objectForKey:@"name"],detail];cell.accessoryType=dir?UITableViewCellAccessoryDisclosureIndicator:UITableViewCellAccessoryNone;return cell;}
- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    if(tableView!=_remoteFilesTable)return;[tableView deselectRowAtIndexPath:indexPath animated:YES];NSDictionary*e=[_remoteEntries objectAtIndex:indexPath.row];
    if([[e objectForKey:@"dir"] boolValue]){
        NSString *p=[self remotePathForEntry:e];[_remoteRelativePath release];_remoteRelativePath=[p copy];[self startBrowseURL:_remoteBaseURL];
    } else {
        _selectedRemoteIndex=indexPath.row;
        UIActionSheet *s=[[[UIActionSheet alloc] initWithTitle:[e objectForKey:@"name"] delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete" otherButtonTitles:@"Download",@"Rename",nil] autorelease];
        s.tag=920;[s showInView:_filesPanel];
    }
}
- (void)startDownloadFromURL:(NSURL *)url {
    if(!url)return;
    if(_downloadConnection){
        NSDictionary*q=[NSDictionary dictionaryWithObjectsAndKeys:@"download",@"type",([[url path] lastPathComponent]?:@"file"),@"name",url,@"url",nil];[self enqueueTransfer:q];return;
    }
    NSString *name=[[url path] lastPathComponent];if(![name length])name=@"download.bin";
    NSString *final=[[self downloadsDirectory] stringByAppendingPathComponent:name];
    NSString *part=[final stringByAppendingString:@".part"];
    unsigned long long existing=0;NSDictionary *attrs=[[NSFileManager defaultManager]attributesOfItemAtPath:part error:nil];if(attrs)existing=[[attrs objectForKey:NSFileSize]unsignedLongLongValue];
    if(!attrs&&[[NSFileManager defaultManager]fileExistsAtPath:final]){
        final=[self uniqueDownloadPathForName:name];part=[final stringByAppendingString:@".part"];existing=0;
    }
    if(![[NSFileManager defaultManager]fileExistsAtPath:part])[[NSFileManager defaultManager]createFileAtPath:part contents:nil attributes:nil];
    _downloadHandle=[[NSFileHandle fileHandleForWritingAtPath:part] retain];[_downloadHandle seekToEndOfFile];
    [_downloadPath release];_downloadPath=[part copy];_downloadReceived=(long long)existing;_downloadResumeOffset=(long long)existing;_downloadExpected=0;
    NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60];
    if([_filesToken length])[r setValue:_filesToken forHTTPHeaderField:@"X-iPad1VNC-Token"];
    if(existing>0)[r setValue:[NSString stringWithFormat:@"bytes=%llu-",existing] forHTTPHeaderField:@"Range"];
    _downloadConnection=[[NSURLConnection alloc]initWithRequest:r delegate:self startImmediately:YES];
    _downloadStatusLabel.text=(existing>0?[NSString stringWithFormat:@"Resuming %.1f MB",(double)existing/1048576.0]:@"Downloading…");
}
- (void)refreshFileList {
    NSArray *items=[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self downloadsDirectory] error:nil];
    NSMutableString *s=[NSMutableString string];
    for(NSString *name in [items sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]){
        NSString *fp=[[self downloadsDirectory] stringByAppendingPathComponent:name];
        NSDictionary *a=[[NSFileManager defaultManager] attributesOfItemAtPath:fp error:nil];
        unsigned long long bytes=[[a objectForKey:NSFileSize] unsignedLongLongValue];
        [s appendFormat:@"%@   %.1f KB\n",name,(double)bytes/1024.0];
    }
    if(![s length])[s appendString:@"No downloaded files yet."];
    _fileListView.text=s;
}
- (void)downloadTapped {
    NSString *u=[_downloadURLField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self startDownloadFromURL:[NSURL URLWithString:u]];
}
- (void)cancelDownloadTapped {_uploading=NO; if(_downloadConnection){[_downloadConnection cancel];[_downloadConnection release];_downloadConnection=nil;}if(_downloadHandle){[_downloadHandle closeFile];[_downloadHandle release];_downloadHandle=nil;}if(_downloadPath){[_downloadPath release];_downloadPath=nil;}_downloadStatusLabel.text=@"Cancelled — partial file kept for resume";_downloadProgress.progress=0; }
- (void)closeFilesTapped { [_downloadURLField resignFirstResponder]; _filesPanel.hidden=YES; }

- (void)streamUploadInfo:(NSDictionary*)info {
    NSAutoreleasePool*pool=[[NSAutoreleasePool alloc]init];NSString*lp=[info objectForKey:@"local"],*rp=[info objectForKey:@"remote"];NSDictionary*a=[[NSFileManager defaultManager]attributesOfItemAtPath:lp error:nil];unsigned long long total=[[a objectForKey:NSFileSize]unsignedLongLongValue];NSFileHandle*f=[NSFileHandle fileHandleForReadingAtPath:lp];if(!f){[pool drain];return;}
    NSDictionary *rst=[self remoteStatPath:rp];unsigned long long off=([[rst objectForKey:@"size"] unsignedLongLongValue]<=total?[[rst objectForKey:@"size"] unsignedLongLongValue]:0);if(off>0)[f seekToFileOffset:off];_uploading=YES;
    while(_uploading&&off<total){NSData*chunk=[f readDataOfLength:64*1024];if(![chunk length])break;NSString*esc=[rp stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];NSString*u=[NSString stringWithFormat:@"%@/api/upload-chunk?path=%@&offset=%llu&total=%llu",[_remoteBaseURL absoluteString],esc,off,total];NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:u] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];[r setHTTPMethod:@"POST"];[r setHTTPBody:chunk];[r setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];if([_filesToken length])[r setValue:_filesToken forHTTPHeaderField:@"X-iPad1VNC-Token"];NSURLResponse*resp=nil;NSError*err=nil;[NSURLConnection sendSynchronousRequest:r returningResponse:&resp error:&err];if(err)break;off+=[chunk length];NSNumber*pct=[NSNumber numberWithDouble:(total?(double)off/(double)total:0)];[self performSelectorOnMainThread:@selector(uploadProgressMain:) withObject:pct waitUntilDone:NO];}
    [f closeFile];_uploading=NO;[self performSelectorOnMainThread:@selector(uploadFinishedMain:) withObject:(off>=total?@"Upload complete":@"Upload failed/cancelled") waitUntilDone:NO];[pool drain];
}
- (void)uploadProgressMain:(NSNumber*)n {_downloadProgress.progress=[n floatValue];_downloadStatusLabel.text=[NSString stringWithFormat:@"Uploading %.0f%%",[n floatValue]*100.0];}
- (void)uploadFinishedMain:(NSString*)s {_downloadStatusLabel.text=s;_downloadProgress.progress=([s hasPrefix:@"Upload complete"]?1:0);[_currentTransfer release];_currentTransfer=nil;[self startBrowseURL:_remoteBaseURL];[self startNextTransfer];}

- (void)performFileAPIPath:(NSString*)path method:(NSString*)method body:(NSData*)body contentType:(NSString*)contentType {
    if(!_remoteBaseURL)return;NSURL *u=[NSURL URLWithString:[NSString stringWithFormat:@"%@%@",[_remoteBaseURL absoluteString],path]];
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:u cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [r setHTTPMethod:method];if([_filesToken length])[r setValue:_filesToken forHTTPHeaderField:@"X-iPad1VNC-Token"];
    if(contentType)[r setValue:contentType forHTTPHeaderField:@"Content-Type"];if(body)[r setHTTPBody:body];
    NSURLResponse *resp=nil;NSError *err=nil;NSData *d=[NSURLConnection sendSynchronousRequest:r returningResponse:&resp error:&err];
    if(err){_downloadStatusLabel.text=[NSString stringWithFormat:@"API failed: %@",[err localizedDescription]];return;}
    NSDictionary *o=(d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil);
    if([[o objectForKey:@"ok"] boolValue]){_downloadStatusLabel.text=@"Done";[self startBrowseURL:_remoteBaseURL];}
    else _downloadStatusLabel.text=[NSString stringWithFormat:@"API: %@",[o objectForKey:@"error"]?:@"failed"];
}
- (void)mkdirRemote {
    if(!_remoteBaseURL){_downloadStatusLabel.text=@"Browse first";return;}
    UIAlertView *a=[[[UIAlertView alloc] initWithTitle:@"New Folder" message:@"Folder name" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Create",nil] autorelease];a.tag=930;a.alertViewStyle=UIAlertViewStylePlainTextInput;[a show];
}
- (void)renameRemoteEntry:(NSDictionary*)entry {
    _selectedRemoteIndex=[_remoteEntries indexOfObjectIdenticalTo:entry];
    UIAlertView *a=[[[UIAlertView alloc] initWithTitle:@"Rename" message:@"New name" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Rename",nil] autorelease];a.tag=931;a.alertViewStyle=UIAlertViewStylePlainTextInput;[[a textFieldAtIndex:0] setText:[entry objectForKey:@"name"]];[a show];
}
- (void)deleteRemoteEntry:(NSDictionary*)entry {
    NSString *rp=[self remotePathForEntry:entry];NSDictionary *o=[NSDictionary dictionaryWithObject:rp forKey:@"path"];NSData *b=[NSJSONSerialization dataWithJSONObject:o options:0 error:nil];[self performFileAPIPath:@"/api/delete" method:@"POST" body:b contentType:@"application/json"];
}
- (void)uploadLocalFile {
    NSArray *files=[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self downloadsDirectory] error:nil];
    if(![files count]){_downloadStatusLabel.text=@"No local downloaded files to upload";return;}
    UIActionSheet *s=[[[UIActionSheet alloc] initWithTitle:@"Upload local file" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil] autorelease];s.tag=921;
    NSUInteger max=MIN((NSUInteger)12,[files count]);for(NSUInteger i=0;i<max;i++)[s addButtonWithTitle:[files objectAtIndex:i]];s.cancelButtonIndex=[s addButtonWithTitle:@"Cancel"];[s showInView:_filesPanel];
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {
    if(connection==_browseConnection){[_browseData setLength:0];return;}
    if(connection==_downloadConnection){
        NSInteger code=([response isKindOfClass:[NSHTTPURLResponse class]]?[(NSHTTPURLResponse*)response statusCode]:200);
        if(_downloadResumeOffset>0&&code!=206){[_downloadHandle truncateFileAtOffset:0];[_downloadHandle seekToFileOffset:0];_downloadReceived=0;_downloadResumeOffset=0;}
        long long remaining=[response expectedContentLength];_downloadExpected=(remaining>0?_downloadReceived+remaining:0);_downloadStatusLabel.text=[NSString stringWithFormat:@"Downloading %@",[_downloadPath lastPathComponent]];
    }
}
- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data {if(connection==_browseConnection){[_browseData appendData:data];return;}if(connection==_downloadConnection){[_downloadHandle writeData:data];_downloadReceived+=[data length];if(_downloadExpected>0)_downloadProgress.progress=(float)((double)_downloadReceived/(double)_downloadExpected);_downloadStatusLabel.text=[NSString stringWithFormat:@"%.1f / %.1f MB",(double)_downloadReceived/1048576.0,(_downloadExpected>0?(double)_downloadExpected/1048576.0:0.0)];}}
- (void)connectionDidFinishLoading:(NSURLConnection*)connection {if(connection==_browseConnection){[self parseDirectoryHTML:_browseData baseURL:_remoteBaseURL];[_browseConnection release];_browseConnection=nil;[_browseData release];_browseData=nil;return;}if(connection==_downloadConnection){[_downloadHandle closeFile];[_downloadHandle release];_downloadHandle=nil;[_downloadConnection release];_downloadConnection=nil;NSString*part=[[_downloadPath copy]autorelease];NSString*final=([part hasSuffix:@".part"]?[part substringToIndex:[part length]-5]:part);[[NSFileManager defaultManager]removeItemAtPath:final error:nil];[[NSFileManager defaultManager]moveItemAtPath:part toPath:final error:nil];_downloadProgress.progress=1.0;_downloadStatusLabel.text=[NSString stringWithFormat:@"Saved: %@",[final lastPathComponent]];[_downloadPath release];_downloadPath=nil;[_currentTransfer release];_currentTransfer=nil;[self refreshFileList];[self startNextTransfer];}}
- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {if(connection==_browseConnection){[_browseConnection release];_browseConnection=nil;[_browseData release];_browseData=nil;_downloadStatusLabel.text=[NSString stringWithFormat:@"Browse failed: %@",[error localizedDescription]];return;}if(connection==_downloadConnection){if(_downloadHandle){[_downloadHandle closeFile];[_downloadHandle release];_downloadHandle=nil;}[_downloadConnection release];_downloadConnection=nil;if(_downloadPath){[_downloadPath release];_downloadPath=nil;}_downloadStatusLabel.text=[NSString stringWithFormat:@"Failed — resumable: %@",[error localizedDescription]];_downloadProgress.progress=0;[_currentTransfer release];_currentTransfer=nil;[self startNextTransfer];}}
- (void)applicationDidEnterBackground:(UIApplication *)application { (void)application;if(_reconnectTimer){[_reconnectTimer invalidate];[_reconnectTimer release];_reconnectTimer=nil;}[self stopClipboardTimer]; }
- (void)applicationWillEnterForeground:(UIApplication *)application { (void)application;if(_shouldAutoReconnect&&!_client)[self scheduleReconnect];else if(_client)[self startClipboardTimer]; }

- (void)applicationDidReceiveMemoryWarning:(UIApplication*)application {
    (void)application;
    if(_terminalBuffer)[_terminalBuffer trimScrollbackTo:500];
    if(_browseData)[_browseData setLength:0];
    if(_remoteEntries&&[_remoteEntries count]>200){NSRange r=NSMakeRange(200,[_remoteEntries count]-200);[_remoteEntries removeObjectsInRange:r];[_remoteFilesTable reloadData];}
    _statusLabel.text=@"Memory pressure: caches trimmed";
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];_shouldAutoReconnect=NO;[self stopClipboardTimer];
    if(_reconnectTimer){[_reconnectTimer invalidate];[_reconnectTimer release];}
    if(_downloadConnection){[_downloadConnection cancel];[_downloadConnection release];}if(_downloadHandle){[_downloadHandle closeFile];[_downloadHandle release];}[_downloadPath release];
    _client.delegate=nil;[_client disconnect];[_client release];
    [_terminalSession stop];[_tunnelSession stop];[_terminalSession release];[_tunnelSession release];[_terminalBuffer release];[_terminalKeyBar release];[_terminalPanel release];[_terminalView release];[_terminalInput release];[_sshUserField release];[_sshPortField release];[_sshKeyField release];[_sshTunnelSwitch release];[_terminalButton release];
    [_filesToken release];[_filesTokenField release];[_remoteRelativePath release];
    [_filesPanel release];[_downloadURLField release];[_remoteFilesTable release];[_browseFilesButton release];[_filesUpButton release];[_remoteEntries release];[_remoteBaseURL release];[_browseData release];[_downloadStatusLabel release];[_downloadProgress release];[_fileListView release];[_keyBar release];
    [_toolsPanel release];[_wolMACField release];[_broadcastField release];[_remoteDisplayField release];[_autoResolutionSwitch release];[_diagnosticsLabel release];[_precisionSwitch release];[_dragLockSwitch release];[_lanResults release];[_toolsButton release];
    [_tlsSwitch release];[_transferQueue release];[_currentTransfer release];[_resumeRemotePath release];
    [_exitFullScreenButton release];[_fullScreenButton release];[_settingsButton release];[_filesButton release];[_keyboardButton release];[_qualityControl release];[_inputModeControl release];[_tightSwitch release];[_statsLabel release];[_profilesButton release];[_profiles release];[_speedSlider release];[_speedLabel release];
    [_vncView release];[_keyboardField release];[_statusLabel release];[_connectButton release];[_passwordField release];[_portField release];[_hostField release];[_connectionPanel release];[_controller release];[_window release];[super dealloc];
}
@end
