#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
h = root / "src" / "VNCClient.h"
m = root / "src" / "VNCClient.m"

hs = h.read_text()
ms = m.read_text()

if "NSString *_handshakeError;" not in hs:
    needle = "    SSLContextRef _ssl;\n    BOOL _tlsActive;\n"
    repl = "    SSLContextRef _ssl;\n    BOOL _tlsActive;\n    NSString *_handshakeError;\n"
    if needle not in hs:
        raise SystemExit("VNCClient.h anchor not found")
    hs = hs.replace(needle, repl, 1)

if "- (void)setHandshakeError:" not in ms:
    needle = '- (void)statusMain:(NSString*)s{if([_delegate respondsToSelector:@selector(vncClientStatus:)])[_delegate vncClientStatus:s];}\n'
    repl = needle + '- (void)setHandshakeError:(NSString*)s{if(_handshakeError==s)return;[_handshakeError release];_handshakeError=[s copy];}\n'
    if needle not in ms:
        raise SystemExit("statusMain anchor not found")
    ms = ms.replace(needle, repl, 1)

old = '_qualityProfile=VNCQualityBalanced;_serverBytesPerPixel=2;_lastEncoding=[@"RAW" retain];_ssl=NULL;_tlsActive=NO;'
new = '_qualityProfile=VNCQualityBalanced;_serverBytesPerPixel=2;_lastEncoding=[@"RAW" retain];_ssl=NULL;_tlsActive=NO;_handshakeError=nil;'
if old in ms:
    ms = ms.replace(old, new, 1)

old = '[_host release];[_password release];[_framebuffer release];[_writeLock release];[_lastEncoding release];[super dealloc];'
new = '[_host release];[_password release];[_framebuffer release];[_writeLock release];[_lastEncoding release];[_handshakeError release];[super dealloc];'
if old in ms:
    ms = ms.replace(old, new, 1)

start = ms.index('- (BOOL)startX509TLS {')
end = ms.index('- (void)requestUpdate:', start)
replacement = r'''- (BOOL)startX509TLS {
    if(_ssl)return YES;

    iPad1VNC_SSLNewContext_Fn newContext=iPad1VNC_SSLNewContextPtr();
    iPad1VNC_SSLSetEnableCertVerify_Fn setVerify=iPad1VNC_SSLSetEnableCertVerifyPtr();
    if(!newContext||!setVerify){
        [self setHandshakeError:@"TLS: SecureTransport symbols unavailable on iOS 5.1.1"];
        return NO;
    }

    SSLContextRef ctx=NULL;
    OSStatus st=newContext(false,&ctx);
    if(st!=noErr||!ctx){
        [self setHandshakeError:[NSString stringWithFormat:@"TLS: SSL context creation failed (%ld)",(long)st]];
        return NO;
    }

    st=SSLSetIOFuncs(ctx,iPad1VNCSSLRead,iPad1VNCSSLWrite);
    if(st!=noErr){[self setHandshakeError:[NSString stringWithFormat:@"TLS: SSLSetIOFuncs failed (%ld)",(long)st]];iPad1VNCDisposeSSLContext(ctx);return NO;}
    st=SSLSetConnection(ctx,(SSLConnectionRef)(intptr_t)_sock);
    if(st!=noErr){[self setHandshakeError:[NSString stringWithFormat:@"TLS: SSLSetConnection failed (%ld)",(long)st]];iPad1VNCDisposeSSLContext(ctx);return NO;}

    NSData *hn=[_host dataUsingEncoding:NSUTF8StringEncoding];
    if([hn length]){
        st=SSLSetPeerDomainName(ctx,[hn bytes],[hn length]);
        if(st!=noErr){[self setHandshakeError:[NSString stringWithFormat:@"TLS: peer name setup failed (%ld)",(long)st]];iPad1VNCDisposeSSLContext(ctx);return NO;}
    }

    st=setVerify(ctx,true);
    if(st!=noErr){[self setHandshakeError:[NSString stringWithFormat:@"TLS: certificate verification setup failed (%ld)",(long)st]];iPad1VNCDisposeSSLContext(ctx);return NO;}

    while(_running){
        st=SSLHandshake(ctx);
        if(st==noErr)break;
        if(st==errSSLWouldBlock){usleep(1000);continue;}
        [self setHandshakeError:[NSString stringWithFormat:@"TLS: handshake/certificate failed (%ld)",(long)st]];
        iPad1VNCDisposeSSLContext(ctx);
        return NO;
    }
    if(!_running){[self setHandshakeError:@"TLS: handshake cancelled"];iPad1VNCDisposeSSLContext(ctx);return NO;}

    _ssl=ctx;
    _tlsActive=YES;
    return YES;
}
- (BOOL)negotiateVeNCryptX509Vnc {
    uint8_t ver[2]={0};
    if(!recvAllTransport(_sock,NULL,ver,2)){[self setHandshakeError:@"TLS: VeNCrypt version was not received"];return NO;}
    if(ver[0]!=0||ver[1]<2){[self setHandshakeError:[NSString stringWithFormat:@"TLS: unsupported VeNCrypt version %u.%u",ver[0],ver[1]]];return NO;}

    uint8_t ours[2]={0,2};
    if(!sendAllTransport(_sock,NULL,ours,2)){[self setHandshakeError:@"TLS: could not send VeNCrypt 0.2 selection"];return NO;}
    uint8_t ack=1;
    if(!recvAllTransport(_sock,NULL,&ack,1)){[self setHandshakeError:@"TLS: VeNCrypt version acknowledgement missing"];return NO;}
    if(ack!=0){[self setHandshakeError:@"TLS: server rejected VeNCrypt 0.2"];return NO;}

    uint8_t count=0;
    if(!recvAllTransport(_sock,NULL,&count,1)){[self setHandshakeError:@"TLS: VeNCrypt subtype count missing"];return NO;}
    if(count==0){[self setHandshakeError:@"TLS: server offered no VeNCrypt subtypes"];return NO;}

    BOOL hasX509Vnc=NO;
    for(uint8_t i=0;i<count;i++){
        uint8_t b[4];
        if(!recvAllTransport(_sock,NULL,b,4)){[self setHandshakeError:@"TLS: VeNCrypt subtype list truncated"];return NO;}
        uint32_t stype=be32(b);
        if(stype==261)hasX509Vnc=YES;
    }
    if(!hasX509Vnc){[self setHandshakeError:@"TLS: server does not offer X509Vnc subtype 261"];return NO;}

    uint8_t selected[4];p32(selected,261);
    if(!sendAllTransport(_sock,NULL,selected,4)){[self setHandshakeError:@"TLS: could not select X509Vnc subtype 261"];return NO;}
    uint8_t subAck=0;
    if(!recvAllTransport(_sock,NULL,&subAck,1)){[self setHandshakeError:@"TLS: X509Vnc subtype acknowledgement missing"];return NO;}
    if(subAck!=1){[self setHandshakeError:@"TLS: server rejected X509Vnc subtype 261"];return NO;}
    if(![self startX509TLS])return NO;

    uint8_t challenge[16];
    if(!recvAllTransport(_sock,_ssl,challenge,16)){[self setHandshakeError:@"TLS: VNC authentication challenge missing after TLS"];return NO;}
    if(![self authVNC:challenge]){[self setHandshakeError:@"TLS: VNC authentication response failed"];return NO;}
    return YES;
}
- (BOOL)handshake {
    uint8_t v[12];
    if(!recvAllTransport(_sock,NULL,v,12)||memcmp(v,"RFB ",4)){[self setHandshakeError:@"RFB: invalid or missing server greeting"];return NO;}
    if(!sendAllTransport(_sock,NULL,"RFB 003.008\n",12)){[self setHandshakeError:@"RFB: could not send protocol version"];return NO;}

    uint8_t c=0;
    if(!recvAllTransport(_sock,NULL,&c,1)||!c){[self setHandshakeError:@"RFB: server offered no security types"];return NO;}
    uint8_t types[255];
    if(!recvAllTransport(_sock,NULL,types,c)){[self setHandshakeError:@"RFB: security type list truncated"];return NO;}

    uint8_t sel=0;
    BOOL hasVeNCrypt=NO,hasVnc=NO,hasNone=NO;
    for(int i=0;i<c;i++){if(types[i]==19)hasVeNCrypt=YES;else if(types[i]==2)hasVnc=YES;else if(types[i]==1)hasNone=YES;}

    if(_preferX509TLS){
        if(!hasVeNCrypt){[self setHandshakeError:@"TLS: server does not offer VeNCrypt security type 19"];return NO;}
        sel=19;
    }else if(hasVnc)sel=2;
    else if(hasNone)sel=1;

    if(!sel){[self setHandshakeError:@"RFB: no supported security type"];return NO;}
    if(!sendAllTransport(_sock,NULL,&sel,1)){[self setHandshakeError:@"RFB: security selection send failed"];return NO;}

    if(sel==19){
        if(![self negotiateVeNCryptX509Vnc])return NO;
    }else if(sel==2){
        uint8_t ch[16];
        if(!recvAllTransport(_sock,NULL,ch,16)){[self setHandshakeError:@"VNC auth: challenge missing"];return NO;}
        if(![self authVNC:ch]){[self setHandshakeError:@"VNC auth: response send failed"];return NO;}
    }

    uint8_t result[4];
    if(!recvAllTransport(_sock,_ssl,result,4)){[self setHandshakeError:(_tlsActive?@"TLS: VNC authentication result missing":@"VNC auth: result missing")];return NO;}
    if(be32(result)!=0){[self setHandshakeError:(_tlsActive?@"TLS: VNC authentication rejected":@"VNC authentication rejected")];return NO;}

    uint8_t shared=1;
    if(!sendAllTransport(_sock,_ssl,&shared,1)){[self setHandshakeError:@"RFB: ClientInit send failed"];return NO;}
    uint8_t init[24];
    if(!recvAllTransport(_sock,_ssl,init,24)){[self setHandshakeError:@"RFB: ServerInit missing"];return NO;}
    _fbWidth=be16(init);_fbHeight=be16(init+2);uint32_t nl=be32(init+20);
    if(nl){
        char*name=(char*)malloc(nl);
        BOOL ok=(name!=NULL)&&recvAllTransport(_sock,_ssl,name,nl);
        if(name)free(name);
        if(!ok){[self setHandshakeError:@"RFB: desktop name read failed"];return NO;}
    }
    [_framebuffer release];
    _framebuffer=[[NSMutableData alloc]initWithLength:_fbWidth*_fbHeight*4];
    if(![self sendPixelFormat]||![self sendEncodings]){[self setHandshakeError:@"RFB: pixel format/encoding setup failed"];return NO;}
    return YES;
}
'''
ms = ms[:start] + replacement + ms[end:]

old_network = '''- (void)networkThread{\n    NSAutoreleasePool*p=[[NSAutoreleasePool alloc]init];[self performSelectorOnMainThread:@selector(statusMain:) withObject:@"Connecting…" waitUntilDone:NO];\n    if(![self openSocket]||![self handshake]){[self disconnect];[self performSelectorOnMainThread:@selector(discMain:) withObject:@"Connection/authentication failed" waitUntilDone:NO];[p drain];return;}'''
new_network = '''- (void)networkThread{\n    NSAutoreleasePool*p=[[NSAutoreleasePool alloc]init];[self setHandshakeError:nil];[self performSelectorOnMainThread:@selector(statusMain:) withObject:@"Connecting…" waitUntilDone:NO];\n    if(![self openSocket]){[self setHandshakeError:@"TCP connection failed"];[self disconnect];[self performSelectorOnMainThread:@selector(discMain:) withObject:_handshakeError waitUntilDone:YES];[p drain];return;}\n    if(![self handshake]){NSString *reason=[[_handshakeError copy] autorelease];if(!reason)reason=@"Connection/authentication failed";[self disconnect];[self performSelectorOnMainThread:@selector(discMain:) withObject:reason waitUntilDone:YES];[p drain];return;}'''
if old_network not in ms:
    raise SystemExit("networkThread anchor not found")
ms = ms.replace(old_network, new_network, 1)

h.write_text(hs)
m.write_text(ms)
print("OK: beta4 TLS/VeNCrypt diagnostics applied to VNCClient.h/.m")
